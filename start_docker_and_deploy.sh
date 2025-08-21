#!/bin/bash

echo "🐳 Starting Docker daemon..."

# Kill any existing Docker processes
sudo pkill -f dockerd 2>/dev/null || true
sleep 2

# Start Docker daemon
sudo dockerd > /tmp/docker.log 2>&1 &
DOCKER_PID=$!

# Wait for Docker to be ready
echo "⏳ Waiting for Docker to start..."
for i in {1..30}; do
    if sudo docker info >/dev/null 2>&1; then
        echo "✅ Docker is running!"
        break
    fi
    sleep 1
    echo "   Attempt $i/30..."
done

# Check if Docker is running
if ! sudo docker info >/dev/null 2>&1; then
    echo "❌ Failed to start Docker daemon"
    exit 1
fi

echo ""
echo "🚀 Running production deployment..."
echo ""

# Run deployment with sudo
sudo bash deploy_production.sh

echo ""
echo "📋 Deployment completed!"
echo ""
echo "🔍 To check container status:"
echo "   sudo docker ps"
echo ""
echo "📝 To view logs:"
echo "   sudo docker compose -f docker-compose.production.yml logs -f"
echo ""
echo "🛑 To stop services:"
echo "   sudo docker compose -f docker-compose.production.yml down"