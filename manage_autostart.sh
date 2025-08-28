#!/bin/bash

# NoctisPro Autostart Management Script
# Manages the autostart service for container environments

WORKSPACE_DIR="/workspace"
AUTOSTART_SCRIPT="$WORKSPACE_DIR/autostart_noctispro.sh"
PID_FILE="$WORKSPACE_DIR/autostart_noctispro.pid"
LOG_FILE="$WORKSPACE_DIR/autostart_noctispro.log"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to check if service is running
is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"  # Clean up stale PID file
            return 1
        fi
    fi
    return 1
}

# Function to get service status
get_status() {
    print_status "🔍 Checking NoctisPro Autostart Service Status"
    echo "=================================================="
    
    if is_running; then
        local pid=$(cat "$PID_FILE")
        print_success "Autostart service is running (PID: $pid)"
        
        # Check Django
        if pgrep -f "daphne.*noctis_pro" > /dev/null; then
            print_success "Django server is running"
        else
            print_error "Django server is not running"
        fi
        
        # Check ngrok
        if pgrep -f "ngrok" > /dev/null; then
            print_success "Ngrok tunnel is running"
            if [ -f "$WORKSPACE_DIR/current_ngrok_url.txt" ]; then
                local url=$(cat "$WORKSPACE_DIR/current_ngrok_url.txt")
                echo "   🌍 URL: $url"
            fi
        else
            if [ -f "$WORKSPACE_DIR/current_ngrok_url.txt" ]; then
                local url=$(cat "$WORKSPACE_DIR/current_ngrok_url.txt")
                if [[ "$url" == "http://localhost:8000" ]]; then
                    print_warning "Running in local mode (no external tunnel)"
                    echo "   🏠 Local URL: $url"
                    echo "   ℹ️  To enable external access, configure ngrok authentication"
                else
                    print_error "Ngrok tunnel is not running"
                fi
            else
                print_error "Ngrok tunnel is not running"
            fi
        fi
        
        # Show recent log entries
        echo ""
        print_status "📋 Recent log entries:"
        if [ -f "$LOG_FILE" ]; then
            tail -5 "$LOG_FILE" | while IFS= read -r line; do
                echo "   $line"
            done
        else
            echo "   No log file found"
        fi
        
    else
        print_error "Autostart service is not running"
    fi
    
    echo ""
    echo "🔧 Management Commands:"
    echo "   Start:   ./manage_autostart.sh start"
    echo "   Stop:    ./manage_autostart.sh stop"
    echo "   Restart: ./manage_autostart.sh restart"
    echo "   Status:  ./manage_autostart.sh status"
    echo "   Logs:    ./manage_autostart.sh logs"
}

# Function to start the service
start_service() {
    print_status "🚀 Starting NoctisPro Autostart Service"
    
    if is_running; then
        print_warning "Service is already running"
        return 0
    fi
    
    # Start the service in background
    nohup "$AUTOSTART_SCRIPT" > /dev/null 2>&1 &
    
    # Wait a moment and check if it started
    sleep 3
    if is_running; then
        print_success "Autostart service started successfully"
        print_status "🌍 Your static URL: https://colt-charmed-lark.ngrok-free.app"
        print_status "📊 Use './manage_autostart.sh status' to monitor progress"
    else
        print_error "Failed to start autostart service"
        return 1
    fi
}

# Function to stop the service
stop_service() {
    print_status "🛑 Stopping NoctisPro Autostart Service"
    
    if ! is_running; then
        print_warning "Service is not running"
        return 0
    fi
    
    local pid=$(cat "$PID_FILE")
    
    # Send SIGTERM to allow graceful shutdown
    print_status "Sending termination signal to PID $pid"
    kill "$pid" 2>/dev/null || true
    
    # Wait for graceful shutdown
    local attempts=0
    while [ $attempts -lt 30 ] && kill -0 "$pid" 2>/dev/null; do
        sleep 1
        attempts=$((attempts + 1))
    done
    
    # Force kill if needed
    if kill -0 "$pid" 2>/dev/null; then
        print_warning "Graceful shutdown failed, force killing..."
        kill -9 "$pid" 2>/dev/null || true
        sleep 2
    fi
    
    # Clean up processes
    pkill -f "ngrok" 2>/dev/null || true
    pkill -f "daphne.*noctis_pro" 2>/dev/null || true
    
    # Remove PID file
    rm -f "$PID_FILE"
    
    print_success "Autostart service stopped"
}

# Function to restart the service
restart_service() {
    print_status "🔄 Restarting NoctisPro Autostart Service"
    stop_service
    sleep 2
    start_service
}

# Function to show logs
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        print_status "📋 Showing autostart service logs (press Ctrl+C to exit)"
        tail -f "$LOG_FILE"
    else
        print_error "Log file not found: $LOG_FILE"
    fi
}

# Function to enable automatic startup
enable_autostart() {
    print_status "🔧 Setting up automatic startup"
    
    # Create a simple startup script for container environments
    cat > "$WORKSPACE_DIR/start_on_boot.sh" << 'EOF'
#!/bin/bash
# Simple startup script for container environments
cd /workspace
sleep 10  # Wait for system to be ready
./manage_autostart.sh start
EOF
    
    chmod +x "$WORKSPACE_DIR/start_on_boot.sh"
    
    print_success "Automatic startup configured"
    print_status "💡 For container environments, ensure this runs on container start"
    print_status "💡 You can call './start_on_boot.sh' from your container's entrypoint"
}

# Main script logic
case "${1:-status}" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    status)
        get_status
        ;;
    logs)
        show_logs
        ;;
    enable-autostart)
        enable_autostart
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|enable-autostart}"
        echo ""
        echo "Commands:"
        echo "  start            - Start the autostart service"
        echo "  stop             - Stop the autostart service"
        echo "  restart          - Restart the autostart service"
        echo "  status           - Show service status (default)"
        echo "  logs             - Show live logs"
        echo "  enable-autostart - Set up automatic startup"
        exit 1
        ;;
esac