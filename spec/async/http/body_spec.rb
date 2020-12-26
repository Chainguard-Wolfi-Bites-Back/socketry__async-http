# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'async/http/body'

require 'async/http/server'
require 'async/http/client'
require 'async/http/endpoint'

require 'async/io/ssl_socket'

require 'async/rspec/reactor'

require 'localhost/authority'

RSpec.shared_examples Async::HTTP::Body do
	let(:client) {Async::HTTP::Client.new(client_endpoint, protocol: described_class)}
	
	it "can stream requests" do
		server = Async::HTTP::Server.for(server_endpoint, protocol: described_class) do |request|
			input = request.body
			output = Async::HTTP::Body::Writable.new
			
			Async::Task.current.async do |task|
				input.each do |chunk|
					output.write(chunk.reverse)
				end
				
				output.close
			end
			
			Protocol::HTTP::Response[200, [], output]
		end
		
		server_task = reactor.async do
			server.run
		end
		
		output = Async::HTTP::Body::Writable.new
		
		reactor.async do |task|
			output.write("Hello World!")
			output.close
		end
		
		response = client.post("/", {}, output)
		
		expect(response).to be_success
		expect(response.read).to be == "!dlroW olleH"
		
		server_task.stop
		client.close
	end
	
	it "can stream response" do
		notification = Async::Notification.new
		
		server = Async::HTTP::Server.for(server_endpoint, protocol: described_class) do |request|
			body = Async::HTTP::Body::Writable.new
			
			Async::Task.current.async do |task|
				10.times do |i|
					body.write("#{i}")
					notification.wait
				end
				
				body.close
			end
			
			Protocol::HTTP::Response[200, {}, body]
		end
		
		server_task = reactor.async do
			server.run
		end
		
		response = client.get("/")
		
		expect(response).to be_success
		
		j = 0
		# This validates interleaving
		response.body.each do |line|
			expect(line.to_i).to be == j
			j += 1
			
			notification.signal
		end
		
		server_task.stop
		client.close
	end
end

RSpec.describe Async::HTTP::Protocol::HTTP1, timeout: 2 do
	include_context Async::RSpec::Reactor
	
	let(:endpoint) {Async::HTTP::Endpoint.parse('http://127.0.0.1:9296', reuse_port: true)}
	let(:client_endpoint) {endpoint}
	let(:server_endpoint) {endpoint}
	
	it_should_behave_like Async::HTTP::Body
end

RSpec.describe Async::HTTP::Protocol::HTTPS, timeout: 2 do
	include_context Async::RSpec::Reactor
	let(:authority) {Localhost::Authority.new}
	
	let(:server_context) {authority.server_context}
	let(:client_context) {authority.client_context}
	
	# Shared port for localhost network tests.
	let(:server_endpoint) {Async::HTTP::Endpoint.parse("https://localhost:9296", ssl_context: server_context)}
	let(:client_endpoint) {Async::HTTP::Endpoint.parse("https://localhost:9296", ssl_context: client_context)}
	
	it_should_behave_like Async::HTTP::Body
end