#!/usr/bin/env bash
set -e

package_file=''
INSTALL_AGENT='true'
DOWNLOAD_DIR_PREFIX="/tmp/opsworks-downloader"
DEFAULT_ASSETS_BUCKET="opsworks-instance-assets-us-east-1.s3.amazonaws.com"

USAGE=<<EOL

  Usage: $0 [-r] [-R <asset-bucket>]
    -r Only install ruby packages. [default is false]
    -R Download assets from given asset bucket

  This script will install the agent's ruby environment and the instance agent itself. With the
  '-r' option it will only install the ruby environment.
EOL

# detect os platform, family, version and architecture

get_redhatish_platform() {
  local file="$1"
  if grep -q "Red Hat" "$file"; then
    echo "redhat"
  elif grep -q "CentOS" "$file"; then
    echo "redhat"
  elif grep -q "Amazon Linux" "$file"; then
    echo "amazon"
  else
    cat "$file"
  fi
}

get_redhatish_version() {
  local file="$1"
  sed "s/.*release \([0-9.]\+\).*/\1/" < "$file"
}

get_redhatish_architecture() {
  case $(uname -i) in
    x86_64)
      echo "x86_64" ;;
    i386|i686)
      echo "i686" ;;
    *)
      uname -i
  esac
}

get_debianish_architecture() {
  case $(uname -i) in
    x86_64)
      echo "amd64" ;;
    i386|i686)
      echo "i386" ;;
    *)
      uname -i
  esac
}

detect_platform_and_architecture() {
  local _platform="$1"
  case "$_platform" in
    "debian"|"ubuntu")
      platform_family="debian"
      architecture=$(get_debianish_architecture)
      ;;
    "centos"|"redhat"|"amazon")
      platform_family="rhel"
      architecture=$(get_redhatish_architecture)
      ;;
    *)
      echo "Unsupported OS: $_platform." >&2
      exit 1
      ;;
  esac
}

detect_os() {
  shopt -s nocasematch # case insensitive match for comparision with [Uu]buntu
  if [[ -x "/usr/bin/lsb_release" ]]; then
    LSB_ID=$(lsb_release -si)
    LSB_RELEASE=$(lsb_release -sr)
  elif [[ -f "/etc/lsb-release" ]]; then
    LSB_ID=$(grep DISTRIB_ID /etc/lsb-release | sed "s/^DISTRIB_ID=\(.*\)$/\1/")
    LSB_RELEASE=$(grep DISTRIB_RELEASE /etc/lsb-release | sed -e "s/^DISTRIB_RELEASE=\(.*\)$/\1/")
  fi

  if [[ -e "/etc/debian_version" ]]; then
    if [[ "$LSB_ID" =~ Ubuntu ]]; then
      platform="ubuntu"
      platform_version="$LSB_RELEASE"
    else
      platform="debian"
      platform_version=$( cat "/etc/debian_version")
    fi
  elif [[ -e "/etc/redhat-release" ]]; then
    platform=$(get_redhatish_platform "/etc/redhat-release")
    platform_version=$(get_redhatish_version "/etc/redhat-release")
    platform_version="${platform_version%%.[0-9.]*}" # strip minor version for RHEL
  elif [[ -e "/etc/system-release" ]]; then
    platform=$(get_redhatish_platform "/etc/system-release")
    platform_version=$(get_redhatish_version "/etc/system-release")
  else
    platform="$LSB_ID"
    platform_version="$LSB_RELEASE"
  fi

  detect_platform_and_architecture "$platform"
  shopt -u nocasematch # disable case insensitive match
}

# download and install ruby

ruby_version() {
  case "${platform}#${platform_version}" in
    "amazon#2014.09"|"amazon#2015.03"|"amazon#2015.09"|"ubuntu#14.04"|"ubuntu#12.04"|"redhat#7"|"redhat#6")
      echo "2.0.0-p645" ;;
    "amazon#2012.09"|"amazon#2013.03"|"amazon#2013.09")
      echo "2.0.0-p451" ;;
    *) # not supported OS release
      echo "2.0.0-p481"
  esac
}

package_name() {
  local name="opsworks-agent-ruby"
  local release="1"

  case "$platform_family" in
    "rhel")
      echo "${name}-$(ruby_version)-${release}.${architecture}.rpm"
      ;;
    "debian")
      echo "${name}_$(ruby_version)-${release}_${architecture}.deb"
      ;;
    *)
      echo "Unsupported OS family: $platform_family" >&2
      exit 1
      ;;
  esac
}

download_url() {
  echo "https://${ASSETS_DOWNLOAD_BUCKET}/packages/$platform/$platform_version/$(package_name)"
}

download_package () {
  echo "Downloading agent ruby package"
  package_file=$("$(dirname "${BASH_SOURCE[0]}")/downloader.sh" -u "$(download_url)" -d "$DOWNLOAD_DIR_PREFIX")
  if [ $? -gt 0 ]
  then
    exit $?
  fi
}

install_ruby () {
  echo "Installing agent ruby"
  case "$platform_family" in
    "rhel")
      rpm -Uvh --nodeps --force "$package_file" ;;
    "debian")
      dpkg -i "$package_file" ;;
    *)
      echo "Unsupported OS family: $platform_family" >&2
      exit 1
      ;;
  esac
}

# Install agent

install_agent () {
  #Execute agent installer using the agent ruby
  echo "Installing instance agent"
  /opt/aws/opsworks/local/bin/ruby "$( dirname "${BASH_SOURCE[0]}" )/opsworks-agent-installer.rb"
}

cleanup_previous_run() {
  for package_dir in ${DOWNLOAD_DIR_PREFIX}*; do
    if [[ -n "$package_dir" ]] && [[ "$package_dir" != '/' ]] && [[ -n "$(find "$package_dir" -maxdepth 0 -mmin +60 2>/dev/null)" ]]; then
      rm -rf "$package_dir"
    fi
  done
}

cleanup () {
  echo "Cleanning up"
  if [ "$( dirname "$package_file" )" != '' ] && [ "$( dirname "$package_file" )" != '/' ]
  then
    rm -rf "$( dirname "$package_file" )"
  else
    echo "Failed to cleanup tmp directory"
  fi
}

#
# Main block

while getopts "rR:h" optname
do
  case "$optname" in
    "r")
      # don't install the agent
      INSTALL_AGENT='false'
      ;;
    "R")
      ASSETS_DOWNLOAD_BUCKET="${OPTARG}"
      echo "Using $ASSETS_DOWNLOAD_BUCKET for assets."
      ;;
  esac
done

if [ -z "${ASSETS_DOWNLOAD_BUCKET}" ]
then
  ASSETS_DOWNLOAD_BUCKET=$DEFAULT_ASSETS_BUCKET
  echo "Using $ASSETS_DOWNLOAD_BUCKET for assets (default)."
fi

detect_os
cleanup_previous_run
download_package
install_ruby

if [ ${INSTALL_AGENT} == 'true'  ]
then
  install_agent
fi

cleanup
