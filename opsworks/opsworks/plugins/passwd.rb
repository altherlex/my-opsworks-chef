provides 'passwd', 'current_user'

require 'etc'

unless passwd
  passwd Mash.new

  Etc.passwd do |entry|
    passwd[entry.name] = Mash.new(:dir => entry.dir, :gid => entry.gid, :uid => entry.uid, :shell => entry.shell, :gecos => entry.gecos)
  end
end

unless current_user
  current_user Etc.getlogin
end