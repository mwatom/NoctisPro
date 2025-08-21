#!/bin/bash

echo "🔧 Fixing Docker issues on Ubuntu Server 24.04..."

# Install iptables-legacy to fix nf_tables issues
echo "📦 Installing iptables-legacy..."
sudo apt update
sudo apt install -y iptables-persistent

# Switch to iptables-legacy
echo "🔄 Switching to iptables-legacy..."
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

# Install fuse-overlayfs for storage driver
echo "📦 Installing fuse-overlayfs..."
sudo apt install -y fuse-overlayfs

# Create Docker daemon configuration
echo "⚙️  Configuring Docker daemon..."
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "storage-driver": "vfs",
    "iptables": true,
    "ip-forward": true,
    "bridge": "none"
}
EOF

echo "✅ Docker configuration complete!"
echo ""
echo "🚀 Now you can run the deployment:"
echo "   sudo dockerd > /tmp/docker.log 2>&1 &"
echo "   sleep 10"
echo "   sudo docker compose -f docker-compose.production.yml --env-file .env.production up -d --build"