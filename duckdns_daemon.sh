#!/bin/bash
# DuckDNS Background Daemon for NOCTIS PRO
echo "🦆 Starting DuckDNS Background Daemon..."

while true; do
    /workspace/update_duckdns.sh
    sleep 300  # Wait 5 minutes
done