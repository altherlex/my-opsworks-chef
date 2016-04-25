template "#{current_path}/config/database.yml" do
  source "database.yml.erb"
  user config[:user]
  group config[:group]
  variables rails_env: rails_env, database: config[:database]
end

if first_instance?
  execute "bundle exec rake db:migrate" do
    user config[:user]
    group config[:group]
    cwd current_path
    environment config["environment_variables"]
  end
end
