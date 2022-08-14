require 'socket'
require 'uri'
require 'cgi'
require 'erb'

require_relative './templ.rb'
require_relative './mime.rb'

class Application
	def call(req)
		segments = req["PATH_INFO"].split("/").select {|e| e != ".." && e != "" }
		method = req["REQUEST_METHOD"]
		content = req["CONTENT"]

		if segments.length == 0
			return redirectToDefaultPage()
		end

		#get /static/*
		if segments[0] == 'static' && method == 'GET'
			headers = {"content-type" => MIME_EXT[File.extname(segments[-1])]}
			fileName = "./#{segments.join("/")}"
			if File.file?(fileName)
				return 200, headers, [ File.open(fileName, 'rb') { |io| io.read } ]
			end
			return 404, {"content-type" => "text/plain"}, ["file not found!"]
		end

		#get /favicon.ico
		if segments[0].start_with?("favicon") && method == "GET"
			return 307, {"Location" => "/static/icons/computer.png", "content-type" => "image/png"}, [""]
		end

		#get /req/./host.host.com/path/path/index.html?kek=lel
		if segments[0] == 'req' && method == 'GET'
			segments = segments[1..-1]

			if segments.length == 0
				return redirectToDefaultPage()
			end

			if segments[0].length == 1
				type = segments[0]
				segments = segments[1..-1]
			end

			if segments.length == 0
				return redirectToDefaultPage()
			end

			url = GopherUrl.new("gopher://#{segments.join("/")}")
			if type != nil
				url.type = type
			end

			if url.type == "1" || url.type == "7"
				headers = { "content-type" => "text/html; charset=utf-8", "X-Content-Type-Options" => "nosniff" }
				return 200, headers, GopherPageRender.new(GopherRequest.new(url))
			end

			return 200, {}, GopherRequest.new(url)
		end

		return 404, {"content-type" => "text/plain"}, ["service not found!"]
	end

	def redirectToDefaultPage()
		gurl = GopherUrl.new($config["home"]) #need to use the servers config file??
		return 307, {"Location" => Application.GetProxyPath(gurl)}, [""]
	end

	def self.GetProxyPath(gopherurl)
		"/req/#{gopherurl.type}/#{gopherurl.host_and_port}#{gopherurl.pathAndQuery}"
	end
end

class GopherPageRender < Templ
	TEMPLATENAME = "nav.rhtml"

	def initialize(req)
		@req = req
		@unprocessed = ""
	end

	def each
		yield "<!DOCTYPE html><html><head><title>#{@req.url.host_and_port}#{@req.url.pathAndQuery}</title><link rel=\"stylesheet\" href=\"/static/style.css\" /></head><body>#{Render("nav.rhtml")}<div class='gopher-page'>"
		@req.each do |chunk|
			extractLines(chunk).each do |row|
				if row.strip() == "."
					break
				end
				element = GopherElement.new(row)
				yield GopherElementRender.new(element).Render("gopherelement.rhtml")
			end
		end
		yield "</div></body></html>"
 	end

	def extractLines(chunk, last=false)
		@unprocessed += chunk
		if last
			return [@unprocessed]
		end

		res = []
		while i = @unprocessed.index("\r\n")
			row = @unprocessed[0..i-1]
			@unprocessed = @unprocessed[i+2..-1]
			res.append(row)
		end

		return res
	end

	def url_segments
		segments = [@req.url.host_and_port] + @req.url.segments
		
		urls = []
		gurl = GopherUrl.new("gopher://#{segments[0]}")

		puts gurl.path

		urls.append Application.GetProxyPath(gurl)
		segments[1..-1].each do |seg, index|
			gurl.segments.append(seg)
			urls.append Application.GetProxyPath(gurl)
		end
		
		return segments, urls
	end

	def url_query
		@req.url.query
	end

	def full_proxy_url_without_query
		Application.GetProxyPath(GopherUrl.new(@req.url.without_query))
	end

	def one_up
		Application.GetProxyPath(GopherUrl.new(@req.url.one_up))
	end
