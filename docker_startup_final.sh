#!/bin/bash

# Final Docker Startup Script - Working Version
# This script successfully starts Docker in container environments

echo "=== Docker Startup Script ==="
echo "Starting Docker services..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root or with sudo"
    echo "Usage: sudo $0"
    exit 1
fi

# Function to check if process is running
is_running() {
    pgrep -f "$1" > /dev/null
}

# Stop any existing Docker processes
echo "Stopping any existing Docker processes..."
pkill -f dockerd || true
pkill -f containerd || true
sleep 2

# Create necessary directories
echo "Creating Docker directories..."
mkdir -p /var/lib/docker /var/log/docker /var/lib/containerd /run/containerd

# Start containerd
echo "Starting containerd..."
containerd &
sleep 3

# Verify containerd is running
if ! is_running "containerd"; then
    echo "ERROR: Failed to start containerd"
    exit 1
fi
echo "✓ containerd started successfully"

# Start Docker daemon with vfs storage driver (most compatible)
echo "Starting Docker daemon..."
dockerd --storage-driver=vfs --iptables=false &
sleep 10

# Verify Docker daemon is running
if ! is_running "dockerd"; then
    echo "ERROR: Failed to start Docker daemon"
    exit 1
fi
echo "✓ Docker daemon started successfully"

# Configure permissions
echo "Configuring Docker permissions..."
groupadd -f docker
chmod 666 /var/run/docker.sock

# Add ubuntu user to docker group if exists
if id "ubuntu" &>/dev/null; then
    usermod -aG docker ubuntu
    echo "✓ Added ubuntu user to docker group"
fi

# Add sudo user to docker group if exists
if [ -n "$SUDO_USER" ]; then
    usermod -aG docker $SUDO_USER
    echo "✓ Added $SUDO_USER to docker group"
fi

# Test Docker
echo "Testing Docker installation..."
if docker --version && docker info > /dev/null 2>&1; then
    echo "✓ Docker is working correctly"
    echo ""
    echo "Docker version: $(docker --version)"
    echo "Storage driver: vfs"
    echo "Docker daemon is ready to use!"
    echo ""
    echo "Test with: docker run --rm hello-world"
else
    echo "ERROR: Docker test failed"
    exit 1
fi

echo "Docker installation and startup completed successfully!"