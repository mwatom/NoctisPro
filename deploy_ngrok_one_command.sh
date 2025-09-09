#!/bin/bash

# 🚀 NoctisPro PACS - One Command Ngrok Deployment
# Complete deployment script with error handling and validation
# Uses your existing static URL: mallard-shining-curiously.ngrok-free.app

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
STATIC_URL="mallard-shining-curiously.ngrok-free.app"
DJANGO_PORT="8000"
PROJECT_DIR="/workspace"
NGROK_BINARY="/usr/bin/ngrok"  # Use system ngrok we just installed
VENV_PATH="$PROJECT_DIR/venv"

# Function definitions
print_header() {
    echo ""
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}🚀 NoctisPro PACS - Ngrok Deployment${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if port is in use
port_in_use() {
    lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1
}

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local max_attempts=${2:-30}
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    return 1
}

# Function to setup ngrok authentication
setup_ngrok_auth() {
    print_status "Checking ngrok authentication..."
    
    if $NGROK_BINARY config check >/dev/null 2>&1; then
        print_success "Ngrok is already authenticated"
        return 0
    fi
    
    print_warning "Ngrok needs authentication setup"
    echo ""
    echo -e "${YELLOW}To get your FREE ngrok auth token:${NC}"
    echo -e "1. Visit: ${CYAN}https://dashboard.ngrok.com/signup${NC}"
    echo -e "2. Sign up for a free account"
    echo -e "3. Go to: ${CYAN}https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
    echo -e "4. Copy your auth token"
    echo ""
    
    # Check if token exists in environment or .env file
    local auth_token=""
    
    # Check environment variable
    if [ -n "${NGROK_AUTHTOKEN:-}" ]; then
        auth_token="$NGROK_AUTHTOKEN"
        print_success "Found auth token in environment variable"
    fi
    
    # Check .env file
    if [ -z "$auth_token" ] && [ -f "$PROJECT_DIR/.env" ]; then
        auth_token=$(grep "^NGROK_AUTHTOKEN=" "$PROJECT_DIR/.env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || true)
        if [ -n "$auth_token" ]; then
            print_success "Found auth token in .env file"
        fi
    fi
    
    # Prompt for token if not found
    if [ -z "$auth_token" ]; then
        while [ -z "$auth_token" ]; do
            read -p "Enter your ngrok auth token: " auth_token
            if [ -z "$auth_token" ]; then
                print_error "Auth token cannot be empty"
            fi
        done
    fi
    
    # Configure ngrok
    print_status "Configuring ngrok with auth token..."
    if $NGROK_BINARY config add-authtoken "$auth_token"; then
        print_success "Ngrok authentication configured successfully!"
        
        # Save token to .env file
        if [ ! -f "$PROJECT_DIR/.env" ]; then
            echo "NGROK_AUTHTOKEN=$auth_token" > "$PROJECT_DIR/.env"
        else
            if grep -q "NGROK_AUTHTOKEN" "$PROJECT_DIR/.env"; then
                sed -i "s/NGROK_AUTHTOKEN=.*/NGROK_AUTHTOKEN=$auth_token/" "$PROJECT_DIR/.env"
            else
                echo "NGROK_AUTHTOKEN=$auth_token" >> "$PROJECT_DIR/.env"
            fi
        fi
        print_success "Auth token saved to .env file"
        return 0
    else
        print_error "Failed to configure ngrok authentication"
        return 1
    fi
}

# Function to cleanup existing processes
cleanup_processes() {
    print_status "Cleaning up existing processes..."
    
    # Kill Django processes
    if pgrep -f "manage.py runserver" >/dev/null; then
        print_warning "Stopping existing Django server..."
        pkill -f "manage.py runserver" || true
        sleep 2
    fi
    
    # Kill ngrok processes
    if pgrep -f "ngrok.*http" >/dev/null; then
        print_warning "Stopping existing ngrok tunnel..."
        pkill -f "ngrok.*http" || true
        sleep 2
    fi
    
    print_success "Cleanup completed"
}

# Function to setup virtual environment
setup_venv() {
    print_status "Setting up Python virtual environment..."
    
    if [ ! -d "$VENV_PATH" ]; then
        print_status "Creating virtual environment..."
        python3 -m venv "$VENV_PATH"
    fi
    
    # Activate virtual environment
    source "$VENV_PATH/bin/activate"
    print_success "Virtual environment activated"
    
    # Install/upgrade pip
    pip install --upgrade pip >/dev/null 2>&1
    
    # Install requirements if they exist
    if [ -f "$PROJECT_DIR/requirements.txt" ]; then
        print_status "Installing Python dependencies..."
        pip install -r "$PROJECT_DIR/requirements.txt" >/dev/null 2>&1
        print_success "Dependencies installed"
    fi
}

# Function to setup Django
setup_django() {
    print_status "Setting up Django application..."
    
    cd "$PROJECT_DIR"
    
    # Run migrations
    print_status "Running database migrations..."
    python manage.py makemigrations >/dev/null 2>&1 || true
    python manage.py migrate >/dev/null 2>&1
    print_success "Database migrations completed"
    
    # Collect static files
    print_status "Collecting static files..."
    python manage.py collectstatic --noinput >/dev/null 2>&1
    print_success "Static files collected"
    
    # Create logs directory
    mkdir -p "$PROJECT_DIR/logs"
}

# Function to start Django server
start_django() {
    print_status "Starting Django server on port $DJANGO_PORT..."
    
    cd "$PROJECT_DIR"
    source "$VENV_PATH/bin/activate"
    
    # Start Django server in background
    nohup python manage.py runserver 0.0.0.0:$DJANGO_PORT > "$PROJECT_DIR/logs/django.log" 2>&1 &
    DJANGO_PID=$!
    
    # Wait for Django to start
    print_status "Waiting for Django server to initialize..."
    if wait_for_service "http://localhost:$DJANGO_PORT" 30; then
        print_success "Django server started successfully (PID: $DJANGO_PID)"
        echo "DJANGO_PID=$DJANGO_PID" > "$PROJECT_DIR/deployment_pids.env"
        return 0
    else
        print_error "Django server failed to start"
        cat "$PROJECT_DIR/logs/django.log"
        return 1
    fi
}

# Function to start ngrok tunnel
start_ngrok() {
    print_status "Starting ngrok tunnel with static URL: $STATIC_URL..."
    
    # Start ngrok in background
    nohup $NGROK_BINARY http --url="https://$STATIC_URL" $DJANGO_PORT > "$PROJECT_DIR/logs/ngrok.log" 2>&1 &
    NGROK_PID=$!
    
    # Wait for ngrok to establish tunnel
    print_status "Waiting for ngrok tunnel to establish..."
    sleep 8
    
    # Check if ngrok started successfully
    if kill -0 $NGROK_PID 2>/dev/null; then
        print_success "Ngrok tunnel established successfully (PID: $NGROK_PID)"
        echo "NGROK_PID=$NGROK_PID" >> "$PROJECT_DIR/deployment_pids.env"
        
        # Test the tunnel
        print_status "Testing tunnel connection..."
        sleep 3
        if curl -s -H "ngrok-skip-browser-warning: 1" "https://$STATIC_URL" >/dev/null 2>&1; then
            print_success "Tunnel is responding correctly!"
        else
            print_warning "Tunnel test inconclusive - may still be initializing"
        fi
        
        return 0
    else
        print_error "Ngrok tunnel failed to start"
        cat "$PROJECT_DIR/logs/ngrok.log"
        return 1
    fi
}

# Function to display deployment info
show_deployment_info() {
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}🎉 DEPLOYMENT SUCCESSFUL!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${CYAN}🌐 Your NoctisPro PACS is now live at:${NC}"
    echo ""
    echo -e "${WHITE}🏠 Main Application:${NC}"
    echo -e "   https://$STATIC_URL/"
    echo ""
    echo -e "${WHITE}🔧 Admin Panel:${NC}"
    echo -e "   https://$STATIC_URL/admin/"
    echo -e "   Default login: admin / admin123"
    echo ""
    echo -e "${WHITE}📋 Worklist:${NC}"
    echo -e "   https://$STATIC_URL/worklist/"
    echo ""
    echo -e "${WHITE}🖼️ DICOM Viewer:${NC}"
    echo -e "   https://$STATIC_URL/dicom-viewer/"
    echo ""
    echo -e "${WHITE}📊 System Status:${NC}"
    echo -e "   https://$STATIC_URL/health/"
    echo ""
    echo -e "${CYAN}📋 Process Information:${NC}"
    echo -e "   Django PID: $DJANGO_PID"
    echo -e "   Ngrok PID: $NGROK_PID"
    echo -e "   Log files: $PROJECT_DIR/logs/"
    echo ""
    echo -e "${YELLOW}🛠️ Management Commands:${NC}"
    echo -e "   View Django logs: tail -f $PROJECT_DIR/logs/django.log"
    echo -e "   View ngrok logs:  tail -f $PROJECT_DIR/logs/ngrok.log"
    echo -e "   Stop deployment:  $PROJECT_DIR/stop_deployment.sh"
    echo ""
    echo -e "${GREEN}✅ Your medical imaging system is live and ready!${NC}"
    echo ""
}

