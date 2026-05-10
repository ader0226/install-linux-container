#!/usr/bin/env bash
# shell-attack-lab universal installer (macOS / Linux)
# 在含有 xxx.ovpn 的目錄下執行：
#   /bin/bash -c "$(curl -fsSL <INSTALL_URL>)"
set -euo pipefail

IMAGE="${SHELL_LAB_IMAGE:-ghcr.io/ader0226/shell-attack-lab:latest}"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
cyan()   { printf '\033[36m%s\033[0m\n' "$*"; }

# ── 1. docker compose 可用？ ────────────────────────────────────
if ! command -v docker >/dev/null 2>&1; then
    red "✗ 找不到 docker，請先安裝 Docker Desktop:"
    echo "  https://www.docker.com/products/docker-desktop/"
    exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
    red "✗ 'docker compose' 子指令不可用（請更新 Docker Desktop 到 v2+）"
    exit 1
fi
green "✓ docker compose 可用"

# ── 2. 找當前目錄的 .ovpn ────────────────────────────────────────
OVPN_DIR="$(pwd)"
shopt -s nullglob
ovpns=("$OVPN_DIR"/*.ovpn)
shopt -u nullglob
if (( ${#ovpns[@]} == 0 )); then
    red "✗ 在 $OVPN_DIR 找不到 .ovpn 檔"
    echo "  請 cd 到含有 xxx.ovpn 的目錄再執行一次"
    exit 1
fi
OVPN_FILE="$(basename "${ovpns[0]}")"
green "✓ 使用 VPN 設定: $OVPN_FILE"

# ── 3. state dir ─────────────────────────────────────────────────
STATE_DIR="$OVPN_DIR/.shell-attack-lab"
mkdir -p "$STATE_DIR"
ENV_FILE="$STATE_DIR/.env"
COMPOSE_FILE="$STATE_DIR/docker-compose.yml"

# ── 4. 找 / 沿用 proxy port ─────────────────────────────────────
PROXY_PORT=""
if [[ -f "$ENV_FILE" ]]; then
    PROXY_PORT="$(awk -F= '/^PROXY_PORT=/{print $2}' "$ENV_FILE" | tr -d '\r' || true)"
fi
if [[ -z "$PROXY_PORT" ]]; then
    PROXY_PORT="$(python3 -c 'import socket
s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
    echo "PROXY_PORT=$PROXY_PORT" > "$ENV_FILE"
    green "✓ 配置新 proxy port: $PROXY_PORT"
else
    cyan "↻ 沿用既有 proxy port: $PROXY_PORT"
fi

# ── 5. 產生 compose.yml ─────────────────────────────────────────
cat > "$COMPOSE_FILE" <<EOF
services:
  lab:
    image: $IMAGE
    container_name: shell-lab
    hostname: lab
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - "$OVPN_DIR:/vpn:ro"
    ports:
      - "127.0.0.1:\${PROXY_PORT}:1080"
    restart: unless-stopped
EOF

DC=(docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE")

# ── 6. 啟動容器（已在跑就跳過 up） ──────────────────────────────
"${DC[@]}" pull >/dev/null 2>&1 || true
"${DC[@]}" up -d
green "✓ 容器已啟動"

# ── 7. 等 VPN 上線 ───────────────────────────────────────────────
printf '  等待 VPN 上線'
for i in {1..30}; do
    if "${DC[@]}" exec -T lab ip link show tun0 >/dev/null 2>&1; then
        printf ' ✓\n'
        ok=1
        break
    fi
    sleep 1
    printf '.'
done
if [[ "${ok:-}" != "1" ]]; then
    printf '\n'
    yellow "⚠ tun0 30 秒內未上線（可能 .ovpn 有問題或 THM 房間未開）"
    echo "   docker compose -f $COMPOSE_FILE logs 看細節"
fi

# ── 8. 開 Chromium 系 browser，帶 SOCKS5 proxy ─────────────────
TMP_PROFILE="$(mktemp -d -t shell-lab-profile.XXXXXX)"
PROXY_FLAGS=(
    "--user-data-dir=$TMP_PROFILE"
    "--proxy-server=socks5://127.0.0.1:$PROXY_PORT"
    "--no-first-run"
    "--no-default-browser-check"
    "about:blank"
)

launch_browser() {
    case "$(uname -s)" in
        Darwin)
            for app in "Google Chrome" "Microsoft Edge" "Brave Browser" "Chromium" "Arc"; do
                if [[ -d "/Applications/$app.app" ]]; then
                    open -na "$app" --args "${PROXY_FLAGS[@]}" >/dev/null 2>&1 &
                    cyan "✓ 已用 $app 開啟（SOCKS5 127.0.0.1:$PROXY_PORT）"
                    return 0
                fi
            done
            ;;
        Linux)
            for bin in google-chrome google-chrome-stable chromium chromium-browser \
                       microsoft-edge microsoft-edge-stable brave-browser; do
                if command -v "$bin" >/dev/null 2>&1; then
                    "$bin" "${PROXY_FLAGS[@]}" >/dev/null 2>&1 &
                    cyan "✓ 已用 $bin 開啟（SOCKS5 127.0.0.1:$PROXY_PORT）"
                    return 0
                fi
            done
            ;;
    esac
    return 1
}

if ! launch_browser; then
    yellow "⚠ 沒找到 Chromium 系 browser，請手動設 SOCKS5: 127.0.0.1:$PROXY_PORT"
    yellow "   推薦：Chrome / Edge / Brave"
fi

# ── 9. 進容器互動 shell ─────────────────────────────────────────
echo
green "════════════════════════════════════════════════════════"
echo  "  進入容器互動 shell（Ctrl-D 離開不會停容器）"
echo  "  Browser 已連 SOCKS5: 127.0.0.1:$PROXY_PORT"
echo  "  下次再執行此腳本可繼續同一個容器"
green "════════════════════════════════════════════════════════"
echo

exec "${DC[@]}" exec -u student lab bash
