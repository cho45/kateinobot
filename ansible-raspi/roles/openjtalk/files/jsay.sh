#!/bin/sh

VOICE=/usr/share/hts-voice/nitech-jp-atr503-m001/nitech_jp_atr503_m001.htsvoice
VOICE=/usr/share/hts-voice/mei/mei_normal.htsvoice
TMP=/tmp/jsay.wav

echo "$1" | open_jtalk \
        -m $VOICE \
        -a 0.55 \
        -b 0.5 \
        -r 1.0 \
        -jf 0.3 \
        -x /var/lib/mecab/dic/open-jtalk/naist-jdic \
        -ow $TMP && \
        aplay --quiet $TMP
        rm -f $TMP
