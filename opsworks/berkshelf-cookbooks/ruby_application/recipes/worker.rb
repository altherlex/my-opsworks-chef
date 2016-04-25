template "#{current_path}/Procfile" do
  source "procfile.erb"
  user config[:user]
  group config[:group]
  variables config[:worker]
end

execute "foreman export upstart /etc/init -a #{app_name} -u #{config[:user]} -l /var/log/#{app_name}" do
  cwd current_path
  environment config["environment_variables"]
end

execute "service #{app_name} restart || service #{app_name} start"
