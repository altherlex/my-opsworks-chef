require File.expand_path(File.dirname(__FILE__) + '/../bootstrap')
require File.expand_path(File.dirname(__FILE__) + '/../bootstrap/registration')

module Bootstrap
  class InstanceAgentRegistrationInstaller < Bootstrap::Installer
    include Bootstrap::Utils
    include Bootstrap::System
    include Bootstrap::Registration

    def self.run
      new.run
    end

    def initialize(options = {})
      options = {
        :component => 'agent-installer',
        :log_file => '/var/log/aws/opsworks/installer.log'
      }.update(options)
      super(options)
    end

    def run
      set_path
      Bootstrap::Log.measure('Enable additional repositories'){ enable_additional_repositories }
      Bootstrap::Log.measure('Install system updates'){ install_system_updates }
      Bootstrap::Log.measure('Installing legacy OS packages'){ install_legacy_os_packages }
      Bootstrap::Log.measure('Installing OS packages'){ install_os_packages }
      Bootstrap::Log.measure('Creating registration agent config'){ generate_agent_config }
      Bootstrap::Log.measure('Setting the hostname'){ set_hostname }
      Bootstrap::Log.measure('Enabling OS services'){ enable_os_services }
      Bootstrap::Log.measure('Installing instance agent'){ install_instance_agent }
      Bootstrap::Log.measure('Installing bundled gems'){ install_bundled_gems }
      Bootstrap::Log.measure('Installing lockrun'){ install_lockrun }
      Bootstrap::Log.measure('Setting up and configuring sudo policies'){ configure_sudo }
      Bootstrap::Log.measure('Setting up instance agent user and permissions'){ setup_instance_agent_user_and_permissions }
      Bootstrap::Log.measure('Linking instance agent'){ symlink_current_release }
      Bootstrap::Log.measure('Bootstrapping monit'){ install_instance_agent_monit }
      Bootstrap::Log.measure('Installing instance updater cron job'){ install_updater_cron_job }
      Bootstrap::Log.measure('Setting up log rotation'){ setup_logrotate }
      Bootstrap::Log.measure('Cleaning up pre-config'){ cleanup_pre_config }
      Bootstrap::Log.info "Successfully installed the agent on instance #{instance_id}"

      begin
        IO.for_fd(3).puts("Instance successfully registered. Instance ID: #{instance_id}")
      rescue Error::EBADF
      end
    end

    def install_system_updates
      return unless debian_family?
      ENV["DEBIAN_FRONTEND"] = "noninteractive"
      system("dpkg --configure -a")
      apt_get("update")
    end

    def instance_id
      YAML.load(File.open(config[:agent_config_file]))[:identity]
    rescue Exception => e
      Bootstrap::Log.error "Could not retrieve instance id: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
      ''
    end

    # overwrite the utils method to set OpsWorks Instance Name
    def instance_hostname
      YAML.load(File.open(config[:agent_config_file]))[:hostname]
    rescue Exception => e
      Bootstrap::Log.error "Could not retrieve instance hostname: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
      ''
    end

    def reboot_required?
      false
    end
  end
end
