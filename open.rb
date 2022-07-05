require 'cgi'
require 'uri'

url = ARGV[0] || "gopher://gopher.floodgap.com"
`start http://localhost:5678/req?url=#{CGI::escape(url)}`