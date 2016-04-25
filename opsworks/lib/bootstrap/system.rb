require 'timeout'
load File.expand_path(File.dirname(__FILE__) + '/core_ext/string.rb')

module Bootstrap
  module System

    def install_bundled_gems
      # install all bundled gems, to our custom gem environment
      execute "#{config[:root_dir]}/local/bin/bundle install --local --shebang '#{config[:ruby_bin]}' --binstubs --deployment", :dir => config[:release_dir]
    end

    def install_lockrun
      execute "gcc #{config[:release_dir]}/vendor/lockrun/lockrun.c -o #{config[:release_dir]}/bin/lockrun"
    end

    # ensure the lock file exists and has the right ownership and permisisons
    def prepare_lockrun
      lockfile = "#{config[:shared_dir]}/lockrun.lock"
      FileUtils.touch lockfile
      FileUtils.chmod 0640, lockfile
      FileUtils.chown config[:user], config[:group], lockfile
    end

    def configure_sudo
      FileUtils.mkdir_p '/etc/sudoers.d'
      FileUtils.chmod 0750, '/etc/sudoers.d'
      File.open("/etc/sudoers.d/#{config[:program_name]}", 'w') do |sudoers|
         sudoers.puts "#{config[:user]} ALL=NOPASSWD:#{config[:current_agent_symlink]}/bin/chef_command_wrapper.sh, " +
                      "#{config[:current_agent_symlink]}/bin/chef-client, " +
                      "#{config[:current_agent_symlink]}/bin/opsworks-agent-uninstaller"

        sudoers.puts "Defaults:#{config[:user]} !requiretty"
      end
      FileUtils.chmod 0440, "/etc/sudoers.d/#{config[:program_name]}"

      if File.read('/etc/sudoers').scan(/^#include\ \/etc\/sudoers.d\/#{config[:program_name]}$/).empty?
        File.open('/etc/sudoers', 'a') do |sudoers|
          sudoers.puts "#include /etc/sudoers.d/#{config[:program_name]}"
        end
      end
    end

    def uninstall_old_updater_cron_jobs
      if (old_crontab = File.read("/etc/crontab")).include?(config[:program_name])
        File.open("/etc/crontab", "w") do |crontab|
          old_crontab.lines.each do |line|
            crontab.puts line unless line.include?("#{config[:program_name]}-updater")
          end
        end
      end
    end

    def install_updater_cron_job
      uninstall_old_updater_cron_jobs
      File.open("/etc/cron.d/#{config[:program_name]}-updater", "w") do |crontab|
        crontab.puts 'MAILTO=""'
        crontab.puts "* * * * * root cd #{config[:current_agent_symlink]} && bin/lockrun --verbose --lockfile=#{config[:shared_dir]}/lockrun.lock -- #{config[:current_agent_symlink]}/bin/#{config[:program_name]}-updater"
      end
    rescue Exception => e
      raise "Failed to install the updater cron job: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
    end

    def install_instance_agent_monit
      conf_dir = ''
      monitrc = ''
      instance_agent_monitrc = ''

      if rhel_family?
        conf_dir = '/etc/monit.d'
        monitrc = '/etc/monit.conf'
      else
        conf_dir = '/etc/monit/conf.d'
        monitrc = '/etc/monit/monitrc'
      end

      instance_agent_monitrc = "#{conf_dir}/#{config[:program_name]}.monitrc"

      FileUtils.mkdir_p conf_dir

      File.open('/etc/default/monit', 'w') do |file|
        if debian_family?
          file.puts <<-EO_MONIT.strip_heredoc
            START=yes
          EO_MONIT
        else
          file.puts <<-EO_MONIT.strip_heredoc
            startup=1
            CHECK_INTERVALS=120
          EO_MONIT
        end
      end

      File.open(monitrc, 'w') do |file|
        file.puts <<-EO_MONITRC.strip_heredoc
          set daemon 60
          set mailserver localhost
          set eventqueue
              basedir /var/monit
              slots 100
          set logfile syslog
          Include #{conf_dir}/*.monitrc
          set httpd port 2812 and use the address localhost
            allow localhost
        EO_MONITRC
      end
      File.open("#{conf_dir}/#{config[:program_name]}.monitrc", 'w') do |file|
        if rhel_family?
          file.puts <<-EO_MONITRC.strip_heredoc
            check process #{config[:program_name]} with pidfile "#{config[:pid_dir]}/#{config[:program_name]}.pid"
              start program = "/usr/bin/env #{agent_command("start")}"
              stop program = "/usr/bin/env #{agent_command("stop")}"
              depends on #{config[:program_name]}-statistic-daemons-log
              depends on #{config[:program_name]}-process-command-daemons-log
              depends on #{config[:program_name]}-keep-alive-daemons-log
              group opsworks

            # check run of statistic daemon
            check file #{config[:program_name]}-statistic-daemons-log with path "#{config[:log_dir]}/opsworks-agent.statistics.log"
              if timestamp > 2 minutes for 3 cycles then restart
              group opsworks

            # check run of process command daemon
            check file #{config[:program_name]}-process-command-daemons-log with path "#{config[:log_dir]}/opsworks-agent.process_command.log"
              if timestamp > 2 minutes for 3 cycles then restart
              group opsworks

            # check run of keep alive deamon
            check file #{config[:program_name]}-keep-alive-daemons-log with path "#{config[:log_dir]}/opsworks-agent.keep_alive.log"
              if timestamp > 2 minutes for 3 cycles then restart
              group opsworks
          EO_MONITRC
        else
          file.puts <<-EO_MONITRC.strip_heredoc
            check process #{config[:program_name]} with pidfile "#{config[:pid_dir]}/#{config[:program_name]}.pid"
              start program = "/usr/bin/env #{agent_command("start")}"
              stop program = "/usr/bin/env #{agent_command("stop")}"
              depends on #{config[:program_name]}-master-running
              depends on #{config[:program_name]}-statistic-daemons-log
              depends on #{config[:program_name]}-process-command-daemons-log
              depends on #{config[:program_name]}-keep-alive-daemons-log
              group opsworks

            check process #{config[:program_name]}-master-running matching "#{config[:program_name]}:\\smaster"
              if not exist for 2 cycles then restart
              group opsworks

            # check run of statistic daemon
            check file #{config[:program_name]}-statistic-daemons-log with path "#{config[:log_dir]}/opsworks-agent.statistics.log"
              if timestamp > 2 minutes for 3 cycles then restart
              if does not exist for 3 cycles then restart
              group opsworks

            # check run of process command daemon
            check file #{config[:program_name]}-process-command-daemons-log with path "#{config[:log_dir]}/opsworks-agent.process_command.log"
              if timestamp > 2 minutes for 3 cycles then restart
              if does not exist for 3 cycles then restart
              group opsworks

            # check run of keep alive deamon
            check file #{config[:program_name]}-keep-alive-daemons-log with path "#{config[:log_dir]}/opsworks-agent.keep_alive.log"
              if timestamp > 2 minutes for 3 cycles then restart
              if does not exist for 3 cycles then restart
              group opsworks
          EO_MONITRC
        end
      end
      if reboot_required?
        Bootstrap::Log.info 'Reboot required - will not restart monit now.'
      else
        Bootstrap::Log.info 'Reboot not required - will restart monit now.'
        execute('service monit restart')
      end
    end

    def setup_logrotate
      File.open("/etc/logrotate.d/#{config[:program_name]}", 'w') do |file|
        file.puts <<-EOF.strip_heredoc
          #{config[:log_dir]}/*.log {
              rotate 20
              dateext
              dateformat -%Y-%m-%d
              compress
              missingok
              notifempty
              size 1024k
              copytruncate
          }
        EOF
      end
    end

    ['start','stop'].each do |action|
      define_method("#{action}_monit") do |*args|
        Dir.chdir(config[:release_dir]) do
          execute "service monit #{action}" or raise "Failed to #{action} monit"
        end
      end
    end

    ['start','stop'].each do |action|
      define_method("#{action}_agent") do |*args|
        Dir.chdir(config[:release_dir]) do
          system(agent_command(action)) or raise "Failed to #{action} agent"
        end
      end
    end

    def agent_command(action)
      if uses_systemd?
        "systemctl #{action} #{config[:program_name]}"
      else
        "service #{config[:program_name]} #{action}"
      end
    end

    def uses_systemd?
      system("hash systemctl 2>/dev/null") # use systemctl for systemd
    end

    def restart_monit
      stop_monit
      start_monit
    end

    def agent_starts?
      Dir.chdir(config[:release_dir]) do
        # 'status' will deliever 1 in case the agent is not running, so
        # we cannot use the method execute, because we'll raise an exception
        if system(agent_command("status"))
          stop_agent
          wait_until_agent_dies
        end
        start_agent
        stop_agent
        wait_until_agent_dies
      end
    end

    def rpm_installed?(name)
      system("rpm -q '#{name}'", :out => :close)
    end

    protected
    # wait until agent dies or kill it after 60 seconds
    def wait_until_agent_dies
      Timeout::timeout(60) do
        if running_agent_processes.size == 0
          break
        end

        Bootstrap::Log.debug "Waiting for the agent to stop, still #{procs.size} procesess running.\n#{procs.join("\n")}"
        sleep 5
      end
    rescue Timeout::Error => e
      Bootstrap::Log.info "Timeout exceeded, Killing all running instance agent processes."
      running_agent_processes.each do |p|
        `kill -9 #{p.split.first}` or raise "Cannot kill process #{p.inspect.split.first}"
      end
    end

    # deliver an array with the current running agent processes, each element starting with the pid
    def running_agent_processes
      `ps ax`.split(/\n/).collect{|l| l.scan(/.*#{config[:program_name]}.*:\ of\ master/)}.flatten.compact
    end
  end
end
