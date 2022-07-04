# http_server.rb
require 'socket'
require './app.rb'
 
server = TCPServer.new 5678

loop do
	Thread.new(server.accept) { |session|
		#session = server.accept
		app = Application.new
		request = session.gets
		puts request

		method, full_path = request.split(' ')
		path, query = full_path.split('?')

		status, headers, body = app.call({
			'REQUEST_METHOD' => method,
			'PATH_INFO' => path,
			'QUERY_STRING' => query
		})

		session.print "HTTP/1.1 #{status}\r\n"
		headers.each do |key, value|
			session.print "#{key}: #{value}\r\n"
		end
		session.print "transfer-encoding: chunked\r\n"
		session.print "\r\n"

		body.each do |chunk|
			puts "#{chunk.length.to_s(16)}\r\n#{chunk}\r\n"
			session.print "#{chunk.length.to_s(16)}\r\n#{chunk}\r\n"
		end

		session.print "0\r\n\r\n"
		session.close
	}
end