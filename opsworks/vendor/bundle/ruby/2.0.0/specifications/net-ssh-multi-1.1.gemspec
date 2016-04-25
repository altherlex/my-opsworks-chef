# -*- encoding: utf-8 -*-
# stub: net-ssh-multi 1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "net-ssh-multi"
  s.version = "1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Jamis Buck", "Delano Mandelbaum"]
  s.date = "2011-04-03"
  s.description = "Control multiple Net::SSH connections via a single interface."
  s.email = ["net-ssh@solutious.com"]
  s.extra_rdoc_files = ["README.rdoc", "CHANGELOG.rdoc"]
  s.files = ["CHANGELOG.rdoc", "README.rdoc"]
  s.homepage = "http://github.com/net-ssh/net-ssh"
  s.rdoc_options = ["--line-numbers", "--title", "Control multiple Net::SSH connections via a single interface.", "--main", "README.rdoc"]
  s.rubyforge_project = "net-ssh-multi"
  s.rubygems_version = "2.2.1"
  s.summary = "Control multiple Net::SSH connections via a single interface."

  s.installed_by_version = "2.2.1" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<net-ssh>, [">= 2.1.4"])
      s.add_runtime_dependency(%q<net-ssh-gateway>, [">= 0.99.0"])
    else
      s.add_dependency(%q<net-ssh>, [">= 2.1.4"])
      s.add_dependency(%q<net-ssh-gateway>, [">= 0.99.0"])
    end
  else
    s.add_dependency(%q<net-ssh>, [">= 2.1.4"])
    s.add_dependency(%q<net-ssh-gateway>, [">= 0.99.0"])
  end
end
