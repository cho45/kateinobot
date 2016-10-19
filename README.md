KATEINOBOT
==========

LINE BOT for my katei.

## システム構成

### bot.rb

LINE からの Webhook を受けるウェブサーバ。実際には HTTPS な h2o からリバースプロキシ経由でアクセスされる。

また、WebSocket サーバとして client.rb からの接続をうけ、Webhook 発生時のイベントの処理をデリゲートする。

固定IPを持ち、HTTPS でアクセスできる VPS 上で起動しておく。

### client.rb

bot.rb の WebSocket サーバに接続して、LINE からのイベントを受けとって実際に処理をする。

Raspberry Pi など、家庭内 LAN から起動しておく。

### なぜこんな構成か？

* Raspberry Pi を家庭内 LAN に置いて実際の応答処理を行いたい
* 家庭内へのポート解放をやりたくない
* DDNS とか管理したくない
* 経路は暗号化したい

あたりを解決するため。

家庭内からは VPS の HTTPS (というか WSS) に繋ぎにいくだけですむ。


## Raspberry Pi

Raspberry Pi 側では client.rb を起動する。

```
sudo apt-get install ruby-dev libssl-dev
sudo gem install bundle
bundle
ruby client.rb
```
