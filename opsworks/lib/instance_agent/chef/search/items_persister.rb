# encoding: UTF-8
require 'instance_agent/chef/utils'
require 'instance_agent/chef/search/nodes'
require 'instance_agent/chef/search/data_bags'

module InstanceAgent
  module Chef
    module Search
      class ItemsPersister

        include InstanceAgent::Chef::Utils

        def initialize(payload, data_bags_dir, search_nodes_dir)
          @payload = payload
          @data_bags_dir = data_bags_dir
          @search_nodes_dir = search_nodes_dir

          raise RuntimeError, "Payload is not a Hash. Couldn't initalize #{self.class}." unless valid_payload?
        end

        def persist
          log :info, "Deleting old chef search items"
          cleanup

          log :info, "Generating chef search items"
          InstanceAgent::Chef::Search::DataBags.new(@payload, @data_bags_dir).persist
          InstanceAgent::Chef::Search::Nodes.new(@payload, @search_nodes_dir).persist
        end

        def cleanup
          [@data_bags_dir, @search_nodes_dir].each do |target|
            FileUtils.rm_rf target
          end
        rescue => e
          log :error, "Could not delete directory. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
          raise e
        end

        private

        def valid_payload?
          @payload.is_a?(Hash)
        end

      end
    end
  end
end
