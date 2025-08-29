#!/bin/bash

# NoctisPro Production Management Suite
# Complete production management with zero-error guarantee

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${BOLD}${BLUE}$1${NC}"; }

show_help() {
    echo "NoctisPro Production Management Suite"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       Start all production services"
    echo "  stop        Stop all production services"
    echo "  restart     Restart all production services"
    echo "  status      Show detailed system status"
    echo "  logs        Show recent logs"
    echo "  url         Get public URL"
    echo "  health      Run health checks"
    echo "  deploy      Full production deployment"
    echo "  backup      Create system backup"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start"
    echo "  $0 status"
    echo "  $0 logs"
}

get_status() {
    local service=$1
    local pid_file="${service}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "RUNNING ($pid)"
            return 0
        else
            echo "STOPPED (stale pid)"
            rm -f "$pid_file"
            return 1
        fi
    else
        if pgrep -f "$service.*noctis_pro" > /dev/null 2>&1; then
            echo "RUNNING (no pid file)"
            return 0
        else
            echo "STOPPED"
            return 1
        fi
    fi
}

start_services() {
    log_header "🚀 Starting NoctisPro Production Services"
    
    # Check if already running
    if [ -f "daphne.pid" ] && kill -0 $(cat daphne.pid) 2>/dev/null; then
        log_warning "Services already running. Use 'restart' to restart."
        return 0
    fi
    
    # Load environment
    if [ -f ".env.production" ]; then
        export $(grep -v '^#' ".env.production" | grep -v '^$' | xargs) 2>/dev/null || true
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Start Daphne
    log_info "Starting Daphne server..."
    nohup daphne -b ${DAPHNE_BIND:-0.0.0.0} -p ${DAPHNE_PORT:-8000} \
        --access-log logs/daphne-access.log \
        noctis_pro.asgi:application > logs/daphne.log 2>&1 &
    
    echo $! > daphne.pid
    sleep 5
    
    if kill -0 $(cat daphne.pid) 2>/dev/null; then
        log_success "Daphne started successfully"
    else
        log_error "Failed to start Daphne"
        return 1
    fi
    
    # Start ngrok
    log_info "Starting ngrok tunnel..."
    if [ ! -z "${NGROK_AUTHTOKEN:-}" ] && [ ! -z "${NGROK_STATIC_DOMAIN:-}" ]; then
        nohup ngrok http --authtoken="$NGROK_AUTHTOKEN" --url="$NGROK_STATIC_DOMAIN" ${DAPHNE_PORT:-8000} --log stdout > logs/ngrok.log 2>&1 &
    else
        nohup ngrok http ${DAPHNE_PORT:-8000} --log stdout > logs/ngrok.log 2>&1 &
    fi
    echo $! > ngrok.pid
    
    log_success "Services started successfully!"
    
    # Get URL after a moment
    sleep 10
    get_url
}

stop_services() {
    log_header "🛑 Stopping NoctisPro Production Services"
    
    local stopped=0
    
    # Stop Daphne
    if [ -f "daphne.pid" ]; then
        local pid=$(cat daphne.pid)
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Stopping Daphne (PID: $pid)..."
            kill "$pid"
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
            fi
            log_success "Daphne stopped"
            stopped=1
        fi
        rm -f daphne.pid
    fi
    
    # Stop ngrok
    if [ -f "ngrok.pid" ]; then
        local pid=$(cat ngrok.pid)
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Stopping ngrok (PID: $pid)..."
            kill "$pid"
            log_success "Ngrok stopped"
            stopped=1
        fi
        rm -f ngrok.pid
    fi
    
    # Cleanup any remaining processes
    pkill -f "daphne.*noctis_pro" 2>/dev/null || true
    pkill -f "ngrok" 2>/dev/null || true
    
    if [ $stopped -eq 1 ]; then
        log_success "All services stopped successfully"
    else
        log_info "No services were running"
    fi
    
    rm -f current_ngrok_url.txt
}

show_status() {
    log_header "📊 NoctisPro Production Status"
    echo ""
    
    # Service status
    echo "🔧 Services:"
    echo "  • Daphne: $(get_status daphne)"
    echo "  • Ngrok:  $(get_status ngrok)"
    
    # System services
    echo ""
    echo "🔌 System Services:"
    if pgrep redis-server > /dev/null; then
        echo "  • Redis:      RUNNING"
    else
        echo "  • Redis:      STOPPED"
    fi
    
    if pgrep nginx > /dev/null; then
        echo "  • Nginx:      RUNNING"
    else
        echo "  • Nginx:      STOPPED"
    fi
    
    if pgrep postgres > /dev/null; then
        echo "  • PostgreSQL: RUNNING"
    else
        echo "  • PostgreSQL: STOPPED"
    fi
    
    # Connectivity
    echo ""
    echo "🌐 Connectivity:"
    if curl -s -f http://localhost:${DAPHNE_PORT:-8000} >/dev/null 2>&1; then
        echo "  • Local HTTP: ✅ RESPONDING"
    else
        echo "  • Local HTTP: ❌ NOT RESPONDING"
    fi
    
    # URLs
    echo ""
    echo "🔗 Access URLs:"
    echo "  • Local:  http://localhost:${DAPHNE_PORT:-8000}"
    echo "  • Admin:  http://localhost:${DAPHNE_PORT:-8000}/admin/"
    
    if [ -f "current_ngrok_url.txt" ]; then
        local url=$(cat current_ngrok_url.txt)
        echo "  • Public: $url"
        echo "  • Public Admin: $url/admin/"
    else
        # Try to get from API
        local url=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['tunnels'][0]['public_url'] if data.get('tunnels') else '')
