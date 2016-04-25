load File.expand_path(File.dirname(__FILE__) + '/../bootstrap.rb')
load File.expand_path(File.dirname(__FILE__) + '/config.rb')
load File.expand_path(File.dirname(__FILE__) + '/log.rb')
load File.expand_path(File.dirname(__FILE__) + '/os_detect.rb')
load File.expand_path(File.dirname(__FILE__) + '/utils.rb')
load File.expand_path(File.dirname(__FILE__) + '/system.rb')
load File.expand_path(File.dirname(__FILE__) + '/installer.rb')
load File.expand_path(File.dirname(__FILE__) + '/updater.rb')

File.umask 077

module Bootstrap
  class UpdateInstaller < Bootstrap::Updater

    def self.run(options = {})
      new(options).run
    end

    def initialize(options = {})
      # trigger regeneration of this release's path with :release_dir => nil
      options = {
        :component => 'update-installer',
        :release_dir => nil
      }.update(options)
      super(options)
    end

    def run
      set_path
      Bootstrap::Log.measure('Installing ruby'){ install_ruby }
      Bootstrap::Log.measure('Installing new instance agent'){ install_instance_agent }
      Bootstrap::Log.measure('Installing new bundled gems'){ install_bundled_gems }
      Bootstrap::Log.measure('Installing new lockrun'){ install_lockrun }
      Bootstrap::Log.measure('Symlinking new instance agent'){ symlink_current_release }
      Bootstrap::Log.measure('Setting up new instance agent user and permissions'){ setup_instance_agent_user_and_permissions }
      Bootstrap::Log.measure('Stoping monit'){ stop_monit }
      Bootstrap::Log.measure('Setting up and configure sudo policies'){ configure_sudo }
      Bootstrap::Log.measure('Bootstrapping monit'){ install_instance_agent_monit }
      Bootstrap::Log.measure('Checking updater cronjob'){ install_updater_cron_job }
      # if we've a problem starting the agent, we've rollback on the updater.
      Bootstrap::Log.measure('Checking installation'){ agent_starts? }
      Bootstrap::Log.measure('Starting monit'){ start_monit }
    end
  end
end
