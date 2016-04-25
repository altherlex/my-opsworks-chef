# encoding: UTF-8
require 'cli'
require 'cli/base'

module Cli
  module Options
    module ListCommands

      ListCommandsError = Class.new(StandardError)

      include Cli::Logger
      include Cli::Base

      def list_commands
        @commands.sort_by{ |k| k[:date] }.each do |command|
          puts "%-25s  %-s" % [command[:date], command[:activity]]
        end

        logger :info, 'Listed commands'
      rescue Exception => e
        logger :error, "Could not list locally available commands: #{e} - #{e.message} - #{e.backtrace.join("\n")}"
        raise ListCommandsError, "Could not list in raw format: #{e} - #{e.message} - #{e.backtrace.join("\n")}"
      end

    end
  end
end
