# Login shell 進入點：強制 source .bashrc。
# 不依賴 /etc/skel 的 .profile chain，避免某些 SSH/PAM 設定下 .bashrc 沒被讀到。
[[ -f ~/.bashrc ]] && . ~/.bashrc
