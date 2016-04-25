# encoding: UTF-8
require 'pathname'

module InstanceAgent
  module Chef
    class Config

      attr_reader :config

      def initialize(stage, chef_log_level)
        root_dir = InstanceAgent::Config.config[:root_dir]
        shared_dir = InstanceAgent::Config.config[:shared_dir]
        data_dir = File.join(shared_dir, '/data')
        default_cookbooks_path = File.join(root_dir, "cookbooks")
        merged_cookbooks_path = File.join(root_dir, "merged-cookbooks")
        site_cookbooks_path = File.join(root_dir, "site-cookbooks")
        berkshelf_cookbooks_path = File.join(root_dir, "berkshelf-cookbooks")

        @config = {
          :data_dir => data_dir,
          :default_cookbooks_path => default_cookbooks_path,
          :site_cookbooks_path => site_cookbooks_path,
          :berkshelf_cookbooks_path => berkshelf_cookbooks_path,
          :berkshelf_cache_path => File.join(shared_dir, '/berkshelf_cache'),
          :merged_cookbooks_path => merged_cookbooks_path,
          :ohai_plugin_path => File.join(root_dir, '/plugins'),
          :file_cache_path => File.join(shared_dir, "/cache.#{stage}"),
          :data_bags_dir => File.join(data_dir, '/data_bags'),
          :search_nodes_dir => File.join(data_dir, '/nodes'),
          :config_file => File.join(shared_dir, "/client.#{stage}.rb"),
          :config_template => File.join(Pathname.new(__FILE__).realpath.dirname, '/client_config.erb'),
          :config_yaml_file => File.join(shared_dir, "/client.#{stage}.yml"),
          :config_yaml_template => File.join(Pathname.new(__FILE__).realpath.dirname, '/client_yaml.erb'),
          :command_wrapper => File.join(root_dir, '/bin/chef_command_wrapper.sh'),
          :command => File.join(root_dir, '/bin/chef-client'),
          :log_level => chef_log_level.to_sym.inspect,
          :local_mode => true
        }
      end

    end
  end
end
