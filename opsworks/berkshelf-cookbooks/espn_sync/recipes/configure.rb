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
