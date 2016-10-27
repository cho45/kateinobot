#!/usr/bin/env ruby -v

require 'stringio'

module ECHONET_Lite
	EHD1 = 0b00010000
	EHD2_DEFINED = 0x81
	EHD2_ANY = 0x82

	class ParseError < Exception
	end

	def self.parse_frame(frame)
		ret = Frame.parse(frame)
		unless ret.valid?
			raise ParseError.new("not an ECHONET Lite frame")
		end
		ret
	end

	Frame = Struct.new(:ehd1, :ehd2, :tid, :edata) do
		def self.parse(frame)
			ret = self.new(*frame.unpack("CCna*"))
			if ret.valid? && ret.format_defined?
				ret.edata = EDATA.parse(ret.edata)
			end
			ret
		end

		def valid?
			ehd1 == EHD1
		end

		def format_defined?
			ehd2 == EHD2_DEFINED
		end

		def format_any?
			ehd2 == EHD2_ANY
		end

		def pack
			[ehd1, ehd2, tid].pack("CCn") + edata.pack
		end
	end

	EDATA = Struct.new(:seoj, :deoj, :esv, :opc, :properties) do
		def self.parse(edata)
			ret = self.new(*edata.unpack("a3a3CCa*"))
			ret.seoj = EOJ.parse(ret.seoj)
			ret.deoj = EOJ.parse(ret.deoj)

			props = []
			StringIO.open(ret.properties) do |io|
				ret.opc.times do
					epc, pdc = *io.read(2).unpack("CC")
					edt = io.read(pdc)
					props << Property.new(epc, pdc, edt)
				end
			end
			ret.properties = props

			ret
		end

		def pack
			seoj.pack + deoj.pack + [esv, opc].pack("CC") + properties.map {|i|
				i.pack
			}.join
		end
	end

	EOJ = Struct.new(:class_group_code, :class_code, :instance_code) do
		def self.parse(eoj)
			self.new(*eoj.unpack("CCC"))
		end

		def pack
			to_a.pack("CCC")
		end
	end

	Property = Struct.new(:epc, :pdc, :edt) do
		def pack
			self.pdc = edt.length
			[epc, pdc].pack("CC") + edt
		end
	end
end

