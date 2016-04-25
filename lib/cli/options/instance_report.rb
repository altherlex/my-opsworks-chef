# encoding: UTF-8
require 'cli'
require 'cli/options/stack_state'
require 'bootstrap'
require 'bootstrap/updater'

module Cli
  module Options
    module InstanceReport

      InstanceReportError = Class.new(StandardError)

      include Cli::Options::StackState
      include Cli::Logger

      def instance_report
        report
      end

      protected
      def report
        _agent_status = ''
        if pid = InstanceAgent::Runner::Master.status
          _agent_status = "The AWS OpsWorks agent is running as PID #{pid}"
        else
          _agent_status = 'No AWS OpsWorks agent running'
        end

        updater = Bootstrap::Updater.new(
          :component => 'opsworks-agent-cli',
          :log_dir => '/var/log/aws/opsworks/'
        )

        state = raw_stack_state
        cpu_info = File.read('/proc/cpuinfo')

        message = <<-EO_MSG.strip_heredoc

          AWS OpsWorks Instance Agent State Report:

            Last activity was a "#{state[:last_command][:activity].to_s}" on #{Time.at(state[:last_command][:sent_at]).utc.to_s}
            Agent Status: #{_agent_status}
            Agent Version: #{updater.send(:local_version)}, #{updater.update_needed? ? 'update needed' : 'up to date'}
            OpsWorks Stack: #{state[:stack]['name']}
            OpsWorks Layers: #{state[:instance]['layers'].join(', ')}
            OpsWorks Instance: #{state[:instance]['hostname']}
            EC2 Instance ID: #{state[:instance]['aws_instance_id']}
            EC2 Instance Type: #{state[:instance]['instance_type']}
            Architecture: #{state[:instance]['architecture']}
            Total Memory: #{"%.02f Gb" % [File.read('/proc/meminfo').match(/^MemTotal:(.*)kB$/)[1].to_f / (1000**2) ]}
            CPU: #{cpu_info.scan(/^processor/).size}x #{cpu_info.scan(/^model name\t:(.*)/).first.first.to_s rescue 'UNKNOWN'}

          Location:

            EC2 Region: #{state[:instance]['region']}
            EC2 Availability Zone: #{state[:instance]['availability_zone']}

          Networking:

            Public IP: #{state[:instance]['ip']}
            Private IP: #{state[:instance]['private_ip']}
        EO_MSG

        puts "%s\n" % message

        logger :info, 'Showed instance report'
      rescue Exception => e
        logger :error, "Could not show instance report: #{e.class} - #{e.message}- #{e.backtrace.join("\n")}"
        raise InstanceReportError, "Could not show information about the current state of the opsworks agent: #{e.class} - #{e.message}- #{e.backtrace.join("\n")}"
      end

    end
  end
end
