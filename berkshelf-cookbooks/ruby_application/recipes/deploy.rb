include_recipe "deploy"

opsworks_deploy do
  deploy_data config
  app app_name
end

execute "bundle check --path=#{shared_path}/bundle || bundle install --binstubs #{shared_path}/bin --path #{shared_path}/bundle --deployment --without development test" do
  user config[:user]
  group config[:group]
  cwd current_path
  environment config["environment_variables"]
end

template "#{current_path}/.env" do
  source "dotenv.erb"
  user config[:user]
  group config[:group]
  variables environment_variables: config[:environment_variables]
end
