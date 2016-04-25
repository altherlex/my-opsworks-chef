# encoding: UTF-8
require 'fileutils'

module InstanceAgent
  class LogUpload
    def initialize(log_file, upload_url)
      @log_file = log_file
      @upload_url = upload_url
    end

    def upload
      compress!
      3.times do
        break if try_upload
        sleep 5
      end
      cleanup!
    end

    def try_upload
      log :debug, "Running log upload with #{@log_file}"
      args = [
        'curl',
        '-H', '"HTTP_ACCEPT_ENCODING: gzip"',
        '-T', "#{@log_file}.gz",
        @upload_url
      ]

      success = system(*args)

      if success
        log :info, "Successfully uploaded log file #{@log_file}"
      else
        log :error, "Failed uploading log file #{@log_file} with exitcode #{$?.exitstatus}"
      end
      success
    end

    protected
    def log(severity, message)
      raise ArgumentError, "Unknown severity #{severity.inspect}" unless InstanceAgent::Log::SEVERITIES.include?(severity.to_s)
      InstanceAgent::Log.send(severity.to_sym, "Log upload: #{message}")
    end

    def compress!
      Zlib::GzipWriter.open("#{@log_file}.gz") do |gz|
        gz.write File.read(@log_file)
      end
    rescue Exception => e
      log :error, "Failed to create gzipped log for uploading #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
      raise e
    end

    def cleanup!
      FileUtils.rm "#{@log_file}.gz"
    end
  end
end
