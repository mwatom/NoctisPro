#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="/etc/noctis/duckdns.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

# Also source main env for PUBLIC_URL if present
MAIN_ENV_FILE="/etc/noctis/noctis.env"
[ -f "$MAIN_ENV_FILE" ] && source "$MAIN_ENV_FILE" || true

# If token exists but subdomain is missing, infer from PUBLIC_URL or fall back to machine-based name
if [ -z "${DUCKDNS_SUBDOMAIN:-}" ] && [ -n "${DUCKDNS_TOKEN:-}" ]; then
	if [[ "${PUBLIC_URL:-}" =~ ^https?://([a-zA-Z0-9-]+)\.duckdns\.org/?.*$ ]]; then
		DUCKDNS_SUBDOMAIN="${BASH_REMATCH[1]}"
	else
		MACHINE_ID="$( (cat /etc/machine-id 2>/dev/null || uuidgen) | tr -d '-' | cut -c1-8 )"
		DUCKDNS_SUBDOMAIN="noctis-$MACHINE_ID"
	fi
fi

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