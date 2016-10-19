#!/usr/bin/env ruby


require 'websocket-eventmachine-client'

require 'pathname'
require 'json'


load(Pathname(__FILE__).parent + "config.rb")
p CONFIG

EM.run do
	trap("TERM") { stop }
	trap("INT")  { stop }


	def connect
		ws = WebSocket::EventMachine::Client.connect(:uri => 'wss://cho45.stfuawsc.com/bot/websocket', :headers => {'WS-KEY' => CONFIG[:WS_KEY]} )

		ws.onopen do
			puts "Connected"
		end

		ws.onmessage do |msg, type|
			p [msg, type]
			return unless type == :text
			data = JSON.parse(msg)
			p data
			case data['type']
			when 'message'
				message = data['message']['text']
				case message
				when 'ステータス'
					ws.send JSON.generate({ type: 'reply_message', replyToken: data['replyToken'], message: {
						type: 'text',
						text: 'クライントサービス稼動中'
					} })
				when /(.+)って(?:喋って|しゃべって|いって|言って)/
					msg = Regexp.last_match[1]
					Thread.start do
						p system('jsay.sh', msg)
					end
					ws.send JSON.generate({ type: 'reply_message', replyToken: data['replyToken'], message: {
						type: 'text',
						text: '音声を生成中です。少し時間がかかります'
					} })
				end
			else
			end
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
