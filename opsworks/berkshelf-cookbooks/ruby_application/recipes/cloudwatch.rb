if first_instance?
  execute "bundle exec whenever --write-crontab" do
    user config[:user]
    group config[:group]
    cwd current_path
    environment config["environment_variables"]
  end
end
