# encoding: UTF-8
# no fancy requires. This is code that runs during bootstrapping!!
# keep it small and low in dependencies

ENV['PATH'] = ['/opt/aws/opsworks/local/bin', '/usr/bin','/usr/sbin','/bin','/sbin'].join(':') + ':' + ENV['PATH']

File.umask 077

unless defined?(Bootstrap)
  require File.expand_path(File.dirname(__FILE__) + '/bootstrap/config')
  require File.expand_path(File.dirname(__FILE__) + '/bootstrap/log')
  require File.expand_path(File.dirname(__FILE__) + '/bootstrap/os_detect')
  require File.expand_path(File.dirname(__FILE__) + '/bootstrap/utils')
  require File.expand_path(File.dirname(__FILE__) + '/bootstrap/system')
  require File.expand_path(File.dirname(__FILE__) + '/bootstrap/installer')
  require File.expand_path(File.dirname(__FILE__) + '/bootstrap/updater')
end

module Bootstrap
  module System
  end

  module Utils
  end
end
