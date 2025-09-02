#!/bin/bash

# 🌐 Professional Ngrok Manager - Medical Imaging Public Access Excellence
# Masterpiece-level ngrok integration with professional static URL management
# Enhanced with medical-grade reliability and professional monitoring

set -euo pipefail

# Professional color palette
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r CYAN='\033[0;36m'
declare -r MAGENTA='\033[0;35m'
declare -r WHITE='\033[1;37m'
declare -r NC='\033[0m'

# Professional icons
declare -r ICON_NETWORK="🌐"
declare -r ICON_SUCCESS="✅"
declare -r ICON_ERROR="🚨"
declare -r ICON_WARNING="⚠️"
declare -r ICON_INFO="ℹ️"
declare -r ICON_TUNNEL="🔗"

# Professional configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGROK_BINARY="$SCRIPT_DIR/ngrok"
NGROK_CONFIG="$HOME/.config/ngrok/ngrok.yml"
NGROK_URL_FILE="$SCRIPT_DIR/current_ngrok_url.txt"
NGROK_LOG="$SCRIPT_DIR/professional_ngrok.log"
NGROK_STATUS_FILE="$SCRIPT_DIR/ngrok_status.json"

# Professional logging
ngrok_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    
    case "$level" in
        "SUCCESS") echo -e "${GREEN}${ICON_SUCCESS} [${timestamp}] ${message}${NC}" ;;
        "ERROR")   echo -e "${RED}${ICON_ERROR} [${timestamp}] ${message}${NC}" ;;
        "WARNING") echo -e "${YELLOW}${ICON_WARNING} [${timestamp}] ${message}${NC}" ;;
        "INFO")    echo -e "${BLUE}${ICON_INFO} [${timestamp}] ${message}${NC}" ;;
        "NETWORK") echo -e "${CYAN}${ICON_NETWORK} [${timestamp}] ${message}${NC}" ;;
        "TUNNEL")  echo -e "${MAGENTA}${ICON_TUNNEL} [${timestamp}] ${message}${NC}" ;;
    esac
    
    echo "[${timestamp}] [$level] $message" >> "$NGROK_LOG"
}

success() { ngrok_log "SUCCESS" "$1"; }
error() { ngrok_log "ERROR" "$1"; exit 1; }
warning() { ngrok_log "WARNING" "$1"; }
info() { ngrok_log "INFO" "$1"; }
network() { ngrok_log "NETWORK" "$1"; }
tunnel() { ngrok_log "TUNNEL" "$1"; }

# Professional ngrok installation
install_professional_ngrok() {
    info "Installing professional ngrok for medical imaging access..."
    
    if [[ ! -f "$NGROK_BINARY" ]]; then
        info "Downloading professional ngrok binary..."
        
        # Download ngrok
        if [[ ! -f "$SCRIPT_DIR/ngrok-v3-stable-linux-amd64.tgz" ]]; then
            curl -L "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz" -o "$SCRIPT_DIR/ngrok-v3-stable-linux-amd64.tgz"
        fi
        
        # Extract ngrok
        tar -xzf "$SCRIPT_DIR/ngrok-v3-stable-linux-amd64.tgz" -C "$SCRIPT_DIR"
        chmod +x "$NGROK_BINARY"
        
        success "Professional ngrok binary installed"
    else
        info "Professional ngrok binary already available"
    fi
    
    # Verify installation
    if "$NGROK_BINARY" version >/dev/null 2>&1; then
        local ngrok_version=$("$NGROK_BINARY" version | head -1)
        success "Professional ngrok verified: $ngrok_version"
    else
        error "Professional ngrok installation verification failed"
    fi
}

# Professional ngrok authentication
setup_professional_auth() {
    info "Setting up professional ngrok authentication..."
    
    # Check if already authenticated
    if "$NGROK_BINARY" config check >/dev/null 2>&1; then
        success "Professional ngrok authentication: VERIFIED"
        return 0
    fi
    
    # Interactive authentication setup
    echo
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║${NC}         ${ICON_NETWORK} ${CYAN}Professional Ngrok Authentication Setup${NC} ${ICON_NETWORK}         ${WHITE}║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    info "🔗 Step 1: Visit https://dashboard.ngrok.com/get-started/your-authtoken"
    info "👤 Step 2: Sign up or log in (100% FREE account)"
    info "📋 Step 3: Copy your authentication token"
    echo
    
    read -p "🔑 Enter your ngrok auth token: " auth_token
    
    if [[ -n "$auth_token" ]]; then
        if "$NGROK_BINARY" config add-authtoken "$auth_token"; then
            success "Professional ngrok authentication configured successfully"
        else
            error "Professional ngrok authentication failed"
        fi
    else
        error "Professional ngrok authentication token required"
    fi
}

