require 'socket'
require 'uri'
require 'cgi'

require_relative './mime.rb'

class Application

	def call(req)
		segments = req["PATH_INFO"].split("/").select {|e| e != ".." && e != "." && e != "" }
		method = req["REQUEST_METHOD"]
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

		#get /req?url=ESCAPED_URL
		if segments[0] == "req" && segments.length == 1 && method == 'GET'

			if query["url"].nil? || query["url"][0].nil?
				url = GopherUrl.new("gopher://gopher.floodgap.com") 
			else
				url = GopherUrl.new(CGI::unescape(query["url"][0]))
			end
			
			if url.scheme != "gopher"
				return 500, {"content-type" => "text/plain"}, ["scheme not supported!"]
			end

			headers = { "content-type" => "text/html; charset=utf-8", "X-Content-Type-Options" => "nosniff" }
			return 200, headers, GopherPageRender.new(GopherRequest.new(url))
		end

		return 404, {"content-type" => "text/plain"}, ["service not found!"]
	end
end

class GopherPageRender
	def initialize(req)
		@req = req
		@unprocessed = ""
	end

	def each
		yield File.read("./static/nav.html", :encoding => 'iso-8859-1').gsub("#url#", @req.url.to_s).gsub("#urlt#", @req.url.to_s(true)) + "\r\n\r\n"
		@req.request do |chunk|
			extractLines(chunk).each do |row| 
				element = GopherElement.new(row)
				puts row
				yield "<p>#{gopherElementToHtml(element)}</p>\r\n"
			end
		end
	end

	def gopherElementToHtml(element)
		case element.type
		when "i"
			return  element.text.strip == "" ? "<br/>" : "<pre>#{element.text}</pre>"
		when "0"
			return "<pre><a href='#{element.url || getProxyUrl(element.host, element.port, element.path, "0")}' target='_blank'>#{element.text}</a></pre>"
		when "1"
			return "<pre><a href='#{getProxyUrl(element.host, element.port, element.path, "1")}'>#{element.text}</a></pre>"
		when "h"
			return "<pre><a href='#{element.url || getProxyUrl(element.host, element.port, element.path, "h")}' target='_blank'>#{element.text}</a></pre>"
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

	def request
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
		@uri = URI(url)
		@segments = @uri.path.split("/").select{|e| e != ""}

		@type = "."

		if scheme == "gopher"
			if @segments.length != 0
				if @segments[0].length == 1
					@type = @segments[0]
					@segments = @segments[1..-1]
				end
			end

			if port == nil
				@port = 70
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
		@uri.port || @port
	end

	def query
		@uri.query
	end

	def scheme
		@uri.scheme
	end

	def to_s(embedtype = false)
		if embedtype
			"#{scheme}://#{host}:#{port}/#{type}/#{pathAndQuery}"
		else
			"#{scheme}://#{host}:#{port}/#{pathAndQuery}"
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