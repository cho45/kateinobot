on_text("ステータス") do
	uname  = `uname -a`.chomp
	uptime = `uptime`.chomp
	cputemp = `vcgencmd measure_temp`.chomp rescue nil
	reply_text("サービス稼働中\n uname: %s\n uptime: %s\n %s" % [uname, uptime, cputemp || "cpu: #{cputemp}"])
end


