require 'socket'
require 'uri'
require 'cgi'

require_relative './mime.rb'

class Application

	def call(req)
		segments = req["PATH_INFO"].split("/").select {|e| e != ".." && e != "." && e != "" }
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
				return 200, headers, [File.read(fileName)]
			end

			return 404, {"content-type" => "text/plain"}, ["file not found!"]
		end

		#get /hex/ content => DATATOHEX
		if segments[0] == "hex" && method == 'GET'
			if !content
				return 500, {"content-type" => "text/plain"}, ["no data to hex!"]
			end
			return 200, {}, [tohex(content)]
		end

		#get /hex/ content => DATATOUNHEX
		if segments[0] == "unhex" && method == 'GET'
			if !content
				return 500, {"content-type" => "text/plain"}, ["no data to hex!"]
			end
			return 200, {}, [fromhex(content)]
		end

		#get /req/HEX-URL
		if segments[0] == "req" && method == 'GET'
			if segments.length == 2
				url = GopherUrl.new(fromhex(segments[1]))
			else
				return 307, {"Location" => "/req/#{tohex(GopherUrl.new("gopher://gopher.floodgap.com").to_s(true))}"}, [""]
			end
			
			if url.scheme != "gopher"
				return 500, {"content-type" => "text/plain"}, ["scheme not supported!"]
			end

			if url.type == "1"
				headers = { "content-type" => "text/html; charset=utf-8", "X-Content-Type-Options" => "nosniff" }
				return 200, headers, GopherPageRender.new(GopherRequest.new(url))
			end

			return 200, {}, GopherRequest.new(url)
		end

		return 404, {"content-type" => "text/plain"}, ["service not found!"]
	end
end

def tohex(str)
	str.unpack('H*')[0]
end

def fromhex(hex)
	[hex].pack('H*')
end

class GopherPageRender
	def initialize(req)
		@req = req
		@unprocessed = ""
	end

	def each
		yield File.read("./static/nav.html", :encoding => 'iso-8859-1').gsub("#url#", @req.url.to_s).gsub("#urlt#", @req.url.to_s(true)) + "\r\n\r\n" + "<body>"
		@req.each do |chunk|
			extractLines(chunk).each do |row| 
				element = GopherElement.new(row)
				puts row
				yield "<p>#{gopherElementToHtml(element)}</p>\r\n"
			end
		end
		yield "</body>"
	end

	def gopherElementToHtml(element)
		case element.type
		when "i"
			return element.text.strip == "" ? "<br/>" : "<pre>#{element.text}</pre>"
		when "3"
			return "<pre>Error: #{element.text}</pre>"
		else
			return "<pre><a href='#{element.url || getProxyUrl(element.host, element.port, element.path, element.type)}'>#{element.text}</a></pre>"
		end
		return "<pre>#{element.text}</pre>"
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
		gurl = GopherUrl.new("gopher://#{host}:#{port}/#{path}")
		gurl.type = type
		"/req?url=#{CGI::escape(gurl.to_s(true))}"
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
		@uri = URI(url.gsub(" ", "%20").gsub(">", "%3E").gsub("<", "%3C").gsub("|","%7C"))
		@segments = CGI::unescape(@uri.path).split("/").select{|e| e != ""}

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

	def pathAndQuery
		"#{path}#{query == nil ? "" : "?#{query}"}"
	end

	def host
		@uri.host
	end

	def port
		@uri.port
	end

	def query
		@uri.query
	end

	def scheme
		@uri.scheme
	end

	def to_s(embedtype = false)
		portpart = port ? ":#{port}" : ""
		if embedtype
			"#{scheme}://#{host}#{portpart}/#{type}/#{pathAndQuery}"
		else
			"#{scheme}://#{host}#{portpart}/#{pathAndQuery}"
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
		end

		if @path.start_with?("URL:")
			@url = @path[4..-1]
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