# encoding: UTF-8
$: << File.expand_path(File.dirname(File.realpath(__FILE__))) + '../lib'
require 'rubygems'

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])

if defined?(Bundler)
  Bundler.require(:default)
end

require 'json'
require 'yaml'
require 'active_support/json'
require 'active_support/core_ext'

require 'cli/base'
require 'cli/logger'

module Cli
  module Base
  end

  module Logger
  end

  module Options
    module AgentReport
    end

    module InstanceReport
    end

    module ListCommands
    end

    module RunCommands
    end

    module ShowLog
    end

    module ShowJson
    end

    module StackState
    end
  end
end
