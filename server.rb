# server.rb
require 'socket'
require 'timeout'
require 'yaml'
require './app.rb'

$config = YAML.load_file('config.yml')

PORT = $config["port"].to_i
HOME = $config["home"]
LOGG = $config["logging"].to_i

puts " __ _ ___ _ __| |_  _ _ _____ ___  _ "
puts "/ _` / _ \\ '_ \\ ' \\| '_/ _ \\ \\ / || |"
puts "\\__, \\___/ .__/_||_|_| \\___/_\\_\\\\_, |"
puts "|___/    |_|                    |__/ "
puts

server = TCPServer.new PORT

puts "proxy running at port #{PORT}!"
puts
puts "home:"
puts "http://localhost:#{PORT}"
puts 

def log(message, lvl=1)
	if lvl >= LOGG
		puts "~ #{Thread.current.object_id}: #{message}" 
	end
end

loop do
	Thread.new(server.accept) { |session|
		tid = Thread.current.object_id

		# extract http request data
		req_headers = []
		loop do
			row = session.gets.strip

			if row == "" #empty row => done with headers, only content from here
				break
			end

			req_headers.append(row)
		end

		log("Headers:\n #{req_headers.join("\n")}")

		# read the content, not needet for now (might not work at all, not tested)
		#contentLength = req_headers.detect {|s| s.start_with "Content-Length"}.split(" ")[1].to_i
		#if contentLength != 0
		#	content = session.read(contentLength)
		#end

		begin
			method, full_path = req_headers[0].split(' ')
		rescue
			log("ERR: INVALID REQ-HEADER", 3)
			session.close
			next
		end

		log("#{method} #{full_path}", 2)

		# compute response
		app = Application.new
		begin
			res_status, res_headers, res_body = app.call({
				'REQUEST_METHOD' => method,
				'PATH_INFO' => full_path,
				#'CONTENT' => content
			})
		rescue StandardError => e # currently does not catch SocketErrors??? idk y
			# error occured while computing the response

			log("RESPONSE ERROR: #{method} #{full_path}\n Class: #{e.class}. Message: #{e.message}. Backtrace:  \n #{e.backtrace.join("\n")}", 3)
			res_status, res_headers, res_body = app.ErrorMessage(500, "Internal server error! see the logs for more detail")
		end

		# send headers
		session.print "HTTP/1.1 #{res_status}\r\n"
		res_headers["transfer-encoding"] = "chunked"

		res_headers.each do |key, value|
			session.print "#{key}: #{value}\r\n"
		end
		session.print "\r\n"

		# send body data (chunked-encoding)
		res_body.each do |chunk|
			if chunk
				session.print "#{chunk.bytesize.to_s(16)}\r\n#{chunk}\r\n"
			end
		end
		session.print "0\r\n\r\n"
		session.close
	}
end