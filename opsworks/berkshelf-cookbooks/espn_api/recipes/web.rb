include_recipe "nginx::service"

if first_instance?
  execute "bundle exec rake db:migrate" do
    user config[:user]
    group config[:group]
    cwd current_path
    environment config["environment_variables"]
  end
end

execute "bundle exec rake assets:precompile" do
  user config[:user]
  group config[:group]
  cwd current_path
  environment config["environment_variables"].merge("RAILS_GROUPS" => "assets")
end

template "#{current_path}/Procfile" do
  source "procfile.erb"
  user config[:user]
  group config[:group]
  variables command: "bundle exec puma -C config/puma.rb"
end

execute "foreman export upstart /etc/init -a #{app_name} -u #{config[:user]} -l /var/log/#{app_name}" do
  cwd current_path
  environment config["environment_variables"]
end

execute "service #{app_name} restart || service #{app_name} start"

service "nginx" do
  supports reload: true
  action :reload
end
