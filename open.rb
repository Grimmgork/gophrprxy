require_relative './app.rb'

url = ARGV[0] || "gopher://gopher.floodgap.com"
gurl = GopherUrl.new(url)

`start http://localhost:5678/#{Application.GetProxyPath(gurl)}`