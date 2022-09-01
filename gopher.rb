# gopher.rb
require 'socket'
require 'cgi'

class GopherUrl
	attr_writer :type
	attr_writer :query

	def initialize(url)
		# url = CGI::unescape(url)

		begin
			@scheme, url = url.split("://")
		rescue
			@scheme = "gopher"
		end
		@segments = url.split("/").select{|e| e.strip() != ""}

		@type = "."
		if @segments.last.include? "?"
			@query = @segments.last.split("?", 2)[1]
			@segments[-1] = @segments.last[0..-@query.length-2]
			@query = CGI::unescape(@query)

			puts @query

			if @type == "." || @type == nil
				@type = "1"
			end
		end

		# maybe clean up all segments with strip?

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
			puts "no type!"
			@type = "1"
			puts @type
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

class GopherRequest
	def url
		@url
	end

	def initialize(url, buffersize)
		@buffersize = buffersize
		@url = url
		if @buffersize == nil || @buffersize < 1
			@buffersize = 255
		end
	end

	def each
		# puts "TCPCALL: #{@url.to_s}"
		s = TCPSocket.new @url.host, @url.port || 70
		s.write "#{@url.pathAndQuery}\r\n"
		loop do
			begin 
				chunk = s.read(@buffersize)
			rescue
				puts "GOPHER REQUEST TCP CONN LOST"
				break
			end
			if chunk == nil
				break
			end
			# puts chunk
			yield chunk
		end
		s.close
	end
end