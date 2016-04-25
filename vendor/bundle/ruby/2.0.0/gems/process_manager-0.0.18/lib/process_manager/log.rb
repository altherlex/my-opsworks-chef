# encoding: UTF-8
require 'logger'

module ProcessManager
  class Log
    NORMAL_SEVERITIES = %W{debug info warn unknown}
    ERROR_SEVERITIES = %W{error fatal}
    SEVERITIES = NORMAL_SEVERITIES + ERROR_SEVERITIES

    class Formatter < ::Logger::Formatter
      Format = "[%s] %5s [%s]: %s\n"

      def format_datetime(time)
        time.strftime('%Y-%m-%d %H:%M:%S')
      end

      def call(severity, time, progname, msg)
        Format % [format_datetime(time), severity, progname, msg2str(msg)]
      end

    end
    class << self
      attr_accessor :logger
    end

    class Logger
      attr_accessor :logger

      def initialize(log_device)
        ::File.umask ProcessManager::Config.config[:log_file_umask]
        @logger = ::Logger.new(log_device)
        @logger.progname = "#{ProcessManager::Config.config[:program_name]}(#{$$})"
        @logger.formatter = ProcessManager::Log::Formatter.new
        if ProcessManager::Config.config[:verbose]
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

      NORMAL_SEVERITIES.each do |level|
        log_level = ::Logger.const_get(level.upcase)
        define_method(level) do |message|
          raise "No logger available" unless @logger
          @logger.progname = "#{ProcessManager::Config.config[:program_name]}(#{$$})"
          @logger.add(log_level, message)
        end
      end

      ERROR_SEVERITIES.each do |level|
        log_level = ::Logger.const_get(level.upcase)
        define_method(level) do |message|
          @logger.progname = "#{ProcessManager::Config.config[:program_name]}(#{$$})"
          @logger.add(log_level, message)
          ProcessManager.on_error_callbacks.each do |callback|
            begin
              callback.call(message)
            rescue Exception
              # error callbacks shouldn't break the main flow
            end
          end if level == 'error'
        end
      end

    end

    def self.[](logger_name)
      logger_name = logger_name.to_sym
      @logger_collection ||= {}
      @logger_collection[logger_name] ||= ProcessManager::Log::Logger.new(log_device(logger_name))
    end

    def self.log_device(logger_name)
      if logger_name.is_a?(String) || logger_name.is_a?(Symbol)
        raise 'Please init ProcessManager::Log with a base log file!' unless @base_log_file
        @base_log_file.gsub(/\.log/, ".#{logger_name.to_s.demodulize}.log")
      else # IO?
        logger_name
      end
    end

    def self.init(log_device)
      @base_log_file = log_device
      if @logger.nil? || ((@logger.logger.logdev.dev.path != log_device) rescue true)
        @logger = ::ProcessManager::Log::Logger.new(log_device)
      end
      @logger
    end

    def self.level=(level)
      @logger.level = ::Logger.const_get(level.to_s.upcase)
    end

    (NORMAL_SEVERITIES + ERROR_SEVERITIES).each do |level|
      singleton_class.instance_eval do
        define_method(level) do |message|
          raise "No logger available" unless @logger
          @logger.progname = "#{ProcessManager::Config.config[:program_name]}(#{$$})"
          @logger.send(level, message)
        end
      end
    end

  end
end
