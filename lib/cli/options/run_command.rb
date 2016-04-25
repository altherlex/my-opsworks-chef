# encoding: UTF-8
# Executes locally available commands running InstanceAgent::Chef
# This module expects InstanceAgent::Log and InstanceAgent::Config
# this are instantiated in Cli::Runner.
require 'cli'
require 'instance_agent/chef/runner'

module Cli
  module Options
    module RunCommand

      RunCommandError = Class.new(StandardError)

      include Cli::Logger
      include Cli::Base

      attr_reader :chef_payload

      def run_command
        case
        when begin @flags[:f] || @flags[:file] rescue nil end
          run_chef
        else
          call_with_params_for(:run_chef)
        end
      end

      protected
      def run_chef
        payload = ''
        begin
          if @command.nil?
            payload = File.read(@args)
            logger :info, "About to run custom custom command from: #{@args}", :stdout => true
          else
            payload = File.read(@command[:json_file])
            logger :info, "About to re-run '#{@command[:activity]}' from #{@command[:date]}", :stdout => true
          end
        rescue Exception => e
          logger :error, "Could not gather payload for running command: #{e} - #{e.message}"
          raise RunCommandError, "Could n't gather payload for running command: #{e} - #{e.message} - #{e.backtrace.join("\n")}"
        end

        chef = ::InstanceAgent::Chef::Runner.new(payload)
        chef.run

        if chef.exitcode.zero?
          logger :info, "Finished Chef run with exitcode #{chef.exitcode}", :stdout => true
        else
          logger :error, "Chef run failed with exitcode #{chef.exitcode}"
          exit_now! "Chef run failed with exitcode #{chef.exitcode}", chef.exitcode
        end
        true  #a failed chef run output is enough feedback
      end

    end
  end
end
