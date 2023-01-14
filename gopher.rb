# gopher.rb
require 'socket'
require 'cgi'
require 'pathname'

def find_and_remove_regex(str, regex)
	str = str.sub(regex, '')
	return str, Regexp.last_match(0)
end

class GopherUrl
	attr_accessor :query, :port, :host, :scheme, :segments
	attr_reader :type

	def initialize(url)
		url, @query = find_and_remove_regex(url, /\?.*$/)
		if @query != nil
			@query = @query[1..-1]
		end

		url, @scheme = find_and_remove_regex(url, /^.*:\/\//)

		if @scheme != nil
			@scheme = @scheme.split(":")[0]
		end

		url, @host = find_and_remove_regex(url, /^[^\/]*/)
		if @host != nil
			@host, @port = @host.split(":")
		end
		url = Pathname.new(url).cleanpath
		@segments = url.to_s.split("/").select {|s| s != ""}
		if @segments.length > 0
			if @segments[0].length == 1
				self.type=@segments[0]
				@segments = @segments[1..-1]
			end
		end
	end

	def type=(val)
		if val == "" || val == "."
			@type=nil
			return
		end
		@type = val
	end

	def path(upto = -1)
		if @segments == nil || @segments.length == 0
			return "/"
		end
		return "/#{@segments[0..upto].join("/")}"
	end

	def path_and_query
		path + (query ? "?#{query}" : "")
	end

	def host_and_port
		(host ? host : "") + (port ? ":#{port}" : "")
	end

	def segment(index)
		@segments[index]
	end

	def to_s(supress = "")
		# supress: stlq [s]heme [t]ype [l]ocation{upto} [q]uery

		if supress.match(/[^stlq\d-]/)
			throw "invalid argument see sourcecode comments for usage!"
		end

		res = host_and_port

		if not supress.match(/t/)
			# add type
			res = res + "/#{type}"
		end

		if not supress.match(/s/)
			# add sheme
			if scheme
				res = "#{scheme}://" + res
			end
		end

		location = supress.match(/l[0-9-]*/)
		if location == nil
			# path gets fully printed
			res = res + path
			if not supress.match(/q/)
				res = res + (query && query != "" ? "?#{query}" : "")
			end
		else
			# path gets partially or not at all printed
			location = location[0]
			if location.length > 1
				location = location[1..-1].to_i
				res = res + path(location)
			end
		end

		return res;
	end

	def imply_empty_defaults()
		@scheme = "gopher"
		if @port == nil
			@port = 70
		end
	
		if type == nil or type == ""
			if segments.length == 0
				self.type = "1"
			end
		end
	end
end

class GopherElement
	attr_reader :type, :text, :path, :host, :port, :url

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

	def get_binding
		binding
	end
end

class GopherRequest
	attr_reader :url

	def initialize(fullurl, buffersize)
		@buffersize = buffersize
		@url = fullurl
		if @buffersize == nil || @buffersize < 1
			@buffersize = 255
		end
	end

	def each
		# puts "TCPCALL: #{@url.to_s}"
		s = TCPSocket.new @url.host, @url.port || 70
		s.write "#{@url.path_and_query}\r\n"
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