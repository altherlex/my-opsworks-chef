# encoding: UTF-8
require 'cli'
require 'cli/logger'

module Cli
  module Base

    include Cli::Logger

    attr_reader :commands, :command

    Struct.new('Command', :activity, :date, :json_file)

    def gather_commands
      @commands = []
      json_files.each do |json_file|
        activity = parse_json(json_file)['opsworks']['activity']
        date = json_file.sub(/.*\/(.{10})-(\d{2})-(\d{2})-(\d{2}).*/, '\1T\2:\3:\4')
        @commands << Struct::Command.new(activity, date, json_file)
      end
      if @commands.blank?
        msg = "No commands where found on this instance. Please execute a command on this instance using\n" +
              "the Web Console at https://console.aws.amazon.com/opsworks"
        logger :warn, msg
        $stderr.puts msg
      end
      @commands
    rescue Exception => e
      raise "Couldn't gather commands. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
    end

    def call_with_params_for(method)
      @command = if @args.blank?
        [@commands.last]
      elsif @args =~ /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
        @commands.select {|cmd| cmd[:date].eql?(@args)}
      elsif valid_activities.include?(@args)
        @commands.select {|cmd| cmd[:activity].eql?(@args)}
      else
        logger :error, "Please verify the given argument. Couldn't find information for '#{@args}'"
        abort
      end.pop

      if @command
        send(method) or raise "Couldn't call #{method}"
      else
        logger :error, "Couldn't find command for arguments: #{@args.inspect}"
        abort
      end
    end

    def valid_activities
      parse_json(@commands.last.json_file)['opsworks']['valid_client_activities'] rescue nil
    end

    private

    def json_files
      Dir["#{@config[:shared_dir]}/chef/*.json"].sort
    rescue Exception => e
      raise "Could not list command files: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
    end

    def parse_json(file)
      JSON.parse(File.read(file))
    rescue Exception => e
      raise "Could not parse #{file}: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
    end

  end
end
