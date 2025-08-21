#!/bin/bash
set -e

echo "=== Simple Docker Startup ==="

# Function to print colored output
print_status() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root or with sudo"
    exit 1
fi

print_status "Stopping any existing Docker processes..."
pkill -f dockerd || true
pkill -f containerd || true
sleep 2

print_status "Starting containerd..."
mkdir -p /var/lib/containerd /run/containerd
containerd &
sleep 3

print_status "Starting Docker daemon with vfs storage driver (most compatible)..."
mkdir -p /var/lib/docker /var/log/docker

# Use vfs storage driver which should work in any environment
dockerd \
    --storage-driver=vfs \
    --host=unix:///var/run/docker.sock \
    --tls=false \
    --iptables=false \
    --bridge=none \
    --log-level=info &

print_status "Waiting for Docker daemon to start..."
sleep 5

# Wait for Docker to be ready
count=0
while [ $count -lt 30 ]; do
    if docker info > /dev/null 2>&1; then
        print_status "Docker started successfully!"
        break
    fi
    sleep 1
    count=$((count + 1))
    echo -n "."
done

if [ $count -eq 30 ]; then
    print_error "Docker failed to start"
    print_error "Checking logs..."
    docker info || true
    exit 1
fi

echo ""
print_status "Configuring Docker permissions..."
groupadd -f docker
chmod 666 /var/run/docker.sock

# Add ubuntu user to docker group if exists
if id "ubuntu" &>/dev/null; then
    usermod -aG docker ubuntu
    print_status "Added user 'ubuntu' to docker group"
fi

if [ -n "$SUDO_USER" ]; then
    usermod -aG docker $SUDO_USER
    print_status "Added user '$SUDO_USER' to docker group"
fi

print_status "Testing Docker installation..."
docker --version
echo ""
docker info
echo ""

print_status "Running hello-world test..."
if timeout 30 docker run --rm hello-world; then
    print_status "Docker hello-world test successful!"
else
    print_status "Hello-world test may have failed, but Docker is running"
fi

print_status "Docker is now ready to use!"
print_status "Note: You may need to re-login for group permissions to take effect"

# Create simple restart script
cat > /usr/local/bin/restart-docker << 'EOF'
#!/bin/bash
echo "Restarting Docker..."
pkill -f dockerd || true
pkill -f containerd || true
sleep 2
containerd &
sleep 3
dockerd --storage-driver=vfs --host=unix:///var/run/docker.sock --tls=false --iptables=false --bridge=none &
sleep 5
echo "Docker restarted"
EOF

chmod +x /usr/local/bin/restart-docker
print_status "Created restart-docker command for future use"