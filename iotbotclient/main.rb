#!/usr/bin/env ruby

require 'websocket-eventmachine-client'

require 'pathname'
require 'json'

require "#{File.absolute_path(File.dirname(__FILE__))}/lib/context.rb"

class Token
	TOKEN_PATH = "#{ENV["HOME"]}/.iotgwconnecttoken"

	def self.read
		File.read(TOKEN_PATH).chomp
	end
end

while Token.read.nil?
	puts "token is empty"
	sleep 10
end

EM.run do
	trap("TERM") { stop }
	trap("INT")  { stop }

	def connect
		puts "Connecting"
		ws = WebSocket::EventMachine::Client.connect(:uri => 'wss://linebot.cho45.stfuawsc.com/websocket', :headers => {'X-Token' => Token.read } )
		@context = Context.new(ws)
		@id = 0

		ws.onopen do
			puts "Connected"
		end

		ws.onmessage do |msg, type|
			return unless type == :text
			event = JSON.parse(msg)
			p event

			if event["id"].nil?
				if event["error"]
					p event["error"]
					next
				end

				case event["result"]["type"]
				when "webhook"
					data = event["result"]["data"]
					@context.handle_event(data)
				end
			end
		end

		ws.onerror do |error|
			p error
			sleep 1
			EM.next_tick {
				connect
			}
		end

		ws.onclose do |code, reason|
			puts "Disconnected with status code: #{code}"
			sleep 1
			EM.next_tick {
				connect
			}
		end
	end

	connect
end

