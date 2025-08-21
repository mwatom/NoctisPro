#!/bin/bash

echo "════════════════════════════════════════════════════════════"
echo "🏥 NOCTIS PRO MEDICAL IMAGING SYSTEM - PRODUCTION DEPLOYMENT 🏥"
echo "════════════════════════════════════════════════════════════"
echo ""

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

echo "✅ Docker is installed and running!"
echo ""

# Create necessary directories
echo "🚀 Creating data directories..."
mkdir -p data/postgres
mkdir -p data/redis  
mkdir -p data/media
mkdir -p data/static
mkdir -p data/dicom_storage
mkdir -p backups
echo "✅ Data directories created!"
echo ""

# Set proper permissions
echo "🔐 Setting proper permissions..."
chmod 755 data
chmod 755 data/*
echo "✅ Permissions set!"
echo ""

# Build and start services
echo "🏗️  Building Docker images..."
docker compose -f docker-compose.desktop.yml build

if [ $? -eq 0 ]; then
    echo "✅ Docker images built successfully!"
    echo ""
    
    echo "🚀 Starting Noctis Pro Medical Imaging System..."
    docker compose -f docker-compose.desktop.yml up -d
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Noctis Pro is now running!"
        echo ""
        echo "📋 Service Status:"
        docker compose -f docker-compose.desktop.yml ps
        echo ""
        echo "🌐 Access your medical imaging system:"
        echo "   • Web Interface: http://localhost:8000"
        echo "   • DICOM Receiver: localhost:11112"
        echo "   • Database Admin: http://localhost:8080 (if adminer is enabled)"
        echo ""
        echo "📝 To view logs: docker compose -f docker-compose.desktop.yml logs -f"
        echo "🛑 To stop: docker compose -f docker-compose.desktop.yml down"
        echo ""
        echo "🎉 Deployment completed successfully!"
    else
        echo "❌ Failed to start services. Check the logs for more information."
        exit 1
    fi
else
    echo "❌ Failed to build Docker images. Please check the error messages above."
    exit 1
fi