#!/usr/bin/env bash
# 連到容器並建立到 THM 靶機的 port forward。
set -euo pipefail
cd "$(dirname "$0")"

read -rp '靶機 IP: ' ip
ip="${ip// /}"
if [[ -z "$ip" ]]; then
    echo '沒輸入 IP，結束。' >&2
    exit 1
fi

read -rp '靶機 port（直接 Enter = 80）: ' port
port="${port// /}"
port="${port:-80}"

case "$port" in
    80)  local_port=8080 ;;
    443) local_port=8443 ;;
    *)   local_port="$port" ;;
esac

scheme=http
[[ "$port" == "443" ]] && scheme=https
url="${scheme}://127.0.0.1:${local_port}"

echo
echo "─────────────────────────────────────────────"
echo "  靶機：     ${ip}:${port}"
echo "  瀏覽器開： ${url}"
echo "  保持這個視窗開著；關掉就斷了。"
echo "─────────────────────────────────────────────"
echo

exec ssh -p 2222 -L "${local_port}:${ip}:${port}" student@127.0.0.1
