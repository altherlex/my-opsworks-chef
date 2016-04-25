require 'cli'
require 'cli/options/agent_report'
require 'cli/options/instance_report'
require 'cli/options/get_json'
require 'cli/options/list_commands'
require 'cli/options/run_command'
require 'cli/options/show_log'
require 'cli/options/stack_state'
require 'cli/options/update_agent'
require 'instance_agent'

module Cli
  class Runner

    ArgumentValidationError = Class.new(Exception)
    InitializationError = Class.new(Exception)

    include Cli::Base
    include Cli::Logger
    include Cli::Options::AgentReport
    include Cli::Options::InstanceReport
    include Cli::Options::GetJson
    include Cli::Options::ListCommands
    include Cli::Options::ShowLog
    include Cli::Options::StackState
    include Cli::Options::RunCommand
    include Cli::Options::UpdateAgent

    VALID_ACTIVITIES = [
      'reboot',
      'stop',
      'setup',
      'configure',
      'deploy',
      'update_dependencies',
      'install_dependencies',
      'update_custom_cookbooks',
      'execute_recipes'
    ]

    attr_reader :config, :args, :flags

    def self.run(options = {})
      options = {
        :flags => nil,
        :args => nil,
        :cli_option => 'list_commands',
      }.update(options)

      new(options).execute(options[:cli_option])
    rescue => e
      raise e if e.is_a? GLI::CustomExit
      $stderr.puts "Couldn't execute #{options[:cli_option]}: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
    end

    def initialize(options = {})
      options = {
        :program_name => 'opsworks-agent-cli',
        :config_file => '/etc/aws/opsworks/instance-agent.yml'
      }.update(options)

      # get config from InstanceAgent::Config, because we need this for the Chef class anyways
      ::InstanceAgent::Config.config(:config_file => options[:config_file])
      ::InstanceAgent::Config.load_config
      @config = ::InstanceAgent::Config.config

      ::InstanceAgent::Log.init("#{@config[:log_dir]}/opsworks-agent-cli.log")
      @flags = options[:flags]
      @args = options[:args]

      validate_args
      gather_commands
    end

    def execute(cli_option)
      logger(:info, "Executing #{cli_option}")
      send(cli_option)
    end

    protected

    def validate_args
      @args.blank? ||
      @args =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/ ||
      VALID_ACTIVITIES.include?(@args) ||
      (File.exists?(@args) && File.readable?(@args)) or
      raise ArgumentValidationError, "This is not a valid argument: #{@args}"
    end

  end
end
