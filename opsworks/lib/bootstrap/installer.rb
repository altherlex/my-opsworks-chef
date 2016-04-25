require 'fileutils'
require 'yaml'

module Bootstrap
  class Installer

    include Bootstrap::Utils
    include Bootstrap::System

    attr_reader :config

    def self.run
      new.run
    end

    def initialize(options = {})
      options = {
        :component => 'agent-installer',
        :config_file => "#{File.dirname(__FILE__)}/../../conf/bootstrap.yml",
        :log_file => nil
      }.update(options)
      _config = Bootstrap::Config.load_config(options[:config_file])
      _config.config(options)
      _config.validate
      @config = _config.config
      Bootstrap::Log.init(config[:log_file])
    end

    def generate_agent_config
      if File.exists?(config[:agent_pre_config_file])
        FileUtils.mkdir_p File.dirname(config[:agent_config_file])
        File.open(config[:agent_config_file], 'w') do |f|
          f.print YAML.dump({
            :program_name => config[:program_name],
            :root_dir => config[:current_agent_symlink],
            :shared_dir => config[:shared_dir],
            :log_dir => config[:log_dir],
            :pid_dir => config[:pid_dir],
            :user => config[:user],
            :group => config[:group]
           }.merge YAML.load(File.open(config[:agent_pre_config_file]))
         )
        end
      else
        Bootstrap::Log.info 'Skipped generation of agent configuration.'
      end
    rescue Exception => e
        raise "Failed to write agent configuration file: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
    end

    def create_agent_root_dir_skeleton
      Bootstrap::Log.info 'Creating basic directory structure'
      FileUtils.mkdir_p(config[:releases_dir], :mode => 0750)

      [config[:log_dir], config[:shared_dir], config[:pid_dir]].each do |dir|
        File.umask 0022
        FileUtils.mkdir_p dir
      end
    end

    def install_ruby
      installer_script = File.join(File.dirname(__FILE__), '/../../bin/installer_wrapper.sh')
      configuration = YAML.load(File.read(config[:agent_config_file]))
      execute "#{installer_script} -r -R '#{configuration[:assets_download_bucket]}'"

      unless File.readable?(config[:ruby_bin]) && File.executable?(config[:ruby_bin])
        raise "The ruby binary is not executable or readable."
      end
    end

    def install_instance_agent
      if File.exists?(config[:release_dir])
        if File.exists?(config[:current_agent_symlink]) && File.readlink(config[:current_agent_symlink]) == config[:release_dir]
          raise "#{config[:release_dir]} already exists and is current - aborting."
        else
          Bootstrap::Log.warn "The release #{config[:release_dir]} already existed - deleting before re-installing"
          FileUtils.rm_rf config[:release_dir]
        end
      end
      create_agent_root_dir_skeleton
      Bootstrap::Log.info 'Populating agent home directory with current release'
      File.umask 0227
      FileUtils.cp_r "#{File.dirname(__FILE__)}/../../", config[:release_dir]
      # Create the TARGET_VERSION file, only during initial installation.
      # It will be updated per cookbook.
      FileUtils.cp "#{config[:release_dir]}/VERSION", "#{config[:shared_dir]}/TARGET_VERSION" unless File.exists?("#{config[:shared_dir]}/TARGET_VERSION")
      FileUtils.chmod 0640, "#{config[:shared_dir]}/TARGET_VERSION"
    end

    def unlink_last_release
      Bootstrap::Log.info 'Unlinking last release'
      FileUtils.rm config[:current_agent_symlink], :verbose => true
      FileUtils.rm "/etc/init.d/#{config[:program_name]}", :verbose => true
      FileUtils.rm "#{config[:agent_client_symlink_target_dir]}/#{config[:agent_client_file_name]}", :verbose => true
    end

    def symlink_current_release
      Bootstrap::Log.info 'Linking new release'
      raise "Link target #{config[:release_dir]} does not exist - aborting in order not to break agent installation." unless File.exists?(config[:release_dir])
      unlink_last_release if File.exist?(config[:current_agent_symlink])
      FileUtils.ln_sf config[:release_dir], config[:current_agent_symlink]
      FileUtils.ln_sf "#{config[:current_agent_symlink]}/bin/#{config[:program_name]}", '/etc/init.d/'
      FileUtils.ln_sf config[:agent_client], config[:agent_client_symlink_target_dir]
    end

    def setup_instance_agent_user_and_permissions
      unless (Etc.getgrnam(config[:group]) rescue false)
        Bootstrap::Log.info 'Creating agent system group'
        execute "groupadd --system #{config[:group]}"
      end
      unless (Etc.getpwnam(config[:user]) rescue false)
        Bootstrap::Log.info 'Creating agent system user'
        execute "useradd --system --home-dir #{config[:current_agent_symlink]} -g #{config[:group]} --shell /bin/bash #{config[:user]}"
      end
      Bootstrap::Log.info 'Ensuring file system ownership policies'
      FileUtils.chown 'root', config[:group], [config[:root_dir], config[:releases_dir]]
      FileUtils.chown_R config[:user], config[:group], [config[:log_dir], config[:shared_dir]]
      FileUtils.chown_R 'root', config[:group], config[:release_dir]

      Bootstrap::Log.info 'Ensuring file system access policies'
      FileUtils.chmod 0550, Dir.glob("#{config[:release_dir]}/bin/*")
      FileUtils.chmod 0644, Dir.glob("#{config[:log_dir]}/*.log")
      # ensure the way into root_dir, shared_dir and log_dir is open
      FileUtils.chmod 0755, File.expand_path('..', config[:root_dir])
      FileUtils.chmod 0755, File.expand_path('..', config[:shared_dir])
      FileUtils.chmod 0755, File.expand_path('..', config[:log_dir])
      prepare_lockrun
    end

    def cleanup_pre_config
      if File.exists? config[:agent_pre_config_file]
        Bootstrap::Log.info 'Deleting pre-configuration file.'
        FileUtils.rm config[:agent_pre_config_file]
      end
    end

    def enable_additional_repositories
      if redhat? && platform_version.start_with?("7")
        system("rpm -Uvh 'http://download.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm'") unless rpm_installed? "epel-release-7-5.noarch"
        # yum-config-manager will one enable repositories that are already defined, but disabled. It will exit 0, even when the repo is not defined
        system("yum-config-manager --enable rhui-REGION-rhel-server-optional")
        system("yum-config-manager --enable rhui-REGION-rhel-server-rhscl")
      elsif redhat? && platform_version.start_with?("6")
        system("rpm -Uvh 'http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm'") unless rpm_installed? "epel-release-6-8.noarch"
        # yum-config-manager will one enable repositories that are already defined, but disabled. It will exit 0, even when the repo is not defined
        system("yum-config-manager --enable rhui-REGION-rhel-server-releases-optional")
      elsif ubuntu?
        code_name = ubuntu_code_name
        IO.write("/etc/apt/sources.list.d/#{code_name}-multiverse.list", <<EOM
deb http://archive.ubuntu.com/ubuntu/ #{code_name} main universe
deb-src http://archive.ubuntu.com/ubuntu/ #{code_name} main universe
deb http://archive.ubuntu.com/ubuntu/ #{code_name}-updates main universe
deb-src http://archive.ubuntu.com/ubuntu/ #{code_name}-updates main universe
deb http://archive.ubuntu.com/ubuntu/ #{code_name}-security main universe
deb-src http://archive.ubuntu.com/ubuntu/ #{code_name}-security main universe
deb http://archive.ubuntu.com/ubuntu/ #{code_name}-updates multiverse
deb-src http://archive.ubuntu.com/ubuntu/ #{code_name}-updates multiverse
deb http://archive.ubuntu.com/ubuntu/ #{code_name}-security multiverse
deb-src http://archive.ubuntu.com/ubuntu/ #{code_name}-security multiverse
deb http://archive.ubuntu.com/ubuntu/ #{code_name} multiverse
deb-src http://archive.ubuntu.com/ubuntu/ #{code_name} multiverse
deb http://security.ubuntu.com/ubuntu #{code_name}-security multiverse
deb-src http://security.ubuntu.com/ubuntu #{code_name}-security multiverse
EOM
                )
      end
    end

    def install_legacy_os_packages
      if amazon_linux?
        %w(ruby18 ruby18-devel rubygems18).each { |pkg| install_package pkg }
      elsif ubuntu? && platform_version == "14.04"
        %w(ruby ruby-dev).each { |pkg| install_package pkg }
      elsif ubuntu? && platform_version == "12.04"
        %w(ruby ruby-dev rubygems libopenssl-ruby).each { |pkg| install_package pkg }
      end
    end

    def enable_os_services
      enable_service "monit"
    end

    def install_os_packages
      if debian_family?
        ENV["DEBIAN_FRONTEND"] = "noninteractive"
        install_package "build-essential"
        %w(libicu-dev libssl-dev libxslt-dev libxml2-dev).each { |pkg| install_package(pkg) }
      elsif rhel_family?
        yum "groupinstall 'Development Tools'"
        %w(libicu-devel openssl-devel libxml2-devel libxslt-devel).each { |pkg| install_package(pkg) }
      end

      install_package "monit"
    end
  end
end
