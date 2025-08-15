#!/bin/bash
set -euo pipefail

# Noctis Pro Docker Setup Script for Ubuntu Server 24.04
# This script automates the complete installation process

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to get user input
get_input() {
    local prompt="$1"
    local default="$2"
    local result
    
    read -p "$prompt [$default]: " result
    echo "${result:-$default}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
    exit 1
fi

# Check if sudo is available
if ! command_exists sudo; then
    print_error "sudo is required but not installed. Please install sudo first."
    exit 1
fi

print_status "Starting Noctis Pro Docker Setup for Ubuntu Server 24.04"
echo "================================================================"

# Step 1: Update system
print_status "Step 1: Updating Ubuntu system..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget gnupg lsb-release ca-certificates git nano

print_success "System updated successfully"

# Step 2: Install Docker
print_status "Step 2: Installing Docker..."

# Remove old Docker installations
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package list and install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

print_success "Docker installed successfully"

# Step 3: Configure firewall
print_status "Step 3: Configuring firewall..."

sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8000/tcp
sudo ufw allow 11112/tcp
sudo ufw --force enable

print_success "Firewall configured"

# Step 4: Get configuration from user
print_status "Step 4: Collecting configuration information..."

echo ""
echo "Please provide the following information for your Noctis Pro installation:"
echo ""

ADMIN_USER=$(get_input "Admin username" "admin")
ADMIN_EMAIL=$(get_input "Admin email" "admin@localhost")
ADMIN_PASS=$(get_input "Admin password" "admin123")
DOMAIN_NAME=$(get_input "Domain name (optional)" "localhost")
IS_PRODUCTION=$(get_input "Is this a production deployment? (y/n)" "n")

# Generate secure secret key
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
POSTGRES_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))")

print_success "Configuration collected"

# Step 5: Setup project directory
print_status "Step 5: Setting up project directory..."

PROJECT_DIR="$HOME/NoctisPro"
if [[ -d "$PROJECT_DIR" ]]; then
    print_warning "Directory $PROJECT_DIR already exists. Backing up to ${PROJECT_DIR}.backup"
    sudo mv "$PROJECT_DIR" "${PROJECT_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
fi

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# If this script is being run from the source directory, copy files
if [[ -f "$(dirname "$0")/docker-compose.yml" ]]; then
    print_status "Copying Noctis Pro files..."
    cp "$(dirname "$0")"/* . 2>/dev/null || true
else
    print_warning "Docker files not found in script directory. Please ensure you have the Noctis Pro source code."
    print_status "You can download the source code and place it in $PROJECT_DIR"
    echo "Required files: Dockerfile, docker-compose.yml, .env.docker, requirements.txt"
    exit 1
fi

print_success "Project directory set up"

# Step 6: Create environment file
print_status "Step 6: Creating environment configuration..."

if [[ ! -f ".env.docker" ]]; then
    print_error ".env.docker template not found. Please ensure you have the complete Noctis Pro source code."
    exit 1
fi

cp .env.docker .env

# Update environment file with user settings
sed -i "s/SECRET_KEY=.*/SECRET_KEY=$SECRET_KEY/" .env
sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" .env
sed -i "s/ADMIN_USER=.*/ADMIN_USER=$ADMIN_USER/" .env
sed -i "s/ADMIN_EMAIL=.*/ADMIN_EMAIL=$ADMIN_EMAIL/" .env
sed -i "s/ADMIN_PASS=.*/ADMIN_PASS=$ADMIN_PASS/" .env

if [[ "$IS_PRODUCTION" == "y" || "$IS_PRODUCTION" == "Y" ]]; then
    sed -i "s/DEBUG=.*/DEBUG=False/" .env
    sed -i "s/BUILD_TARGET=.*/BUILD_TARGET=production/" .env
    if [[ "$DOMAIN_NAME" != "localhost" ]]; then
        sed -i "s/# DOMAIN_NAME=.*/DOMAIN_NAME=$DOMAIN_NAME/" .env
    fi
fi

# Set secure permissions
chmod 600 .env

print_success "Environment configured"

# Step 7: Build and start the system
print_status "Step 7: Building and starting Noctis Pro (this may take several minutes)..."

# Apply docker group membership (required for docker commands)
newgrp docker << EOF
# Build Docker images
docker compose build

# Start all services
docker compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 30

# Check service status
docker compose ps
EOF

print_success "Noctis Pro started successfully"

# Step 8: Display access information
print_status "Step 8: Getting access information..."

SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "🎉 Installation Complete!"
echo "========================="
echo ""
echo "Your Noctis Pro DICOM system is now running!"
echo ""
echo "📡 Access URLs:"
echo "   Web Interface: http://$SERVER_IP:8000"
echo "   Admin Panel:   http://$SERVER_IP:8000/admin-panel/"
echo "   Worklist:      http://$SERVER_IP:8000/worklist/"
echo ""
echo "🔐 Login Credentials:"
echo "   Username: $ADMIN_USER"
echo "   Password: $ADMIN_PASS"
echo ""
echo "🏥 DICOM Configuration:"
echo "   DICOM Port: $SERVER_IP:11112"
echo "   AE Title: NOCTIS_SCP"
echo ""
echo "📁 Project Location: $PROJECT_DIR"
echo ""
echo "🔧 Management Commands:"
echo "   View status:  docker compose ps"
echo "   View logs:    docker compose logs -f"
echo "   Stop system:  docker compose down"
echo "   Start system: docker compose up -d"
echo ""
echo "📚 Documentation:"
echo "   Full guide: $PROJECT_DIR/UBUNTU_DOCKER_SETUP.md"
echo "   Docker guide: $PROJECT_DIR/DOCKER_SETUP.md"
echo ""

# Final verification
print_status "Running final verification..."

cd "$PROJECT_DIR"
newgrp docker << EOF
# Check if all containers are running
if docker compose ps | grep -q "Up"; then
    echo "✅ Docker containers are running"
else
    echo "❌ Some containers may not be running properly"
    echo "Check status with: docker compose ps"
    echo "Check logs with: docker compose logs"
fi

# Test web interface
if curl -s -f "http://localhost:8000" > /dev/null; then
    echo "✅ Web interface is accessible"
else
    echo "❌ Web interface is not responding"
    echo "This may be normal if the system is still starting up"
    echo "Wait a few minutes and try accessing: http://$SERVER_IP:8000"
fi
EOF

print_warning "IMPORTANT SECURITY NOTES:"
echo "1. Change the default admin password after first login"
echo "2. Update the SECRET_KEY in production environments"
echo "3. Configure SSL/TLS for production deployments"
echo "4. Regularly backup your data and configuration"
echo ""

print_success "Setup completed! You may need to logout and login again to use Docker commands without sudo."

echo ""
echo "If you encounter any issues, check the troubleshooting section in:"
echo "$PROJECT_DIR/UBUNTU_DOCKER_SETUP.md"