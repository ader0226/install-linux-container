#!/usr/bin/env bash
# Boot the lab container (macOS / Linux)
set -euo pipefail
cd "$(dirname "$0")"

docker compose pull
docker compose up -d

cat <<'EOF'

Lab container is up.

進入容器：
  ssh -p 2222 student@127.0.0.1
  （第一次會問 host key，輸入 yes；密碼是 student）

THM 靶機網頁轉發（另開一個終端機）：
  ./forward.sh   （會問靶機 IP/port 然後直接幫你連）

停止：./stop.sh   （或 docker compose down）
EOF
