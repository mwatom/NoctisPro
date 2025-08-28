#!/bin/bash

# Check Autostart Status Script

echo "🔍 NoctisPro Autostart Status Check"
echo "==================================="
echo ""

# Function to show status with color
show_status() {
    local service="$1"
    local description="$2"
    
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
        if systemctl is-active "$service" >/dev/null 2>&1; then
            echo "✅ $description: Enabled and Running"
        else
            echo "🟡 $description: Enabled but Not Running"
        fi
    else
        echo "❌ $description: Not Enabled"
    fi
}

# Check main service
echo "📊 Service Status:"
show_status "noctispro-complete" "NoctisPro Complete System"

# Check dependencies
echo ""
echo "🔗 Dependencies:"
show_status "postgresql" "PostgreSQL Database"
show_status "redis-server" "Redis Cache"

# Check ngrok configuration
echo ""
echo "🌐 Ngrok Configuration:"
if ngrok config check >/dev/null 2>&1; then
    echo "✅ Ngrok: Configured with auth token"
else
    echo "❌ Ngrok: Not configured (need auth token)"
fi

# Check environment files
echo ""
echo "📁 Configuration Files:"
if [ -f "/workspace/.env.ngrok" ]; then
    echo "✅ Ngrok Environment: Present"
    if grep -q "NGROK_USE_STATIC=true" "/workspace/.env.ngrok" 2>/dev/null; then
        STATIC_URL=$(grep "NGROK_STATIC_URL=" "/workspace/.env.ngrok" 2>/dev/null | cut -d'=' -f2 | tr -d ' "')
        if [ ! -z "$STATIC_URL" ]; then
            echo "   🔗 Static URL: https://$STATIC_URL"
        fi
    fi
else
    echo "❌ Ngrok Environment: Missing"
fi

if [ -f "/workspace/.env.production" ]; then
    echo "✅ Production Environment: Present"
else
    echo "❌ Production Environment: Missing"
fi

# Check current URL
echo ""
echo "🌍 Current Access:"
if [ -f "/workspace/current_ngrok_url.txt" ]; then
    URL=$(cat "/workspace/current_ngrok_url.txt" 2>/dev/null)
    if [ ! -z "$URL" ]; then
        echo "   🌐 Ngrok URL: $URL"
    else
        echo "   🟡 Ngrok URL file exists but is empty"
    fi
else
    echo "   ❌ No current ngrok URL available"
fi

echo "   🏠 Local URL: http://localhost:80"

# Check logs
echo ""
echo "📝 Recent Activity:"
if systemctl is-active noctispro-complete >/dev/null 2>&1; then
    echo "   Last 3 log entries:"
    journalctl -u noctispro-complete -n 3 --no-pager --output=short-iso 2>/dev/null | sed 's/^/      /'
else
    echo "   Service not running - no active logs"
fi

# Show useful commands
echo ""
echo "🔧 Useful Commands:"
echo "   Start service:     sudo systemctl start noctispro-complete"
echo "   Stop service:      sudo systemctl stop noctispro-complete" 
echo "   Restart service:   sudo systemctl restart noctispro-complete"
echo "   View live logs:    sudo journalctl -u noctispro-complete -f"
echo "   Check full status: sudo systemctl status noctispro-complete"
echo ""

# Final summary
echo "📋 Summary:"
if systemctl is-enabled noctispro-complete >/dev/null 2>&1; then
    echo "✅ Autostart is configured and will run on boot"
    if systemctl is-active noctispro-complete >/dev/null 2>&1; then
        echo "✅ System is currently running"
    else
        echo "🟡 System configured but not currently running"
        echo "   Run: sudo systemctl start noctispro-complete"
    fi
else
    echo "❌ Autostart is NOT configured"
    echo "   Run: sudo ./quick_autostart_setup.sh"
fi