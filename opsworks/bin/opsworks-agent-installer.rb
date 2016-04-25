#!/opt/aws/opsworks/local/bin/ruby

require 'pathname'
$:.unshift("#{Pathname.new(__FILE__).realpath.dirname}/../lib")
require 'bootstrap'
require 'bootstrap/instance_agent_installer'

Bootstrap::InstanceAgentInstaller.run  if __FILE__ == $0
