#!/opt/aws/opsworks/local/bin/ruby

gemfile = File.join(File.dirname(__FILE__), '..', 'Gemfile')
aws_sdk_version = File.open(gemfile).grep(/aws-sdk/).first.scan(/\d+\.*/).join
if aws_sdk_version.empty?
  Gem.install 'aws-sdk'
  gem 'aws-sdk'
else
  Gem.install 'aws-sdk', aws_sdk_version
  gem 'aws-sdk', aws_sdk_version
end

require 'pathname'
$:.unshift("#{Pathname.new(__FILE__).realpath.dirname}/../lib")
require 'bootstrap'
require 'bootstrap/instance_agent_registration_installer'

Bootstrap::InstanceAgentRegistrationInstaller.run  if __FILE__ == $0
