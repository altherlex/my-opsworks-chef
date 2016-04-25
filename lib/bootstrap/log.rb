# encoding: UTF-8
require 'logger'

module Bootstrap
  class Log
    NORMAL_SEVERITIES = ['debug', 'info', 'warn', 'unknown'] unless defined? Bootstrap::Log::NORMAL_SEVERITIES
    ERROR_SEVERITIES = ['error', 'fatal']  unless defined? Bootstrap::Log::ERROR_SEVERITIES
    SEVERITIES = NORMAL_SEVERITIES + ERROR_SEVERITIES unless defined? Bootstrap::Log::SEVERITIES

    class Formatter < ::Logger::Formatter
      FORMAT = "[%s] %5s [%s]: %s\n" unless defined?(FORMAT)

      def format_datetime(time)
        time.strftime('%Y-%m-%d %H:%M:%S')
      end

      def call(severity, time, progname, msg)
        FORMAT % [format_datetime(time), severity, progname, msg2str(msg)]
      end

    end

    class << self
      attr_accessor :logger
    end

    class Logger
      attr_accessor :logger

      def initialize(log_device)
        @logger = ::Logger.new(log_device)
        @logger.progname = "#{Bootstrap::Config.config[:component]} (#{$$})"
        @logger.formatter = Bootstrap::Log::Formatter.new
        if Bootstrap::Config.config[:verbose]
          self.level = 'debug'
        else
          self.level = 'info'
        end
      end

      def level=(level)
        if level.is_a?(Fixnum)
          @logger.level = level
        else
          @logger.level = ::Logger.const_get(level.to_s.upcase)
        end
      end

      def progname=(name)
        @logger.progname=(name)
      end

      NORMAL_SEVERITIES.each do |severity|
        log_level = ::Logger.const_get(severity.upcase)
        define_method(severity) do |message|
          raise 'No logger available' unless @logger
          @logger.progname = "#{Bootstrap::Config.config[:component]} (#{$$})"
          @logger.add(log_level, message)
        end
      end

      ERROR_SEVERITIES.each do |severity|
        log_level = ::Logger.const_get(severity.upcase)
        define_method(severity) do |message|
          @logger.progname = "#{Bootstrap::Config.config[:component]} (#{$$})"
          @logger.add(log_level, message)
        end
      end

    end

    def self.log_device(logger_name)
      if logger_name.is_a?(String) || logger_name.is_a?(Symbol)
        raise 'Please init Bootstrap::Log with a base log file!' unless @base_log_file
        @base_log_file.sub(/\.log/, ".#{logger_name.to_s.demodulize}.log")
      else # IO?
        logger_name
      end
    end

    def self.init(log_device)
      @base_log_file = log_device
      if @logger.nil? || ((@logger.logger.logdev.dev.path != log_device) rescue true)
        @logger = ::Bootstrap::Log::Logger.new(log_device)
      end
      @logger
    end

    def self.level=(level)
      @logger.level = ::Logger.const_get(level.to_s.upcase)
    end

    def self.measure(description)
        now = Time.now.to_i
        self.info("Starting: #{description}")
        yield
        self.info("Finished: #{description}  \(#{Time.now.to_i - now} sec\)")
    end

    SEVERITIES.each do |severity|
      singleton_class.instance_eval do
        define_method(severity) do |message|
          raise 'No logger available' unless @logger
          @logger.progname = "#{Bootstrap::Config.config[:component]} (#{$$})"
          @logger.send(severity, message)
        end
      end
    end

  end
end
