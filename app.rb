require 'cgi'
require 'erb'

require './templ.rb'
require './mime.rb'
require './gopher.rb'

class Application
	def call(req)

		req_path = req["PATH_INFO"] || ""
		req_segments = req_path.split("/").select {|e| e != ".." && e.strip != "" }
		req_method = req["REQUEST_METHOD"]
		#req_content = req["CONTENT"]

		if req_segments.length == 0
			return redirectToDefaultPage()
		end

		#get /static/*
		if req_segments[0] == 'static' && req_method == 'GET'
			headers = {"content-type" => MIME_EXT[File.extname(req_segments[-1])], "X-Content-Type-Options" => "nosniff", "Cache-Control" => "max-age=120"}
			fileName = "./#{req_segments.join("/")}"
			if File.file?(fileName)
				return 200, headers, [ File.open(fileName, 'rb') { |io| io.read } ]
			end
			return ErrorMessage(404, "file not found!")
		end

		#get /favicon.ico
		if req_segments[0].start_with?("favicon") && req_method == "GET"
			return 307, {"Location" => "/static/icons/computer.png", "content-type" => "image/png"}, [""]
		end

		#get /req/./host.host.com/path/path/index.html?kek=lel
		if req_segments[0] == 'req' && req_method == 'GET'
			req_segments = req_segments[1..-1]

			if req_segments.length == 0
				return redirectToDefaultPage()
			end

			if req_segments[0].length == 1
				type = req_segments[0]
				req_segments = req_segments[1..-1]
			else
				type = "."
			end

			if req_segments.length == 0
				return redirectToDefaultPage()
			end

			url = GopherUrl.new("gopher://#{req_segments.join("/")}")
			if type != nil
				url.type = type
			end

			if url.type == "." #sniff if the resource is a gopher page
				# start request
				# get first chunk
				# inspect for gopher like syntax (5 tabs and a newline?)
			end

			if url.type == "1" || url.type == "7"
				headers = { "content-type" => "text/html; charset=utf-8", "X-Content-Type-Options" => "nosniff" }
				return 200, headers, GopherPageRender.new(GopherRequest.new(url))
			end

			return 200, {}, GopherRequest.new(url)
		end

		return ErrorMessage(404, "not found!")
	end

	def redirectToDefaultPage()
		gurl = GopherUrl.new($config["home"])
		return 307, {"Location" => Application.GetProxyPath(gurl)}, [""]
	end

	def ErrorMessage(status, message)
		return status, {"content-type" => "text/plain"}, ["ERROR: #{status} #{message}"]
	end

	def self.GetProxyPath(gopherurl)
		"/req/#{gopherurl.type}/#{gopherurl.host_and_port}#{gopherurl.pathAndQuery}"
	end
end

class GopherPageRender < Templ
	TEMPLATENAME = "nav.rhtml"

	def initialize(req)
		@req = req
		@unprocessed = ""
	end

	def each
		yield "<!DOCTYPE html><html><head><title>#{@req.url.host_and_port}#{@req.url.pathAndQuery}</title><link rel=\"stylesheet\" href=\"/static/style.css\" /></head><body>#{Render("nav.rhtml")}<div class='gopher-page'>"
		@req.each do |chunk|
			extractLines(chunk).each do |row|
				if row.strip() == "."
					break
				end
				element = GopherElement.new(row)
				yield GopherElementRender.new(element).Render("gopherelement.rhtml")
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

		# puts gurl.path

		urls.append Application.GetProxyPath(gurl)
		segments[1..-1].each do |seg, index|
			gurl.segments.append(seg)
			urls.append Application.GetProxyPath(gurl)
		end
		
		return segments, urls
	end

	def url_query
		@req.url.query
	end

	def full_proxy_url_without_query
		Application.GetProxyPath(GopherUrl.new(@req.url.without_query))
	end

	def one_up
		Application.GetProxyPath(GopherUrl.new(@req.url.one_up))
	end

	def home_url
		begin 
			Application.GetProxyPath(GopherUrl.new($config["home"]))
		rescue
			nil
		end
	end
end

class GopherElementRender < Templ
	TEMPLATENAME = "gopherelement.rhtml"

	def initialize(element)
		@element = element
	end

	def full_proxy_url_without_query
		url = "gopher://#{@element.host}:#{@element.port}/#{@element.type}/#{@element.path}"
		gurl = GopherUrl.new(url)
		gurl.query = nil
		Application.GetProxyPath(gurl)
	end

	def full_proxy_url
		url = "gopher://#{@element.host}:#{@element.port}/#{@element.type}/#{@element.path}"
		gurl = GopherUrl.new(url)
		Application.GetProxyPath(gurl)
	end
end