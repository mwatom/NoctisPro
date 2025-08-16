#!/bin/bash

# NoctisPro Internet Deployment Script for Linux
# Makes your NoctisPro system accessible from anywhere on the internet
# Supports Ubuntu, Debian, CentOS, RHEL, and other Linux distributions

set -e

# Configuration
PROJECT_PATH="${1:-$(pwd)}"
ADMIN_USERNAME="${2:-admin}"
ADMIN_PASSWORD="${3:-Admin123!}"
ADMIN_EMAIL="${4:-admin@noctispro.com}"
PORT="${5:-8000}"
TUNNEL_TYPE="${6:-cloudflare}"  # cloudflare or ngrok

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 NoctisPro Internet Deployment Starting...${NC}"
echo -e "${CYAN}📁 Project Path: $PROJECT_PATH${NC}"
echo -e "${CYAN}🌐 Local Port: $PORT${NC}"
echo -e "${CYAN}🌍 Tunnel Type: $TUNNEL_TYPE${NC}"

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    echo -e "${BLUE}Detected OS: $OS $VER${NC}"
}

# Function to install Python and pip
install_python() {
    echo -e "${YELLOW}🐍 Installing Python and dependencies...${NC}"
    
    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}✅ Python3 is already installed${NC}"
        python3 --version
    else
        echo -e "${YELLOW}Installing Python3...${NC}"
        
        if command -v apt-get &> /dev/null; then
            # Debian/Ubuntu
            sudo apt-get update
            sudo apt-get install -y python3 python3-pip python3-venv python3-dev build-essential
        elif command -v yum &> /dev/null; then
            # RHEL/CentOS
            sudo yum install -y python3 python3-pip python3-devel gcc
        elif command -v dnf &> /dev/null; then
            # Fedora
            sudo dnf install -y python3 python3-pip python3-devel gcc
        elif command -v pacman &> /dev/null; then
            # Arch Linux
            sudo pacman -S python python-pip gcc
        else
            echo -e "${RED}❌ Could not detect package manager. Please install Python3 manually.${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}✅ Python3 installed successfully${NC}"
    fi
}

# Function to create virtual environment and install dependencies
setup_python_environment() {
    echo -e "${YELLOW}📦 Setting up Python environment...${NC}"
    
    cd "$PROJECT_PATH"
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        echo -e "${CYAN}Creating virtual environment...${NC}"
        python3 -m venv venv
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install required packages
    echo -e "${CYAN}Installing Python packages...${NC}"
    pip install django>=4.2.0
    pip install djangorestframework
    pip install pillow
    pip install pydicom
    pip install pynetdicom
    pip install numpy
    pip install scipy
    pip install gunicorn
    
    echo -e "${GREEN}✅ Python environment setup complete${NC}"
}

# Function to run login fix script
run_login_fix() {
    echo -e "${YELLOW}🔧 Running login fix script...${NC}"
    
    cd "$PROJECT_PATH"
    source venv/bin/activate
    
    if [ -f "fix_login_and_deploy_internet.py" ]; then
        python fix_login_and_deploy_internet.py
        echo -e "${GREEN}✅ Login fix completed${NC}"
    else
        echo -e "${YELLOW}⚠️  Login fix script not found, but continuing...${NC}"
    fi
}

# Function to setup Cloudflare tunnel
setup_cloudflare_tunnel() {
    echo -e "${YELLOW}🌍 Setting up Cloudflare Tunnel...${NC}"
    
    # Download cloudflared
    if ! command -v cloudflared &> /dev/null; then
        echo -e "${CYAN}📥 Downloading Cloudflare Tunnel...${NC}"
        
        # Detect architecture
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) CLOUDFLARED_ARCH="amd64" ;;
            aarch64) CLOUDFLARED_ARCH="arm64" ;;
            armv7l) CLOUDFLARED_ARCH="arm" ;;
            *) echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"; exit 1 ;;
        esac
        
        # Download and install cloudflared
        wget -O cloudflared "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CLOUDFLARED_ARCH}"
        chmod +x cloudflared
        sudo mv cloudflared /usr/local/bin/
        
        echo -e "${GREEN}✅ Cloudflare Tunnel installed${NC}"
    else
        echo -e "${GREEN}✅ Cloudflare Tunnel already installed${NC}"
    fi
}

