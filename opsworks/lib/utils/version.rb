module InstanceAgent
  module Agent
    module Version
      def agent_version
        File.read(InstanceAgent::Config.config[:root_dir] + '/VERSION').strip
      rescue
        '0'
      end
    end
  end
end
