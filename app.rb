require 'socket'
require 'uri'
require 'cgi'

require_relative './mime.rb'

class Application

	def call(req)
		segments = req["PATH_INFO"].split("/").select {|e| e != ".." && e != "" }
		method = req["REQUEST_METHOD"]
		content = req["CONTENT"]
		begin 
			query = CGI::parse(req["QUERY_STRING"])
		rescue
			query = {}
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
		url = GopherUrl.new("gopher://gopher.floodgap.com")
		return 307, {"Location" => "/#{url.type}/#{url.host}/#{url.path}"}, [""]
	end
end

class GopherPageRender
	def initialize(req)
		@req = req
		@unprocessed = ""
		@typeIcons = {
			"0" => "/static/icons/textfile.png",
			"1" => "/static/icons/folder.png",
			"h" => "/static/icons/web.png",
			"I" => "/static/icons/image.png",
			"g" => "/static/icons/clip.png",
			"p" => "/static/icons/image.png",
			"u" => "/static/icons/globe.png",
			"7" => "/static/icons/gears.png"
		}
	end

	def each
		yield File.read("./static/nav.html", :encoding => 'iso-8859-1').gsub("#url#", @req.url.to_s).gsub("#urlt#", @req.url.to_s(true))
		if @req.url.type == "7"
			yield "<script src='/static/query.js'></script>\r\n"
		end
		yield "<body><div id='gopher-page'>\r\n"
		@req.each do |chunk|
			extractLines(chunk).each do |row| 
				element = GopherElement.new(row)
				puts row
				yield "<pre class='gopher-element'><img class='gopher-element-icon' src='#{@typeIcons[element.type] || "/static/icons/blank.png"}'/>#{gopherElementToHtml(element)}</pre>\r\n"
			end
		end
		yield "</div></body>"
	end

	def gopherElementToHtml(element)
		case element.type
		when "i"
			return element.text.strip == "" ? "<br/>" : element.text
		when "3"
			return "Error: #{element.text}"
		else
			return "<a href='#{element.url || getProxyUrl(element.host, element.port, element.path, element.type)}'>#{element.text}</a>"
		end
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

	def getProxyUrl(host, port, path, type)
		"/req/#{type}/#{host}:#{port}/#{path}".gsub("#","%23")
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
		s.write "#{@url.path}\r\n"
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

		@scheme = "gopher"
		@scheme = url.split("://")[0]

		url = url.split("://")[1]

		hostAndPort = url.split("/")[0]
		@port = hostAndPort.split(":")[1]
		@host = hostAndPort.split(":")[0]

		@segments = url.split("/")[1..-1].select{|e| e != ""}

		@type = "."

		if scheme == "gopher"
			if @segments.length != 0
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
		@segments.join("/")
	end

	def host
		@host
	end

	def port
		@port
	end

	def scheme
		@scheme
	end

	def query
		@query
	end

	def to_s(embedtype = false)
		portpart = port ? ":#{port}" : ""
		if embedtype
			"#{scheme}://#{host}#{portpart}/#{type}/#{path}"
		else
			"#{scheme}://#{host}#{portpart}/#{path}"
		end
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
		else
			@path = @path.strip()
		end

		if @path.start_with?("URL:")
			@url = @path[4..-1]
			@type = "u"
		else
			@path = @path.split("/").select {|s| s != ""}.join("/")
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

	def to_s
		puts "type: #{@type}"
		puts "text: #{@text}"
		puts "path: #{@path}"
		puts "host: #{@host}"
		puts "port: #{@port}"
	end
end