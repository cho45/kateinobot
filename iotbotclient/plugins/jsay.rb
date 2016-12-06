on_text(/^\(mouth\)(.+)$/) do |e, match|
	msg = match[1]
	Thread.start do
		system('jsay.sh', msg)
	end
	reply_text('音声を生成中です。少し時間がかかります')
end




