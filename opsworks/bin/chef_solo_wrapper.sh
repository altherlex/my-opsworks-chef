#! /bin/bash

# Wrapper for chef-solo to catch STDOUT and STDERR into a file,
# necessary because this is run with sudo

while getopts "s:j:c:L:h" optname
do
  case "$optname" in
    "s")
      # path to the chef-solo binary
      CHEF_SOLO="$OPTARG"
      ;;
    "L")
      # the log file to use
      CHEF_LOG_FILE="$OPTARG"
      ;;
    "j")
      # the opsworks json
      JSON_FILE="$OPTARG"
      ;;
    "c")
      # the chef configuration file
      CHEF_CONFIG="$OPTARG"
      ;;
    "h")
      usage
      exit 0
      ;;
    *)
      echo "Unknown error while processing options"
      usage
      exit 1
      ;;
  esac
done

usage(){
  cat <<EOL

  Usage: $0 -s <CHEF_SOLO> -j <JSON_FILE> -c <CHEF_CONFIG> -L <CHEF_LOG_FILE>
   -s Absolute path to the chef-solo executable.
   -j Absolute path to the JSON file.
   -c Absolute path to the chef configuration file.
   -L Absolute path to the for the chef log file to be created by chef.
   -h Show this stuff.

   This script acts as a wrapper for chef-solo and will redirect STDOUT and STDERR
   into the logfile.

   This script is meant to be used only from the process_command daemon.

EOL
}

if [ -z "$CHEF_SOLO" ] || [ -z "$JSON_FILE" ] || [ -z "$CHEF_CONFIG" ] || [ -z "$CHEF_LOG_FILE" ]
then
  echo "[ERROR] Parameter missing."
  usage
  exit 1
fi

_RUBYOPT="-E utf-8"

echo "[$(date  +%c)] About to execute: RUBYOPT=\"$_RUBYOPT\" \"$CHEF_SOLO\" -j \"$JSON_FILE\" -c \"$CHEF_CONFIG\" 2>&1"

# create the log file readable for the aws user
touch $CHEF_LOG_FILE && chmod 644 $CHEF_LOG_FILE

exec &> >(tee -a ${CHEF_LOG_FILE}) 2>&1
RUBYOPT="$_RUBYOPT" "$CHEF_SOLO" -j "$JSON_FILE" -c "$CHEF_CONFIG"
