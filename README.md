KATEINOBOT
==========

LINE BOT for my katei.

## システム構成

### bot.rb

LINE からの Webhook を受けるウェブサーバ。実際には HTTPS な h2o からリバースプロキシ経由でアクセスされる。

また、WebSocket サーバとして client.rb からの接続をうけ、適切に処理を行う。

### client.rb

bot.rb の WebSocket サーバに接続して、LINE からのイベントを受けとって実際に処理をする。


## Raspberry Pi

```
sudo apt-get install ruby-dev libssl-dev
sudo gem install bundle
bundle
ruby client.rb
```
