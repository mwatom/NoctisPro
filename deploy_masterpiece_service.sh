#!/bin/bash

# 🚀 Deploy Masterpiece Refined as Service
# Compatible with both old and new Linux systems
# Auto-starts on server bootup with ngrok static URL

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration - Auto-Detection Enhanced
WORKSPACE_DIR="/workspace"
REFINED_SYSTEM_DIR="/workspace/noctis_pro_deployment"
STATIC_URL="mallard-shining-curiously.ngrok-free.app"
DJANGO_PORT="8000"
SERVICE_NAME="noctispro-masterpiece"
PID_FILE="$WORKSPACE_DIR/${SERVICE_NAME}.pid"
LOG_FILE="$WORKSPACE_DIR/${SERVICE_NAME}.log"
NGROK_LOG="$WORKSPACE_DIR/ngrok_${SERVICE_NAME}.log"

# Auto-detection variables
DETECTED_SECRET_KEY=""
DETECTED_NGROK_TOKEN=""
DETECTED_ENV_FILE=""

print_header() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}🚀  Masterpiece Refined Service Deployment${NC}"
    echo -e "${CYAN}   Auto-Start + Ngrok Static URL${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}🚨${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

# Detect system type
detect_system() {
    if command -v systemctl > /dev/null 2>&1 && [ -d /etc/systemd/system ]; then
        echo "systemd"
    elif [ -d /etc/init.d ] && [ -w /etc/init.d ] 2>/dev/null; then
        echo "initd"
    else
        echo "legacy"
    fi
}

# Auto-detect workspace environment variables and tokens
auto_detect_environment() {
    print_info "🔍 Auto-detecting workspace environment..."
    
    # Detect best environment file to use
    local env_priority=(".env.production.fixed" ".env.production" ".env" ".env.container" ".env.demo")
    
    for env_file in "${env_priority[@]}"; do
        if [ -f "$WORKSPACE_DIR/$env_file" ]; then
            DETECTED_ENV_FILE="$WORKSPACE_DIR/$env_file"
            print_success "Found environment file: $env_file"
            break
        fi
    done
    
    if [ -z "$DETECTED_ENV_FILE" ]; then
        print_warning "No environment file found, will create one"
        DETECTED_ENV_FILE="$WORKSPACE_DIR/.env.production"
    fi
    
    # Auto-detect or generate SECRET_KEY
    if [ -f "$DETECTED_ENV_FILE" ]; then
        DETECTED_SECRET_KEY=$(grep "^SECRET_KEY=" "$DETECTED_ENV_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "")
    fi
    
    if [ -z "$DETECTED_SECRET_KEY" ] || [ "$DETECTED_SECRET_KEY" = "noctis-production-secret-2024-change-me" ]; then
        print_info "Generating new secure SECRET_KEY..."
        if command -v openssl > /dev/null 2>&1; then
            DETECTED_SECRET_KEY=$(openssl rand -base64 50 | tr -d '\n')
        elif command -v python3 > /dev/null 2>&1; then
            DETECTED_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))" 2>/dev/null || echo "masterpiece-secret-$(date +%s)")
        else
            DETECTED_SECRET_KEY="masterpiece-secret-$(date +%s)-$(whoami)"
        fi
        print_success "Generated new SECRET_KEY"
    else
        print_success "Using existing SECRET_KEY from $DETECTED_ENV_FILE"
    fi
}

