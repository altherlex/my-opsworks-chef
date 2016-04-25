module Cli
  module Logger

    CliLoggingError = Class.new(Exception)

    def format_message(severity, message)
      "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{"%5s" % severity.to_s.upcase} [#{@config[:program_name]}(#{$$})]: #{message}"
    end

    def print_message(io, severity, message)
      io.puts format_message(severity, message)
    end

    def logger(severity, message, options = {})
      options = {
        :stdout => false,
      }.update(options)

      raise ArgumentError, "Unknown log severity #{severity.to_s}" unless InstanceAgent::Log::SEVERITIES.include?("#{severity.to_s}")
      ::InstanceAgent::Log.send(severity, message)

      case severity
      when :error
        print_message($stderr, severity, message)
      else
        print_message($stdout, severity, message) if options[:stdout]
      end
      return severity != :error
    rescue Exception => e
      raise CliLoggingError, "Failed to log: #{message} - #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
    end

  end
end
