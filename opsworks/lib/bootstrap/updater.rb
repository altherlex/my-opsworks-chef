require 'tempfile'
require 'timeout'

module Bootstrap
  class Updater < Bootstrap::Installer

    WAIT_AFTER_FAILED_UPDATES = 10 * 60  # 10 minutes
    REMOTE_REVISION_CHECK_RATE = 0.1

    include Bootstrap::Utils
    include Bootstrap::System

    attr_reader :target_version, :agent_url

    def initialize(options = {})
      options = {
        :component => 'agent-updater',
        :config_file => "#{File.expand_path(File.dirname(__FILE__))}/../../conf/bootstrap.yml",
        :log_dir => '/var/log/aws/opsworks'
      }.update(options)
      _config = Bootstrap::Config.load_config(options[:config_file])
      _config.config(options)
      _config.validate
      @config = _config.config
      if options[:log_file].nil? || options[:log_file].empty?
        config[:log_file] = "#{config[:log_dir]}/updater.log"
      else
        config[:log_file] = options[:log_file]
      end
      Bootstrap::Log.init(config[:log_file])
    end

    def update_needed?
      update_needed_due_to_version ||
        rand < REMOTE_REVISION_CHECK_RATE && update_needed_due_to_revision
    end

    def update_needed_due_to_version
      target_version != local_version
    end

    def update_needed_due_to_revision
      remote_revision > local_revision
    end

    def download
      agent_url if @agent_url.nil?
      download_agent_cmd = [
        # Downloads in new temporary directory and returns the file path.
        %(downloaded_file="$(#{File.dirname(__FILE__)}/../../bin/downloader.sh -c "#{agent_url}-checksum" -u "#{agent_url}")"),
        # Move to right place and cleanup download directory.
        %(mv "${downloaded_file}" "/tmp/#{config[:agent_installer_tgz]}"),
        %(rm -rf "/tmp/${download_target}*")
      ].join("\n")
      Bootstrap::Log.info `( #{download_agent_cmd} ) 2>&1`
    rescue Exception => e
      raise "Failed to download update. #{e} - #{e.backtrace.join("\n")}"
    end

    def update_or_rollback
      Dir.mktmpdir do |tmpdir|
        Bootstrap::Log.info 'Extracting new agent'
        execute "tar xzpof /tmp/#{config[:agent_installer_tgz]}", :dir => tmpdir
        Bootstrap::Log.info 'Deleting downloaded files'
        execute "rm -vf /tmp/#{config[:agent_installer_tgz]}*"

        Bootstrap::Log.info 'Installing the new downloaded agent'
        load_class_from "#{tmpdir}/#{config[:agent_installer_tgz].gsub(/\..*$/,'')}/#{config[:program_name]}/lib/bootstrap/update_installer.rb"

        begin
          Bootstrap::Log.measure('Running update-installer'){ Bootstrap::UpdateInstaller.run }
          Bootstrap::Log.info 'Deleting old agents'
          delete_old_agents if config[:delete_old_agents]
          Bootstrap::Log.info 'Successfuly updated instance agent.'
          FileUtils.rm_f failed_setup_marker_file
        rescue Exception => e
          Bootstrap::Log.error "Update unsuccessful, trying to rollback: #{e} - #{e.backtrace.join("\n")}"
          rollback
          delete_broken_update
          FileUtils.touch failed_setup_marker_file
        end
      end
    rescue Exception => e
      Bootstrap::Log.error "Update was unsuccessful, but system should be intact: #{e} - #{e.backtrace.join("\n")}"
    end

    protected
    def rollback
      load_class_from "#{config[:release_dir]}/lib/bootstrap/rollback.rb"
      Bootstrap::Log.measure('Running rollback procedure'){ Bootstrap::Rollback.run }
    rescue Exception => e
      Bootstrap::Log.error "Failed to rollback - agent installation may be broken: #{e} - #{e.backtrace.join("\n")}"
    end

    def delete_broken_update
      broken_update = Dir.glob("#{config[:releases_dir]}/*").sort.last
      if File.identical?(broken_update, config[:release_dir])
        Bootstrap::Log.info 'Nothing to delete, the update broke before copying it into the releases dir.'
      else
        Bootstrap::Log.info "Deleting failed update: #{broken_update}"
        FileUtils.rm_rf broken_update if config[:delete_old_agents]
      end
    rescue Exception => e
      Bootstrap::Log.error "Could not delete broken update: #{e} - #{e.backtrace.join("\n")}"
    end

    def load_class_from(klass_file)
      raise "Bailing out, could not load '#{klass_file}'" unless File.readable?(klass_file)
      load klass_file
    end

    def delete_old_agents
      Bootstrap::Log.info 'Deleting old releases'
      # delete all but the last config[:releases_to_keep] releases
      old_releases = Dir[File.join(config[:releases_dir],'*')].sort_by{|f| File.mtime f}[0 .. -(config[:releases_to_keep].to_i + 1)]
      Bootstrap::Log.debug "Releases to delete: #{old_releases.join(', ')}"
      old_releases.each do |directory|
        Bootstrap::Log.debug "Deleting #{directory}"
        FileUtils.rm_rf directory
      end
    rescue Exception => e
      Bootstrap::Log.error "Could not delete old installations: #{e} - #{e.backtrace.join("\n")}"
    end

    def agent_url
      configuration = YAML.load(File.read(config[:agent_config_file]))
      @agent_url = [configuration[:agent_installer_base_url], target_version, config[:agent_installer_tgz]].join('/')
    end

    def revision_file
      config[:release_dir] + '/REVISION'
    end

    def local_version_file
      File.join(config[:release_dir], "VERSION")
    end

    def local_version
      File.read(local_version_file).chomp
    end

    def local_revision
      if File.exists?(revision_file)
        File.read(revision_file)[/(\d\d\d\d\-\d\d-\d\d-\d\d:\d\d:\d\d)/, 1]
      else
        Bootstrap::Log.info "No local REVISION file? Using '' instead"
        ''
      end
    rescue Exception => e
      Bootstrap::Log.error "Could not parse local REVISION file! Using 0 instead: #{e} - #{e.backtrace.join("\n")}"
      ''
    end

    def target_version_file
      config[:shared_dir] + '/TARGET_VERSION'
    end

    def target_version
      @target_version = File.read(target_version_file).chomp
    end

    def remote_revision
      revision = Timeout::timeout(31) {`curl -m 30 -s #{agent_url + '-REVISION'}`}
      if revision.match(/^(\d\d\d\d-\d\d-\d\d-\d\d:\d\d:\d\d) \d+/)
        $1
      else
        Bootstrap::Log.error "Failed to download remote REVISION file. Falling back to ''"
        ''
      end
    rescue Exception => e
      Bootstrap::Log.error "Could not read remote revision. Falling back to '': #{e} - #{e.backtrace.join("\n")}"
      ''
    end

    def failed_setup_marker_file
      File.join(config[:shared_dir], "FAILED_UPDATE")
    end

    def update_failed_recently?
      File.exist?(failed_setup_marker_file) && Time.now - File.mtime(failed_setup_marker_file) < WAIT_AFTER_FAILED_UPDATES
    end
  end
end
