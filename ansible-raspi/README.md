ansible-raspi
=============

Raspberry Pi 向けに IoT Gateway 用のセットアップを行える Ansible Playbook

## つかいかた

まず ansble が必要です。<a href="http://docs.ansible.com/ansible/intro_installation.html">Installation</a>

同一ネットワーク内に接続済みの Raspberry Pi がある場合で、mDNS によるアドレス解決が可能なら

```
./run.sh
```

でセットアップ可能です。

# アップデート

この Playbook を使うと対象ホストの /home/pi/app/kateinobot/ansible-raspi に、Ansible およびこの Playbook 自身もインストールされます。
そのため以下のようにすることでアップデートすることが可能です。

```
cd /home/pi/app/kateinobot/ansible-raspi 
git pull
./run-local.sh
```

