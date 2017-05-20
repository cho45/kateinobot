require 'logger'
require 'json'
require "#{File.absolute_path(__FILE__)}/../plugin_loader"

class Context
	class Handler
		attr_reader :proc
		def initialize(&block)
			@proc = block
		end

		def can_handle?(event)
			true
		end

		def handle(arg)
			@proc.call(arg)
		end
	end

	class TextHandler < Handler
		attr_reader :text
		def initialize(text, &block)
			super(&block)
			@text = text
		end

		def handle(arg)
			@proc.call(arg, @matchdata)
		end

		def can_handle?(event)
			ret = 
				event['type'] == 'message' &&
				event['message']['type'] == 'text' &&
				@text === event['message']['text']

			@matchdata = Regexp.last_match

			ret
		end
	end

	class StickerHandler < Handler
		attr_reader :package_id, :sticker_id
		def initialize(package_id, sticker_id, &block)
			super(&block)
			@package_id = package_id
			@sticker_id = sticker_id
		end

		def can_handle?(event)
			event['type'] == 'message' &&
			event['message']['type'] == 'sticker' &&
			event['message']['packageId'] == @package_id &&
			event['message']['stickerId'] == @sticker_id
		end
	end

	module BaseModule
		def context
			@@context
		end
		
		def on_text(text, &block)
			handlers << TextHandler.new(text, &block)
		end

		def on_sticker(package_id: nil, sticker_id: nil, &block)
			handlers << StickerHandler.new(package_id.to_s, sticker_id.to_s, &block)
		end

		def on(&block)
			handlers << Handler.new(&block)
		end

		def reply_text(text)
			context.reply_message({
				type: 'text',
				text: text,
			})
			stop
		end

		def reply_message(*messages)
			context.reply_message(*messages)
			stop
		end

		def logger
			context.logger
		end
	end

	attr_reader :logger

	def initialize(ws, search_paths: ["plugins"], logger: nil)
		@ws = ws
		@logger = logger || Logger.new($stdout)
		BaseModule.class_variable_set(:@@context, self)
		@loader = PluginLoader.new(BaseModule, search_paths: search_paths, logger: @logger)
	end

	def handle_event(event)
		@last_event = event
		@loader.reload
		begin
			@loader.run do |handler|
				event if handler.can_handle?(event)
			end
		rescue => e
			reply_message({
				type: 'text',
				text: e.to_s
			})
		end
	end

	def reply_message(*messages)
		raise "last_event is empty" unless @last_event
		@logger.info "reply_message #{messages.inspect}"
		request("replyMessage", {
			replyToken: @last_event['replyToken'],
			messages: messages
		})
	end

	def request(method, params)
		json = JSON.generate({
			id: @id,
			method: method,
			params: params,
		})
		p :request, json
		@ws.send json
	end
end


if __FILE__ == $0
	ws = Object.new.instance_eval do
		def send(msg)
			p [:send, msg]
		end
		self
	end

	@context = Context.new(ws)
	@context.handle_event({
		'type' => 'message',
		'replyToken' => 'reply_token....',
		'message' => {
			'type' => 'text',
			'text' => 'ステータス',
		}
	})
	@context.handle_event({
		'type' => 'message',
		'replyToken' => 'reply_token....',
		'message' => {
			'type' => 'sticker',
			'packageId' => '4',
			'stickerId' => '284',
		}
	})
	@context.handle_event({
		'type' => 'message',
		'replyToken' => 'reply_token....',
		'message' => {
			'type' => 'sticker',
			'packageId' => 5,
			'stickerId' => 284,
		}
	})
end
