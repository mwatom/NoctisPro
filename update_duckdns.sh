#!/bin/bash
# Auto-update Duck DNS IP
PUBLIC_IP=$(curl -s ifconfig.me)
curl -s "https://www.duckdns.org/update?domains=noctispro2&token=9d40387a-ac37-4268-8d51-69985ae32c30&ip=${PUBLIC_IP}"
echo "$(date): Updated noctispro2.duckdns.org to ${PUBLIC_IP}" >> /workspace/duckdns.log
