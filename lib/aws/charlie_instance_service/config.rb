svc = AWS::SvcDetails.new('CharlieInstanceService', :full_name => 'AWS OpsWorks CharlieInstanceService', :method_name => :charlie_instance_service)

AWS::SERVICES[svc.class_name] = svc

AWS::Core::Configuration.module_eval do
  add_service svc.class_name, svc.method_name.to_s, 'opsworks-instance-service.us-east-1.amazonaws.com'
end