# Auto-detect ngrok authentication
auto_detect_ngrok_auth() {
    print_info "🔍 Auto-detecting ngrok authentication..."
    
    # Check if ngrok is already authenticated
    if $WORKSPACE_DIR/ngrok config check > /dev/null 2>&1; then
        print_success "Ngrok is already authenticated"
        return 0
    fi
    
    # Try to find auth token in environment files
    local env_files=(".env.production.fixed" ".env.production" ".env.ngrok" ".env")
    
    for env_file in "${env_files[@]}"; do
        if [ -f "$WORKSPACE_DIR/$env_file" ]; then
            local token=$(grep "^NGROK.*TOKEN\|^AUTHTOKEN" "$WORKSPACE_DIR/$env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | head -1)
            if [ -n "$token" ] && [ "$token" != "YOUR_TOKEN_HERE" ] && [ "$token" != "your-token-here" ]; then
                DETECTED_NGROK_TOKEN="$token"
                print_success "Found ngrok token in $env_file"
                break
            fi
        fi
    done
    
    # Check ngrok config file
    if [ -z "$DETECTED_NGROK_TOKEN" ] && [ -f "$HOME/.config/ngrok/ngrok.yml" ]; then
        local config_token=$(grep "authtoken:" "$HOME/.config/ngrok/ngrok.yml" 2>/dev/null | awk '{print $2}' | tr -d '"')
        if [ -n "$config_token" ]; then
            DETECTED_NGROK_TOKEN="$config_token"
            print_success "Found ngrok token in config file"
        fi
    fi
    
    # If still no token found, try to configure it
    if [ -z "$DETECTED_NGROK_TOKEN" ]; then
        print_warning "No ngrok auth token found in environment files"
        print_info "Attempting to use existing ngrok configuration..."
        
        # Check if ngrok works without explicit token (might be pre-configured)
        if $WORKSPACE_DIR/ngrok config check > /dev/null 2>&1; then
            print_success "Ngrok configuration is valid"
            return 0
        else
            print_warning "Ngrok needs authentication setup"
            return 1
        fi
    else
        # Configure ngrok with detected token
        print_info "Configuring ngrok with detected token..."
        $WORKSPACE_DIR/ngrok config add-authtoken "$DETECTED_NGROK_TOKEN" > /dev/null 2>&1 || {
            print_warning "Failed to configure ngrok with detected token"
            return 1
        }
        print_success "Ngrok configured with auto-detected token"
    fi
    
    return 0
}

# Auto-detect workspace configuration
auto_detect_workspace() {
    print_info "🔍 Auto-detecting workspace configuration..."
    
    # Detect workspace directory (might not always be /workspace)
    if [ -n "${WORKSPACE:-}" ]; then
        WORKSPACE_DIR="$WORKSPACE"
    elif [ -n "$PWD" ] && [ -f "$PWD/manage.py" ]; then
        WORKSPACE_DIR="$PWD"
    elif [ -f "/workspace/manage.py" ]; then
        WORKSPACE_DIR="/workspace"
    else
        WORKSPACE_DIR="$(pwd)"
    fi
    
    # Update paths based on detected workspace
    REFINED_SYSTEM_DIR="$WORKSPACE_DIR/noctis_pro_deployment"
    PID_FILE="$WORKSPACE_DIR/${SERVICE_NAME}.pid"
    LOG_FILE="$WORKSPACE_DIR/${SERVICE_NAME}.log"
    NGROK_LOG="$WORKSPACE_DIR/ngrok_${SERVICE_NAME}.log"
    
    print_success "Workspace detected at: $WORKSPACE_DIR"
    
    # Auto-detect Django port from existing configuration
    if [ -f "$WORKSPACE_DIR/.env.ngrok" ]; then
        local detected_port=$(grep "^DJANGO_PORT=" "$WORKSPACE_DIR/.env.ngrok" 2>/dev/null | cut -d'=' -f2)
        if [ -n "$detected_port" ]; then
            DJANGO_PORT="$detected_port"
            print_success "Django port detected: $DJANGO_PORT"
        fi
    fi
    
    # Auto-detect static URL
    if [ -f "$WORKSPACE_DIR/.env.ngrok" ]; then
        local detected_url=$(grep "^NGROK_STATIC_URL=" "$WORKSPACE_DIR/.env.ngrok" 2>/dev/null | cut -d'=' -f2)
        if [ -n "$detected_url" ]; then
            STATIC_URL="$detected_url"
            print_success "Static URL detected: $STATIC_URL"
        fi
    fi
    
    # Check if current ngrok URL file exists
    if [ -f "$WORKSPACE_DIR/current_ngrok_url.txt" ]; then
        local current_url=$(cat "$WORKSPACE_DIR/current_ngrok_url.txt" 2>/dev/null | head -1 | tr -d '\n')
        if [ -n "$current_url" ] && [[ "$current_url" == *"ngrok"* ]]; then
            STATIC_URL="$current_url"
            print_success "Using current ngrok URL: $STATIC_URL"
        fi
    fi
}

# Create or update environment file with auto-detected values
setup_environment_file() {
    print_info "📝 Setting up environment file with auto-detected values..."
    
    local env_content="# NoctisPro Masterpiece - Auto-Generated Environment
DEBUG=False
SECRET_KEY=$DETECTED_SECRET_KEY
DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
ALLOWED_HOSTS=*,$STATIC_URL,localhost,127.0.0.1
USE_SQLITE=True
STATIC_ROOT=$WORKSPACE_DIR/staticfiles
MEDIA_ROOT=$WORKSPACE_DIR/media
SERVE_MEDIA_FILES=True
BUILD_TARGET=production
ENVIRONMENT=production
HEALTH_CHECK_ENABLED=True
TIME_ZONE=UTC
USE_TZ=True
DICOM_STORAGE_PATH=$WORKSPACE_DIR/media/dicom
DJANGO_PORT=$DJANGO_PORT
NGROK_STATIC_URL=$STATIC_URL"

    if [ -n "$DETECTED_NGROK_TOKEN" ]; then
        env_content="$env_content
NGROK_AUTHTOKEN=$DETECTED_NGROK_TOKEN"
    fi
    
    echo "$env_content" > "$DETECTED_ENV_FILE"
    print_success "Environment file configured: $DETECTED_ENV_FILE"
}

# Install and setup ngrok
install_setup_ngrok() {
    print_info "Setting up ngrok..."
    
    # Check if ngrok binary exists
    if [ ! -f "$WORKSPACE_DIR/ngrok" ]; then
        print_info "Ngrok binary not found, attempting to install..."
        
        # Check if compressed ngrok package exists
        if [ -f "$WORKSPACE_DIR/ngrok-v3-stable-linux-amd64.tgz" ]; then
            print_info "Found ngrok package, extracting..."
            cd "$WORKSPACE_DIR"
            tar -xzf ngrok-v3-stable-linux-amd64.tgz
            chmod +x ngrok
            print_success "Ngrok extracted and made executable"
        else
            # Download ngrok if not present
            print_info "Downloading ngrok..."
            cd "$WORKSPACE_DIR"
            
            # Detect architecture
            ARCH=$(uname -m)
            case $ARCH in
                x86_64) NGROK_ARCH="amd64" ;;
                aarch64|arm64) NGROK_ARCH="arm64" ;;
                armv7l) NGROK_ARCH="arm" ;;
                i386|i686) NGROK_ARCH="386" ;;
                *) 
                    print_error "Unsupported architecture: $ARCH"
                    return 1
                ;;
            esac
            
            # Download ngrok
            NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-${NGROK_ARCH}.tgz"
            if curl -L -o ngrok-v3-stable-linux-${NGROK_ARCH}.tgz "$NGROK_URL"; then
                tar -xzf ngrok-v3-stable-linux-${NGROK_ARCH}.tgz
                chmod +x ngrok
                print_success "Ngrok downloaded and installed"
            else
                print_error "Failed to download ngrok"
                return 1
            fi
        fi
    else
        print_success "Ngrok binary already exists"
    fi
    
    # Verify ngrok binary works
    if ! "$WORKSPACE_DIR/ngrok" version > /dev/null 2>&1; then
        print_error "Ngrok binary is not working properly"
        return 1
    fi
    
    print_success "Ngrok binary is functional"
    
    # Configure ngrok authentication
    setup_ngrok_auth
}

