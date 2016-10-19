#!/usr/bin/env ruby

require 'sinatra'
require 'sinatra-websocket'

require 'line/bot'
require 'pathname'
require 'pp'
require 'json'

load(Pathname(__FILE__).parent + "config.rb")
p CONFIG

set :server, 'thin'
set :port, 8876
set :sockets, []

def client
	@client ||= Line::Bot::Client.new { |config|
		config.channel_secret = CONFIG[:LINE_CHANNEL_SECRET]
		config.channel_token = CONFIG[:LINE_CHANNEL_TOKEN]
	}
end

post '/line/events' do
	body = request.body.read

	signature = request.env['HTTP_X_LINE_SIGNATURE']
	unless client.validate_signature(body, signature)
		error 400 do 'Bad Request' end
	end

	events = client.parse_events_from(body)
	events.each { |event|
		p event
		case event
		when Line::Bot::Event::Beacon
			message = {
				type: 'text',
				text: 'Beacon Detected!',
			}
			client.reply_message(event['replyToken'], message)
		when Line::Bot::Event::Message
			next unless event['source']['type'] == 'group'
			next unless CONFIG[:ALLOW_GROUPS].include?(event['source']['groupId'])

			case event.type
			when Line::Bot::Event::MessageType::Text
				text = event.message['text']

				case text
				when 'てすと'
					message = {
						type: 'text',
						text: 'BOTは稼動中です',
					}
					client.reply_message(event['replyToken'], message)
				else
					settings.sockets.each do |ws|
						warn "Delegate event to WS client: #{ws}"
						ws.send JSON.generate(event.instance_variable_get(:@src))
					end
				end
			end
		end
	}

	"OK"
end


get '/websocket' do
	# h2o は upgrade を送ってくるが、em-websocket が Upgrade しか許容してないクソ実装なので
	request.env["HTTP_CONNECTION"] = "Upgrade"
	if request.websocket? then
		request.websocket do |ws|
			ws.onopen do
				warn "New connection"
				# sinatra-websocket だと handshake が渡ってこないので env を直接見てる。クソ
				if request.env['HTTP_WS_KEY'] == CONFIG[:WS_KEY]
					warn "WS-KEY is valid"
					settings.sockets << ws
				else
					ws.close_connection
				end
			end
			ws.onmessage do |msg|
				data = JSON.parse(msg)
				p data
				case data['type']
				when 'reply_message'
					p client.reply_message(data['replyToken'], data['message'])
				else
					warn "unexpected type: #{data['type']}"
				end
			end
			ws.onclose do
				warn "Connection closed"
				settings.sockets.delete(ws)
			end
		end
	end
end
