require 'socket'
require 'uri'
require 'cgi'

require_relative './mime.rb'

class Application

	def call(req)
		segments = req["PATH_INFO"].split("/")
		segments = segments.select {|e| e != ".." && e != "." && e != "" }
		begin 
			query = CGI::parse(req["QUERY_STRING"])
		rescue
			query = {}
		end

		#get /static/*
		if segments[0] == 'static' && req["REQUEST_METHOD"] == 'GET'
			headers = {
				"content-type" => MIME_EXT[File.extname(segments[-1])]
			}

			fileName = "./#{segments.join("/")}"
			if File.file?(fileName)
				return 200, headers, [File.read(fileName)]
			end

			return 404, {"content-type" => "text/plain"}, ["file not found!"]
		end

		#get /req?url=URLtype=TYPE
		if segments[0] == "req" && segments.length == 1 && req["REQUEST_METHOD"] == 'GET'

			if query["url"].nil? || query["url"][0].nil?
				url = URI("gopher://gopher.floodgap.com") 
			else
				url = URI(CGI::unescape(query["url"][0]))
			end
			
			if url.scheme != "gopher"
				return 500, {"content-type" => "text/plain"}, ["scheme not supported!"]
			end

			headers = { "content-type" => "text/html; charset=utf-8", "X-Content-Type-Options" => "nosniff" }
			return 200, headers, GopherRequestRender.new(GopherRequest.new(url))
		end

		return 404, {"content-type" => "text/plain"}, ["service not found!"]
	end
end

class GopherRequestRender
	def initialize(req)
		@req = req
	end

	def each
		yield File.read("./static/nav.html", :encoding => 'iso-8859-1').gsub("#url", @req.url.to_s)
		@req.request do |row|
			element = GopherElement.new(row)
			puts row
			yield gopherElementToHtml(element) + "\r\n"
		end
	end

	def gopherElementToHtml(element)
		case element.type
		when "i"
			return  element.text.strip == "" ? "<br/>" : "<p>#{element.text}</p>"
		when "1"
			return "<p><a href='#{getProxyUrl(element.host, element.port, element.path, "1")}'>#{element.text}</a></p>"
		when "h"
			return "<p><a href='#{element.url || getProxyUrl(element.host, element.port, element.path, "h")}'>#{element.text}</a></p>"
		end

		return "<p>#{element.text}</p>"
	end

	def getProxyUrl(host, port, path, type)
		port = port || 70
		"/req?url=#{getGopherUrl(host, port, path)}&type=#{type}"
	end

	def getGopherUrl(host, port, path)
		"gopher://#{host}:#{port}/#{path}"
	end
end

class GopherRequest
	def url
		@url
	end

	def initialize(url)
		@url = url
	end

	def request
		s = TCPSocket.new @url.host, @url.port || 70
		s.write "#{@url.path}\r\n"
		loop do
			line = s.gets
			if line == nil
				break
			end
			yield line
		end
		s.close
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