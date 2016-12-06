#!/usr/bin/env ruby


require 'sinatra'
# gem install sinatra-contrib
require 'sinatra/json'
require 'erubis'
set :erb, :escape_html => true
set :port, 9981

TOKEN_PATH = "#{ENV["HOME"]}/.iotgwconnecttoken"

get "/api/status" do
	headers(
		'Access-Control-Allow-Origin' => 'http://insecure.linebot.cho45.stfuawsc.com',
		"Access-Control-Request-Method" => 'POST, GET, OPTIONS'
	)

	token = File.read(TOKEN_PATH).chomp rescue nil

	json(
		version: "lxdev-0.0.1",
		name: "Raspberry Pi",
		type: "generic",
		token: token,
	)
end

# トークンを本当に設定しますか?
# という画面がこのオリジン上にも必要。

$csrf_token = 'invalid'

post "/connect" do
	if params['sk'] != $csrf_token
		$csrf_token = rand.to_s
		erb <<-EOF
			<meta charset="utf-8"/>
			<meta name="robots" content="noindex,nofollow,noarchive">
			<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"/>
			<form action="" method="post">
				<p>以下のボタンで続行します</p>
				<input type="hidden" name="sk" value="<%= $csrf_token %>">
				<input type="hidden" name="token" value="<%= params['token'] %>">
				<input type="hidden" name="return" value="<%= params['return'] %>">
				<button type="submit">このデバイスを登録する</button>
			</form>
			<style>
				body {
					text-align: center;
				}
				button {
					margin: 1em 0;
					border: none;
					outline: none;
					background: #7c809e;
					font-size: 18px;
					padding: 1em 2em;
					color: #fff;
					font-weight: 600;
				}
			</style>
		EOF
	else
		File.open(TOKEN_PATH, "w") do |f|
			f.puts params['token']
		end

		redirect(params['return']);
	end
end

get "/" do
	$csrf_token = rand.to_s
	erb <<-EOF
		<meta charset="utf-8"/>
		<meta name="robots" content="noindex,nofollow,noarchive">
		<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"/>
		<form action="/update" method="post">
			<input type="hidden" name="sk" value="<%= $csrf_token %>">
			<input type="hidden" name="token" value="<%= params['token'] %>">
			<input type="hidden" name="return" value="<%= params['return'] %>">
			<button type="submit">アップデート</button>
		</form>
		<style>
			body {
				text-align: center;
			}
			button {
				margin: 1em 0;
				border: none;
				outline: none;
				background: #7c809e;
				font-size: 18px;
				padding: 1em 2em;
				color: #fff;
				font-weight: 600;
			}
		</style>
	EOF
end

$updating = false
post "/update" do
	content_type 'text/plain; charset=utf-8'

	$updating = true
	begin
		stream do |out|
			10.times do
				sleep 1
				out << Time.now.to_s << "\n"
			end
		end
	ensure
		$updating = false
	end
end
