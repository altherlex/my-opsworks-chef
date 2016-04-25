# encoding: UTF-8
module InstanceAgent
  module Runner
    class Master < ProcessManager::Daemon::Master

      def self.description(pid = $$)
        "master #{pid}"
      end

      def self.child_class
        ::InstanceAgent::Runner::Child
      end

      def self.pid_description
        ProcessManager::Config.config[:program_name]
      end

      def after_initialize
      end

      def self.log_file
        File.join(ProcessManager::Config.config[:log_dir], "#{ProcessManager::Config.config[:program_name]}.log")
      end

      def self.pid_file
        File.join(ProcessManager::Config.config[:pid_dir], "#{ProcessManager::Config.config[:program_name]}.pid")
      end

    end
  end
end
