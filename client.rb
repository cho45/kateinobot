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

class Token
	TOKEN_PATH = "#{ENV["HOME"]}/.iotgwconnecttoken"

	def self.read
		File.read(TOKEN_PATH).chomp rescue nil
	end
end

while Token.read.nil?
	puts "token is empty"
	sleep 10
end

EM.run do
	trap("TERM") { stop }
	trap("INT")  { stop }

	def request(ws, method, params)
		json = JSON.generate({
			id: @id,
			method: method,
			params: params,
		})
		p json
		ws.send json
	end

	def process_data(ws, data)
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
					request(ws, 'replyMessage', { replyToken: data['replyToken'], messages: [ {
						type: 'text',
						text: 'サービス稼働中 (uptime: %s / CPU %s)' % [uptime, cputemp]
					} ] })
				# when /^(.+)って(?:喋って|しゃべって|いって|言って)$/
				when /^\(mouth\)(.+)$/
					msg = Regexp.last_match[1]
					Thread.start do
						p system('jsay.sh', msg)
					end
					request(ws, 'replyMessage', { replyToken: data['replyToken'], messages: [ {
						type: 'text',
						text: '音声を生成中です。少し時間がかかります'
					} ] })
				when 'エアコン'
					request(ws, 'replyMessage', { replyToken: data['replyToken'], messages: [ {
						type: 'template',
						altText: "エアコンをオンにするには「暖房つけて」「冷房つけて」\nオフにするには「エアコンけして」と発言します",
						template: {
							type: 'buttons',
							thumbnailImageUrl: nil,
							title: 'エアコン',
							text: '選択するとエアコンを操作できます',
							actions: [
								{
									type: 'message',
									label: '暖房',
									text: '暖房つけて',
								},
								{
									type: 'message',
									label: '冷房',
									text: '冷房つけて',
								},
								{
									type: 'message',
									label: 'オフ',
									text: 'エアコンけして',
								}
							]
						}
					} ] })
				when '暖房つけて'
					request(ws, 'replyMessage', { replyToken: data['replyToken'], messages: [ {
						type: 'text',
						text: '暖房にします'
					} ] })
					Thread.start do
						p system('ir.rb', 'aircon_warm_on')
					end
				when '冷房つけて'
					request(ws, 'replyMessage', { replyToken: data['replyToken'], messages: [ {
						type: 'text',
						text: '冷房にします'
					} ] })
					Thread.start do
						p system('ir.rb', 'aircon_cool_on')
					end
				when 'エアコンけして'
					request(ws, 'replyMessage', { replyToken: data['replyToken'], messages: [ {
						type: 'text',
						text: 'エアコンをオフにします'
					} ] })
					Thread.start do
						p system('ir.rb', 'aircon_off')
					end
				when '室温'
					temp = @adt7410.calculate_temperature
					request(ws, 'replyMessage', { replyToken: data['replyToken'], messages: [ {
						type: 'text',
						text: '現在の室温は%.1f℃' % [temp]
					} ] })
				end
			when 'sticker'
				case [data['message']['packageId'], data['message']['stickerId']]
				when ['4', '284'] # うんこ
					request(ws, 'replyMessage', { replyToken: data['replyToken'], messages: [ {
						type: 'text',
						text: 'うんちはトイレでしてね'
					} ] })
				end
			end
		else
		end
	end


	def connect
		@id = 0
		ws = WebSocket::EventMachine::Client.connect(:uri => 'wss://linebot.cho45.stfuawsc.com/websocket', :headers => {'X-Token' => Token.read } )

		ws.onopen do
			puts "Connected"
		end

		ws.onmessage do |msg, type|
			begin
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
						process_data(ws, data)
					end
				end

			rescue Exception => e
				p e
				request(ws, 'replyMessage', { replyToken: data['replyToken'], messages: [ {
					type: 'text',
					text: e.inspect
				} ] })
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