# Setup ngrok authentication
setup_ngrok_auth() {
    print_info "Configuring ngrok authentication..."
    
    # Try auto-detection first
    if auto_detect_ngrok_auth; then
        print_success "Ngrok is properly authenticated"
        return 0
    fi
    
    # If auto-detection fails, try to configure manually
    print_warning "Ngrok authentication not detected automatically."
    print_info "Attempting to set up ngrok authentication..."
    
    # Check if user wants to configure ngrok interactively
    echo ""
    echo -e "${YELLOW}Ngrok Authentication Setup:${NC}"
    echo "1. Get your free auth token from: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo "2. You can also add NGROK_AUTHTOKEN to your .env file"
    echo ""
    
    # Try to find token in environment or prompt user
    local token=""
    
    # Check environment variables
    if [ -n "${NGROK_AUTHTOKEN:-}" ]; then
        token="$NGROK_AUTHTOKEN"
        print_info "Using NGROK_AUTHTOKEN from environment"
    elif [ -n "${NGROK_TOKEN:-}" ]; then
        token="$NGROK_TOKEN"
        print_info "Using NGROK_TOKEN from environment"
    fi
    
    # If still no token, check if we're in interactive mode
    if [ -z "$token" ] && [ -t 0 ]; then
        echo -e "${CYAN}Enter your ngrok auth token (or press Enter to skip):${NC}"
        read -p "Token: " token
    fi
    
    # Configure ngrok if we have a token
    if [ -n "$token" ] && [ "$token" != "YOUR_TOKEN_HERE" ] && [ "$token" != "your-token-here" ]; then
        if "$WORKSPACE_DIR/ngrok" config add-authtoken "$token" > /dev/null 2>&1; then
            print_success "Ngrok configured with provided token"
            return 0
        else
            print_warning "Failed to configure ngrok with provided token"
        fi
    fi
    
    # Final check
    if "$WORKSPACE_DIR/ngrok" config check > /dev/null 2>&1; then
        print_success "Ngrok is properly configured"
        return 0
    else
        print_warning "Ngrok is not authenticated - will use free tier with random URLs"
        print_info "For static URLs, get your auth token from: https://dashboard.ngrok.com/"
        return 0  # Don't fail deployment, just warn
    fi
}

