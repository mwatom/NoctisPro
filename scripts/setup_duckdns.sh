#!/usr/bin/env bash
set -euo pipefail

# Additive DuckDNS setup script: registers/updates a DuckDNS subdomain with your IP
# and writes a systemd timer to auto-refresh every 5 minutes.
#
# Usage (as root or with sudo):
#   ./scripts/setup_duckdns.sh <TOKEN> <SUBDOMAIN> [ipv4]
#
# Example:
#   sudo ./scripts/setup_duckdns.sh YOUR_TOKEN noctispro

TOKEN="${1:-}"
SUBDOMAIN="${2:-}"
IPV4="${3:-}"

if [[ -z "${TOKEN}" || -z "${SUBDOMAIN}" ]]; then
  echo "Usage: $0 <TOKEN> <SUBDOMAIN> [ipv4]" >&2
  exit 1
fi

if [[ -z "${IPV4}" ]]; then
  IPV4=$(curl -s https://ifconfig.me || curl -s https://api.ipify.org || true)
fi

if [[ -z "${IPV4}" ]]; then
  echo "[WARN] Could not auto-detect public IPv4. DuckDNS will use the requester IP."
fi

DUCKDNS_URL="https://www.duckdns.org/update?domains=${SUBDOMAIN}&token=${TOKEN}&ip=${IPV4}"
RESP=$(curl -s "${DUCKDNS_URL}" || true)
echo "[INFO] DuckDNS update response: ${RESP}"

cat >/etc/systemd/system/duckdns-update.service <<SERVICE
[Unit]
Description=DuckDNS updater
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/curl -s "${DUCKDNS_URL}"
User=root

[Install]
WantedBy=multi-user.target
SERVICE

cat >/etc/systemd/system/duckdns-update.timer <<TIMER
[Unit]
Description=Run DuckDNS updater every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Unit=duckdns-update.service

[Install]
WantedBy=timers.target
TIMER

systemctl daemon-reload
systemctl enable --now duckdns-update.timer
echo "[DONE] DuckDNS timer enabled. Subdomain: ${SUBDOMAIN}.duckdns.org"

