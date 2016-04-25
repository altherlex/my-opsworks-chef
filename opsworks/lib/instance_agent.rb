# encoding: UTF-8
$:<< File.expand_path(File.dirname(File.realpath(__FILE__))) + '/lib'

require 'rubygems'
# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)
require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])

if defined?(Bundler)
  Bundler.require(:default)
end

require 'active_support/all'
require 'process_manager'
require 'aws-sdk'
require 'aws/charlie_instance_service'

unless defined?(InstanceAgent)
  require 'instance_agent/exceptions'
  require 'instance_agent/crypto'
  require 'instance_agent/rna'
  require 'instance_agent/chef/runner'
  require "instance_agent/update_agent_runner"
  require 'instance_agent/config'
  require 'instance_agent/log'
  require 'instance_agent/log_upload'
  require 'instance_agent/agent/base'
  require 'instance_agent/agent/keep_alive'
  require 'instance_agent/agent/statistics'
  require 'instance_agent/agent/process_command'
  require 'instance_agent/runner/master'
  require 'instance_agent/runner/child'
end

module InstanceAgent
  VERSION = '0.0.1'

  module Runner
  end

  module Agent
  end
end
