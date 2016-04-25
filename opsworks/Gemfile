
# we do not want any user gems,
# only the ones bundled by us
#disable_system_gems

source 'https://rubygems.org'

# our dependencies
gem 'bundler', '1.5.3'
gem 'activesupport','3.2.16',  :require => 'active_support'
gem 'json', '1.7.7'
gem 'multi_json', '1.7.4'
gem 'gli', '2.5.6'
gem 'aws-sdk', '1.65.0'
gem 'nokogiri', '1.5.9'
gem 'process_manager', '0.0.18'

gem 'diff-lcs'
gem 'chef-zero'
gem 'chef', '11.10.4'
gem 'ipaddress'
gem 'mixlib-shellout'
gem 'yajl-ruby'
gem 'ohai', '6.20.0', :path => 'vendor/gems/ohai-6.20.0'
gem 'ruby-hmac', '0.4.0'
gem 'thor', '0.18.1'
gem 'mixlib-authentication'#, '~>1.3.0'
gem 'mixlib-cli'#, '~>1.3.0'
gem 'mixlib-config'#, '1.1.2'
gem 'mixlib-log'#, '1.6.0'
gem 'net-ssh-multi', '~> 1.1.0'

gem 'highline', '1.6.19'

gem 'moneta'#, '0.7.16'  # fixed version as dependency to the old chef version
gem 'minitest-chef-handler', '1.0.1'
#fix this ones for now
gem 'erubis', '2.7.0'
gem 'uuidtools', '2.1.4'
gem 'systemu', '2.5.2'
# require'ing rake causes Rake::DSL#desc to hide GLI::DSL#desc and thus breaks the CLI docs
gem 'rake', '10.0.3', :require => false
gem 'rest-client', '1.6.7'
gem 'mime-types', '1.23'
gem 'daemons', '1.1.9'

group :development do
# this doesn't need to be a global or even a standart depency
# use it if you need it, but don't commit it.
#  gem 'ruby-debug', '0.10.4', :require => nil
#  gem 'ruby-debug-base', '0.10.4', :require => nil
end

group :test do
  gem 'test-unit', '2.5.5'
  gem 'shoulda', '3.5.0'
  gem 'shoulda-matchers', '1.5.6'
  gem 'shoulda-context', '1.1.2'
  gem 'mocha', '0.13.3', :require => 'mocha/setup'
  gem 'fakefs', '0.5.1', :require => 'fakefs/safe'
  gem 'timecop', '0.6.1'
end