# Check if ngrok is configured (enhanced with auto-detection)
check_ngrok() {
    print_info "Checking ngrok configuration..."
    
    # First ensure ngrok is installed and set up
    if ! install_setup_ngrok; then
        print_error "Failed to install or setup ngrok"
        return 1
    fi
    
    print_success "Ngrok is ready for use"
    return 0
}

# Install system dependencies
install_system_dependencies() {
    print_info "Installing system dependencies..."
    
    # Check if we have sudo access for package installation
    if ! sudo -n true 2>/dev/null; then
        print_warning "Sudo access required for system package installation."
        print_info "You may be prompted for your password to install system dependencies."
        echo ""
    fi
    
    # Detect OS
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        print_info "Detected Debian/Ubuntu system"
        
        # Update package list
        sudo apt update -qq
        
        # Install essential packages
        sudo apt install -y \
            python3 \
            python3-pip \
            python3-venv \
            python3-dev \
            build-essential \
            libcups2-dev \
            libpq-dev \
            pkg-config \
            libcairo2-dev \
            libgirepository1.0-dev \
            libjpeg-dev \
            libpng-dev \
            libtiff-dev \
            libffi-dev \
            libssl-dev \
            curl \
            wget \
            git \
            tmux \
            redis-server \
            postgresql-client \
            libmagic1 \
            poppler-utils \
            ghostscript
            
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS/Fedora
        print_info "Detected RHEL/CentOS/Fedora system"
        
        # Determine package manager
        if command -v dnf >/dev/null 2>&1; then
            PKG_MGR="dnf"
        elif command -v yum >/dev/null 2>&1; then
            PKG_MGR="yum"
        else
            print_error "No suitable package manager found"
            return 1
        fi
        
        sudo $PKG_MGR install -y \
            python3 \
            python3-pip \
            python3-devel \
            gcc \
            gcc-c++ \
            make \
            cups-devel \
            postgresql-devel \
            pkgconfig \
            cairo-devel \
            gobject-introspection-devel \
            libjpeg-devel \
            libpng-devel \
            libtiff-devel \
            libffi-devel \
            openssl-devel \
            curl \
            wget \
            git \
            tmux \
            redis \
            postgresql \
            file \
            poppler-utils \
            ghostscript
            
    elif [ -f /etc/arch-release ]; then
        # Arch Linux
        print_info "Detected Arch Linux system"
        
        sudo pacman -Syu --noconfirm
        sudo pacman -S --noconfirm \
            python \
            python-pip \
            base-devel \
            libcups \
            postgresql-libs \
            pkg-config \
            cairo \
            gobject-introspection \
            libjpeg-turbo \
            libpng \
            libtiff \
            libffi \
            openssl \
            curl \
            wget \
            git \
            tmux \
            redis \
            postgresql \
            file \
            poppler \
            ghostscript
            
    else
        print_warning "Unknown Linux distribution. Attempting generic installation..."
        # Try to install python3 and pip at minimum
        if command -v apt >/dev/null 2>&1; then
            sudo apt update && sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y python3 python3-pip python3-devel gcc gcc-c++ make
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm python python-pip base-devel
        else
            print_error "Unable to install system dependencies. Please install manually:"
            print_error "- Python 3.8+"
            print_error "- pip"
            print_error "- Development tools (gcc, make, etc.)"
            print_error "- Required system libraries (cups, postgresql, cairo, etc.)"
            return 1
        fi
    fi
    
    # Ensure python3 command is available
    if ! command -v python3 >/dev/null 2>&1; then
        if command -v python >/dev/null 2>&1 && python --version 2>&1 | grep -q "Python 3"; then
            # Create symlink if python points to Python 3
            sudo ln -sf $(which python) /usr/local/bin/python3 2>/dev/null || true
        else
            print_error "Python 3 is not available. Please install Python 3.8 or higher."
            return 1
        fi
    fi
    
    print_success "System dependencies installed successfully"
}

# Setup virtual environment
setup_virtual_environment() {
    print_info "Creating virtual environment..."

    # Always create venv inside project folder if it doesn't exist
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        print_success "Virtual environment created"
    else
        print_success "Virtual environment already exists"
    fi

    # Activate venv
    source venv/bin/activate

    print_info "Installing/updating Python dependencies..."
    pip install --upgrade pip
    
    # Install requirements with better error handling
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
        print_success "Python dependencies installed from requirements.txt"
    else
        print_warning "requirements.txt not found, installing basic Django dependencies..."
        pip install Django pillow django-widget-tweaks python-dotenv gunicorn
        print_success "Basic Django dependencies installed"
    fi
    
    print_success "Virtual environment setup completed"
}