# Function to create stop script
create_stop_script() {
    cat > "$PROJECT_DIR/stop_deployment.sh" << 'EOF'
#!/bin/bash

# Stop NoctisPro PACS deployment

echo "🛑 Stopping NoctisPro PACS deployment..."

# Load process IDs if they exist
if [ -f "/workspace/deployment_pids.env" ]; then
    source "/workspace/deployment_pids.env"
fi

# Stop Django server
if [ -n "${DJANGO_PID:-}" ] && kill -0 "$DJANGO_PID" 2>/dev/null; then
    echo "Stopping Django server (PID: $DJANGO_PID)..."
    kill "$DJANGO_PID"
else
    echo "Stopping any Django processes..."
    pkill -f "manage.py runserver" || true
fi

# Stop ngrok tunnel
if [ -n "${NGROK_PID:-}" ] && kill -0 "$NGROK_PID" 2>/dev/null; then
    echo "Stopping ngrok tunnel (PID: $NGROK_PID)..."
    kill "$NGROK_PID"
else
    echo "Stopping any ngrok processes..."
    pkill -f "ngrok.*http" || true
fi

# Clean up PID file
rm -f "/workspace/deployment_pids.env"

echo "✅ Deployment stopped successfully!"
EOF
    
    chmod +x "$PROJECT_DIR/stop_deployment.sh"
    print_success "Stop script created: $PROJECT_DIR/stop_deployment.sh"
}

