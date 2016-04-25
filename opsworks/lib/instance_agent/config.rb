# encoding: UTF-8
module InstanceAgent
  class Config < ProcessManager::Config
    def self.init
      @config = Config.new
      ProcessManager::Config.instance_variable_set("@config", @config)
    end

    def validate
      errors = super
      validate_children(errors)
      validate_instance_public_key(errors)
      validate_instance_private_key(errors)
      validate_charlie_public_key(errors)
      validate_instance_service_region(errors)
      validate_instance_service_endpoint(errors)
      validate_instance_service_port(errors)
      validate_wait_between_runs(errors)
      validate_user_agent_custom_prefix(errors)
      errors
    end

    def initialize
      super
      @config.update({
        :program_name => 'opsworks-agent',
        :wait_between_spawning_children => 1,
        :log_dir => nil,
        :pid_dir => nil,
        :shared_dir => nil,
        :user => nil,
        :children => 3,
        :instance_public_key => nil,
        :instance_private_key => nil,
        :charlie_public_key => nil,
        :instance_service_region => nil,
        :instance_service_endpoint => nil,
        :instance_service_port => nil,
        :wait_between_runs => 30,
        :wait_after_error => 30,
        :user_agent_custom_prefix => nil,
      })
    end

    def validate_children(errors = [])
      errors << 'children can only be set to 0-2' unless config[:children] == 3
      errors
    end

    def validate_instance_service_region(errors)
      errors << 'please set the region of the Instance Service' unless config[:instance_service_region].present?
      errors
    end

    def validate_instance_service_endpoint(errors)
      errors << 'please set the endpoint of the Instance Service' unless config[:instance_service_endpoint].present?
      errors
    end

    def validate_instance_service_port(errors)
      errors << 'please set the port of the Instance Service' unless config[:instance_service_port].present?
      errors
    end

    def validate_wait_between_runs(errors)
      errors << 'please set the time to wait between runs' unless config[:wait_between_runs].present?
      errors
    end

    def validate_instance_public_key(errors)
      errors << 'please set the instance RSA public key' unless config[:instance_public_key] && config[:instance_public_key].match(/BEGIN PUBLIC KEY/)
      errors
    end

    def validate_instance_private_key(errors)
      errors << 'please set the instance RSA public key' unless config[:instance_private_key] && config[:instance_private_key].match(/BEGIN RSA PRIVATE KEY/)
      errors
    end

    def validate_charlie_public_key(errors)
      errors << 'please set the OpsWorks RSA public key' unless config[:charlie_public_key] && config[:charlie_public_key].match(/BEGIN PUBLIC KEY/)
      errors
    end

    def validate_user_agent_custom_prefix(errors)
      if config[:user_agent_custom_prefix].present? && !config[:user_agent_custom_prefix].match(/[a-z]{1,16}\/[a-z0-9_-]{1,32}/)
        config[:user_agent_custom_prefix] = nil
      end
      errors
    end

  end
end
