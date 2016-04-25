# encoding: UTF-8
require 'instance_agent/chef/utils'

module InstanceAgent
  module Chef
    module Search
      class Nodes

        include InstanceAgent::Chef::Utils
        attr_reader :search_nodes_dir

        def initialize(payload, search_nodes_dir)
          @payload = payload
          @search_nodes_dir = search_nodes_dir
        end

        def persist
          if valid_payload?
            log :info, "Creating search nodes"
            create_search_nodes_dir
            persist_search_nodes
          else
            raise RuntimeError, "Couldn't generate chef search nodes. Bad payload structure, no layers found."
          end
        rescue => e
          log :error, "Couldn't generate chef search nodes. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
          raise e
        end

        private

        def valid_payload?
          @payload["opsworks"].has_key?("layers") rescue false
        end

        def blueprint
          Hash.new do |h,k|
            h[k] = { "default" => { "opsworks" => { "layers" => {} }, "tags" => [] },
                     "automatic" => { "roles" => [] },
                     "run_list" => []
                   }
          end
        end

        def ohai_snippet(name, attr)
          data = { "hostname" => name,
                   "ipaddress" => attr["ip"],
                   "ec2" => {
                     "ami_id" => attr["aws_instance_id"],
                     "hostname" => attr["public_dns_name"],
                     "instance_id" => attr["aws_instance_id"],
                     "instance_type" => attr["instance_type"],
                     "local_hostname" => attr["private_dns_name"],
                     "local_ipv4" => attr["private_ip"],
                     "placement_availability_zone" => attr["availability_zone"],
                     "public_hostname" => attr["public_dns_name"],
                     "public_ipv4" => attr["ip"]
                   },
                   "cloud" => {
                     "public_ips" => [
                       attr["ip"]
                     ],
                     "private_ips" => [
                       attr["private_ip"]
                     ],
                     "public_ipv4" => attr["ip"],
                     "public_hostname" => attr["public_dns_name"],
                     "local_ipv4" => attr["private_ip"],
                     "local_hostname" => attr["private_dns_name"]
                   }
                 }
          data.update({ "fqdn" => "#{name}.#{domain}",
                        "domain" => domain }) if domain.present?
          data
        end

        def search_nodes
          @payload["opsworks"]["layers"]
        end

        def hostname
          unless @hostname
            @hostname = `hostname -s`.split("\n").first
            raise "Unable to determine hostname" if @hostname.blank?
          end
          @hostname
        end

        def domain
          @domain ||= `hostname -d`.split("\n").first
          @domain
        end

        def create_search_nodes_dir
          FileUtils.mkdir_p(search_nodes_dir, :mode => 0700)
          FileUtils.chown(file_owner[:name], file_owner[:group], search_nodes_dir)
        rescue => e
          raise RuntimeError, "Couldn't create base directory for search nodes. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        end

        def instance_node(search_data_tree, instance_name, instance_attr)
          node = search_data_tree[instance_name]
          node["name"] = domain.blank? ? "#{instance_name}" : "#{instance_name}.#{domain}"
          node["default"].merge! instance_attr
          node["default"].merge! ohai_snippet(instance_name, instance_attr)
          node["default"]["opsworks"]["stack"] = @payload["opsworks"]["stack"]

          node
        end

        def search_data
          search_data = blueprint

          search_nodes.each do |layer_name, layer_attr|
            layer_attr["instances"].each do |instance_name, instance_attr|
              node = instance_node(search_data, instance_name, instance_attr)

              node["default"]["tags"] << layer_name
              node["default"]["opsworks"]["layers"][layer_name] = layer_attr.select{|k,_| k != "instances"}
              node["run_list"] << "role[#{layer_name}]"
            end
          end

          # If the stack has no online instances, fill up the search node for localhost as no information was available
          # throuhg the layers. Otherwise chef will generate an empty node and this will cause failures or require
          # unnecessary validation when retrieving node attributes.
          unless search_data[hostname]["default"].keys.count > blueprint["a_node"]["default"].keys.count
            instance_name = hostname
            instance_attr = @payload["opsworks"]["instance"]
            node = instance_node(search_data, instance_name, instance_attr)

            node["default"]["tags"] = instance_attr["layers"]
            node["run_list"] = instance_attr["layers"].map { |layer_name| "role[#{layer_name}]" }
            search_nodes.each do |layer_name, layer_attr|
              node["default"]["opsworks"]["layers"][layer_name] = layer_attr.select{|k,_| k != "instances"}
            end
          end

          search_data
        end

        def persist_search_nodes
          search_data.each do |name, data|
            node_file = File.join(search_nodes_dir, "#{data['name']}.json")

            File.open(node_file, 'w', 0600) do |fd|
              fd.write(JSON.pretty_generate(data))
              log :debug, "Wrote node item: #{fd.path}"
            end
            FileUtils.chown(file_owner[:name], file_owner[:group], node_file)
          end
        rescue => e
          raise RuntimeError, "Couldn't write node information. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        end

      end
    end
  end
end

