
on_text('エアコン') do
	reply_message({
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
	})
end

on_text('暖房つけて') do
	Thread.start do
		p system('/home/pi/bin/ir.rb', 'aircon_warm_on')
	end
	reply_text('暖房をつけます')
end

on_text('冷房つけて') do
	Thread.start do
		p system('/home/pi/bin/ir.rb', 'aircon_cool_on')
	end
	reply_text('冷房つけます')
end

on_text('エアコンけして') do
	Thread.start do
		p system('/home/pi/bin/ir.rb', 'aircon_off')
	end
	reply_text('エアコンをオフにします')
end


