module Bootstrap
  module Utils
    include Bootstrap::OSDetect

    def set_path
      ENV['PATH'] = "#{config[:current_agent_symlink]}/bin:#{ENV['PATH']}"
    end

    def ubuntu_code_name
      `lsb_release --codename --short`.strip
    end

    def yum(cmd)
      execute("yum --assumeyes #{cmd}", :retries => 3, :retry_delay => 10)
    end

    def apt_get(cmd)
      execute("apt-get --assume-yes #{cmd}", :retries => 3, :retry_delay => 10)
    end

    def set_hostname
      hostname = instance_hostname
      unless hostname.nil? || hostname.empty?
        if File.exists?('/usr/bin/ec2-set-hostname')
          FileUtils.rm '/usr/bin/ec2-set-hostname' or raise 'Could not delete /usr/bin/ec2-set-hostname'
        end

        execute("hostname #{hostname}") or raise "Could not set the hostname to #{hostname.inspect}"
        system("echo '#{hostname}' > /etc/hostname")
        system("echo '127.0.0.1 #{hostname}.localdomain #{hostname}' >> /etc/hosts") or raise 'Could not update /etc/hosts'
        if amazon_linux?
          network_config_file = '/etc/sysconfig/network'
          content = File.read(network_config_file).sub(/^HOSTNAME.*$/, "\n#OpsWorks hostname\nHOSTNAME=#{hostname}\n")
          File.open(network_config_file, 'w') do |f|
            f.puts content
          end
        elsif redhat? && platform_version.start_with?("7") && File.exist?("/etc/cloud/cloud.cfg.d")
          File.write("/etc/cloud/cloud.cfg.d/10_opsworks.cfg", <<EOM
# cloud-init 0.7.6 ships with a bug on setting hostname when used on rhel distributions using systemd
# This behaviour is fixed in 0.7.7 with commit http://bazaar.launchpad.net/~cloud-init-dev/cloud-init/trunk/revision/1103
# preserve_hostname enabled will not run the set_hostname/update_hostname modules on boot.
# This disables the detection based on ec2 metadata service. Otherwise the hostname will be overwritten on every boot.
preserve_hostname: true
EOM
                    )
        end
      end
    end

    def instance_hostname
      `hostname`
    rescue Exception => e
      Bootstrap::Log.error "Could not retrieve instance hostname: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
      ''
    end

    def install_package(pkg)
      if debian_family?
        apt_get "install #{pkg}"
      elsif rhel_family?
        yum "install #{pkg}"
      end
    end

    def enable_service(svc)
      if uses_systemd?
        execute "systemctl enable #{svc}"
      elsif debian_family?
        execute "update-rc.d #{svc} enable"
      elsif rhel_family?
        execute "chkconfig #{svc} on"
      end
    end

    def reboot_required?
      if debian_family?
        File.exists?('/var/run/reboot-required')
      elsif rhel_family?
        `uname -r`.chomp != `rpm -q --last kernel | perl -pe 's/^kernel-(\\S+).*/$1/' | head -1`.chomp
      end
    end

    def execute(cmd, options = {})
      options = {
        :dir => '/tmp',
        :retries => 0,
        :retry_delay => 2
      }.update(options)
      num_retries = 0

      Bootstrap::Log.info "About to execute \`#{cmd.inspect}\` from #{options[:dir]} with #{options[:retries]} retries"
      Dir.chdir(options[:dir]) do
        loop do
          output = `#{cmd} 2>&1`
          Bootstrap::Log.debug("#{output.chomp}") unless output.empty?
          if $? == 0
            break
          else
            if num_retries < options[:retries]
              Bootstrap::Log.debug("Retrying command \`#{cmd.inspect}\` #{$?}, retry num #{num_retries + 1} of #{options[:retries]}, waiting #{options[:retry_delay]}s")
              sleep(options[:retry_delay])
              num_retries += 1
              next
            else
              raise "Failed to execute #{cmd.inspect} #{$?}: #{output}"
            end
          end
        end
      end
      true
    end
  end
end
