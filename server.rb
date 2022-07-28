# server.rb
require 'socket'
require './app.rb'
 
PORT = 5678
HOST = "trinitron"


puts " __ _ ___ _ __| |_  _ _ _____ ___  _ "
puts "/ _` / _ \\ '_ \\ ' \\| '_/ _ \\ \\ / || |"
puts "\\__, \\___/ .__/_||_|_| \\___/_\\_\\\\_, |"
puts "|___/    |_|                    |__/ "
puts

server = TCPServer.new PORT

puts "Server started at port #{PORT}!"
puts
puts "navigate:"
puts "http://#{HOST}:#{PORT}#{Application.GetProxyPath(GopherUrl.new("gopher://gopher.floodgap.com"))}"

loop do
	Thread.new(server.accept) { |session|
		app = Application.new
		
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

		#begin
			status, headers, body = app.call({
				'REQUEST_METHOD' => method,
				'PATH_INFO' => full_path,
				'CONTENT' => content
			})
			#rescue
			#status = 500
			#headers = {"content-type" => "text/plain"}
			#body = ["Internal error!"]
		#end

		session.print "HTTP/1.1 #{status}\r\n"
		headers.each do |key, value|
			session.print "#{key}: #{value}\r\n"
		end
		session.print "transfer-encoding: chunked\r\n"
		session.print "\r\n"

		body.each do |chunk|
			#puts chunk.class
			if chunk
				session.print "#{chunk.bytesize.to_s(16)}\r\n#{chunk}\r\n"
			else
				puts "\r\nattempted to send NIL???\r\n"
			end
		end

		session.print "0\r\n\r\n"
		session.close
	}
end