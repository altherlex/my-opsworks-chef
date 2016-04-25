# encoding: UTF-8
require 'instance_agent/chef/runner'

module InstanceAgent
  module Chef
    module Utils

      private

      def file_owner
        @file_owner ||= {name: InstanceAgent::Config.config[:user], group: InstanceAgent::Config.config[:group]}
      end

      def log(severity, message)
        raise ArgumentError, "Unknown severity #{severity.inspect}" unless InstanceAgent::Log::SEVERITIES.include?(severity.to_s)
        # log using the process command logger or the default one in case that one doesn't exists (i.e. cli)
        @logger ||= InstanceAgent::Log[:process_command].present? ? InstanceAgent::Log[:process_command] : InstanceAgent::Log
        @logger.send(severity.to_sym, "Chef: #{message}")
      end

    end
  end
end
