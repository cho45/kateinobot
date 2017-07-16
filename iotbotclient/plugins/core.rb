on_text("ステータス") do
	uname  = `uname -a`.chomp
	uptime = `uptime`.chomp
	ifconfig = `ifconfig`[/inet addr:([^ ]+)/, 1]
	cputemp = `vcgencmd measure_temp`.chomp rescue nil
	reply_text("サービス稼働中\n ip addr: %s\n uname: %s\n uptime: %s\n %s" % [ifconfig, uname, uptime, cputemp || "cpu: #{cputemp}"])
end


