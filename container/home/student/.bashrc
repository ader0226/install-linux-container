# Lab .bashrc — 互動式 shell 才執行
[[ $- != *i* ]] && return

# 防呆：某些 SSH client 沒帶 TERM 過來，bash 會跑 dumb 模式
[[ -z "$TERM" || "$TERM" == "dumb" ]] && export TERM=xterm-256color

# 防呆：sshd 經 PAM 啟動 child 時可能沒帶 LANG，tmux 會誤判成 non-UTF-8 把中文拆成 byte
[[ "$LANG" != *[Uu][Tt][Ff]* ]] && export LANG=C.UTF-8

# History
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend checkwinsize

# 上一個指令失敗就在 prompt 上方印一行紅字
PROMPT_COMMAND='__rc=$?; [[ $__rc -ne 0 ]] && printf "\033[31m✗ exit %d\033[0m\n" "$__rc"; __rc=0'
PS1='\[\033[36m\]\u@\h\[\033[0m\] \[\033[33m\]\w\[\033[0m\] \$ '

# Aliases
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'

# Pager / editor
export LESS='-R'
export LESSCHARSET=utf-8
export PAGER=less
export EDITOR=vim

# Tab completion（先試新路徑，再 fallback 舊路徑）
if ! shopt -oq posix; then
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        . /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        . /etc/bash_completion
    fi
fi

# 第一次進來給個提示
if [[ -z "$LAB_HINT_SHOWN" ]] && [[ -t 1 ]]; then
    export LAB_HINT_SHOWN=1
    echo
    echo "  輸入  tutorial  進入互動式教學，或  lab-help  看選單。"
    echo
fi
