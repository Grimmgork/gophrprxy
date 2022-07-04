require 'socket'
require 'uri'

class Application
	def call(req)
               statusCode = 200
               headers = {
				"content-type" => "text/html", 
				"transfer-encoding" => "chunked",
				"X-Content-Type-Options" => "nosniff"
			}
		return 200, headers, GopherRequestRender.new(GopherRequest.new(URI("gopher://gopher.floodgap.com")))
	end
end

class GopherRequestRender
	def initialize(req)
		@req = req
	end

	def getChunks
		@req.request do |chunk|
			yield chunk if block_given?
		end
	end
end

class GopherRequest
	def initialize(url)
		@url = url
		@s = TCPSocket.new 'sdf.org', 70
	end

	def request
		@s.write "/ancient-maps\r\n"
		loop do 
			line = @s.read(4096)
			if line == nil
				break
			end
			#line = @s.read     # Read lines from the socket
			#puts line
			yield line
		end
		@s.close
	end
end