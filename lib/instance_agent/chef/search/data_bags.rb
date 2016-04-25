# encoding: UTF-8
require 'instance_agent/chef/utils'

module InstanceAgent
  module Chef
    module Search
      class DataBags

        include InstanceAgent::Chef::Utils
        attr_reader :data_bags_dir

        def initialize(payload, data_bags_dir)
          @payload = payload
          @data_bags_dir = data_bags_dir
        end

        def persist
          if data_bags_defined?
            log :info, "Creating data bags"
            create_data_bags_basedir
            persist_data_bags
          else
            log :info, "No data bags defined."
          end
        rescue => e
          log :error, "Couldn't create data bags. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
          raise e
        end

        private

        def data_bags_defined?
          @payload["opsworks"].has_key?("data_bags") rescue false
        end

        def create_data_bags_basedir
          log :debug, "Creating data bags directory: #{data_bags_dir}"
          FileUtils.mkdir_p(data_bags_dir, :mode => 0700)
          FileUtils.chown(file_owner[:name], file_owner[:group], data_bags_dir)
        rescue => e
          raise RuntimeError, "Couldn't create data bags directory. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        end

        def data_bags
          return nil unless data_bags_defined?
          # location were the data bags are expected
          @payload["opsworks"]["data_bags"]
        end

        def prepare_data_bag_dir(data_bag_dir)
          FileUtils.mkdir_p(data_bag_dir, :mode => 0700)
          FileUtils.chown(file_owner[:name], file_owner[:group], data_bag_dir)
        rescue => e
          raise RuntimeError, "Couldn't prepare data bag item. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        end

        def data_bag_items
          Enumerator.new do |yielder|
            data_bags.each do |name, items|
              log :debug, "Creating data bag: #{name}"
              data_bag_dir = File.join(data_bags_dir, name)
              prepare_data_bag_dir data_bag_dir
              items.each do |item_name, item_content|
                yielder.yield(item_name, item_content, data_bag_dir)
              end
            end
          end
        end

        def persist_data_bags
          data_bag_items.each do |item_name, item_content, data_bag_dir|
            log :debug, "Creating data bag item: #{item_name}"
            data_bag = File.join(data_bag_dir, "#{item_name}.json")

            File.open(data_bag, 'w', 0600) do |fd|
              fd.write(JSON.pretty_generate(item_content))
              FileUtils.chown(file_owner[:name], file_owner[:group], fd.path)
            end
          end
        rescue => e
          raise RuntimeError, "Couldn't create data bags. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        end

      end
    end
  end
end