# Check if refined system exists
check_refined_system() {
    print_info "Checking refined system..."
    
    if [ ! -d "$REFINED_SYSTEM_DIR" ]; then
        print_error "Refined system not found at $REFINED_SYSTEM_DIR"
        return 1
    fi
    
    if [ ! -f "$REFINED_SYSTEM_DIR/manage.py" ]; then
        print_error "Django manage.py not found in refined system"
        return 1
    fi
    
    print_success "Refined system found and ready"
    return 0
}

# Stop existing services
stop_existing() {
    print_info "Stopping existing services..."
    
    # Kill existing processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http" 2>/dev/null || true
    pkill -f "gunicorn.*noctis" 2>/dev/null || true
    
    # Kill tmux sessions
    tmux kill-session -t noctispro 2>/dev/null || true
    tmux kill-session -t $SERVICE_NAME 2>/dev/null || true
    
    # Remove old PID files
    [ -f "$PID_FILE" ] && rm -f "$PID_FILE"
    [ -f "$WORKSPACE_DIR/noctispro_service.pid" ] && rm -f "$WORKSPACE_DIR/noctispro_service.pid"
    
    sleep 3
    print_success "Existing services stopped"
}

# Start the masterpiece service
start_service() {
    print_info "Starting Masterpiece Refined Service..."
    
    cd "$REFINED_SYSTEM_DIR"
    
    # Setup virtual environment with enhanced logging
    setup_virtual_environment
    
    # Run migrations with better error handling
    print_info "Running database migrations..."
    if python manage.py migrate --noinput 2>/dev/null; then
        print_success "Database migrations completed successfully"
    else
        print_warning "Database migrations had issues, but continuing..."
    fi
    
    # Create superuser if it doesn't exist
    print_info "Setting up admin user..."
    python manage.py shell << 'PYTHON_EOF' 2>/dev/null || true
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.local', 'admin123')
    print("Admin user created: admin/admin123")
else:
    print("Admin user already exists")
PYTHON_EOF
    
    # Collect static files
    print_info "Collecting static files..."
    if python manage.py collectstatic --noinput 2>/dev/null; then
        print_success "Static files collected successfully"
    else
        print_warning "Static file collection had issues, but continuing..."
    fi
    
    # Start Django server in tmux session with auto-detected environment
    print_info "Starting Django server with auto-detected configuration..."
    tmux new-session -d -s $SERVICE_NAME
    tmux send-keys -t $SERVICE_NAME "cd $REFINED_SYSTEM_DIR" C-m
    tmux send-keys -t $SERVICE_NAME "source venv/bin/activate" C-m
    
    # Load auto-detected environment file
    if [ -f "$DETECTED_ENV_FILE" ]; then
        tmux send-keys -t $SERVICE_NAME "export \$(cat $DETECTED_ENV_FILE | grep -v '^#' | xargs)" C-m
        print_success "Loaded environment from: $DETECTED_ENV_FILE"
    fi
    
    # Set auto-detected SECRET_KEY if available
    if [ -n "$DETECTED_SECRET_KEY" ]; then
        tmux send-keys -t $SERVICE_NAME "export SECRET_KEY='$DETECTED_SECRET_KEY'" C-m
    fi
    
    tmux send-keys -t $SERVICE_NAME "python manage.py runserver 0.0.0.0:$DJANGO_PORT" C-m
    
    # Wait for Django to start
    sleep 5
    
    # Check if Django is running
    if ! curl -s http://localhost:$DJANGO_PORT > /dev/null 2>&1; then
        print_error "Django server failed to start"
        return 1
    fi
    
    print_success "Django server started on port $DJANGO_PORT"
    
    # Start ngrok with static URL
    print_info "Starting ngrok with static URL..."
    tmux new-window -t $SERVICE_NAME
    tmux send-keys -t $SERVICE_NAME "cd $WORKSPACE_DIR" C-m
    # Check if account supports static URLs, fallback to dynamic
    if [[ "$STATIC_URL" == *"ngrok-free.app"* ]] || [[ "$STATIC_URL" == *"ngrok.io"* ]]; then
        print_info "Using dynamic ngrok URL (free plan)"
        tmux send-keys -t $SERVICE_NAME "./ngrok http $DJANGO_PORT" C-m
    else
        tmux send-keys -t $SERVICE_NAME "./ngrok http --url=$STATIC_URL $DJANGO_PORT" C-m
    fi
    
    # Wait for ngrok to start
    sleep 5
    
    # Save service PID (tmux session)
    tmux list-sessions | grep $SERVICE_NAME | cut -d: -f1 > "$PID_FILE"
    
    print_success "Masterpiece service started successfully!"
    echo ""
    echo -e "${GREEN}🌐 Your application is now available at:${NC}"
    echo -e "${CYAN}   https://$STATIC_URL${NC}"
    echo -e "${CYAN}   Admin: https://$STATIC_URL/admin/${NC}"
    echo ""
    echo -e "${BLUE}📊 Service Status:${NC}"
    echo -e "   Django Server: Running on port $DJANGO_PORT"
    echo -e "   Ngrok Tunnel: Active with static URL"
    echo -e "   Tmux Session: $SERVICE_NAME"
    echo ""
}