end

class GopherRequest
	def url
		@url
	end

	def initialize(url)
		@url = url
		@buffersize = $config["buffersize"].to_i
		if @buffersize == nil || @buffersize < 1
			@buffersize = 255
		end
	end

	def each
		puts "TCPCALL: #{@url.to_s}"
		s = TCPSocket.new @url.host, @url.port || 70
		s.write "#{@url.pathAndQuery}\r\n"
		loop do
			chunk = s.read(@buffersize)
			if chunk == nil
				break
			end
			puts chunk
			yield chunk
		end
		s.close
	end
end

class GopherUrl
  	attr_writer :type
	attr_writer :query

	def initialize(url)
		#url = CGI::unescape(url)
		@scheme, url = url.split("://")
		@segments = url.split("/").select{|e| e.strip() != ""}

		@type = "."
		if @segments.last.include? "?"
			@query = @segments.last.split("?", 2)[1]
			@segments[-1] = @segments.last[0..-@query.length-2]
			@query = CGI::unescape(@query)

			if @type == "." || @type == nil
				@type = "1"
			end
		end

		@host, @port = @segments.first.split(":",2)
		@host = @host.strip()

		@segments = @segments[1..-1]

		if @segments.last
			if scheme == "gopher"
				if path && @segments.length != 0
					if @segments[0].length == 1
						@type = @segments[0]
						@segments = @segments[1..-1]
					end
				else
					@type = "1"
				end
			end
		else
			@type = "1"
		end
	end

	def type
		@type
	end

	def path(upto = -1)
		@segments.length > 0 ? "/#{@segments[0..upto].join("/")}" : ""
	end

	def pathAndQuery
		path + (@query && @query != "" ? "?#{@query}" : "")
	end

	def host
		@host
	end

	def port
		@port
	end

	def host_and_port
		host + (port ? ":#{port}" : "")
	end

	def scheme
		@scheme
	end

	def query
		@query
	end

	def segments
		@segments
	end

	def to_s(embedtype = false)
		if embedtype
			"#{scheme}://#{host_and_port}/#{type}#{pathAndQuery}"
		else
			"#{scheme}://#{host_and_port}#{pathAndQuery}"
		end
	end

	def without_query()
		"#{scheme}://#{host_and_port}/#{type}#{path}"
	end

	def one_up()
		"#{scheme}://#{host_and_port}/#{type}#{path(-2)}"
	end
end

class GopherElement
	def initialize(row)
		cols = row.split("\t")

		@type = cols[0][0]
		cols[0] = cols[0][1..-1]

		@text = cols[0]
		@path = cols[1]

		if @path == nil
			@path = ""
		end
			
		@path = @path.strip()

		if @path.start_with?("URL:") || @path.start_with?("URI:")
			@url = @path[4..-1]
			@type = "u"
		else
			@path = @path.split("/").select {|s| s.strip() != ""}.join("/")
		end

		@host = cols[2]
		@port = cols[3].to_i
	end

	def type
		@type
	end

	def text
		@text
	end

	def path
		@path
	end

	def host
		@host
	end

	def port
		@port
	end

	def url
		@url
	end

	def get_binding
		binding
	end
end

class GopherElementRender < Templ
	TEMPLATENAME = "gopherelement.rhtml"

	def initialize(element)
		@element = element
	end

	def full_proxy_url_without_query
		url = "gopher://#{@element.host}:#{@element.port}/#{@element.type}/#{@element.path}"
		gurl = GopherUrl.new(url)
		gurl.query = nil
		Application.GetProxyPath(gurl)
	end

	def full_proxy_url
		url = "gopher://#{@element.host}:#{@element.port}/#{@element.type}/#{@element.path}"
		gurl = GopherUrl.new(url)
		Application.GetProxyPath(gurl)
	end
end