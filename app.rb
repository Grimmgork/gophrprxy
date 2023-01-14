# app.rb
require 'cgi'
require 'erb'
require 'pathname'

require './templ.rb'
require './mime.rb'
require './gopher.rb'


class Application

	def initialize(home, buffersize)
		@home = home
		@buffersize = buffersize
	end

	def call(req)
		req_path = req["PATH_INFO"] || ""
		req_segments = req_path.split("/").select {|e| e != ".." && e.strip != "" }
		req_method = req["REQUEST_METHOD"]
		#req_content = req["CONTENT"]

		if req_segments.length == 0
			return res_redirect_default_page()
		end

		#get /url?url=[encodedurl]&mod=[encodedpath]
		if req_segments[0].split("?")[0] == 'url'
			begin
				params = CGI.parse(req_segments[0].split("?")[1].strip);
			rescue
				return res_error_message(400, "Bad request!")
			end

			url = params["url"][0]
			mod = params["mod"][0]

			if not url
				return res_error_message(400, "Bad request!")
			end

			gurl = GopherUrl.new(url)
			if gurl.scheme == "gopher"
				return 307, {"Location" => Application.get_proxy_path(gurl)}, [""]
			end
			return res_error_message(400, "Invalid url!")
		end

		#get /static/*
		if req_segments[0] == 'static' && req_method == 'GET'
			headers = {"content-type" => MIME_EXT[File.extname(req_segments[-1])], "X-Content-Type-Options" => "nosniff"}
			fileName = "./#{req_segments.join("/")}"
			if File.file?(fileName)
				return 200, headers, [ File.open(fileName, 'rb') { |io| io.read } ]
			end
			return res_error_message(404, "file not found!")
		end

		#get /favicon.ico
		if req_segments[0].start_with?("favicon") && req_method == "GET"
			return 307, {"Location" => "/static/icons/computer.png", "content-type" => "image/png"}, [""]
		end

		#get /req/./host.host.com/path/path/index.html?kek=lel
		if req_segments[0] == 'req' && req_method == 'GET'
			req_segments = req_segments[1..-1]

			if req_segments.length == 0
				return res_error_message(400, "bad request!")
			end

			type_parameter = nil
			# extract type from path
			if req_segments[0].length == 1
				type_parameter = req_segments[0]
				req_segments = req_segments[1..-1]
			end

			# if a host is provided, there must be at least one segment left.
			# else the request is invalid and we redirect to home
			if req_segments.length == 0
				return res_error_message(413, "bad request!")
			end

			url = GopherUrl.new("gopher://#{req_segments.join("/")}")
			url.imply_empty_defaults()
			
			# if a type was providet in the url, we force it
			if type_parameter != nil
				url.type = type_parameter
			end

			if url.type == "." #sniff if the resource is a gopher page
				# start request
				# get first chunk
				# inspect for gopher like syntax (5 tabs and a newline?)
			end

			greq = GopherRequest.new(url, @buffersize)

			if url.type == "1" || url.type == "7"
				headers = { "content-type" => "text/html; charset=utf-8", "X-Content-Type-Options" => "nosniff" }
				return 200, headers, GopherPageRender.new(greq, @home)
			end

			return 200, {}, greq
		end

		return res_error_message(404, "not found!")
	end

	def res_redirect_default_page()
		gurl = GopherUrl.new(@home)
		return 307, {"Location" => Application.get_proxy_path(gurl)}, [""]
	end

	def res_error_message(status, message)
		return status, {"content-type" => "text/plain"}, ["ERROR: #{status} #{message}"]
	end

	def modify_url(url, mod)
		path, query = mod.match /(?:\.\/)?([^?]*)(\?.*$)?/
		if not path.start_with?("/")
			# relative
			path = url.segments.join("/") + path
		end
		path = Pathname.new(path).cleanpath
		url.segments = path.split("/")
		url.query = query
	end

	def self.get_proxy_path(gopherurl)
		"/req/#{gopherurl.type || "."}/#{gopherurl.host_and_port}#{gopherurl.path_and_query.gsub("#", "%23")}"
	end
end

class GopherPageRender < Templ

	TEMPLATENAME = "navbar.rhtml"

	def initialize(req, home)
		@home = home
		@req = req
		@unprocessed = ""
	end

	def each
		yield <<~EOS 
		<!DOCTYPE html>
		<html>
		<head>
		<title>#{h(@req.url.host_and_port)}#{h(@req.url.path_and_query)}</title>
		<link rel=\"stylesheet\" href=\"/static/style.css\" />
		</head>
		<body>
		#{render()}
		<pre class='gopher-page'>
		EOS
		@req.each do |chunk|
			extractLines(chunk).each do |row|
				if row.strip() == "."
					break
				end
				element = GopherElement.new(row)
				yield GopherElementRender.new(element, @req.url.host).render()
			end
		end
		yield <<~EOS
		</pre>
		</body>
		</html>
		EOS
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
		gurl.type = "1"
		urls.append Application.get_proxy_path(gurl)
		segments[1..-1].each do |seg, index|
			gurl.segments.append(seg)
			urls.append Application.get_proxy_path(gurl)
		end
		
		return segments, urls
	end

	def url_full
		@req.url.to_s()
	end

	def url_query
		@req.url.query
	end

	def url_without_query
		@req.url.to_s("q")
	end

	def one_up_url
		Application.get_proxy_path(GopherUrl.new(@req.url.to_s("l-2")))
	end

	def home_url
		Application.get_proxy_path(GopherUrl.new(@home))
	end
end

class GopherElementRender < Templ

	TEMPLATENAME = "gopherelement.rhtml"

	def initialize(element, page_host)
		@element = element
		@page_host = page_host
	end

	def is_foreign
		@page_host != @element.host
	end

	def full_proxy_url_without_query
		url = "gopher://#{@element.host}:#{@element.port}/#{@element.type}/#{@element.path}"
		gurl = GopherUrl.new(url)
		gurl.query = nil
		Application.get_proxy_path(gurl)
	end

	def full_proxy_url
		url = "gopher://#{@element.host}:#{@element.port}/#{@element.type}/#{@element.path}"
		gurl = GopherUrl.new(url)
		Application.get_proxy_path(gurl)
	end
end