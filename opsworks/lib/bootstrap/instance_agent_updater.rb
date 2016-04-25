$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))
require 'bootstrap'
require 'bootstrap/updater'

module Bootstrap
  class InstanceAgentUpdater < Bootstrap::Updater

    File.umask 077

    def self.run
      new.run
    end

    def initialize(options = {})
      options = {
        :component => 'agent-updater'
      }.update(options)
      super(options)
    end

    def run
      if Process.uid != 0
        msg = "This action cannot be execute as an unprivileged user. You must run this command as 'root' or using `sudo`"
        $stderr.puts msg
        Bootstrap::Log.error msg
        return 1
      end

      if update_needed?
        if update_failed_recently?
          Bootstrap::Log.info "Skipping attempt to update the instance agent to version #{target_version}, another update attempt failed less than 10 minutes ago"
        else
          Bootstrap::Log.info "Updating the instance agent to version #{target_version}"
          Bootstrap::Log.measure("Downloading new agent version #{target_version}"){ download }
          Bootstrap::Log.measure('Updating the agent'){ update_or_rollback }
        end
      else
        Bootstrap::Log.info "Skipping update (target version: #{target_version}, local version: #{local_version}, local revision: #{local_revision})"
      end
    end

  end
end
