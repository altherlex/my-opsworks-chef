# encoding: UTF-8
# This module displays log files. It expects the instance variable @commands
# to be available
require 'cli'

module Cli
  module Options
    module ShowLog

      include Cli::Logger
      include Cli::Base

      ShowLogError = Class.new(StandardError)

      def show_log
        call_with_params_for(:display_log)
      end

      protected
      def display_log
        command = ''

        if @args.nil?
          command = 'less +F'
        else
          command = display_log_flags
        end

        trap('INT', 'IGNORE')
        system "#{command} #{@command.json_file.sub('.json', '.log')} 2> /dev/null"
        trap('INT', 'DEFAULT')

        if $?.success?
          logger :info, "Displayed log (#{@flags}). args: #{@args} / date: #{@command.date}"
        else
          logger :error, "Could not show log. (exitcode = #{$?.exitstatus})"
        end
      end

      private
      def display_log_flags
        case
        when @flags[:b] || @flags[:bottom]
          'less -F'
        when @flags[:t] || @flags[:tail]
          'tail -f'
        else
          'less'
        end
      end

    end
  end
end
