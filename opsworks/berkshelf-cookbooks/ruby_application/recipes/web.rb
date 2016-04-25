include_recipe "nginx::service"

template "/etc/nginx/sites-available/#{app_name}" do
  source "nginx.conf.erb"
  owner "root"
  group "root"
  mode 00644
  variables({
    "application" => app_name,
    "deploy" => config
  })
end

nginx_site app_name, enabled: true

directory "#{current_path}/tmp/sockets" do
  recursive true
  action :delete
end

link "#{current_path}/tmp/sockets" do
  to "#{shared_path}/sockets"
  owner config[:user]
  group config[:group]
end

template "#{current_path}/Procfile" do
  source "procfile.erb"
  user config[:user]
  group config[:group]
  variables config[:web]
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