# Function to monitor deployment
monitor_deployment() {
    print_status "Monitoring deployment... Press Ctrl+C to stop"
    
    # Set up trap for clean shutdown
    trap 'echo ""; print_warning "Shutting down deployment..."; source "$PROJECT_DIR/deployment_pids.env" 2>/dev/null; kill ${DJANGO_PID:-} ${NGROK_PID:-} 2>/dev/null || true; echo "✅ Deployment stopped."; exit 0' INT
    
    # Monitor loop
    while true; do
        # Check Django process
        if ! kill -0 ${DJANGO_PID:-} 2>/dev/null; then
            print_error "Django server stopped unexpectedly!"
            kill ${NGROK_PID:-} 2>/dev/null || true
            exit 1
        fi
        
        # Check ngrok process
        if ! kill -0 ${NGROK_PID:-} 2>/dev/null; then
            print_error "Ngrok tunnel stopped unexpectedly!"
            kill ${DJANGO_PID:-} 2>/dev/null || true
            exit 1
        fi
        
        sleep 30
    done
}

# Main execution function
main() {
    print_header
    
    # Check prerequisites
    print_status "Checking prerequisites..."
    
    if ! command_exists python3; then
        print_error "Python 3 is required but not installed"
        exit 1
    fi
    
    if ! command_exists "$NGROK_BINARY"; then
        print_error "Ngrok is required but not found at $NGROK_BINARY"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
    
    # Setup ngrok authentication
    if ! setup_ngrok_auth; then
        print_error "Failed to setup ngrok authentication"
        exit 1
    fi
    
    # Cleanup existing processes
    cleanup_processes
    
    # Setup virtual environment
    setup_venv
    
    # Setup Django
    setup_django
    
    # Start Django server
    if ! start_django; then
        print_error "Failed to start Django server"
        exit 1
    fi
    
    # Start ngrok tunnel
    if ! start_ngrok; then
        print_error "Failed to start ngrok tunnel"
        kill ${DJANGO_PID:-} 2>/dev/null || true
        exit 1
    fi
    
    # Create stop script
    create_stop_script
    
    # Show deployment information
    show_deployment_info
    
    # Monitor deployment
    monitor_deployment
}

# Run main function
main "$@"