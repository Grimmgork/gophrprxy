# server.rb
require 'socket'
require './app.rb'
 
server = TCPServer.new 5678

loop do
	Thread.new(server.accept) { |session|
		app = Application.new
		
		contentLength = 0
		rows = []
		loop do 
			row = session.gets
			if row == "\r\n"
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

		begin
			status, headers, body = app.call({
				'REQUEST_METHOD' => method,
				'PATH_INFO' => full_path,
				'CONTENT' => content
			})
			rescue
			status = 500
			headers = {"content-type" => "text/plain"}
			body = ["Internal error!"]
		end

		session.print "HTTP/1.1 #{status}\r\n"
		headers.each do |key, value|
			session.print "#{key}: #{value}\r\n"
		end
		session.print "transfer-encoding: chunked\r\n"
		session.print "\r\n"

		body.each do |chunk|
			session.print "#{chunk.length.to_s(16)}\r\n#{chunk}\r\n"
		end

		session.print "0\r\n\r\n"
		session.close
	}
end