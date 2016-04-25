# -*- encoding: utf-8 -*-
# stub: minitest-chef-handler 1.0.1 ruby lib

Gem::Specification.new do |s|
  s.name = "minitest-chef-handler"
  s.version = "1.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["David Calavera"]
  s.date = "2013-04-25"
  s.description = "Run minitest suites after your Chef recipes to check the status of your system."
  s.email = ["david.calavera@gmail.com"]
  s.homepage = ""
  s.rubygems_version = "2.2.1"
  s.summary = "Run Minitest suites as Chef report handlers"

  s.installed_by_version = "2.2.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<minitest>, ["~> 4.7.3"])
      s.add_runtime_dependency(%q<chef>, [">= 0"])
      s.add_runtime_dependency(%q<ci_reporter>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
      s.add_development_dependency(%q<mocha>, [">= 0"])
      s.add_development_dependency(%q<appraisal>, [">= 0"])
      s.add_development_dependency(%q<ffi>, [">= 1"])
      s.add_development_dependency(%q<vagrant>, [">= 1.1"])
      s.add_development_dependency(%q<berkshelf>, [">= 1.3.1"])
      s.add_development_dependency(%q<berkshelf-vagrant>, [">= 0"])
    else
      s.add_dependency(%q<minitest>, ["~> 4.7.3"])
      s.add_dependency(%q<chef>, [">= 0"])
      s.add_dependency(%q<ci_reporter>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
      s.add_dependency(%q<mocha>, [">= 0"])
      s.add_dependency(%q<appraisal>, [">= 0"])
      s.add_dependency(%q<ffi>, [">= 1"])
      s.add_dependency(%q<vagrant>, [">= 1.1"])
      s.add_dependency(%q<berkshelf>, [">= 1.3.1"])
      s.add_dependency(%q<berkshelf-vagrant>, [">= 0"])
    end
  else
    s.add_dependency(%q<minitest>, ["~> 4.7.3"])
    s.add_dependency(%q<chef>, [">= 0"])
    s.add_dependency(%q<ci_reporter>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
    s.add_dependency(%q<mocha>, [">= 0"])
    s.add_dependency(%q<appraisal>, [">= 0"])
    s.add_dependency(%q<ffi>, [">= 1"])
    s.add_dependency(%q<vagrant>, [">= 1.1"])
    s.add_dependency(%q<berkshelf>, [">= 1.3.1"])
    s.add_dependency(%q<berkshelf-vagrant>, [">= 0"])
  end
end
