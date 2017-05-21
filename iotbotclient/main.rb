#!/usr/bin/env ruby

require 'websocket-client-simple'

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

ws = nil

connect = lambda do
	logger = Logger.new($stdout)

	logger.info "Connecting"
	ws = WebSocket::Client::Simple.connect('wss://linebot.cho45.stfuawsc.com/websocket', :headers => {'X-Token' => Token.read } )
	context = Context.new(ws, search_paths: [ File.expand_path("~/.iotbotclient/plugins") ], logger: logger)

	ws.on :open do
		logger.info "Connected"
	end

	ws.on :message do |msg|
		next unless msg.type == :text
		event = JSON.parse(msg.data)
		p event
		logger.debug event

		if event["id"].nil?
			if event["error"]
				logger.error event["error"]
				next
			end

			case event["result"]["type"]
			when "webhook"
				data = event["result"]["data"]
				logger.debug "Handle event"

				context.handle_event(data)
			end
		end
	end

	ws.on :error do |error|
		logger.error error
		sleep 1
		connect.()
	end

	ws.on :close do |code|
		logger.info "Disconnected with status code: #{code}"
		sleep 1
		connect.()
	end

	nil
end

connect.()

loop do
	ws.send("0", type: :ping) if ws
	sleep 1
end
