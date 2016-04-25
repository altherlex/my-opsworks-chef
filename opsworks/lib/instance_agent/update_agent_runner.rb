# encoding: UTF-8
module InstanceAgent
  class UpdateAgentRunner

    attr_accessor :payload
    attr_reader :duration, :exitcode

    def initialize(payload)
      @payload = JSON.parse(payload) # overwrite the variable with its hash representation
    rescue => e
      InstanceAgent::Log[:process_command].error "Couldn't instantiate update_agent runner. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
      raise e
    end

    def run
      @duration = Benchmark.realtime do
        begin
          write_target_version_file
          delete_failed_setup_marker_file
          @exitcode = 0
        rescue Exception => e
          @exception = e
          @exitcode = 1
        ensure
          write_log_file
        end
      end

      raise @exception if @exception.present?
      @exitcode.zero?
    end

    def log_file
      File.join(InstanceAgent::Config.config[:log_dir], "update_agent.log")
    end

    private
    def new_target_version
      payload["opsworks"]["agent_version"]
    end

    def target_version_file
      File.join(InstanceAgent::Config.config[:shared_dir], "TARGET_VERSION")
    end

    def write_target_version_file
      IO.write(target_version_file, new_target_version)
    end

    def delete_failed_setup_marker_file
      FileUtils.rm_f File.join(InstanceAgent::Config.config[:shared_dir], "FAILED_UPDATE")
    end

    def write_log_file
      File.open(log_file, "w") do |file|
        if @exitcode.zero?
          file.puts "TARGET_VERSION set to #{new_target_version}"
        else
          file.puts "Failed to set TARGET_VERSION to #{new_target_version}"
          file.puts @exception.message
        end
        file.flush
      end
    end
  end
end
