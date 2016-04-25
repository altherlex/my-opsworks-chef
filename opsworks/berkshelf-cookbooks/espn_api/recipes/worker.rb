# Not incremental per deploy on crontab tasks
execute "crontab -l | sed 's/>/>>/' | crontab - && crontab -r && crontab -l | sed 's/>/>>/' | crontab -" do
  user config[:user]
  group config[:group]
  cwd current_path
  environment config["environment_variables"]
end

execute "bundle exec whenever --set 'environment=#{rails_env}' --update-crontab" do
  user config[:user]
  group config[:group]
  cwd current_path
  environment config["environment_variables"]
end

template "#{current_path}/Procfile" do
  source "procfile.erb"
  user config[:user]
  group config[:group]
  variables command: "bundle exec shoryuken -R -C config/shoryuken.yml"
end

execute "foreman export upstart /etc/init -a #{app_name} -u #{config[:user]} -l /var/log/#{app_name}" do
  cwd current_path
  environment config["environment_variables"]
end

file "/var/log/pubnub.log" do
  user config[:user]
  group config[:group]
  mode "0755"
end

execute "service #{app_name} restart || service #{app_name} start"
