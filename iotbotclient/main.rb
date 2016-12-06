#!/usr/bin/env ruby

require 'websocket-eventmachine-client'

require 'pathname'
require 'json'
require 'logger'

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
		@logger = Logger.new($stdout)

		@logger.info "Connecting"
		ws = WebSocket::EventMachine::Client.connect(:uri => 'wss://linebot.cho45.stfuawsc.com/websocket', :headers => {'X-Token' => Token.read } )
		@context = Context.new(ws, search_paths: [ File.expand_path("~/.iotbotclient/plugins") ], logger: @logger)
		@id = 0

		ws.onopen do
			@logger.info "Connected"
		end

		ws.onmessage do |msg, type|
			return unless type == :text
			event = JSON.parse(msg)
			@logger.debug event

			if event["id"].nil?
				if event["error"]
					@logger.error event["error"]
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
			@logger.error error
			sleep 1
			EM.next_tick {
				connect
			}
		end

		ws.onclose do |code, reason|
			@logger.info "Disconnected with status code: #{code}"
			sleep 1
			EM.next_tick {
				connect
			}
		end
	end

	connect
end

