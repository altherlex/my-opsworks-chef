# encoding: UTF-8
require 'cli'

module Cli
  module Options
    module StackState

      StackStateOptionError = Class.new(StandardError)

      include Cli::Base
      include Cli::Logger

      def stack_state
        puts JSON.pretty_generate( raw_stack_state )

        logger(:info, 'Listed stack state')
      rescue Exception => e
        raise "Could not display stack state: #{e} - #{e.message} - #{e.backtrace.join("\n")}"
      end

      def raw_stack_state
        node = parse_json(@commands.last.json_file)['opsworks']

        {
          :last_command => {
            :sent_at => node['sent_at'],
            :activity => node['activity']
          },
          :instance => node['instance'],
          :layers => node['layers'],
          :applications => node['applications'],
          :stack => node['stack'],
          :agent => {
            :valid_activities => node['valid_client_activities']
          }
        }.rehash

      rescue Exception => e
        logger :error, "Could not generate raw stack state: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        raise "Could not generate raw stack state: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
      end

    end
  end
end
