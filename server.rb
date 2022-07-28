# server.rb
require 'socket'
require 'yaml'
require './app.rb'

config = YAML.load_file('config.yml')

PORT = config["port"].to_i
HOME = config["home"]

puts " __ _ ___ _ __| |_  _ _ _____ ___  _ "
puts "/ _` / _ \\ '_ \\ ' \\| '_/ _ \\ \\ / || |"
puts "\\__, \\___/ .__/_||_|_| \\___/_\\_\\\\_, |"
puts "|___/    |_|                    |__/ "
puts

server = TCPServer.new PORT

puts "Server started at port #{PORT}!"
puts
puts "home:"
puts "http://localhost:#{PORT}#{Application.GetProxyPath(GopherUrl.new(HOME))}"

loop do
	Thread.new(server.accept) { |session|

		# extract http request data
		contentLength = 0
		rows = []
		loop do 
			row = session.gets
			if row == "\r\n" || !row
				break
			end

			row = row[0..-3]
			if row.start_with?("Content-Length")
				contentLength = row.split(" ")[1].to_i
			end
			rows.append(row)
		end

		puts rows

		if contentLength != 0
			content = session.read(contentLength)
		end

		method, full_path = rows[0].split(' ')

		# compute respnse
		app = Application.new
		begin
			status, headers, body = app.call({
				'REQUEST_METHOD' => method,
				'PATH_INFO' => full_path,
				'CONTENT' => content
			})
			rescue => e
			# error occured while computing the response
			puts "====================="
			puts "EXCEPTION: #{e.class}. Message: #{e.message}. Backtrace:  \n #{e.backtrace.join("\n")}"
			puts "====================="
			status = 500
			headers = {"content-type" => "text/plain"}
			body = ["Internal error!"]
		end

		# send headers
		session.print "HTTP/1.1 #{status}\r\n"
		headers.each do |key, value|
			session.print "#{key}: #{value}\r\n"
		end
		session.print "transfer-encoding: chunked\r\n"
		session.print "\r\n"

		# send body data (chunked-encoding)
		body.each do |chunk|
			if chunk
				session.print "#{chunk.bytesize.to_s(16)}\r\n#{chunk}\r\n"
			end
		end
		session.print "0\r\n\r\n"
		session.close
	}
end