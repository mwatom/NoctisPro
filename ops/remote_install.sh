#!/usr/bin/env bash
set -euo pipefail

# Bootstrap installer for a clean server.
# Usage examples:
#   bash -lc "$(curl -fsSL https://raw.githubusercontent.com/mwatom/NoctisPro/main/ops/remote_install.sh)" \
#     your.domain.com           # optional domain
#   # or without a domain (auto-generated stable URL)
#   bash -lc "$(curl -fsSL https://raw.githubusercontent.com/mwatom/NoctisPro/main/ops/remote_install.sh)"

REPO_URL="${REPO_URL:-https://github.com/mwatom/NoctisPro}"
APP_DIR="${APP_DIR:-/opt/noctis}"
SUDO=${SUDO:-sudo}

$SUDO apt-get update -y
$SUDO apt-get install -y git curl

if [ ! -d "$APP_DIR/.git" ]; then
  echo "Cloning $REPO_URL to $APP_DIR"
  $SUDO rm -rf "$APP_DIR"
  $SUDO git clone "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"

# Forward optional domain/DuckDNS args
SERVER_NAME="${1:-${SERVER_NAME:-}}"
DUCKDNS_SUBDOMAIN="${2:-${DUCKDNS_SUBDOMAIN:-}}"
DUCKDNS_TOKEN="${3:-${DUCKDNS_TOKEN:-}}"

# Ensure the installer knows the repo URL for future auto-deploys
REPO_URL="$REPO_URL" SERVER_NAME="$SERVER_NAME" DUCKDNS_SUBDOMAIN="$DUCKDNS_SUBDOMAIN" DUCKDNS_TOKEN="$DUCKDNS_TOKEN" \
  $SUDO bash "$APP_DIR/ops/install_services.sh" "$SERVER_NAME" "$DUCKDNS_SUBDOMAIN" "$DUCKDNS_TOKEN"