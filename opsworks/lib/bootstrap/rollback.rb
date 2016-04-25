# get the current environment
load File.expand_path(File.dirname(__FILE__) + '/../bootstrap.rb')
load File.expand_path(File.dirname(__FILE__) + '/config.rb')
load File.expand_path(File.dirname(__FILE__) + '/log.rb')
load File.expand_path(File.dirname(__FILE__) + '/os_detect.rb')
load File.expand_path(File.dirname(__FILE__) + '/utils.rb')
load File.expand_path(File.dirname(__FILE__) + '/system.rb')
load File.expand_path(File.dirname(__FILE__) + '/installer.rb')
load File.expand_path(File.dirname(__FILE__) + '/updater.rb')

module Bootstrap
  class Rollback < Bootstrap::Updater

    def self.run(options = {})
      new(options).run
    end

    def initialize(options = {})
      # :release_dir => nil to recalculate release_dir
      options = {
        :component => 'rollback',
        :release_dir => nil,
      }.update(options)
      super(options)
    end

    def run
      set_path
      Bootstrap::Log.measure('Symlinking the last agent to be current again'){ symlink_current_release }
      Bootstrap::Log.measure('Stoping monit'){ stop_monit }
      Bootstrap::Log.measure('Bootstrapping monit'){ install_instance_agent_monit }
      Bootstrap::Log.measure('Make sure any instance agent processes are stopped'){ stop_agent && wait_until_agent_dies }
      Bootstrap::Log.measure('Checking installation'){ agent_starts? }
      Bootstrap::Log.measure('Starting monit'){ start_monit }
    end

  end
end
