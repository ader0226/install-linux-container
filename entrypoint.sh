#!/usr/bin/env bash
set -euo pipefail

# Make sure /dev/net/tun is present so vpn-up works later.
if [[ ! -c /dev/net/tun ]]; then
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200 || true
    chmod 600 /dev/net/tun || true
fi

# Foreground sshd (PID 1).
exec /usr/sbin/sshd -D -e
