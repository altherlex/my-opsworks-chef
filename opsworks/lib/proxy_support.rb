# loads http proxy information from /etc/environment when this file is required

begin
  File.read("/etc/environment").split("\n").each do |line|
    name, value = line.split(?=, 2)
    next unless %[http_proxy https_proxy].include?(name)
    value.match(/^"(.*)"$/) { |m| value = m[1] }  # strip possible extra quotes
    ENV[name] ||= value  # do not override existing values
  end if File.readable?("/etc/environment")
rescue => e
  warn "Couldn't parse /etc/environment: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
end
