
require 'pathname'
require 'logger'

class PluginLoader
	attr_accessor :handled

	def initialize(base_module, search_paths: ["plugins"], logger: nil)
		@base_module = base_module
		@search_paths = search_paths
		@loaded = []
		@logger = logger || Logger.new($stdout)
		reload
	end

	def reload
		files = @search_paths.flat_map {|i|
			Pathname.glob("#{i}/*.rb").sort_by {|i| i.basename }
		}

		loading = []
		files.each do |f|
			loaded = @loaded.find {|i| i[:file] == f.to_s }

			if loaded.nil? || loaded[:time] < f.mtime
				if loaded
					@logger.info "re-loading #{f}"
				else
					@logger.info "loading #{f}"
				end

				loader = self
				mod = Module.new do
					@loader = loader
					@handlers = []
					def self.handlers
						@handlers
					end

					def self.stop
						@loader.handled = true
					end
				end
				mod.extend @base_module
				mod.module_eval(f.read, f.to_s)

				loading << {
					file: f.to_s,
					time: f.mtime,
					module: mod,
				}
			else
				loading << loaded
			end
		end
		@loaded = loading
		@loaded.each do |loaded|
			loaded[:module].handlers.each do |handler|
				@logger.info "Loaded: #{loaded[:file]} :: #{handler.inspect}"
			end
		end
	end

	def run(&block)
		handlers = @loaded.flat_map {|i|
			i[:module].handlers
		}

		@logger.info "run... (#{handlers.size} handlers)"

		begin
			self.handled = false
			handlers.each do |handler|
				call = block.call(handler)
				if call
					@logger.info "running #{handler.inspect}"
					begin
						handler.handle(call)
					rescue Exception => e
						@logger.error "exception on running #{handler.inspect}"
						@logger.error "#{e}"
						e.backtrace.each do |bt|
							@logger.error "\t#{bt}"
						end
						raise e
					end
				else
					@logger.info "skipping #{handler.inspect}"
				end
				if self.handled
					@logger.info "stop"
					break
				end
			end
		rescue StopException
			@logger.info "stop"
		end
	ensure
		@logger.info "done"
	end
end



