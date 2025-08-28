#!/bin/bash

# NoctisPro Production Status Checker
# Quick status check for all components

SERVICE_NAME="noctispro-production-startup"
WORKSPACE_DIR="/workspace"

echo "🔍 NoctisPro Production Status Check"
echo "====================================="
echo ""

# Function to check service status
check_service() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        echo "✅ $service: Running"
        return 0
    else
        echo "❌ $service: Stopped"
        return 1
    fi
}

# Function to check port
check_port() {
    local port="$1"
    local description="$2"
    if netstat -tuln | grep -q ":$port "; then
        echo "✅ $description (port $port): Listening"
        return 0
    else
        echo "❌ $description (port $port): Not listening"
        return 1
    fi
}

# Function to check HTTP endpoint
check_http() {
    local url="$1"
    local description="$2"
    if curl -s -f "$url" >/dev/null 2>&1; then
        echo "✅ $description: Responding"
        return 0
    else
        echo "❌ $description: Not responding"
        return 1
    fi
}

echo "🔧 System Services:"
echo "==================="
check_service "postgresql"
check_service "redis-server"
check_service "$SERVICE_NAME"
echo ""

echo "🌐 Network Services:"
echo "===================="
check_port "5432" "PostgreSQL"
check_port "6379" "Redis"
check_port "8000" "Django"
check_port "4040" "Ngrok Web UI"
echo ""

echo "🌍 HTTP Endpoints:"
echo "=================="
check_http "http://localhost:8000" "Django Application"
check_http "http://localhost:4040" "Ngrok Web Interface"
echo ""

echo "📊 Service Details:"
echo "==================="
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Service Status:"
    systemctl status "$SERVICE_NAME" --no-pager -l | head -10
    echo ""
    
    echo "Recent Logs:"
    journalctl -u "$SERVICE_NAME" --no-pager -l --since "5 minutes ago" | tail -10
    echo ""
fi

echo "🔗 Ngrok Tunnel Information:"
echo "============================="

# Try to get ngrok tunnel info
if curl -s http://localhost:4040/api/tunnels >/dev/null 2>&1; then
    NGROK_INFO=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    tunnels = data.get('tunnels', [])
    if tunnels:
        for tunnel in tunnels:
            print(f\"  Protocol: {tunnel.get('proto', 'unknown')}\")
            print(f\"  Public URL: {tunnel.get('public_url', 'unknown')}\")
            print(f\"  Local URL: {tunnel.get('config', {}).get('addr', 'unknown')}\")
            print(f\"  Region: {tunnel.get('region', 'unknown')}\")
            print()
    else:
        print('  No active tunnels found')
except Exception as e:
    print(f'  Error parsing tunnel data: {e}')
" 2>/dev/null)
    
    if [ ! -z "$NGROK_INFO" ]; then
        echo "$NGROK_INFO"
    else
        echo "  Unable to retrieve tunnel information"
    fi
else
    echo "  Ngrok Web UI not accessible"
fi

echo ""

echo "📂 Log Files:"
echo "============="
echo "System Service Logs:"
echo "  View: sudo journalctl -u $SERVICE_NAME -f"
echo ""

if [ -f "$WORKSPACE_DIR/noctispro_production.log" ]; then
    echo "Application Logs (last 5 lines):"
    tail -5 "$WORKSPACE_DIR/noctispro_production.log" | sed 's/^/  /'
    echo "  Full log: $WORKSPACE_DIR/noctispro_production.log"
fi

if [ -f "$WORKSPACE_DIR/django_production.log" ]; then
    echo ""
    echo "Django Logs (last 3 lines):"
    tail -3 "$WORKSPACE_DIR/django_production.log" | sed 's/^/  /'
    echo "  Full log: $WORKSPACE_DIR/django_production.log"
fi

if [ -f "$WORKSPACE_DIR/ngrok_production.log" ]; then
    echo ""
    echo "Ngrok Logs (last 3 lines):"
    tail -3 "$WORKSPACE_DIR/ngrok_production.log" | sed 's/^/  /'
    echo "  Full log: $WORKSPACE_DIR/ngrok_production.log"
fi

echo ""

echo "⚙️  Quick Actions:"
echo "=================="
echo "Start service:    sudo systemctl start $SERVICE_NAME"
echo "Stop service:     sudo systemctl stop $SERVICE_NAME"
echo "Restart service:  sudo systemctl restart $SERVICE_NAME"
echo "View logs:        sudo journalctl -u $SERVICE_NAME -f"
echo "Check config:     cat $WORKSPACE_DIR/.env.ngrok"
echo ""

# Overall health assessment
echo "📈 Overall Health:"
echo "=================="

healthy=true

# Check critical services
for service in postgresql redis-server "$SERVICE_NAME"; do
    if ! systemctl is-active --quiet "$service"; then
        healthy=false
        break
    fi
done

# Check critical ports
for port in 5432 6379 8000; do
    if ! netstat -tuln | grep -q ":$port "; then
        healthy=false
        break
    fi
done

if $healthy; then
    echo "🟢 System is healthy and running normally"
else
    echo "🔴 System has issues that need attention"
fi

echo ""
echo "Status check completed at $(date)"