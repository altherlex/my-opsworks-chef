require 'ohai'

module InstanceAgent
  module Agent
    class KeepAlive < Base
      VERSION = '2013-01-23'

      def perform
        log :debug, 'Performing keepalive'
        duration = Benchmark.realtime do
          Timeout::timeout(120) do
            client.report_keep_alive(:keep_alive_report => JSON.dump(message))
          end
        end
        log :info, "Reporting keepalive. (#{"%.3f" % duration} sec)"
      end

      protected
      def message
        cipher = OpenSSL::Cipher::AES.new(128, :CBC)
        cipher.encrypt
        key = cipher.random_key
        iv = Base64.encode64(cipher.random_iv)
        encrypted_data = Base64.encode64(cipher.update(data) + cipher.final)

        encrypted_key = InstanceAgent::Crypto.encrypt_key(key)
        signature = InstanceAgent::Crypto.sign(encrypted_data)
        iv_signature = InstanceAgent::Crypto.sign(iv)

        {
          :type => 'keep_alive',
          :version => VERSION,
          :payload => {
            :signature => signature,
            :signature_key_id => InstanceAgent::Crypto.instance_public_key_fingerprint,
            :encrypted_key => encrypted_key,
            :iv => iv,
            :iv_signature => iv_signature,
            :encrypted_data => encrypted_data
          }
        }
      end

      def data
        JSON.dump({
          :agent_version => self.agent_version,
          :sent_at => Time.now.utc.iso8601
        }.update(platform_data))
      end

      def platform_mapping(ohai_platform)
        case ohai_platform
        when "redhat"
          "Red Hat Enterprise Linux"
        else
          ohai_platform
        end
      end

      def platform_data
        ohai = Ohai::System.new
        ohai.require_plugin 'os'
        ohai.require_plugin 'platform'
        {
          :platform => {
            :family => ohai.platform_family,
            :name => platform_mapping(ohai.platform),
            :version => ohai.platform_version
          }
        }
      rescue Exception => e
        log :warn, "Errors occurred while gathering platform data: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        {}
      end
    end
  end
end
