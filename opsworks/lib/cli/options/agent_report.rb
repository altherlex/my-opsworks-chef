# encoding: UTF-8
require 'cli'
require 'cli/options/stack_state'
require 'bootstrap'
require 'bootstrap/updater'
require 'instance_agent'

module Cli
  module Options
    module AgentReport

      AgentReportError = Class.new(StandardError)

      include Cli::Logger
      include Cli::Options::StackState

      def agent_report
        updater = Bootstrap::Updater.new(
          :component => 'opsworks-agent-cli',
          :log_dir => '/var/log/aws/opsworks/'
        )

        state = raw_stack_state
        agent_status = ''

        if pid = InstanceAgent::Runner::Master.status
          agent_status = "The AWS OpsWorks agent is running as PID #{pid}"
        else
          agent_status = 'No AWS OpsWorks agent running'
        end

        status_message = <<-EO_MSG.strip_heredoc

          AWS OpsWorks Instance Agent State Report:

            Last activity was a "#{state[:last_command][:activity].to_s}" on #{Time.at(state[:last_command][:sent_at]).utc.to_s}
            Agent Status: #{agent_status}
            Agent Version: #{updater.send(:local_version)}, #{updater.update_needed? ? 'update needed' : 'up to date'}
        EO_MSG

        puts "%s\n" % status_message

        logger :info, 'Showed agent report'
      rescue Exception => e
        logger :error, "Could not show information about the current state of the opsworks agent: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        raise AgentReportError, "Could not show information about the current state of the opsworks agent: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
      end

    end
  end
end
