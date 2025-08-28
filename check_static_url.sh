#!/bin/bash

# NoctisPro Static URL Check Script
# Verifies that the static ngrok URL is properly configured and working

WORKSPACE_DIR="/workspace"

echo "🔍 NoctisPro Static URL Status Check"
echo "===================================="
echo ""

# Function to log with timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

# Check environment file
if [ -f "$WORKSPACE_DIR/.env.ngrok" ]; then
    log "📁 Found ngrok environment file"
    
    # Check if static mode is enabled
    if grep -q "NGROK_USE_STATIC=true" "$WORKSPACE_DIR/.env.ngrok"; then
        log "✅ Static mode enabled"
        
        # Get static URL
        STATIC_URL=$(grep "NGROK_STATIC_URL=" "$WORKSPACE_DIR/.env.ngrok" | cut -d'=' -f2 | tr -d ' "')
        if [ ! -z "$STATIC_URL" ]; then
            log "🌐 Configured static URL: https://$STATIC_URL"
            
            # Check if current URL file exists and matches
            if [ -f "$WORKSPACE_DIR/current_ngrok_url.txt" ]; then
                CURRENT_URL=$(cat "$WORKSPACE_DIR/current_ngrok_url.txt")
                log "📄 Current active URL: $CURRENT_URL"
                
                if [[ "$CURRENT_URL" == "https://$STATIC_URL" ]]; then
                    log "✅ URLs match - static URL is active!"
                else
                    log "⚠️  URLs don't match - ngrok may not be using static URL"
                fi
            else
                log "ℹ️  No current URL file found (service may not be running)"
            fi
            
            # Test connectivity
            log "🌐 Testing connectivity to static URL..."
            if curl -s -o /dev/null -w "%{http_code}" "https://$STATIC_URL" | grep -q "200\|302"; then
                log "✅ Static URL is accessible and responding"
            else
                log "❌ Static URL is not responding or unreachable"
            fi
            
        else
            log "❌ NGROK_STATIC_URL is not set in environment file"
        fi
    else
        log "❌ Static mode is disabled (NGROK_USE_STATIC=false or not set)"
    fi
    
    # Check auth token
    if grep -q "NGROK_AUTHTOKEN=" "$WORKSPACE_DIR/.env.ngrok" && ! grep -q "NGROK_AUTHTOKEN=$" "$WORKSPACE_DIR/.env.ngrok"; then
        log "✅ Ngrok auth token is configured"
    else
        log "❌ Ngrok auth token is not configured"
    fi
    
else
    log "❌ Ngrok environment file not found: $WORKSPACE_DIR/.env.ngrok"
fi

echo ""

# Check if service is running
if systemctl is-active --quiet noctispro-complete 2>/dev/null; then
    log "✅ NoctisPro service is running"
elif systemctl is-enabled --quiet noctispro-complete 2>/dev/null; then
    log "⚠️  NoctisPro service is enabled but not running"
else
    log "ℹ️  NoctisPro service is not installed or enabled"
fi

# Check if ngrok process is running
if pgrep -f ngrok > /dev/null; then
    NGROK_PID=$(pgrep ngrok)
    log "✅ Ngrok process is running (PID: $NGROK_PID)"
    
    # Try to get URL from ngrok API
    NGROK_API_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data['tunnels']:
        if tunnel['proto'] == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
" 2>/dev/null)
    
    if [ ! -z "$NGROK_API_URL" ]; then
        log "🌐 Ngrok API reports URL: $NGROK_API_URL"
    else
        log "⚠️  Could not get URL from ngrok API"
    fi
else
    log "❌ Ngrok process is not running"
fi

echo ""
echo "📋 Summary:"
echo "==========="

if [ ! -z "$STATIC_URL" ]; then
    echo "  Static URL: https://$STATIC_URL"
    echo "  Status: $([ -f "$WORKSPACE_DIR/current_ngrok_url.txt" ] && echo "Active" || echo "Inactive")"
else
    echo "  Static URL: Not configured"
fi

echo ""
echo "💡 Tips:"
echo "  - To configure static URL: ./setup_ngrok_static.sh"
echo "  - To install auto-start: ./install_autostart.sh"
echo "  - To check service logs: sudo journalctl -u noctispro-complete -f"
echo ""