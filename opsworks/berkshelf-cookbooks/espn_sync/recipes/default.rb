include_recipe "deploy"
package "imagemagick"
package "libmagick++-dev"
package "nodejs"

gem_package "bundler" do
  gem_binary "/usr/bin/gem"
  action :install
end

gem_package "foreman" do
  gem_binary "/usr/bin/gem"
  action :install
end

swap_file "/mnt/swap" do
  size node[app_name]["swap"]["memory_size"]
end

opsworks_deploy_dir do
  user config[:user]
  group config[:group]
  path config[:deploy_to]
end
