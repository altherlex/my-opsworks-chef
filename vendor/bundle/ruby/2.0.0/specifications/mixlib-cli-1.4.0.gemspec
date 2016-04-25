# -*- encoding: utf-8 -*-
# stub: mixlib-cli 1.4.0 ruby lib

Gem::Specification.new do |s|
  s.name = "mixlib-cli"
  s.version = "1.4.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Opscode, Inc."]
  s.date = "2013-12-05"
  s.description = "A simple mixin for CLI interfaces, including option parsing"
  s.email = "info@opscode.com"
  s.extra_rdoc_files = ["README.rdoc", "LICENSE", "NOTICE"]
  s.files = ["LICENSE", "NOTICE", "README.rdoc"]
  s.homepage = "http://www.opscode.com"
  s.rubygems_version = "2.2.1"
  s.summary = "A simple mixin for CLI interfaces, including option parsing"

  s.installed_by_version = "2.2.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 0"])
      s.add_development_dependency(%q<rdoc>, [">= 0"])
    else
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 0"])
      s.add_dependency(%q<rdoc>, [">= 0"])
    end
  else
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 0"])
    s.add_dependency(%q<rdoc>, [">= 0"])
  end
end