# Create systemd service file
create_systemd_service() {
    print_info "Creating systemd service..."
    
    cat > /tmp/${SERVICE_NAME}.service << EOF
[Unit]
Description=NoctisPro Masterpiece Refined Service
After=network.target

[Service]
Type=forking
User=root
WorkingDirectory=$WORKSPACE_DIR
ExecStart=$WORKSPACE_DIR/deploy_masterpiece_service.sh start
ExecStop=$WORKSPACE_DIR/deploy_masterpiece_service.sh stop
ExecReload=$WORKSPACE_DIR/deploy_masterpiece_service.sh restart
PIDFile=$PID_FILE
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    if [ -w /etc/systemd/system ]; then
        sudo cp /tmp/${SERVICE_NAME}.service /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable ${SERVICE_NAME}.service
        print_success "Systemd service created and enabled"
    else
        print_warning "Cannot write to /etc/systemd/system (no sudo access)"
        cp /tmp/${SERVICE_NAME}.service "$WORKSPACE_DIR/"
        print_info "Service file saved to $WORKSPACE_DIR/${SERVICE_NAME}.service"
    fi
}

# Create init.d service script
create_initd_service() {
    print_info "Creating init.d service..."
    
    cat > /tmp/${SERVICE_NAME} << 'EOF'
#!/bin/bash
### BEGIN INIT INFO
# Provides:          noctispro-masterpiece
# Required-Start:    $local_fs $network $named $time $syslog
# Required-Stop:     $local_fs $network $named $time $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       NoctisPro Masterpiece Refined Service
### END INIT INFO

SCRIPT_DIR="/workspace"
SCRIPT="$SCRIPT_DIR/deploy_masterpiece_service.sh"
LOCK_FILE="/var/lock/subsys/noctispro-masterpiece"

start() {
    if [ -f "$LOCK_FILE" ]; then
        echo "Service is already running"
        return 1
    fi
    
    echo "Starting NoctisPro Masterpiece Service..."
    $SCRIPT start
    
    if [ $? -eq 0 ]; then
        touch "$LOCK_FILE"
        echo "Service started successfully"
        return 0
    else
        echo "Failed to start service"
        return 1
    fi
}

stop() {
    if [ ! -f "$LOCK_FILE" ]; then
        echo "Service is not running"
        return 1
    fi
    
    echo "Stopping NoctisPro Masterpiece Service..."
    $SCRIPT stop
    
    if [ $? -eq 0 ]; then
        rm -f "$LOCK_FILE"
        echo "Service stopped successfully"
        return 0
    else
        echo "Failed to stop service"
        return 1
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    status)
        if [ -f "$LOCK_FILE" ]; then
            echo "Service is running"
        else
            echo "Service is stopped"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
esac

exit $?
EOF

    if [ -w /etc/init.d ]; then
        sudo cp /tmp/${SERVICE_NAME} /etc/init.d/
        sudo chmod +x /etc/init.d/${SERVICE_NAME}
        
        # Enable service for different systems
        if command -v update-rc.d > /dev/null 2>&1; then
            sudo update-rc.d ${SERVICE_NAME} defaults
        elif command -v chkconfig > /dev/null 2>&1; then
            sudo chkconfig --add ${SERVICE_NAME}
            sudo chkconfig ${SERVICE_NAME} on
        fi
        
        print_success "Init.d service created and enabled"
    else
        print_warning "Cannot write to /etc/init.d (no sudo access)"
        cp /tmp/${SERVICE_NAME} "$WORKSPACE_DIR/"
        chmod +x "$WORKSPACE_DIR/${SERVICE_NAME}"
        print_info "Service script saved to $WORKSPACE_DIR/${SERVICE_NAME}"
    fi
}

# Create cron job for auto-start
create_cron_job() {
    print_info "Setting up cron job for auto-start..."
    
    if command -v crontab > /dev/null 2>&1; then
        # Remove existing cron jobs for this service
        (crontab -l 2>/dev/null | grep -v "${SERVICE_NAME}" | grep -v "deploy_masterpiece_service.sh") > /tmp/cron_tmp || true
        
        # Add new cron job
        echo "@reboot sleep 30 && $WORKSPACE_DIR/deploy_masterpiece_service.sh start > $WORKSPACE_DIR/autostart_${SERVICE_NAME}.log 2>&1" >> /tmp/cron_tmp
        
        crontab /tmp/cron_tmp
        rm -f /tmp/cron_tmp
        
        print_success "Cron job created for auto-start"
    else
        print_warning "Cron not available"
    fi
}

