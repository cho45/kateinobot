on_text("ステータス") do
	uptime = `uptime`.chomp
	cputemp = `vcgencmd measure_temp`.chomp
	reply_text('サービス稼働中 (uptime: %s / CPU %s)' % [uptime, cputemp])
end

on_sticker(package_id: 4, sticker_id: 284) do
	reply_text("うんちはトイレでしてね")
end

on do |e|
	logger.info e.inspect
end