require 'thread'
class SKSTACK_IP
	EVENT_RECV_NS = 1
	EVENT_RECV_NA = 2
	EVENT_RECV_ECHO = 5
	EVENT_COMPLETED_ED_SCAN = 0x1F
	EVENT_RECV_BEACON = 0x20
	EVENT_UDP_SENT = 0x21
	EVENT_COMPLETED_ACTIVE_SCAN = 0x22

	EVENT_PANA_ERROR = 0x24
	EVENT_PANA_COMPLETED = 0x25
	EVENT_RECV_SESSION_CLOSE = 0x26
	EVENT_PANA_CLOSED = 0x27
	EVENT_PANA_TIMEOUT = 0x28
	EVENT_SESSION_EXPIRED = 0x29
	EVENT_SEND_LIMIT = 0x32
	EVENT_SEND_UNLOCK = 0x33

	def initialize(port)
		@event_callbacks = {}

		@port = port
		@port.set_encoding(Encoding::BINARY)

		@rest = nil

		@queue = Queue.new
		@read_thread = Thread.start do
			Thread.current.abort_on_exception = true
			buffer = ""
			while true
				# need to know command name preceded by whole line
				# because there is ERXUDP/ERXTCP which include length and any binary bytes.
				c = @port.getc
				if c.nil?
					raise "unexpected IO closed"
				end
				buffer << c
				case c
				when ' ', "\r"
					command = buffer.sub(/[\r ]$/, '')
					p buffer
					case command
					when "ERXUDP"
						event = {}
						event[:sender]    = @port.gets(" ").sub(/\s+$/, '')
						event[:dest]      = @port.gets(" ").sub(/\s+$/, '')
						event[:rport]     = @port.gets(" ").sub(/\s+$/, '').unpack("n")[0]
						event[:lport]     = @port.gets(" ").sub(/\s+$/, '').unpack("n")[0]
						event[:senderlla] = @port.gets(" ").sub(/\s+$/, '')
						event[:secured]   = @port.gets(" ").sub(/\s+$/, '')
						datalen           = @port.gets(" ").sub(/\s+$/, '')
						event[:data]      = @port.read(datalen.to_i(16))
						@port.read(2) # ignore crlf
						callback_event(:ERXUDP, event)
						buffer.clear
					when "ERXTCP"
						event = {}
						event[:sender] = @port.gets(" ").sub(/\s+$/, '')
						event[:rport]  = @port.gets(" ").sub(/\s+$/, '')
						event[:lport]  = @port.gets(" ").sub(/\s+$/, '')
						datalen = @port.gets(" ").sub(/\s+$/, '')
						event[:data]   = @port.read(datalen.to_i(16))
						@port.read(2) # ignore crlf
						callback_event(:ERXTCP, event)
						buffer.clear
					when "EPONG"
						event = {}
						event[:sender] = @port.gets("\n").sub(/\s+$/, '')
						callback_event(:EPONG, event)
						buffer.clear
					when "ETCP"
						event = {}
						event[:status] = @port.gets(" ").sub(/\s+$/, '')
						if event[:status] == "1"
							event[:handle] = @port.gets(" ").sub(/\s+$/, '')
							event[:ipaddr] = @port.gets(" ").sub(/\s+$/, '')
							event[:rport] = @port.gets(" ").sub(/\s+$/, '')
							event[:lport] = @port.gets("\n").sub(/\s+$/, '')
						else
							event[:handle] = @port.gets("\n").sub(/\s+$/, '')
						end
						callback_event(:EPONG, event)
						buffer.clear
					when "EADDR", "ENEIGHBOR"
						# ignore
					when "EPANDESC"
						event = {}
						@port.gets("\n") # ignore
						event[:channel]      = @port.gets("\n")[/Channel:(\S+)/, 1]
						event[:channel_page] = @port.gets("\n")[/Channel Page:(\S+)/, 1]
						event[:pan_id]       = @port.gets("\n")[/Pan ID:(\S+)/, 1]
						event[:addr]         = @port.gets("\n")[/Addr:(\S+)/, 1]
						event[:lqi]          = @port.gets("\n")[/LQI:(\S+)/, 1]
						event[:pair_id]      = @port.gets("\n")[/PairID:(\S+)/, 1]
						p event
						callback_event(:EPANDESC, event)
						buffer.clear
					when "EEDSCAN"
						@port.gets("\n") # ignore
						_rssi = @port.gets("\n")
					when "EPORT"
						@port.gets("\n") # ignore
						6.times do
							_udp = @port.gets("\n") # ignore
						end
						@port.gets("\n") # ignore
						4.times do
							_tcp = @port.gets("\n") # ignore
						end
						@port.gets("\n") # "OK" ignore
					when "EHANDLE"
						@port.gets("\n") # ignore
						while line = @port.gets("\n")
							line.chomp!
							break if line == "OK"
						end
					when "EVENT"
						num, sender, param = *@port.gets("\n").sub(/\s+$/, '').split(/ /)
						event = {
							num: num,
							sender: sender,
							param: param
						}
						callback_event(:EVENT, event)
						buffer.clear
					when "EVER"
						event = {}
						event[:version] = @port.gets("\n").sub(/\s+$/, '')
						callback_event(:EVER, event)
						buffer.clear
					when "EAPPVER"
						event = {}
						event[:version] = @port.gets("\n").sub(/\s+$/, '')
						callback_event(:EAPPVER, event)
						buffer.clear
					else
						# do nothing
					end
				when "\n"
					# event 以外
					line = buffer.chomp
					@queue << line
					buffer.clear
				end
			end
		end
	end

	def command(string)
		@port.write(string + "\r\n")
		res = @queue.pop
		if string.split(/ /)[0] == res.split(/ /)[0] # ignore echoback
			res = @queue.pop
		end
		res
	end

	def on(name, &block)
		(@event_callbacks[name.to_sym] ||= []) << block
	end

	private
	def callback_event(name, event)
		(@event_callbacks[name.to_sym] || []).each do |cb|
			cb.call(event)
		end
	end
end

