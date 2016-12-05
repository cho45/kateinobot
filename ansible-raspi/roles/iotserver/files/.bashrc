hh=$HOSTNAME
uu=$USER
col=32
TITLEBAR='\[\033]0; \w\007\]'
PS1="${TITLEBAR}
\[\e[${col}m\]$uu@$hh \[\e[33m\]\w
\[\e[${col}m\]\$\[\e[m\] "

export PATH="$HOME/bin:$HOME/lib/ruby/gems/1.8/bin:/usr/local/bin:/usr/bin:/bin:/usr/X11R6/bin:$PATH"

alias lm='ls -altr'

