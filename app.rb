require 'socket'
require_relative './mime.rb'
require 'uri'

class Application
	def call(req)
		segments = req["PATH_INFO"].split("/")
		segments = segments.select {|e| e != ".." && e != "." && e != "" }

		if segments[0] == 'static'
			headers = {
				"content-type" => MIME_EXT[File.extname(segments[-1])]
			}

			fileName = "./#{segments.join("/")}"
			if File.file?(fileName)
				return 200, headers, [File.read(fileName)]
			end

			return 404, {"content-type" => "text/plain"}, ["file not found!"]
		end

		if segments[0] == "req"  && segments.length == 1
     		headers = {
				"content-type" => "text/html; charset=utf-8",
				"X-Content-Type-Options" => "nosniff"
			}
			return 200, headers, GopherRequestRender.new(GopherRequest.new(URI("gopher://gopher.floodgap.com")))
		end

		return 404, {"content-type" => "text/plain"}, ["service not found!"]
	end
end

class GopherRequestRender
	def initialize(req)
		@req = req
	end

	def each
		yield File.read("./static/index.html", :encoding => 'iso-8859-1').sub("#url", @req.url.to_s) # "<p>HEADER</p>"
		@req.request do |row|
			element = GopherElement.new(row)
			yield gopherElementToHtml(element)
		end
	end

	def gopherElementToHtml(element)
		case element.type
		when "i"
			return  element.text.strip != "" ? "<p>#{element.text}</p>" : "<br/>"
		when "1"
			return "<p><a href='/req?url=#{element.host}&type=#{element.type}'>#{element.text}</a></p>"
		end
		return "<p>#{element.text}</p>"
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

	def to_s
		puts "type: #{@type}"
		puts "text: #{@text}"
		puts "path: #{@path}"
		puts "host: #{@host}"
		puts "port: #{@port}"
	end
end