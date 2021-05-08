#!/usr/bin/env ruby
# 
# $LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
# $LOAD_PATH.unshift(File.expand_path("../../http-protocol/lib", __dir__))

require 'async'
require 'async/http/client'
require 'async/http/endpoint'

# Console.logger.level = Logger::DEBUG

Async do |task|
	endpoint = Async::HTTP::Endpoint.parse("https://www.google.com")
	
	client = Async::HTTP::Client.new(endpoint)
	
	headers = {
		'accept' => 'text/html',
	}
	
	request = Protocol::HTTP::Request.new(client.scheme, "www.google.com", "GET", "/search?q=cats", headers)
	
	puts "Sending request..."
	response = client.call(request)
	
	puts "Reading response status=#{response.status}..."
	
	if body = response.body
		while chunk = body.read
			puts chunk.size
		end
	end
	
	response.close
	
	puts "Finish reading response."
end
