# -*- encoding: utf-8 -*-
# stub: bourne 1.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "bourne"
  s.version = "1.5.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Joe Ferris"]
  s.date = "2013-06-27"
  s.description = "Extends mocha to allow detailed tracking and querying of\n    stub and mock invocations. Allows test spies using the have_received rspec\n    matcher and assert_received for Test::Unit. Extracted from the\n    jferris-mocha fork."
  s.email = "jferris@thoughtbot.com"
  s.homepage = "http://github.com/thoughtbot/bourne"
  s.rubygems_version = "2.2.1"
  s.summary = "Adds test spies to mocha."

  s.installed_by_version = "2.2.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<mocha>, ["< 0.15", ">= 0.13.2"])
      s.add_development_dependency(%q<rake>, [">= 0"])
    else
      s.add_dependency(%q<mocha>, ["< 0.15", ">= 0.13.2"])
      s.add_dependency(%q<rake>, [">= 0"])
    end
  else
    s.add_dependency(%q<mocha>, ["< 0.15", ">= 0.13.2"])
    s.add_dependency(%q<rake>, [">= 0"])
  end
end
