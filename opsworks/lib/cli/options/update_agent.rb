# encoding: UTF-8
require 'cli'

module Cli
  module Options
    module UpdateAgent

      include Cli::Logger

      UPDATER_CODE = <<-EO_SCRIPT.gsub!(/^\ +/,'')
        #!/opt/aws/opsworks/local/bin/ruby
        $: << '#{File.expand_path(File.dirname(__FILE__) + '/../../..' ) + '/lib'}'
        require 'bootstrap'
        require 'bootstrap/instance_agent_updater'
        puts "Updating OpsWorks Agent from CLI"
        Bootstrap::InstanceAgentUpdater.run
      EO_SCRIPT

      def update_agent
        Dir.mktmpdir do |tmpdir|
          opsworks_agent_updater = "#{tmpdir}/opsworks_agent_updater.rb"

          File.open(opsworks_agent_updater, 'w') do |opsworks_agent_updater_file|
            opsworks_agent_updater_file.puts(UPDATER_CODE)
          end

          FileUtils.chmod 0700, opsworks_agent_updater#.path

          lockrun = "#{@config[:root_dir]}/bin/lockrun"
          lockrun_lock = "#{@config[:shared_dir]}/lockrun.lock"
          args = [
            lockrun, '--wait',
                      '--verbose',
                      "--lockfile=#{lockrun_lock}",
                      '--',
                      opsworks_agent_updater, '2>&1'
          ]

          logger :info, "Updating instance agent"
          duration = Benchmark.realtime { system(*args) }

          if $?.success?
            logger :info, "Successfully updated instance agent. Elapsed Time: #{duration}"
          else
            logger :error, "Failed to update the instance agent. Please check the updater log file and report failures through our support channels"
          end
        end
      end
    end
  end
end
