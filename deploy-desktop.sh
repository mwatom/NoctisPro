#!/bin/bash

# 🚀 NoctisPro - Simple Desktop Deployment
# This script sets up NoctisPro on Ubuntu Desktop in minutes!

set -e

echo "🚀 Starting NoctisPro Desktop Deployment..."
echo "=========================================="

# Check if running on Ubuntu
if ! lsb_release -a 2>/dev/null | grep -q Ubuntu; then
    echo "❌ This script is designed for Ubuntu. Please run on Ubuntu Desktop."
    exit 1
fi

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "✅ Docker installed! You may need to log out and back in."
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "📦 Installing Docker Compose..."
    sudo apt update
    sudo apt install -y docker-compose-plugin
    echo "✅ Docker Compose installed!"
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p backups logs ssl

# Build and start services
echo "🔨 Building and starting NoctisPro..."
docker compose -f docker-compose.simple.yml build
docker compose -f docker-compose.simple.yml up -d

echo "⏳ Waiting for services to start..."
sleep 30

# Check if services are running
echo "🔍 Checking service status..."
if docker compose -f docker-compose.simple.yml ps | grep -q "Up"; then
    echo "✅ Services are running!"
else
    echo "❌ Some services failed to start. Check logs:"
    docker compose -f docker-compose.simple.yml logs
    exit 1
fi

# Create superuser (optional)
echo ""
echo "👤 Would you like to create an admin user? (y/n)"
read -r create_user
if [[ $create_user =~ ^[Yy]$ ]]; then
    echo "Creating admin user..."
    docker compose -f docker-compose.simple.yml exec web python manage.py createsuperuser
fi

echo ""
echo "🎉 NoctisPro Desktop Deployment Complete!"
echo "=========================================="
echo ""
echo "📱 Access your application:"
echo "   Web Interface: http://localhost:8000"
echo "   Admin Panel:   http://localhost:8000/admin"
echo "   DICOM Port:    11112"
echo ""
echo "🔧 Useful commands:"
echo "   View logs:     docker compose -f docker-compose.simple.yml logs -f"
echo "   Stop:          docker compose -f docker-compose.simple.yml down"
echo "   Restart:       docker compose -f docker-compose.simple.yml restart"
echo ""
echo "📂 Data is stored in Docker volumes and will persist between restarts."
echo ""
echo "🌐 Ready to migrate to server? Run: ./deploy-server.sh"
echo ""