require 'logger'
require 'timeout'
class SmartMeterController
	def initialize
		@logger = Logger.new($stdout)
	end

	def start(io, opts)
		@stack = SKSTACK_IP.new(io)
		@events = Queue.new
		@stack.on(:EVENT) do |e|
			@logger.debug("EVENT %p" % e)
			@events << e
		end
		@epandesc = nil
		@stack.on(:EPANDESC) do |e|
			@logger.debug("EPANDESC %p" % e)
			@epandesc = e
		end
		@transactions = {}
		@stack.on(:ERXUDP) do |e|
			@logger.info("ERXUDP %p" % e)
			begin
				frame = ECHONET_Lite.parse_frame(e[:data])
				if transaction = @transactions.delete(frame.tid)
					transaction.call(frame)
				end
			rescue ECHONET_Lite::ParseError
				@logger.info("Not an ECHONET Lite frame")
			end
		end

		@stack.on(:EVER) do |e|
			@logger.info("EVER %p" % e)
		end
		@stack.on(:EAPPVER) do |e|
			@logger.info("EAPPVER %p" % e)
		end

		@stack.command("SKRESET") == "OK" or raise
		@stack.command("SKRESET") == "OK" or raise
		@stack.command("SKVER") == "OK" or raise
		@stack.command("SKAPPVER") == "OK" or raise
		@stack.command("SKSREG SFE 0") == "OK" or raise
		@logger.info("Setting ID and Password")
		@stack.command("SKSETPWD C #{opts[:PASS]}") == "OK" or raise
		@stack.command("SKSETRBID #{opts[:ID]}") == "OK" or raise

		while true
			@logger.info("Scanning device...")
			@stack.command("SKSCAN 2 FFFFFFFF 1")

			while e = @events.pop
				if e[:num].to_i(16) == SKSTACK_IP::EVENT_COMPLETED_ACTIVE_SCAN
					@logger.info("Scan Completed")
					break
				end
			end
			if @epandesc
				break
			end
			@logger.info("Device not found... retrying...")
			sleep 1
		end

		@logger.info("Device found %p" % @epandesc)

		@logger.info("Getting IPv6 Address from MAC Address (%p)" % @epandesc[:addr])
		@ipv6_addr = @stack.command("SKLL64 #{@epandesc[:addr]}")

		@logger.info("Setting Channel and Pan ID")
		@stack.command("SKSREG S2 #{@epandesc[:channel]}") == "OK" or raise
		@stack.command("SKSREG S3 #{@epandesc[:pan_id]}") == "OK" or raise

		@logger.info("Starting PANA")
		@stack.command("SKJOIN #{@ipv6_addr}") == "OK" or raise
		while e = @events.pop
			case e[:num].to_i(16)
			when SKSTACK_IP::EVENT_PANA_COMPLETED
				break
			when SKSTACK_IP::EVENT_PANA_ERROR
				raise "pana error"
			end
		end
		@logger.info("PANA Completed")

		@tid = 0
	end

	def retrieve_power
		@tid += 1

		tid = @tid

		q = Queue.new
		@transactions[tid] = proc {|frame|
			q << frame
		}

		frame = ECHONET_Lite::Frame.new(
			ECHONET_Lite::EHD1,
			ECHONET_Lite::EHD2_DEFINED,
			@tid,
			ECHONET_Lite::EDATA.new(
				ECHONET_Lite::EOJ.new(0x05, 0xFF, 0x01),
				ECHONET_Lite::EOJ.new(0x02, 0x88, 0x01),
				0x62,
				1,
				[
					ECHONET_Lite::Property.new(
						0xe7,
						0x00,
						""
					)
				]
			)
		)

		handle = 1
		port_num = 3610
		sec = 1
		data = frame.pack
		p [:packed, data]
		@stack.command("SKSENDTO %s %s %04X %s %04X %s" % [
			handle,
			@ipv6_addr,
			port_num,
			sec,
			data.length,
			data
		])

		while e = @events.pop
			if e[:num].to_i(16) == SKSTACK_IP::EVENT_UDP_SENT
				unless e[:param].to_i(16) == 0 # success
					return nil
				end
				break
			end
		end

		ret = nil
		begin
			Timeout.timeout(5) do
				ret = q.pop
			end
		rescue Timeout::Error
			@logger.info "UDP Response Timeout"
			@transactions.delete(tid)
		end
		ret
	end
end

io = nil
require 'serialport'
require 'pathname'

load(Pathname(__FILE__).parent + "config.rb")
p CONFIG

begin
	io = SerialPort.new(
		"/dev/ttyUSB0",
		115200,
		8,
		1,
		0
	)
	io.flow_control = SerialPort::NONE
	io.set_encoding(Encoding::BINARY)
rescue Errno::EBUSY => e
	p e
	sleep 1
	retry
end

p io

c = SmartMeterController.new
c.start(io, {
	ID: CONFIG[:B_ROUTE_ID].gsub(/ /, ''),
	PASS: CONFIG[:B_ROUTE_PASS].gsub(/ /, ''),
})
loop do
	frame = c.retrieve_power
	unless frame
		puts "failed to get power"
		next
	end
	frame.edata.properties.each do |prop|
		p prop
		if prop.epc == 0xe7 && prop.pdc == 4
			watts = prop.edt.unpack("N")[0]
			p "#{watts} W"
		end
	end
end

