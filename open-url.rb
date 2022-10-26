require 'cgi'

port = ARGV[1].to_i
host = ARGV[0]
if host =~ /[ *~#"'&%]/
	throw "Invalid Hostname!"
end
url = ARGV[2].strip

puts http://#{host}:#{port}/url?#{CGI.escape(url)}
