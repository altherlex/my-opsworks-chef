require File.expand_path(File.dirname(__FILE__) + '/../bootstrap')

module Bootstrap
  class InstanceAgentInstaller < Bootstrap::Installer

    include Bootstrap::Utils
    include Bootstrap::System

    def self.run
      new.run
    end

    def initialize(options = {})
      options = {
        :component => 'agent-installer',
        :log_file => "/var/log/aws/opsworks/installer.log",
        :last_reboot_file => "/var/lib/aws/opsworks/last_reboot"
      }.update(options)
      super(options)
    end

    def run
      set_path
      Bootstrap::Log.measure('Enable additional repositories'){ enable_additional_repositories }
      Bootstrap::Log.measure('Install system updates'){ install_system_updates }
      Bootstrap::Log.measure('Installing legacy OS packages'){ install_legacy_os_packages }
      Bootstrap::Log.measure('Installing OS packages'){ install_os_packages }
      Bootstrap::Log.measure('Enabling OS services'){ enable_os_services }
      Bootstrap::Log.measure('Setting the hostname'){ set_hostname }
      Bootstrap::Log.measure('Installing instance agent'){ install_instance_agent }
      Bootstrap::Log.measure('Creating agent config'){ generate_agent_config }
      Bootstrap::Log.measure('Installing bundled gems'){ install_bundled_gems }
      Bootstrap::Log.measure('Installing lockrun'){ install_lockrun }
      Bootstrap::Log.measure('Setting up and configuring sudo policies'){ configure_sudo }
      Bootstrap::Log.measure('Setting up instance agent user and permissions'){ setup_instance_agent_user_and_permissions }
      Bootstrap::Log.measure('Linking instance agent'){ symlink_current_release }
      Bootstrap::Log.measure('Bootstrapping monit'){ install_instance_agent_monit }
      Bootstrap::Log.measure('Installing instance updater cron job'){ install_updater_cron_job }
      Bootstrap::Log.measure('Setting up log rotation'){ setup_logrotate }
      Bootstrap::Log.measure('Cleaning up pre-config'){ cleanup_pre_config }
      Bootstrap::Log.info 'Successfully installed the agent'
      reboot_if_required
    end

    def install_system_updates
      if debian_family?
        ENV["DEBIAN_FRONTEND"] = "noninteractive"
        system("dpkg --configure -a")
        apt_get("update")
      end

      return unless install_updates_on_boot?

      if debian_family?
        apt_get("dist-upgrade")
      elsif rhel_family?
        yum("update")
      end
    end

    def reboot_if_required
      if ENV["OPSWORKS_USERDATA_HANDLES_REBOOT"]
        Bootstrap::Log.info "Reboot handled by userdata."
        return
      end

      if reboot_required?
        if reboot_allowed?
          Bootstrap::Log.info "Reboot required, rebooting instance."
          FileUtils.touch(config[:last_reboot_file])
          system("reboot")
        else
          Bootstrap::Log.info "Reboot not allowed, last reboot was within 15 minutes. Reboot loop?"
          start_monit
        end
      else
        Bootstrap::Log.info "Reboot not required."
        start_monit
      end
    end

    def start_monit
      system("/etc/init.d/monit restart")
    end

    def reboot_required?
      if debian_family?
        File.exist?("/var/run/reboot-required")
      elsif rhel_family?
        latest_installed_kernel = `rpm -q --last kernel`.gsub(/^kernel-(\S+).*/, '\1').lines.first
        currently_used_kernel = `uname -r`
        latest_installed_kernel != currently_used_kernel
      else
        false
      end
    end

    def reboot_allowed?
      if File.exist?(config[:last_reboot_file])
        File.mtime(config[:last_reboot_file]) < (Time.now - (15 * 60))
      else
        true
      end
    end

    # overwrite the utils method to set OpsWorks Instance Name
    def instance_hostname
      read_pre_config_file[:hostname]
    rescue Exception => e
      Bootstrap::Log.error "Could not retrieve instance hostname: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
      ''
    end

    def install_updates_on_boot?
      read_pre_config_file[:install_updates_on_boot]
    rescue
      false
    end

    def read_pre_config_file
      @pre_config ||= YAML.load(File.open(config[:agent_pre_config_file]))
    end
  end
end