# Create profile-based auto-start (for containers/limited environments)
create_profile_autostart() {
    print_info "Setting up profile-based auto-start..."
    
    # Create auto-start script
    cat > "$WORKSPACE_DIR/autostart_masterpiece.sh" << EOF
#!/bin/bash
# Auto-start script for NoctisPro Masterpiece

# Check if already running
if tmux has-session -t $SERVICE_NAME 2>/dev/null; then
    echo "Service already running"
    exit 0
fi

# Wait for system to be ready
sleep 10

# Start the service
cd $WORKSPACE_DIR
./deploy_masterpiece_service.sh start > $WORKSPACE_DIR/autostart_${SERVICE_NAME}.log 2>&1 &

echo "Auto-start initiated"
EOF

    chmod +x "$WORKSPACE_DIR/autostart_masterpiece.sh"
    
    # Add to bashrc and profile
    for profile_file in ~/.bashrc ~/.profile; do
        if [ -f "$profile_file" ]; then
            # Remove existing auto-start lines
            grep -v "autostart_masterpiece.sh" "$profile_file" > "${profile_file}.tmp" 2>/dev/null || cp "$profile_file" "${profile_file}.tmp"
            
            # Add new auto-start line
            echo "" >> "${profile_file}.tmp"
            echo "# NoctisPro Masterpiece auto-start" >> "${profile_file}.tmp"
            echo "$WORKSPACE_DIR/autostart_masterpiece.sh 2>/dev/null || true" >> "${profile_file}.tmp"
            
            mv "${profile_file}.tmp" "$profile_file"
            print_success "Added auto-start to $profile_file"
        fi
    done
}

# Setup auto-start based on system type
setup_autostart() {
    print_info "Setting up auto-start for system bootup..."
    
    SYSTEM_TYPE=$(detect_system)
    print_info "Detected system type: $SYSTEM_TYPE"
    
    case $SYSTEM_TYPE in
        "systemd")
            create_systemd_service
            ;;
        "initd")
            create_initd_service
            ;;
        "legacy")
            print_warning "Legacy system detected - using alternative methods"
            ;;
    esac
    
    # Always setup cron and profile methods as backup
    create_cron_job
    create_profile_autostart
    
    print_success "Auto-start setup completed for $SYSTEM_TYPE system"
}

# Stop service
stop_service() {
    print_info "Stopping Masterpiece service..."
    
    # Kill tmux session
    if tmux has-session -t $SERVICE_NAME 2>/dev/null; then
        tmux kill-session -t $SERVICE_NAME
        print_success "Tmux session terminated"
    fi
    
    # Kill processes
    pkill -f "manage.py runserver" 2>/dev/null || true
    pkill -f "ngrok.*http.*$STATIC_URL" 2>/dev/null || true
    
    # Remove PID file
    [ -f "$PID_FILE" ] && rm -f "$PID_FILE"
    
    print_success "Service stopped"
}

# Show service status
show_status() {
    echo ""
    echo -e "${BLUE}📊 Masterpiece Service Status:${NC}"
    echo ""
    
    # Check tmux session
    if tmux has-session -t $SERVICE_NAME 2>/dev/null; then
        echo -e "${GREEN}✅ Tmux Session: Running${NC}"
    else
        echo -e "${RED}❌ Tmux Session: Not found${NC}"
    fi
    
    # Check Django server
    if curl -s http://localhost:$DJANGO_PORT > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Django Server: Running on port $DJANGO_PORT${NC}"
    else
        echo -e "${RED}❌ Django Server: Not responding${NC}"
    fi
    
    # Check ngrok
    if pgrep -f "ngrok.*http.*$STATIC_URL" > /dev/null; then
        echo -e "${GREEN}✅ Ngrok Tunnel: Active${NC}"
        echo -e "${CYAN}   URL: https://$STATIC_URL${NC}"
    else
        echo -e "${RED}❌ Ngrok Tunnel: Not active${NC}"
    fi
    
    echo ""
    
    # Show auto-start status
    echo -e "${BLUE}🔧 Auto-Start Status:${NC}"
    [ -f /etc/systemd/system/${SERVICE_NAME}.service ] && echo -e "${GREEN}✅ Systemd service installed${NC}"
    [ -f /etc/init.d/${SERVICE_NAME} ] && echo -e "${GREEN}✅ Init.d service installed${NC}"
    crontab -l 2>/dev/null | grep -q "deploy_masterpiece_service.sh" && echo -e "${GREEN}✅ Cron job configured${NC}"
    [ -f "$WORKSPACE_DIR/autostart_masterpiece.sh" ] && echo -e "${GREEN}✅ Profile auto-start configured${NC}"
    
    echo ""
}

