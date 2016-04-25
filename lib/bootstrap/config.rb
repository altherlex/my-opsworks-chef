load File.expand_path(File.dirname(__FILE__) + '/core_ext/hash.rb')

module Bootstrap
  class Config

    def self.init
      @config = Config.new
    end

    def self.config(options = {})
      @config.config(options) or raise 'No configuration available. Please initialize one first.'
    end

    def self.load_config(config_file = "#{File.dirname(__FILE__)}/../../conf/bootstrap.yml")
      if File.exists?(config_file) && File.readable?(config_file)
        yml_config = YAML.load(File.read( config_file )).symbolize_keys
        init.config.update(yml_config)
        @config.generate_missing_values
        @config
      else
        raise "The config file #{config_file} does not exist or is not readable"
      end
    end

    # The #{File.dirname(__FILE__)}/../../conf/bootstrap.yml" contains a minimal
    # configuration. '*' means that the value for this key is generated.
    #
    # program_name => the name of the application ['opsworks-agent']
    # component => the name of the component running, set on the constructor.[nil]
    # user => user to run the agent ['root']
    # group => group to run the agent ['root']
    # root_dir =>  the base dir for the installation ['/opt/aws/opsworks']
    # log_file => log file for the running program [(root_dir)/releases/this_release]*
    # delete_old_agents => delete old agents after successful update [true]
    # current_agent_symlink => is a link to release_dir called current [(root_dir)/current]*
    # release_dir => path to this current release [(root_dir)/releases/TIMESTAMP-REVISION]*
    # releases_dir => path to the releases folders [(root_dir)/releases]*
    # shared_dir => path to shared folders [(root_dir)/shared]*
    # log_dir => path to log dir [(shared_dir)/log]*
    # pid_dir => path to pid dir [(shared_dir)/pid]*
    # client_binary => nil,
    # ruby_bin => ['#{root_dir}/local/bin/ruby'], the ruby binary the agent uses
    # gem_bin => ['#{root_dir}/local/bin/gem'], the gem binary the agent uses
    # rubygems_version => desired rubygems version, must be set to the current supported version
    # agent_config_file => ['/etc/instance_agent.yml']
    # agent_client_symlink_target_dir => ['/usr/sbin/']
    # agent_client_file_name => name of the file with out path ['opsworks-client']
    # agent_client => this will be generated, path to client in current release
    # agent_installer_tgz => name of the downloaded package ['#{program_name}-installer.tgz']
    # agent_installer_dir => where to unpack the downloaded package [/tmp/opsworks-agent-installer]
    def initialize
      @config = {
        :agent_client => nil,
        :agent_client_file_name => 'opsworks-agent-cli',
        :agent_client_symlink_target_dir => '/usr/sbin',
        :agent_config_file => '/etc/aws/opsworks/instance-agent.yml',
        :agent_installer_dir => '/tmp/opsworks-agent-installer',
        :agent_installer_tgz => 'opsworks-agent-installer.tgz',
        :agent_pre_config_file => '/var/lib/aws/opsworks/pre_config.yml',
        :component => nil,
        :current_agent_symlink => nil,
        :delete_old_agents => true,
        :gem_bin => '/opt/aws/opsworks/local/bin/gem',
        :group => 'root',
        :log_dir => nil,
        :log_file => nil,
        :pid_dir => nil,
        :program_name => 'opsworks-agent',
        :release_dir => nil,
        :releases_dir => nil,
        :releases_to_keep => '3',
        :root_dir => '/opt/aws/opsworks',
        :ruby_bin => '/opt/aws/opsworks/local/bin/ruby',
        :shared_dir => nil,
        :user => 'root'
      }
    end

    def config(options = {})
      unless options.nil? || options.empty?
        @config.update(options)
        generate_missing_values
      end
      @config
    end

    def generate_missing_values
      [
       'agent_client',
       'current_agent_symlink',
       'shared_dir',
       'pid_dir',
       'log_dir',
       'log_file',
       'releases_dir',
       'release_dir',
      ].each do |k|
        self.send(k) if @config[k.to_sym].nil?
       end
    end

    def validate
      find_keys_with_nil_values
    end

    def find_keys_with_nil_values
      @config.keys.each do |k|
        raise "Invalid bootstrap configuration. #{k} shouldn't be nil." if @config[k.to_sym].nil?
      end
    end

    private
    #
    # The following methods are used to generate/populate the config object.
    def current_agent_symlink
      @config[:current_agent_symlink] = "#{@config[:root_dir]}/current"
    end

    def releases_dir
      @config[:releases_dir] = "#{@config[:root_dir]}/releases"
    end

    def release_dir
      revision = File.read("#{File.expand_path(File.dirname(__FILE__))}/../../REVISION").split
      # TODO: can be written much clearer after reworking revision file handling (YAML instead of space separation), next line as well
      raise "Corrupt REVISION file. Aborting." if revision.join(' ').scan(/\d{4}-\d{2}-\d{2}-\d\d:\d\d:\d\d \d.*/).empty?
      @config[:release_dir] = "#{releases_dir}/#{revision.shift.gsub(/[-|:]/,'')}_#{revision.shift}"
    end

    def shared_dir
      @config[:shared_dir] = "#{@config[:root_dir]}/shared"
    end

    def log_dir
      @config[:log_dir] = "#{@config[:shared_dir]}/log"
    end

    def log_file
      @config[:log_file] = "#{@config[:log_dir]}/#{@config[:component]}.log"
    end

    def pid_dir
      @config[:pid_dir] = "#{@config[:shared_dir]}/pid"
    end

    def agent_client
      @config[:agent_client] = "#{current_agent_symlink}/bin/#{@config[:agent_client_file_name]}"
    end
  end
end
