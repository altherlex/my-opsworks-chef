# encoding: UTF-8
require 'instance_agent/chef/config'
require 'instance_agent/chef/utils'
require 'instance_agent/chef/search/items_persister'
require 'utils/template'
require 'utils/version'

module InstanceAgent
  module Chef
    class Runner

      include Chef::Utils
      include InstanceAgent::Agent::Version

      attr_reader :duration, :exitcode, :chef_log_level, :payload
      attr_accessor :chef_run

      TIME_FORMAT = '%Y-%m-%d-%H-%M-%S'

      def initialize(_payload)
        @chef_run = {}
        @time = Time.now.utc.strftime(TIME_FORMAT)

        persist_payload _payload
        @payload = JSON.parse(_payload) # overwrite the variable with its hash representation
        @chef_log_level = payload["opsworks"].fetch("chef_log_level", "info")

        prepare_stages_for_chef_runs

        InstanceAgent::Chef::Search::ItemsPersister.new(payload, chef_run["stage1"].last[:config][:data_bags_dir], chef_run["stage1"].last[:config][:search_nodes_dir]).persist
      rescue => e
        log :error, "Couldn't instantiate chef runner. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        raise e
      end

      def run
        generate_chef_config_yaml(chef_run["stage1"].last)
        if stage1_result = run_chef(*chef_run["stage1"])
          generate_chef_config_yaml(chef_run["stage2"].last)
          stage2_result = run_chef(*chef_run["stage2"])
          stage1_result && stage2_result
        end
      end

      def logs_dir
        shared_dir = InstanceAgent::Config.config[:shared_dir]
        File.join(shared_dir,'/chef')
      end

      def lockrun
        File.join(InstanceAgent::Config.config[:root_dir], '/bin/lockrun')
      end

      def lockrun_lock
        shared_dir = InstanceAgent::Config.config[:shared_dir]
        File.join(shared_dir, '/lockrun.lock')
      end

      def log_file
        chef_file_name[:log]
      end

    private

      def prepare_stages_for_chef_runs
        prepare_stage1_chef_run
        prepare_stage2_chef_run
      end

      def prepare_stage1_chef_run
        chef_run_header =
          "[#{DateTime.now.strftime}] INFO: AWS OpsWorks instance #{InstanceAgent::Config.config[:identity]}, Agent version #{agent_version}"
        config = InstanceAgent::Chef::Config.new("stage1", chef_log_level).config

        chef_run["stage1"] = [
          run_list('stage1'),
          :config => config,
          :cookbook_path => [config[:default_cookbooks_path]],
          :log_line_to_append => '\n---\n',
          :log_line_to_prepend => chef_run_header
        ]
      end

      def prepare_stage2_chef_run
        config = InstanceAgent::Chef::Config.new("stage2", chef_log_level).config

        chef_run["stage2"] = [
          run_list('stage2'),
          :config => config,
          :cookbook_path => [config[:merged_cookbooks_path]]
        ]
      end

      def basename(counter)
        "#{@time}-#{'%.2d' % counter}"
      end

      def chef_file_name
        if @chef_file_name.nil?
        counter = 0
          begin
            @chef_file_name = File.join(logs_dir, basename(counter += 1))
          end while File.exists?("#{@chef_file_name}.json") || File.exists?("#{@chef_file_name}.log")
        end

        {:json => "#{@chef_file_name}.json", :log => "#{@chef_file_name}.log"}
      end

      def persist_payload(payload)
        FileUtils.mkdir_p logs_dir

        File.open(chef_file_name[:json], 'w') do |f|
          f.write(payload)
        end
      rescue => e
        log :error, "Couldn't persist payload for chef runner. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        raise e
      end

      def generate_chef_client_config(options = {})
        config = options[:config]
        renderer = InstanceAgent::Utils::Template::Renderer.new(config[:config_template])

        log :debug, "Generating chef client configuration from template"
        File.open(config[:config_file], "w") do |client_config|
          client_config.puts renderer.render(:config => config, :cookbook_path => options[:cookbook_path])
        end
      rescue => e
        log :error, "Couldn't create chef configuration file. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        raise e
      end

      # this is used as an interface to the cookbooks for reading chef configuration attributes. Not all attributes
      # are readable via Chef::Config during the chef run.
      def generate_chef_config_yaml(options = {})
        config = options[:config]
        renderer = InstanceAgent::Utils::Template::Renderer.new(config[:config_yaml_template])

        log :debug, "Generating chef configuratiton attributes yaml from template"
        File.open(config[:config_yaml_file], "w") do |yaml_file|
          yaml_file.puts renderer.render(:config => config, :cookbook_path => options[:cookbook_path])
        end

        # make sure we maintain the old client.yml for customers who are overriding core OpsWorks cookbooks
        generate_old_style_config_yaml(config)
      rescue => e
        log :error, "Couldn't create chef configuration attributes yaml file. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        raise e
      end

      def generate_old_style_config_yaml(config)
        old_style_yaml_file = File.join(File.dirname(config[:config_yaml_file]), "client.yml")
        FileUtils.ln_sf(config[:config_yaml_file], old_style_yaml_file)
      end

      def run_list(stage)
        case stage
        when 'stage1'
          payload['recipes'].join(',')
        when 'stage2'
          payload['opsworks_custom_cookbooks']['recipes'].join(',')
        end
      rescue => e
        log :error, "Could not gather run list for chef run. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        raise e
      end

      def run_chef(run_list, options = {})
        generate_chef_client_config(options)
        config = options[:config]

        args = [
          lockrun, "--wait",
                            "--verbose",
                            "--lockfile=#{lockrun_lock}",
                            "--",
                            "env", "HOME=/root",
                            "sudo", config[:command_wrapper],
                            "-s", config[:command],
                            "-j", chef_file_name[:json],
                            "-c", config[:config_file],
                            "-o", run_list,
                            "-L", chef_file_name[:log],
        ]
        args += ["-A", options[:log_line_to_append]] if options[:log_line_to_append]
        args += ["-P", options[:log_line_to_prepend]] if options[:log_line_to_prepend]
        args << "2>&1"

        log :debug, "Running chef client with #{chef_file_name[:json]} and run list set to #{run_list}"
        @duration = Benchmark.realtime do
          log :debug, "About to execute: #{args.join(' ')}"
          File.umask 0027
          system(*args)
        end

        @exitcode = $?.exitstatus
        if $?.exited?
          log :info, "Finished running chef solo with exitcode #{@exitcode}. (#{duration} sec)"
        else
          log :info, "Running chef solo didn't finish normally, exitcode not available: #{$?.inspect}. (#{duration} sec)"
        end

        $?.exited? && @exitcode.zero?
      end

    end
  end
end
