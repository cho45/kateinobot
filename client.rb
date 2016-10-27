#!/usr/bin/env ruby


require 'websocket-eventmachine-client'

require 'pathname'
require 'json'

$LOAD_PATH << "../ruby-i2c-devices/lib"
require 'i2c'
require 'i2c/driver/i2c-dev'
require 'i2c/device/adt7410'

@driver = I2CDevice::Driver::I2CDev.new("/dev/i2c-1")
@adt7410 = I2CDevice::ADT7410.new(address: 0x48, driver: @driver)

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
			begin
				p [msg, type]
				return unless type == :text
				data = JSON.parse(msg)
				p data
				case data['type']
				when 'message'
					type = data['message']['type']
					case type
					when 'text'
						case data['message']['text']
						when 'ステータス'
							uptime = `uptime`.chomp
							cputemp = `vcgencmd measure_temp`.chomp
							ws.send JSON.generate({ type: 'reply_message', replyToken: data['replyToken'], message: {
								type: 'text',
								text: 'サービス稼働中 (uptime: %s / CPU %s)' % [uptime, cputemp]
							} })
						# when /^(.+)って(?:喋って|しゃべって|いって|言って)$/
						when /^\(mouth\)(.+)$/
							msg = Regexp.last_match[1]
							Thread.start do
								p system('jsay.sh', msg)
							end
							ws.send JSON.generate({ type: 'reply_message', replyToken: data['replyToken'], message: {
								type: 'text',
								text: '音声を生成中です。少し時間がかかります'
							} })
						when 'エアコンつけて'
							ws.send JSON.generate({ type: 'reply_message', replyToken: data['replyToken'], message: {
								type: 'text',
								text: 'エアコンをオンにします'
							} })
							Thread.start do
								p system('ir.rb', 'aircon_on')
							end
						when 'エアコンけして'
							ws.send JSON.generate({ type: 'reply_message', replyToken: data['replyToken'], message: {
								type: 'text',
								text: 'エアコンをオフにします'
							} })
							Thread.start do
								p system('ir.rb', 'aircon_off')
							end
						when '温度'
							temp = @adt7410.calculate_temperature
							ws.send JSON.generate({ type: 'reply_message', replyToken: data['replyToken'], message: {
								type: 'text',
								text: '現在の室温は%.1f℃' % [temp]
							} })
						end
					when 'sticker'
						case [data['message']['packageId'], data['message']['stickerId']]
						when ['4', '284'] # うんこ
							ws.send JSON.generate({ type: 'reply_message', replyToken: data['replyToken'], message: {
								type: 'text',
								text: 'うんちはトイレでしてね'
							} })
						end
					end
				else
				end
			rescue Exception => e
				p e
				ws.send JSON.generate({ type: 'reply_message', replyToken: data['replyToken'], message: {
					type: 'text',
					text: e.inspect
				} })
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
