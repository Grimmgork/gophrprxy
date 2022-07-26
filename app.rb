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

		#get /static/*
		if segments[0] == 'static' && method == 'GET'
			headers = {"content-type" => MIME_EXT[File.extname(segments[-1])]}
			fileName = "./#{segments.join("/")}"
			if File.file?(fileName)
				return 200, headers, [ File.open(fileName, 'rb') { |io| io.read } ]
			end
			return 404, {"content-type" => "text/plain"}, ["file not found!"]
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
		gurl = GopherUrl.new("gopher://gopher.floodgap.com")
		return 307, {"Location" => GetProxyPath(gurl)}, [""]
	end

	def self.GetProxyPath(gopherurl)
		"/req/#{gopherurl.type}/#{gopherurl.host}#{gopherurl.path}"
	end
end

class GopherPageRender
	include Templ

	def initialize(req)
		@req = req
		@unprocessed = ""
	end

	def getIconForType(type)
		typeIcons = {
			"i" => "blank.png",
			"0" => "textfile.png",
			"1" => "folder.png",
			"h" => "web.png",
			"I" => "image.png",
			"g" => "clip.png",
			"p" => "image.png",
			"u" => "globe.png",
			"7" => "gears.png",
			"9" => "binary.png",
			"3" => "error.png",
			"d" => "document.png"
		}

		res = typeIcons[type]
		if res == nil
			return  "questionmark.png"
		end
		return res
	end

	def each
		yield "<!DOCTYPE html><html><head><link rel=\"stylesheet\" href=\"/static/style.css\" /></head><body>#{Render("nav.rhtml")}<div class='gopher-page'>"
		@req.each do |chunk|
			extractLines(chunk).each do |row|
				if row == "."
					break
				end
				element = GopherElement.new(row)
				yield element.Render("gopherelement.rhtml")
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
end

class GopherRequest
	def url
		@url
	end

	def initialize(url)
		@url = url
	end

	def each
		puts "TCPCALL: #{@url.to_s}"
		s = TCPSocket.new @url.host, @url.port || 70
		s.write "#{@url.pathAndQuery}\r\n"
		loop do
			chunk = s.read(255)
			if chunk == nil
				break
			end
			yield chunk
		end
		s.close
	end
end

class GopherUrl 
  	attr_writer :type

	def initialize(url)
		url = CGI::unescape(url)

		@scheme, url = url.split("://")

		hostAndPort = url.split("/",2)[0]
		@host, @port = hostAndPort.split(":",2)
		@host = @host.strip()

		@segments = []

		path = url.split("/",2)[1]
		if path 
			@segments = path.split("/").select{|e| e.strip() != ""}
			@query = @segments[-1].split("?")[1]
		end

		@type = "."
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
	end

	def type
		@type
	end

	def path
		"/#{@segments.join("/")}"
	end

	def pathAndQuery
		path + (query ? "?#{query}" : "")
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
end

class GopherElement
	include Templ

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

		if @path.start_with?("URL:")
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