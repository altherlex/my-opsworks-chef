def first_instance?
  if node["opsworks"]["instance"]["layers"].include?("application")
    instances = node["opsworks"]["layers"]["application"]["instances"].keys
    current_instance = node["opsworks"]["instance"]["hostname"]

    !instances.first || instances.first == current_instance
  end
end

def app_name
  node["espn_sync"]["name"]
end

def config
  node["deploy"][app_name]
end

def rails_env
  config["environment_variables"]["RAILS_ENV"] || "production"
end

def current_path
  "#{config["deploy_to"]}/current"
end

def shared_path
  "#{config["deploy_to"]}/shared"
end
