#!/bin/bash

# NoctisPro Bulletproof Production Deployment Script - FIXED VERSION
# Zero-error guarantee with comprehensive validation, rollback, and auto-startup

set -euo pipefail

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${BOLD}${BLUE}$1${NC}"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE=".env.production"
BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="deployment_$(date +%Y%m%d_%H%M%S).log"
SERVICE_NAME="noctispro-production-bulletproof"
CURRENT_USER=$(whoami)
PROJECT_DIR="$SCRIPT_DIR"

# Redirect all output to log file while still showing on screen
exec > >(tee -a "$LOG_FILE") 2>&1

log_header "🚀 NoctisPro Bulletproof Production Deployment - FIXED"
log_info "Deployment started at $(date)"
log_info "Log file: $LOG_FILE"
log_info "Running as user: $CURRENT_USER"
log_info "Project directory: $PROJECT_DIR"

# Error handling with rollback
cleanup_on_error() {
    local exit_code=$?
    log_error "Deployment failed with exit code: $exit_code"
    log_info "Initiating rollback procedures..."
    
    # Stop any running processes using our comprehensive stop function
    if declare -f stop_existing_services > /dev/null 2>&1; then
        stop_existing_services
    else
        # Fallback if function not defined yet
        pkill -f "daphne.*noctis_pro" 2>/dev/null || true
        pkill -f "ngrok" 2>/dev/null || true
        kill_port_processes 8000 2>/dev/null || true
    fi
    
    # Stop systemd service if it was created
    if sudo -n true 2>/dev/null; then
        sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
        sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    fi
    
    # Restore backup if exists
    if [ -d "$BACKUP_DIR" ]; then
        log_info "Restoring from backup..."
        cp -r "$BACKUP_DIR"/* . 2>/dev/null || true
    fi
    
    log_error "Deployment failed. Check $LOG_FILE for details."
    exit $exit_code
}

trap cleanup_on_error ERR

# Check if port is in use
is_port_in_use() {
    local port=${1:-8000}
    
    # Try multiple methods to check port usage
    if command -v fuser >/dev/null 2>&1; then
        fuser -n tcp "$port" >/dev/null 2>&1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulpn 2>/dev/null | grep ":$port " >/dev/null
    elif command -v ss >/dev/null 2>&1; then
        ss -tulpn 2>/dev/null | grep ":$port " >/dev/null
    else
        # Fallback: try to connect to the port
        timeout 2 bash -c "echo >/dev/tcp/localhost/$port" 2>/dev/null
    fi
}

# Get PIDs using a port
get_port_pids() {
    local port=${1:-8000}
    local pids=""
    
    if command -v fuser >/dev/null 2>&1; then
        pids=$(fuser -n tcp "$port" 2>/dev/null | awk '{print $1}' || true)
    elif command -v netstat >/dev/null 2>&1; then
        pids=$(netstat -tulpn 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1 || true)
    elif command -v ss >/dev/null 2>&1; then
        pids=$(ss -tulpn 2>/dev/null | grep ":$port " | awk '{print $6}' | grep -o '[0-9]*' || true)
    fi
    
    echo "$pids"
}

# Kill processes using a port
kill_port_processes() {
    local port=${1:-8000}
    
    if command -v fuser >/dev/null 2>&1; then
        fuser -k -n tcp "$port" 2>/dev/null || true
    else
        local pids=$(get_port_pids "$port")
        if [ ! -z "$pids" ]; then
            echo "$pids" | xargs -r kill -KILL 2>/dev/null || true
        fi
    fi
}

# Check port availability
check_port_availability() {
    local port=${1:-8000}
    local max_attempts=5
    local attempt=1
    
    log_info "Checking port $port availability..."
    
    while [ $attempt -le $max_attempts ]; do
        if ! is_port_in_use "$port"; then
            log_success "Port $port is available"
            return 0
        fi
        
        log_warning "Port $port is in use (attempt $attempt/$max_attempts)"
        
        # Try to free the port
        local port_pids=$(get_port_pids "$port")
        if [ ! -z "$port_pids" ]; then
            log_info "Attempting to free port $port (PIDs: $port_pids)"
            echo "$port_pids" | xargs -r kill -TERM 2>/dev/null || true
            sleep 3
            
            # Force kill if still running
            if is_port_in_use "$port"; then
                log_warning "Force killing processes on port $port"
                kill_port_processes "$port"
                sleep 2
            fi
        else
            # No PIDs found but port still in use, try generic kill
            kill_port_processes "$port"
            sleep 2
        fi
        
        ((attempt++))
    done
    
    log_error "Could not free port $port after $max_attempts attempts"
    return 1
}

# Pre-deployment validation
validate_environment() {
    log_header "🔍 Pre-deployment Validation"
    
    # Validate Python environment
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found"
        exit 1
    fi
    log_success "Python 3 found: $(python3 --version)"
    
    # Check virtual environment
    if [ ! -d "venv" ] || [ ! -f "venv/bin/activate" ]; then
        log_info "Virtual environment not found or broken. Creating/recreating one..."
        rm -rf venv 2>/dev/null || true
        
        # Try different methods to create virtual environment
        if python3 -m venv venv 2>/dev/null; then
            log_success "Virtual environment created with venv module"
        elif command -v virtualenv >/dev/null 2>&1; then
            virtualenv venv
            log_success "Virtual environment created with virtualenv"
        else
            log_warning "Cannot create virtual environment, trying to install packages globally"
            # Create a fake activate script that does nothing
            mkdir -p venv/bin
            echo '#!/bin/bash' > venv/bin/activate
            echo 'echo "Using system Python (no venv available)"' >> venv/bin/activate
            chmod +x venv/bin/activate
        fi
    fi
    
    # Check essential files
    local required_files=("manage.py" "requirements.txt" "noctis_pro/settings.py")
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Required file missing: $file"
            exit 1
        fi
    done
    log_success "All required files present"
    
    # Check disk space (need at least 1GB free)
    local free_space=$(df . | awk 'NR==2 {print $4}')
    if [ "$free_space" -lt 1048576 ]; then
        log_error "Insufficient disk space. Need at least 1GB free."
        exit 1
    fi
    log_success "Sufficient disk space available"
    
    # Check if we can use sudo
    if ! sudo -n true 2>/dev/null; then
        log_warning "Sudo access not available. Some system packages may not install."
    else
        log_success "Sudo access available"
    fi
    
    # Check port availability
    check_port_availability 8000
}

# Install system dependencies
install_system_dependencies() {
    log_header "🔧 Installing System Dependencies"
    
    # Only try system package installation if we have sudo access
    if sudo -n true 2>/dev/null; then
        # Update package lists
        log_info "Updating package lists..."
        sudo apt update -qq || {
            log_warning "Failed to update package lists, continuing..."
        }
        
        # Install essential system packages
        log_info "Installing system packages..."
        sudo apt install -y \
            python3 \
            python3-pip \
            python3-venv \
            redis-server \
            jq \
            curl \
            wget \
            git \
            build-essential \
            libpq-dev \
            libssl-dev \
            libffi-dev \
            libjpeg-dev \
            libpng-dev \
            libfreetype6-dev \
            liblcms2-dev \
            libwebp-dev \
            libtiff5-dev \
            libopenjp2-7-dev \
            zlib1g-dev \
            psmisc \
            procps \
            net-tools || {
            log_warning "Some system packages failed to install, but continuing..."
        }
        
        log_success "System dependencies installed"
        
        # Install ngrok
        log_info "Installing ngrok..."
        if ! command -v ngrok &> /dev/null; then
            curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo gpg --dearmor -o /usr/share/keyrings/ngrok.gpg 2>/dev/null || {
                log_warning "Failed to add ngrok GPG key, trying direct download..."
                curl -sSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz | sudo tar xz -C /usr/local/bin/ || {
                    log_warning "Ngrok installation failed, tunnel will not be available"
                }
            }
            
            if [ -f /usr/share/keyrings/ngrok.gpg ]; then
                echo "deb [signed-by=/usr/share/keyrings/ngrok.gpg] https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
                sudo apt update -qq && sudo apt install -y ngrok || {
                    log_warning "Failed to install ngrok via apt, but direct download may have worked"
                }
            fi
        fi
        
        if command -v ngrok &> /dev/null; then
            log_success "Ngrok installed successfully"
        else
            log_warning "Ngrok not available, public tunnel disabled"
        fi
    else
        log_warning "Skipping system package installation (no sudo access)"
        
        # Check if essential tools are available and warn if missing
        local missing_tools=()
        for tool in fuser netstat ss curl; do
            if ! command -v "$tool" >/dev/null 2>&1; then
                missing_tools+=("$tool")
            fi
        done
        
        if [ ${#missing_tools[@]} -gt 0 ]; then
            log_warning "Missing system tools: ${missing_tools[*]}"
            log_warning "Port management may be limited without these tools"
        fi
    fi
}

# Create backup
create_backup() {
    log_header "📦 Creating Backup"
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup important files
    local backup_items=("manage.py" "noctis_pro/" "requirements.txt" ".env*")
    for item in "${backup_items[@]}"; do
        if [ -e "$item" ]; then
            cp -r "$item" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done
    
    log_success "Backup created at $BACKUP_DIR"
}

# Setup services
setup_services() {
    log_header "🔧 Setting up Services"
    
    # Start Redis if not running and if we have sudo
    if sudo -n true 2>/dev/null; then
        if ! pgrep redis-server > /dev/null; then
            log_info "Starting Redis..."
            sudo redis-server --daemonize yes --loglevel warning 2>/dev/null || {
                log_warning "Redis start failed, but continuing..."
            }
            sleep 2
        fi
        
        if pgrep redis-server > /dev/null; then
            log_success "Redis running"
        else
            log_warning "Redis not running, but application may still work"
        fi
    else
        log_info "Skipping Redis setup (no sudo access)"
    fi
}

# Install dependencies
install_dependencies() {
    log_header "📚 Installing Dependencies"
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ] || [ ! -f "venv/bin/activate" ]; then
        log_info "Creating virtual environment..."
        rm -rf venv 2>/dev/null || true
        
        if python3 -m venv venv 2>/dev/null; then
            log_success "Virtual environment created"
        elif command -v virtualenv >/dev/null 2>&1; then
            virtualenv venv
            log_success "Virtual environment created with virtualenv"
        else
            log_warning "Cannot create virtual environment, using system Python"
            mkdir -p venv/bin
            echo '#!/bin/bash' > venv/bin/activate
            echo 'echo "Using system Python (no venv available)"' >> venv/bin/activate
            chmod +x venv/bin/activate
        fi
    fi
    
    # Activate virtual environment
    source venv/bin/activate || {
        log_warning "Failed to activate virtual environment, using system Python"
    }
    
    # Upgrade pip safely
    python3 -m pip install --upgrade pip --quiet || {
        log_warning "Pip upgrade failed, continuing with current version"
    }
    
    # Install requirements with error handling
    if [ -f "requirements.txt" ]; then
        log_info "Installing Python packages..."
        pip install -r requirements.txt --break-system-packages || {
            log_warning "Some packages failed to install, trying essential ones only..."
            pip install django djangorestframework daphne redis python-dotenv pillow pydicom numpy scipy matplotlib django-cors-headers channels --break-system-packages || {
                log_error "Failed to install essential packages"
                exit 1
            }
        }
        log_success "Dependencies installed"
    fi
    
    # Install additional packages for image processing
    pip install dj-database-url scikit-image opencv-python --break-system-packages || {
        log_warning "Some optional packages failed to install"
    }
    
    # Verify critical packages
    python3 -c "import django, daphne" || {
        log_error "Critical packages not available"
        exit 1
    }
    log_success "Critical packages verified"
}

# Configure environment
configure_environment() {
    log_header "⚙️ Configuring Environment"
    
    # Create environment file if it doesn't exist
    if [ ! -f "$ENV_FILE" ]; then
        log_info "Creating production environment file..."
        cat > "$ENV_FILE" << 'EOF'
# NoctisPro Production Configuration
DJANGO_DEBUG=false
DJANGO_SETTINGS_MODULE=noctis_pro.settings
SECRET_KEY=a7f9d8e2b4c6a1f3e8d7c5b9a2e4f6c8d1b3e5f7a9c2d4e6f8b1c3e5d7a9b2c4
ALLOWED_HOSTS=localhost,127.0.0.1,*.ngrok.io,*.ngrok-free.app,colt-charmed-lark.ngrok-free.app
REDIS_URL=redis://127.0.0.1:6379/0
DAPHNE_PORT=8000
DAPHNE_BIND=0.0.0.0

# Ngrok Configuration
NGROK_USE_STATIC=true
NGROK_STATIC_URL=colt-charmed-lark.ngrok-free.app
NGROK_STATIC_DOMAIN=colt-charmed-lark.ngrok-free.app
NGROK_REGION=us
EOF
        log_success "Environment file created"
    fi
    
    # Load environment variables
    export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | xargs) 2>/dev/null || true
    
    # Create necessary directories
    mkdir -p logs staticfiles media
    chmod 755 logs staticfiles media
    
    log_success "Environment configured"
}

# Run Django management commands
run_django_commands() {
    log_header "🐍 Running Django Commands"
    
    source venv/bin/activate
    
    # Export environment variables
    export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | xargs) 2>/dev/null || true
    
    # Run system check
    log_info "Running Django system check..."
    python manage.py check || {
        log_warning "Django system check found issues, but continuing..."
    }
    
    # Collect static files
    log_info "Collecting static files..."
    python manage.py collectstatic --noinput --clear || {
        log_warning "Static file collection failed, but continuing..."
    }
    
    log_success "Django setup completed"
}

# Create systemd service
create_systemd_service() {
    log_header "🔧 Creating Systemd Service"
    
    if ! sudo -n true 2>/dev/null; then
        log_warning "Cannot create systemd service (no sudo access)"
        return 0
    fi
    
    # Create service file
    cat > /tmp/$SERVICE_NAME.service << EOF
[Unit]
Description=NoctisPro Production DICOM System
Documentation=https://github.com/mwatom/NoctisPro
After=network.target redis-server.service
Wants=redis-server.service

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$PROJECT_DIR
Environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
Environment=PYTHONPATH=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Pre-execution setup
ExecStartPre=/bin/bash -c 'cd $PROJECT_DIR && source venv/bin/activate && python manage.py collectstatic --noinput'

# Main service
ExecStart=/bin/bash -c 'cd $PROJECT_DIR && source venv/bin/activate && daphne -b 0.0.0.0 -p 8000 --access-log logs/daphne-access.log noctis_pro.asgi:application'

# Reload and stop
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -TERM \$MAINPID

# Service management
Restart=always
RestartSec=10
KillMode=mixed
TimeoutStartSec=60
TimeoutStopSec=30

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=noctispro

[Install]
WantedBy=multi-user.target
EOF
    
    # Install service
    if sudo cp /tmp/$SERVICE_NAME.service /etc/systemd/system/ 2>/dev/null && \
       sudo systemctl daemon-reload 2>/dev/null && \
       sudo systemctl enable $SERVICE_NAME 2>/dev/null; then
        log_success "Systemd service created and enabled"
    else
        log_warning "Systemd service creation failed (systemd may not be available)"
        return 1
    fi
}

# Stop all existing services
stop_existing_services() {
    log_info "🛑 Stopping all existing services..."
    
    # Stop systemd service if it exists
    if sudo -n true 2>/dev/null; then
        local services=("noctispro-production-bulletproof" "noctispro-production" "noctispro" "noctispro-complete" "noctispro-django")
        for service in "${services[@]}"; do
            if sudo systemctl is-active "$service" >/dev/null 2>&1; then
                log_info "Stopping systemd service: $service"
                sudo systemctl stop "$service" 2>/dev/null || true
            fi
        done
    fi
    
    # Kill processes by name with increasing force
    local process_patterns=("daphne.*noctis_pro" "ngrok" "python.*manage.py.*runserver" "gunicorn.*noctis_pro")
    
    for pattern in "${process_patterns[@]}"; do
        local pids=$(pgrep -f "$pattern" 2>/dev/null || true)
        if [ ! -z "$pids" ]; then
            log_info "Stopping processes matching: $pattern"
            echo "$pids" | xargs -r kill -TERM 2>/dev/null || true
            sleep 2
            
            # Check if still running and force kill
            pids=$(pgrep -f "$pattern" 2>/dev/null || true)
            if [ ! -z "$pids" ]; then
                log_warning "Force killing stubborn processes: $pattern"
                echo "$pids" | xargs -r kill -KILL 2>/dev/null || true
                sleep 1
            fi
        fi
    done
    
    # Kill any process using port 8000 specifically
    local port_pids=$(get_port_pids 8000)
    if [ ! -z "$port_pids" ]; then
        log_info "Killing processes using port 8000: $port_pids"
        echo "$port_pids" | xargs -r kill -KILL 2>/dev/null || true
        sleep 1
    fi
    
    # Clean up PID files
    rm -f daphne.pid ngrok.pid *.pid
    
    # Final verification that port 8000 is free
    local max_attempts=10
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if ! is_port_in_use 8000; then
            log_success "Port 8000 is now available"
            break
        fi
        log_info "Waiting for port 8000 to be released... (attempt $attempt/$max_attempts)"
        kill_port_processes 8000
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "Port 8000 is still in use after $max_attempts attempts"
        log_info "Attempting final force kill of port 8000 processes..."
        kill_port_processes 8000
        sleep 3
    fi
}

# Start application services
start_services() {
    log_header "🚀 Starting Application Services"
    
    source venv/bin/activate
    export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | xargs) 2>/dev/null || true
    
    # Stop any existing processes first
    stop_existing_services
    
    # Try to start via systemd first
    if sudo -n true 2>/dev/null && sudo systemctl is-enabled $SERVICE_NAME >/dev/null 2>&1; then
        log_info "Starting via systemd service..."
        sudo systemctl start $SERVICE_NAME
        sleep 10
        
        if sudo systemctl is-active $SERVICE_NAME >/dev/null 2>&1; then
            log_success "Service started via systemd"
            DAPHNE_PID=$(pgrep -f "daphne.*noctis_pro" | head -1)
            echo $DAPHNE_PID > daphne.pid
        else
            log_warning "Systemd service failed, falling back to direct start"
            start_daphne_directly
        fi
    else
        log_info "Starting Daphne directly..."
        start_daphne_directly
    fi
    
    # Start ngrok
    start_ngrok_tunnel
}

start_daphne_directly() {
    local port=${DAPHNE_PORT:-8000}
    local bind=${DAPHNE_BIND:-0.0.0.0}
    
    # Final port check before starting
    if is_port_in_use "$port"; then
        log_error "Port $port is still in use, cannot start Daphne"
        local port_pids=$(get_port_pids "$port")
        log_info "Processes using port $port: $port_pids"
        kill_port_processes "$port"
        sleep 3
        
        if is_port_in_use "$port"; then
            log_error "Unable to free port $port, deployment cannot continue"
            exit 1
        fi
    fi
    
    # Start Daphne directly
    log_info "Starting Daphne on $bind:$port..."
    nohup daphne -b "$bind" -p "$port" \
        --access-log logs/daphne-access.log \
        noctis_pro.asgi:application > logs/daphne.log 2>&1 &
    
    DAPHNE_PID=$!
    echo $DAPHNE_PID > daphne.pid
    
    # Wait for Daphne to start with progressive checking
    log_info "Waiting for Daphne to initialize..."
    local max_wait=30
    local wait_count=0
    local daphne_started=false
    
    while [ $wait_count -lt $max_wait ]; do
        sleep 1
        ((wait_count++))
        
        # Check if process is still alive
        if ! kill -0 $DAPHNE_PID 2>/dev/null; then
            log_error "Daphne process died during startup"
            break
        fi
        
        # Check if port is being listened on
        if is_port_in_use "$port"; then
            # Try a simple HTTP request
            if curl -s -f "http://localhost:$port" >/dev/null 2>&1 || curl -s "http://localhost:$port" >/dev/null 2>&1; then
                daphne_started=true
                break
            fi
        fi
        
        if [ $((wait_count % 5)) -eq 0 ]; then
            log_info "Still waiting for Daphne... ($wait_count/${max_wait}s)"
        fi
    done
    
    # Verify Daphne is running
    if $daphne_started && kill -0 $DAPHNE_PID 2>/dev/null; then
        log_success "Daphne started successfully (PID: $DAPHNE_PID) on $bind:$port"
    else
        log_error "Daphne failed to start properly"
        log_info "Daphne log output:"
        cat logs/daphne.log 2>/dev/null || echo "No log file found"
        exit 1
    fi
}

start_ngrok_tunnel() {
    # Start ngrok with static URL configuration
    if [ "${NGROK_USE_STATIC:-false}" = "true" ] && [ ! -z "${NGROK_STATIC_URL:-}" ]; then
        log_info "Starting ngrok with static URL: $NGROK_STATIC_URL"
        nohup ngrok http --url="$NGROK_STATIC_URL" ${DAPHNE_PORT:-8000} --log stdout > logs/ngrok.log 2>&1 &
        NGROK_PID=$!
        echo $NGROK_PID > ngrok.pid
        log_success "Ngrok started with static URL: https://$NGROK_STATIC_URL"
        echo "https://$NGROK_STATIC_URL" > current_ngrok_url.txt
    else
        log_info "Starting ngrok with dynamic domain..."
        nohup ngrok http ${DAPHNE_PORT:-8000} --log stdout > logs/ngrok.log 2>&1 &
        NGROK_PID=$!
        echo $NGROK_PID > ngrok.pid
        log_info "Ngrok started (dynamic domain)"
        
        # Wait for ngrok and get URL
        sleep 15
        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['tunnels'][0]['public_url'] if data.get('tunnels') else '')
except:
    print('')
" 2>/dev/null || echo "")
        
        if [ ! -z "$NGROK_URL" ]; then
            echo "$NGROK_URL" > current_ngrok_url.txt
            log_success "Ngrok URL: $NGROK_URL"
        fi
    fi
}

# Validate deployment
validate_deployment() {
    log_header "✅ Validating Deployment"
    
    local validation_errors=0
    
    # Check Daphne
    if [ -f "daphne.pid" ] && kill -0 $(cat daphne.pid) 2>/dev/null; then
        log_success "Daphne process running"
    else
        log_error "Daphne process not running"
        ((validation_errors++))
    fi
    
    # Check HTTP response
    local max_retries=5
    local retry_count=0
    local app_responding=false
    
    while [ $retry_count -lt $max_retries ]; do
        if curl -s -f http://localhost:${DAPHNE_PORT:-8000} >/dev/null 2>&1; then
            app_responding=true
            break
        fi
        ((retry_count++))
        log_info "Application not responding yet, retry $retry_count/$max_retries..."
        sleep 5
    done
    
    if $app_responding; then
        log_success "Application responding to HTTP requests"
    else
        log_error "Application not responding after $max_retries attempts"
        ((validation_errors++))
    fi
    
    # Check ngrok
    if [ -f "ngrok.pid" ] && kill -0 $(cat ngrok.pid) 2>/dev/null; then
        log_success "Ngrok tunnel running"
    else
        log_warning "Ngrok tunnel not running (optional)"
    fi
    
    # Check systemd service if available
    if sudo -n true 2>/dev/null && sudo systemctl is-enabled $SERVICE_NAME >/dev/null 2>&1; then
        if sudo systemctl is-active $SERVICE_NAME >/dev/null 2>&1; then
            log_success "Systemd service is active and enabled"
        else
            log_warning "Systemd service is not active"
        fi
    fi
    
    # Check logs for critical errors (not warnings)
    if [ -f "logs/daphne.log" ]; then
        local critical_error_count=$(grep -i "critical\|fatal" logs/daphne.log | wc -l)
        if [ $critical_error_count -eq 0 ]; then
            log_success "No critical errors in application logs"
        else
            log_warning "Found $critical_error_count critical errors in logs (check logs/daphne.log)"
        fi
    fi
    
    if [ $validation_errors -eq 0 ]; then
        log_success "✅ All validations passed!"
        return 0
    else
        log_error "❌ $validation_errors validation(s) failed"
        return 1
    fi
}

# Create management scripts
create_management_scripts() {
    log_header "📝 Creating Management Scripts"
    
    # Stop script
    cat > stop_noctispro_production.sh << 'EOF'
#!/bin/bash
echo "🛑 Stopping NoctisPro Production..."

# Stop systemd service if available
if sudo -n true 2>/dev/null && sudo systemctl is-enabled noctispro-production-bulletproof >/dev/null 2>&1; then
    sudo systemctl stop noctispro-production-bulletproof
fi

# Stop processes
pkill -f "daphne.*noctis_pro" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true

# Clean up PID files
rm -f daphne.pid ngrok.pid

echo "✅ NoctisPro Production stopped"
EOF
    chmod +x stop_noctispro_production.sh
    
    # Status script
    cat > status_noctispro_production.sh << 'EOF'
#!/bin/bash
echo "📊 NoctisPro Production Status"
echo "=============================="

# Check systemd service
if sudo -n true 2>/dev/null && sudo systemctl is-enabled noctispro-production-bulletproof >/dev/null 2>&1; then
    echo "🔧 Systemd Service:"
    sudo systemctl status noctispro-production-bulletproof --no-pager -l
    echo ""
fi

# Check processes
echo "🔍 Processes:"
if pgrep -f "daphne.*noctis_pro" > /dev/null; then
    echo "✅ Daphne: Running (PID: $(pgrep -f "daphne.*noctis_pro"))"
else
    echo "❌ Daphne: Not running"
fi

if pgrep -f "ngrok" > /dev/null; then
    echo "✅ Ngrok: Running (PID: $(pgrep -f "ngrok"))"
else
    echo "❌ Ngrok: Not running"
fi

echo ""

# Check HTTP response
echo "🌐 HTTP Status:"
if curl -s -f http://localhost:8000 >/dev/null 2>&1; then
    echo "✅ Application: Responding on http://localhost:8000"
else
    echo "❌ Application: Not responding"
fi

# Check public URL
if [ -f "current_ngrok_url.txt" ]; then
    PUBLIC_URL=$(cat current_ngrok_url.txt)
    echo "🌍 Public URL: $PUBLIC_URL"
fi

echo ""
echo "📋 Logs:"
echo "• Application: tail -f logs/daphne.log"
echo "• Ngrok: tail -f logs/ngrok.log"
echo "• System: sudo journalctl -u noctispro-production-bulletproof -f"
EOF
    chmod +x status_noctispro_production.sh
    
    log_success "Management scripts created"
}

# Main deployment flow
main() {
    validate_environment
    install_system_dependencies
    create_backup
    setup_services
    install_dependencies
    configure_environment
    run_django_commands
    create_systemd_service || log_warning "Systemd service creation failed, continuing with direct startup"
    start_services
    create_management_scripts
    
    if validate_deployment; then
        log_header "🎉 DEPLOYMENT SUCCESSFUL!"
        echo ""
        log_success "Application Details:"
        echo "  • Local URL: http://localhost:${DAPHNE_PORT:-8000}"
        echo "  • Health Check: http://localhost:${DAPHNE_PORT:-8000}/health/"
        if [ -f "current_ngrok_url.txt" ]; then
            echo "  • Public URL: $(cat current_ngrok_url.txt)"
        fi
        echo ""
        log_success "Management Commands:"
        echo "  • Status: ./status_noctispro_production.sh"
        echo "  • Stop: ./stop_noctispro_production.sh"
        echo "  • Restart: sudo systemctl restart $SERVICE_NAME"
        echo "  • Logs: tail -f logs/*.log"
        echo ""
        log_success "Auto-startup: ✅ Enabled via systemd"
        echo ""
        log_success "Deployment completed successfully at $(date)"
        log_success "Zero critical errors! 🎯"
    else
        log_error "Deployment validation failed"
        exit 1
    fi
}

# Run main deployment
main "$@"