# Function to setup ngrok tunnel
setup_ngrok_tunnel() {
    echo -e "${YELLOW}🌍 Setting up ngrok Tunnel...${NC}"
    
    if ! command -v ngrok &> /dev/null; then
        echo -e "${CYAN}📥 Downloading ngrok...${NC}"
        
        # Download and install ngrok
        wget -O ngrok.tgz "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz"
        tar xvzf ngrok.tgz
        sudo mv ngrok /usr/local/bin/
        rm ngrok.tgz
        
        echo -e "${GREEN}✅ ngrok installed${NC}"
    else
        echo -e "${GREEN}✅ ngrok already installed${NC}"
    fi
}

# Function to create startup scripts
create_startup_scripts() {
    echo -e "${YELLOW}📝 Creating startup scripts...${NC}"
    
    cd "$PROJECT_PATH"
    
    # Django startup script
    cat > start_django.sh << EOF
#!/bin/bash
cd "$PROJECT_PATH"
source venv/bin/activate
echo "Starting NoctisPro Django Server..."
gunicorn --bind 0.0.0.0:$PORT --workers 3 noctis_pro.wsgi:application
EOF
    chmod +x start_django.sh
    echo -e "${GREEN}✅ Created start_django.sh${NC}"
    
    # Tunnel startup script
    if [ "$TUNNEL_TYPE" = "cloudflare" ]; then
        cat > start_tunnel.sh << EOF
#!/bin/bash
echo "Starting Cloudflare Tunnel..."
cloudflared tunnel --url http://localhost:$PORT
EOF
    else
        cat > start_tunnel.sh << EOF
#!/bin/bash
echo "Starting ngrok Tunnel..."
ngrok http $PORT
EOF
    fi
    chmod +x start_tunnel.sh
    echo -e "${GREEN}✅ Created start_tunnel.sh${NC}"
    
    # Combined startup script
    cat > start_noctispro_internet.sh << EOF
#!/bin/bash

echo "================================"
echo "  NoctisPro Internet Deployment"
echo "================================"
echo

echo "Starting Django server..."
./start_django.sh &
DJANGO_PID=\$!

echo "Waiting for Django to start..."
sleep 10

echo "Starting internet tunnel..."
./start_tunnel.sh &
TUNNEL_PID=\$!

echo
echo "================================"
echo "  NoctisPro is now accessible!"
echo "================================"
echo
echo "Login Credentials:"
echo "Username: $ADMIN_USERNAME"
echo "Password: $ADMIN_PASSWORD"
echo
echo "The tunnel URL will appear above."
echo "Look for a URL like: https://xxxx.trycloudflare.com"
echo
echo "To stop NoctisPro, press Ctrl+C"

# Wait for interrupt
trap 'echo "Stopping NoctisPro..."; kill \$DJANGO_PID \$TUNNEL_PID; exit' INT
wait
EOF
    chmod +x start_noctispro_internet.sh
    echo -e "${GREEN}✅ Created start_noctispro_internet.sh${NC}"
}

# Function to create systemd service
create_systemd_service() {
    echo -e "${YELLOW}🔧 Creating systemd service...${NC}"
    
    # Create service file
    sudo tee /etc/systemd/system/noctispro.service > /dev/null << EOF
[Unit]
Description=NoctisPro Medical Imaging System
After=network.target

[Service]
Type=forking
User=$USER
WorkingDirectory=$PROJECT_PATH
ExecStart=$PROJECT_PATH/start_django.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable noctispro
    
    echo -e "${GREEN}✅ Systemd service created${NC}"
    echo -e "${CYAN}Use 'sudo systemctl start noctispro' to start as service${NC}"
}

# Function to setup firewall
setup_firewall() {
    echo -e "${YELLOW}🔥 Configuring firewall...${NC}"
    
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian UFW
        sudo ufw allow $PORT/tcp
        echo -e "${GREEN}✅ UFW firewall rule added for port $PORT${NC}"
    elif command -v firewall-cmd &> /dev/null; then
        # RHEL/CentOS/Fedora firewalld
        sudo firewall-cmd --permanent --add-port=$PORT/tcp
        sudo firewall-cmd --reload
        echo -e "${GREEN}✅ Firewalld rule added for port $PORT${NC}"
    else
        echo -e "${YELLOW}⚠️  Please manually configure firewall to allow port $PORT${NC}"
    fi
}

