#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="/etc/noctis/duckdns.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

if [ -z "${DUCKDNS_SUBDOMAIN:-}" ] || [ -z "${DUCKDNS_TOKEN:-}" ]; then
	echo "DuckDNS not configured; missing DUCKDNS_SUBDOMAIN or DUCKDNS_TOKEN" >&2
	exit 0
fi

# Determine current public IPv4 (fallback to local primary IP)
IP_ADDR="$(curl -fsS4 ifconfig.me || true)"
if [ -z "$IP_ADDR" ]; then
	IP_ADDR="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
IP_ADDR=${IP_ADDR:-""}

# Update DuckDNS (ip blank lets DuckDNS auto-detect)
UPDATE_URL="https://www.duckdns.org/update?domains=${DUCKDNS_SUBDOMAIN}&token=${DUCKDNS_TOKEN}"
if [ -n "$IP_ADDR" ]; then
	UPDATE_URL+="&ip=${IP_ADDR}"
fi

curl -fsS "$UPDATE_URL" | grep -qi 'OK' || true