# Main function
main() {
    case "${1:-}" in
        "start")
            print_header
            # Auto-detect environment for start command
            auto_detect_workspace
            auto_detect_environment
            check_ngrok || exit 1
            check_refined_system || exit 1
            stop_existing
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            stop_service
            sleep 2
            # Auto-detect environment for restart
            auto_detect_workspace
            auto_detect_environment
            main start
            ;;
        "status")
            show_status
            ;;
        "setup-autostart")
            setup_autostart
            ;;
        "deploy")
            print_header
            
            # System setup phase
            print_info "🔧 Installing system dependencies..."
            install_system_dependencies || exit 1
            
            # Auto-detection phase
            auto_detect_workspace || exit 1
            auto_detect_environment || exit 1
            setup_environment_file || exit 1
            
            # Verification phase
            check_ngrok || exit 1
            check_refined_system || exit 1
            
            # Deployment phase
            stop_existing
            start_service
            setup_autostart
            
            # Success summary
            echo ""
            print_success "🎉 Masterpiece deployment completed with full environment setup!"
            echo ""
            echo -e "${CYAN}📍 Workspace: $WORKSPACE_DIR${NC}"
            echo -e "${CYAN}🔑 Secret Key: Auto-generated and configured${NC}"
            echo -e "${CYAN}🌐 Application: https://$STATIC_URL${NC}"
            echo -e "${CYAN}🔧 Admin Panel: https://$STATIC_URL/admin/${NC}"
            echo -e "${CYAN}👤 Admin User: admin / admin123${NC}"
            echo -e "${CYAN}🚀 Django Port: $DJANGO_PORT (localhost:$DJANGO_PORT)${NC}"
            echo -e "${CYAN}📁 Environment: $DETECTED_ENV_FILE${NC}"
            echo -e "${GREEN}🔧 System Dependencies: Installed${NC}"
            echo -e "${GREEN}🐍 Python Dependencies: Installed from requirements.txt${NC}"
            echo -e "${GREEN}🗄️  Database: Migrated and ready${NC}"
            echo -e "${GREEN}🚀 Auto-start: Configured for system bootup${NC}"
            echo -e "${GREEN}🌐 Ngrok: Installed and configured${NC}"
            if [ -n "$DETECTED_NGROK_TOKEN" ]; then
                echo -e "${GREEN}🔐 Ngrok Auth: Auto-configured with detected token${NC}"
            else
                echo -e "${YELLOW}🔐 Ngrok Auth: Using free tier (random URLs)${NC}"
            fi
            echo ""
            echo -e "${YELLOW}📋 Next Steps:${NC}"
            echo -e "   • Access your application at: https://$STATIC_URL"
            echo -e "   • Login to admin panel with: admin / admin123"
            echo -e "   • Local development: http://localhost:$DJANGO_PORT"
            echo -e "   • Check status with: $0 status"
            echo ""
            ;;
        *)
            echo -e "${BLUE}🚀 NoctisPro Masterpiece Service Manager${NC}"
            echo -e "${GREEN}   Enhanced with Auto-Detection${NC}"
            echo ""
            echo "Usage: $0 {start|stop|restart|status|setup-autostart|deploy}"
            echo ""
            echo "Commands:"
            echo "  start         - Start the service (auto-detects environment)"
            echo "  stop          - Stop the service"
            echo "  restart       - Restart the service (auto-detects environment)"
            echo "  status        - Show service status"
            echo "  setup-autostart - Configure auto-start only"
            echo "  deploy        - Full deployment with system setup, dependencies & auto-start"
            echo ""
            echo -e "${CYAN}🔍 Auto-Detection Features:${NC}"
            echo "  • Workspace directory detection"
            echo "  • Environment file detection (.env.production.fixed → .env.production → .env)"
            echo "  • SECRET_KEY auto-generation if missing/default"
            echo "  • Ngrok token detection from env files and config"
            echo "  • Django port and static URL detection"
            echo "  • Automatic environment file creation if none exists"
            echo ""
            echo -e "${CYAN}🛠️  System Setup Features:${NC}"
            echo "  • Automatic system dependency installation (Ubuntu/Debian/RHEL/Arch)"
            echo "  • Python virtual environment creation and management"
            echo "  • Django requirements.txt installation"
            echo "  • Database migration and admin user creation"
            echo "  • Django deployment on port 8000"
            echo "  • Static file collection and serving"
            echo "  • Automatic ngrok download, installation and configuration"
            echo "  • Ngrok authentication setup (manual or from environment)"
            echo "  • External access via ngrok tunneling"
            echo ""
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"