# Main execution
main() {
    echo -e "${GREEN}Starting NoctisPro Internet Deployment...${NC}"
    
    # Check if running as root (not recommended)
    if [ "$EUID" -eq 0 ]; then
        echo -e "${YELLOW}⚠️  Running as root. Consider running as regular user.${NC}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}❌ Deployment cancelled${NC}"
            exit 1
        fi
    fi
    
    # Detect distribution
    detect_distro
    
    # Install Python
    install_python
    
    # Setup Python environment
    setup_python_environment
    
    # Run login fix
    run_login_fix
    
    # Setup tunnel
    if [ "$TUNNEL_TYPE" = "cloudflare" ]; then
        setup_cloudflare_tunnel
    elif [ "$TUNNEL_TYPE" = "ngrok" ]; then
        setup_ngrok_tunnel
    else
        echo -e "${RED}❌ Invalid tunnel type: $TUNNEL_TYPE${NC}"
        exit 1
    fi
    
    # Create startup scripts
    create_startup_scripts
    
    # Create systemd service
    create_systemd_service
    
    # Setup firewall
    setup_firewall
    
    # Final instructions
    echo
    echo -e "${GREEN}🎉 NoctisPro Internet Deployment Complete!${NC}"
    echo -e "${GREEN}================================${NC}"
    
    echo
    echo -e "${YELLOW}📋 How to Start Your Internet-Accessible NoctisPro:${NC}"
    echo -e "${CYAN}1. Run: ./start_noctispro_internet.sh${NC}"
    echo -e "${CYAN}2. Wait for the tunnel URL to appear (e.g., https://xxxx.trycloudflare.com)${NC}"
    echo -e "${CYAN}3. Access your system from anywhere using that URL!${NC}"
    
    echo
    echo -e "${YELLOW}🔑 Login Credentials:${NC}"
    echo -e "   Username: $ADMIN_USERNAME"
    echo -e "   Password: $ADMIN_PASSWORD"
    echo -e "   Role: Administrator"
    
    echo
    echo -e "${YELLOW}🛠️  Manual Commands:${NC}"
    echo -e "${CYAN}   Start Django only: ./start_django.sh${NC}"
    echo -e "${CYAN}   Start tunnel only: ./start_tunnel.sh${NC}"
    echo -e "${CYAN}   Start as service: sudo systemctl start noctispro${NC}"
    echo -e "${CYAN}   View service logs: sudo journalctl -u noctispro -f${NC}"
    
    echo
    echo -e "${RED}🔐 Security Notes:${NC}"
    echo -e "${YELLOW}- Your system will be accessible from the internet${NC}"
    echo -e "${YELLOW}- Make sure to change default passwords in production${NC}"
    echo -e "${YELLOW}- Monitor access logs regularly${NC}"
    
    echo
    echo -e "${GREEN}🚀 Ready to launch? Run: ./start_noctispro_internet.sh${NC}"
    
    # Ask if user wants to start immediately
    read -p "Start NoctisPro now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}🚀 Starting NoctisPro...${NC}"
        ./start_noctispro_internet.sh
    fi
}

# Show usage if help requested
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "NoctisPro Internet Deployment Script"
    echo
    echo "Usage: $0 [PROJECT_PATH] [ADMIN_USERNAME] [ADMIN_PASSWORD] [ADMIN_EMAIL] [PORT] [TUNNEL_TYPE]"
    echo
    echo "Parameters:"
    echo "  PROJECT_PATH     - Path to NoctisPro project (default: current directory)"
    echo "  ADMIN_USERNAME   - Admin username (default: admin)"
    echo "  ADMIN_PASSWORD   - Admin password (default: Admin123!)"
    echo "  ADMIN_EMAIL      - Admin email (default: admin@noctispro.com)"
    echo "  PORT             - Local port (default: 8000)"
    echo "  TUNNEL_TYPE      - Tunnel type: cloudflare or ngrok (default: cloudflare)"
    echo
    echo "Example:"
    echo "  $0 /opt/noctispro admin MySecurePass admin@example.com 8080 cloudflare"
    exit 0
fi

# Run main function
main