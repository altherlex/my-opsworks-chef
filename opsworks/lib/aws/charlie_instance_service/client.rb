module AWS
  class CharlieInstanceService
    class Client < Core::JSONClient

      API_VERSION = '2012-10-25'
      CACHEABLE_REQUESTS = Set[]

      signature_version :Version4, 'CharlieInstanceService'

      def self.load_api_config(api_version)
        path = "#{File.dirname(__FILE__)}/../../../conf/charlie_instance_service_#{api_version}.yml"
        YAML.load(File.read(path))
      end

      class Client::V20121025 < Client
        define_client_methods(API_VERSION)
      end

    end
  end
end
