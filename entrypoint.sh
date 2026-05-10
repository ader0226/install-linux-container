#!/usr/bin/env bash
# Auto-start: OpenVPN (using first .ovpn in /vpn) + microsocks SOCKS5 proxy.
# Container stays alive via `sleep infinity`; users attach via `docker compose exec`.
set -uo pipefail

log() { echo "[entrypoint] $*"; }

# 1. Ensure /dev/net/tun is present
if [[ ! -c /dev/net/tun ]]; then
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200 2>/dev/null || true
    chmod 600 /dev/net/tun || true
fi

# 2. Auto-start OpenVPN with the first *.ovpn under /vpn
shopt -s nullglob
ovpns=(/vpn/*.ovpn)
shopt -u nullglob

if (( ${#ovpns[@]} == 0 )); then
    log "WARN: /vpn 中沒有 .ovpn 檔，VPN 不會自動啟動。"
    log "      可在容器內手動執行 vpn-up（前提是 mount 了 ovpn）。"
else
    VPN_CONFIG="${ovpns[0]}"
    LOG=/var/log/openvpn.log
    PIDFILE=/run/openvpn.pid
    AUTH_FILE=/vpn/auth.txt

    OVPN_ARGS=(--config "$VPN_CONFIG" --daemon --log "$LOG" \
               --writepid "$PIDFILE" --script-security 2)
    [[ -f "$AUTH_FILE" ]] && OVPN_ARGS+=(--auth-user-pass "$AUTH_FILE")

    log "啟動 OpenVPN: $VPN_CONFIG"
    cd "$(dirname "$VPN_CONFIG")"
    if openvpn "${OVPN_ARGS[@]}"; then
        for i in {1..30}; do
            if ip link show tun0 >/dev/null 2>&1; then
                log "tun0 上線 ✓"
                break
            fi
            sleep 1
        done
        ip link show tun0 >/dev/null 2>&1 \
            || log "WARN: tun0 30 秒內未上線，請看 $LOG"
    else
        log "WARN: openvpn 啟動失敗，請看 $LOG"
    fi
    cd /
fi

# 3. SOCKS5 proxy on :1080 (always start, even if VPN failed)
log "啟動 microsocks 於 0.0.0.0:1080"
microsocks -i 0.0.0.0 -p 1080 >/var/log/microsocks.log 2>&1 &

# 4. Keep container alive
exec sleep infinity