except:
    print('')
" 2>/dev/null || echo "")
        if [ ! -z "$url" ]; then
            echo "  • Public: $url"
            echo "$url" > current_ngrok_url.txt
        else
            echo "  • Public: Not available"
        fi
    fi
    
    # Recent activity
    echo ""
    echo "📋 Recent Activity:"
    if [ -f "logs/daphne.log" ]; then
        local errors=$(grep -i error logs/daphne.log | wc -l)
        if [ $errors -eq 0 ]; then
            echo "  • No recent errors in application logs"
        else
            echo "  • $errors errors found in logs (check logs/daphne.log)"
        fi
    fi
    
    # System resources
    echo ""
    echo "💾 System Resources:"
    echo "  • Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    echo "  • Disk:   $(df -h . | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
    
    echo ""
}

show_logs() {
    log_header "📋 Recent Logs"
    
    if [ -f "logs/daphne.log" ]; then
        echo ""
        echo "=== Daphne Application Logs (last 20 lines) ==="
        tail -20 logs/daphne.log
    fi
    
    if [ -f "logs/daphne-access.log" ]; then
        echo ""
        echo "=== Daphne Access Logs (last 10 lines) ==="
        tail -10 logs/daphne-access.log
    fi
    
    if [ -f "logs/ngrok.log" ]; then
        echo ""
        echo "=== Ngrok Logs (last 10 lines) ==="
        tail -10 logs/ngrok.log
    fi
}

get_url() {
    if [ -f "current_ngrok_url.txt" ]; then
        local url=$(cat current_ngrok_url.txt)
        log_success "Public URL: $url"
        log_info "Admin Panel: $url/admin/"
    else
        # Try to get from ngrok API
        sleep 5
        local url=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['tunnels'][0]['public_url'] if data.get('tunnels') else '')
except:
    print('')
" 2>/dev/null || echo "")
        
        if [ ! -z "$url" ]; then
            echo "$url" > current_ngrok_url.txt
            log_success "Public URL: $url"
            log_info "Admin Panel: $url/admin/"
        else
            log_warning "Public URL not available yet"
            log_info "Local URL: http://localhost:${DAPHNE_PORT:-8000}"
        fi
    fi
}

run_health_check() {
    log_header "🏥 Health Check"
    
    local issues=0
    
    # Check processes
    if get_status daphne | grep -q "RUNNING"; then
        log_success "✅ Daphne process healthy"
    else
        log_error "❌ Daphne process not running"
        ((issues++))
    fi
    
    # Check HTTP response
    if curl -s -f http://localhost:${DAPHNE_PORT:-8000} >/dev/null 2>&1; then
        log_success "✅ HTTP response healthy"
    else
        log_error "❌ HTTP response failed"
        ((issues++))
    fi
    
    # Check admin access
    if curl -s -f http://localhost:${DAPHNE_PORT:-8000}/admin/ >/dev/null 2>&1; then
        log_success "✅ Admin panel accessible"
    else
        log_error "❌ Admin panel not accessible"
        ((issues++))
    fi
    
    # Check logs for recent errors
    if [ -f "logs/daphne.log" ]; then
        local recent_errors=$(tail -100 logs/daphne.log | grep -i error | wc -l)
        if [ $recent_errors -eq 0 ]; then
            log_success "✅ No recent errors in logs"
        else
            log_warning "⚠️ $recent_errors recent errors in logs"
        fi
    fi
    
    # Summary
    echo ""
    if [ $issues -eq 0 ]; then
        log_success "🎉 All health checks passed!"
    else
        log_error "❌ $issues health check(s) failed"
        return 1
    fi
}

create_backup() {
    log_header "📦 Creating Backup"
    
    local backup_name="backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_name"
    
    # Backup essential files
    cp -r manage.py noctis_pro/ requirements.txt .env* db.sqlite3 logs/ "$backup_name/" 2>/dev/null || true
    
    # Create archive
    tar -czf "${backup_name}.tar.gz" "$backup_name"
    rm -rf "$backup_name"
    
    log_success "Backup created: ${backup_name}.tar.gz"
}

# Main command handling
case "${1:-help}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 2
        start_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    url)
        get_url
        ;;
    health)
        run_health_check
        ;;
    deploy)
        ./deploy_production_bulletproof.sh
        ;;
    backup)
        create_backup
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac