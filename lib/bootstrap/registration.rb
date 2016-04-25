require 'openssl'
require 'aws-sdk'
require 'socket'
require 'net/http'

module Bootstrap
  module Registration

    EC2_METADATA_IP = "169.254.169.254"
    EC2_METADATA_PORT = 80

    def generate_agent_config
      FileUtils.mkdir_p File.dirname(config[:agent_config_file])
      File.open(config[:agent_config_file], 'w') do |f|
        f.print YAML.dump merge_agent_config
      end
    rescue => e
      raise "Failed to write agent configuration file: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
    end

    protected
    def retrieve_instance_identity
      http = Net::HTTP.new(EC2_METADATA_IP, EC2_METADATA_PORT, nil)
      http.open_timeout = 15
      http.read_timeout = 15
      case response =  http.get("/latest/dynamic/instance-identity/")
      when Net::HTTPSuccess
        instance_identity_document = http.get("/latest/dynamic/instance-identity/document").body
        instance_identity_signature = http.get("/latest/dynamic/instance-identity/signature").body
        {
          :document => instance_identity_document,
          :signature => instance_identity_signature
        }
      else
        raise "Failed to access instance identity on EC2 metadata service"
      end
    rescue Errno::ENETUNREACH, Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Errno::ETIMEDOUT, Timeout::Error, SocketError => e
      Bootstrap::Log.error "Failed to fetch instance identity from EC2 metadata service: #{e.class} - #{e.message}"
      raise e
    end

    def merge_agent_config
      agent_config = {
        :program_name => config[:program_name],
        :root_dir => config[:current_agent_symlink],
        :shared_dir => config[:shared_dir],
        :log_dir => config[:log_dir],
        :pid_dir => config[:pid_dir],
        :user => config[:user],
        :group => config[:group]
      }
      agent_config.update load_agent_pre_config
      agent_config.update generate_instance_keypair
      instance_identity = agent_config[:import] ? retrieve_instance_identity : nil
      agent_config.update register_instance(agent_config, instance_identity)
    rescue => e
      raise "Failed to merge agent configuration: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
    end

    def generate_instance_keypair
      rsa = OpenSSL::PKey::RSA.new(2048)
      public_key = rsa.public_key
      public_key_fingerprint = OpenSSL::Digest::SHA1.new(public_key.to_der).hexdigest
      {
        :instance_private_key => rsa.to_pem,
        :instance_public_key => public_key.to_s,
        :instance_public_key_fingerprint => public_key_fingerprint
      }
    rescue => e
      raise "Failed to generate instance key pair: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
    end

    def load_agent_pre_config
      if File.exists?(config[:agent_pre_config_file])
        YAML.load(File.open(config[:agent_pre_config_file]))
      else
        Bootstrap::Log.error "Agent pre-config not found at #{config[:agent_pre_config_file]}"
      end
    rescue => e
      raise "Failed to load agent pre configuration from file #{config[:agent_pre_config_file]}: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
    end

    def register_instance(agent_config, instance_identity=nil)
      opsworks = AWS::OpsWorks.new(
        :access_key_id => agent_config[:access_key_id],
        :secret_access_key => agent_config[:secret_access_key],
        :ops_works_region => agent_config[:ops_works_region],
        :ops_works_endpoint => agent_config[:ops_works_endpoint],
        :ops_works_port => agent_config[:ops_works_port],
        :ops_works_use_ssl => agent_config[:ops_works_use_ssl],
        :ssl_verify_peer => agent_config[:ssl_verify_peer]
      )
      args = {
        :stack_id => agent_config[:stack_id],
        :hostname => agent_config[:hostname] || find_hostname,
        :public_ip => agent_config[:public_ip] || find_ip_address[:public],
        :private_ip => agent_config[:private_ip] || find_ip_address[:private],
        :rsa_public_key => agent_config[:instance_public_key],
        :rsa_public_key_fingerprint => agent_config[:instance_public_key_fingerprint]
      }
      args.update(:instance_identity => instance_identity) if instance_identity
      instance = opsworks.client.register_instance(args)
      {
        :identity => instance[:instance_id]
      }
    rescue => e
      raise "Failed to register instance with args #{args.inspect}: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
    end

    def find_hostname
      Socket.gethostname[/^.*?(?=\.|$)/]  # hostname without domain
    end

    def find_ip_address
      all_addresses = Socket.ip_address_list.select { |addr| addr.ipv4? && !addr.ipv4_loopback? && !addr.ipv4_multicast? }
      raise "Could not detect any IP address." if all_addresses.empty?
      private_addresses, public_addresses = all_addresses.partition { |addr| addr.ipv4_private? }
      {
        :private => (private_addresses.first || public_addresses.first).ip_address,
        :public => (public_addresses.first || private_addresses.first).ip_address
      }
    end
  end
end