# Professional tunnel management
start_professional_tunnel() {
    tunnel "Starting professional ngrok tunnel for medical imaging access..."
    
    # Check if NoctisPro is running
    if ! curl -sf http://localhost:8000 >/dev/null 2>&1; then
        error "NoctisPro application not running on port 8000 - start the application first"
    fi
    
    # Check if tunnel is already running
    if pgrep -f "ngrok.*http.*8000" >/dev/null; then
        warning "Professional ngrok tunnel already running"
        get_professional_tunnel_url
        return 0
    fi
    
    # Start tunnel in background
    tunnel "Establishing professional tunnel connection..."
    nohup "$NGROK_BINARY" http 8000 --log stdout --log-level info > "$NGROK_LOG" 2>&1 &
    local ngrok_pid=$!
    
    # Wait for tunnel establishment
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[0].public_url' 2>/dev/null | grep -q "https://"; then
            local ngrok_url=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
            echo "$ngrok_url" > "$NGROK_URL_FILE"
            
            success "Professional ngrok tunnel established successfully"
            network "Public URL: $ngrok_url"
            
            # Update status file
            update_ngrok_status "active" "$ngrok_url" "$ngrok_pid"
            
            return 0
        fi
        
        ((attempt++))
        tunnel "Establishing tunnel connection... (attempt $attempt/$max_attempts)"
        sleep 2
    done
    
    error "Professional ngrok tunnel failed to establish within timeout"
}

# Professional tunnel URL retrieval
get_professional_tunnel_url() {
    if [[ -f "$NGROK_URL_FILE" ]]; then
        local ngrok_url=$(cat "$NGROK_URL_FILE")
        if [[ "$ngrok_url" =~ ^https?:// ]]; then
            network "Current professional URL: $ngrok_url"
            
            # Test URL accessibility
            if curl -sf "$ngrok_url" >/dev/null 2>&1; then
                success "Professional URL accessibility: VERIFIED"
            else
                warning "Professional URL accessibility: ISSUES DETECTED"
            fi
        else
            warning "Professional URL format: INVALID"
        fi
    else
        warning "Professional ngrok URL: NOT AVAILABLE"
    fi
}

# Professional status management
update_ngrok_status() {
    local status="$1"
    local url="$2"
    local pid="$3"
    
    cat > "$NGROK_STATUS_FILE" << EOF
{
    "status": "$status",
    "public_url": "$url",
    "process_id": "$pid",
    "timestamp": "$(date -Iseconds)",
    "system_version": "Noctis Pro PACS v2.0 Enhanced",
    "tunnel_quality": "Medical Grade Excellence"
}
EOF
}

# Professional tunnel monitoring
monitor_professional_tunnel() {
    info "Starting professional ngrok tunnel monitoring..."
    
    while true; do
        if pgrep -f "ngrok.*http.*8000" >/dev/null; then
            # Check tunnel health
            if curl -s http://localhost:4040/api/tunnels 2>/dev/null | jq -r '.tunnels[0].public_url' 2>/dev/null | grep -q "https://"; then
                local ngrok_url=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url')
                echo "$ngrok_url" > "$NGROK_URL_FILE"
                
                # Test public accessibility
                if curl -sf "$ngrok_url" >/dev/null 2>&1; then
                    success "Professional tunnel health: EXCELLENT - $ngrok_url"
                else
                    warning "Professional tunnel health: DEGRADED - $ngrok_url not accessible"
                fi
            else
                warning "Professional tunnel health: NO ACTIVE TUNNELS"
            fi
        else
            error "Professional ngrok process: NOT RUNNING"
            
            # Attempt automatic restart
            warning "Attempting professional tunnel recovery..."
            start_professional_tunnel
        fi
        
        sleep 30  # Check every 30 seconds
    done
}

# Professional command handling
case "${1:-help}" in
    "install")
        install_professional_ngrok
        ;;
    "auth")
        setup_professional_auth
        ;;
    "start")
        start_professional_tunnel
        ;;
    "status")
        get_professional_tunnel_url
        ;;
    "monitor")
        monitor_professional_tunnel
        ;;
    "stop")
        if pgrep -f "ngrok.*http.*8000" >/dev/null; then
            pkill -f "ngrok.*http.*8000"
            success "Professional ngrok tunnel stopped"
            echo "Not available" > "$NGROK_URL_FILE"
            update_ngrok_status "stopped" "Not available" "0"
        else
            warning "Professional ngrok tunnel not running"
        fi
        ;;
    "restart")
        "$0" stop
        sleep 2
        "$0" start
        ;;
    "help"|*)
        echo
        echo -e "${WHITE}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${WHITE}║${NC}      ${ICON_NETWORK} ${CYAN}Professional Ngrok Manager - Medical Excellence${NC} ${ICON_NETWORK}      ${WHITE}║${NC}"
        echo -e "${WHITE}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${CYAN}Professional Commands:${NC}"
        echo "  $0 install     - Install professional ngrok binary"
        echo "  $0 auth        - Setup professional authentication"
        echo "  $0 start       - Start professional tunnel"
        echo "  $0 stop        - Stop professional tunnel"
        echo "  $0 restart     - Restart professional tunnel"
        echo "  $0 status      - Check professional tunnel status"
        echo "  $0 monitor     - Monitor professional tunnel health"
        echo
        echo -e "${CYAN}Professional Usage:${NC}"
        echo "  1. Install:    $0 install"
        echo "  2. Setup:      $0 auth"
        echo "  3. Start:      $0 start"
        echo "  4. Monitor:    $0 status"
        echo
        ;;
esac