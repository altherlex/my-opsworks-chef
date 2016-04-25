# encoding: UTF-8
require 'utils/version'

module InstanceAgent
  module Agent
    class Base
      attr_accessor :crypto, :client, :logger

      include InstanceAgent::Agent::Version

      def initialize
        @logger_name = self.class.to_s.sub('InstanceAgent::Agent::','').underscore
        @user_agent_prefix = ''

        if InstanceAgent::Config.config[:user_agent_custom_prefix].present?
          @user_agent_prefix += InstanceAgent::Config.config[:user_agent_custom_prefix]
        end

        options = {
          :region => InstanceAgent::Config.config[:instance_service_region],
          :endpoint => InstanceAgent::Config.config[:instance_service_endpoint],
          :port => InstanceAgent::Config.config[:instance_service_port],
          :user_agent_prefix => @user_agent_prefix,
          :use_ssl => true,
          :ssl_verify_peer => true
        }
        if InstanceAgent::Config.config[:access_key_id].present? && InstanceAgent::Config.config[:secret_access_key].present?
          log(:info, "Initializing Instance Service client with credentials from agent configuration.")
          options.update(
            :credential_provider => AWS::Core::CredentialProviders::StaticProvider.new(
              :access_key_id => InstanceAgent::Config.config[:access_key_id],
              :secret_access_key => InstanceAgent::Config.config[:secret_access_key]
            )
          )
        else
          log(:info, "Initializing Instance Service client with credentials from IAM instance profile.")
          options.update(
            :credential_provider => AWS::Core::CredentialProviders::EC2Provider.new(
              :retries => 10
            )
          )
        end
        log(:info, "Running on AWS OpsWorks instance #{InstanceAgent::Config.config[:identity]}")

        @client = AWS::CharlieInstanceService::Client.new(options)
      end

      def self.runner
        self.new
      end

      def description
        self.class.to_s.demodulize.underscore
      end

      def logger
        InstanceAgent::Log[@logger_name]
      end

      def log(severity, message)
        raise ArgumentError, "Unknown severity #{severity.inspect}" unless InstanceAgent::Log::SEVERITIES.include?(severity.to_s)
        logger.send(severity.to_sym, "#{description}: #{message}")
      end

      def run
        perform
      rescue Timeout::Error
        log(:error, "Timeout while reporting to Instance Service")
      rescue AWS::Errors::MissingCredentialsError
        log(:error, "Missing credentials - please check if this instance was started with an IAM instance profile")
        sleep InstanceAgent::Config.config[:wait_after_error]
      rescue AWS::CharlieInstanceService::Errors::ThrottlingException
        log(:error, "Ran into throttling - waiting for #{InstanceAgent::Config.config[:wait_after_error]}s until trying again")
        sleep InstanceAgent::Config.config[:wait_after_error]
      rescue AWS::CharlieInstanceService::Errors::InternalFailure => e
        log(:error, "InstanceService has problems: #{e.class} - #{e.message}")
        sleep InstanceAgent::Config.config[:wait_after_error]
      rescue SocketError, Errno::ENETDOWN, Errno::ECONNRESET, Errno::ECONNREFUSED, AWS::Core::Client::NetworkError => e
        log(:error, "Cannot reach InstanceService: #{e.class} - #{e.message}")
        sleep InstanceAgent::Config.config[:wait_after_error]
      rescue AWS::CharlieInstanceService::Errors::AccessDeniedException
        log(:error, "Access denied to the OpsWorks instance service")
        sleep InstanceAgent::Config.config[:wait_after_error]
      rescue Exception => e
        log(:error, "Error during perform: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}")
        sleep InstanceAgent::Config.config[:wait_after_error]
      end
    end
  end
end
