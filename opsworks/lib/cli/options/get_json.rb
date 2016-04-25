# encoding: UTF-8
# This module prints json files to STDOUT in a human readble way. It expects the
# instance variable @commands to be available
require 'cli'

module Cli
  module Options
    module GetJson

      GetJsonError = Class.new(StandardError)

      include Cli::Logger

      def get_json
        call_with_params_for(:show_pretty_json)
      end

      protected
      def show_pretty_json
        puts JSON.pretty_generate(parse_json(@command[:json_file]))
        logger :info, "Listed command for #{args}"
      rescue Exception => e
        logger :error, "Could not show json : #{e} - #{e.message}"
        raise GetJsonError, "Could not show json : #{e} - #{e.message} - #{e.backtrace.join("\n")}"
      end

    end
  end
end
