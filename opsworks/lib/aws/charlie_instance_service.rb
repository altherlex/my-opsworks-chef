require 'aws/core'
require 'aws/charlie_instance_service/config'

module AWS

  class CharlieInstanceService

    autoload :Client, File.expand_path(File.join(File.dirname(__FILE__), 'charlie_instance_service/client'))
    autoload :Errors, File.expand_path(File.join(File.dirname(__FILE__),  'charlie_instance_service/errors'))
    autoload :Request, File.expand_path(File.join(File.dirname(__FILE__), 'charlie_instance_service/request'))

    include Core::ServiceInterface

    endpoint_prefix 'opsworks'

  end
end