#!/bin/bash
set -e

# Docker startup script for container environments with storage driver fixes
# This script handles common Docker-in-Docker issues

echo "=== Fixed Docker Startup Script ==="

# Function to print colored output
print_status() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

# Function to detect available storage drivers
detect_storage_driver() {
    print_status "Detecting available storage drivers..."
    
    # Check for available storage drivers
    if grep -q "overlay" /proc/filesystems 2>/dev/null; then
        print_status "overlay filesystem is available"
        STORAGE_DRIVER="overlay"
    elif grep -q "aufs" /proc/filesystems 2>/dev/null; then
        print_status "aufs filesystem is available"
        STORAGE_DRIVER="aufs"
    elif grep -q "devicemapper" /proc/filesystems 2>/dev/null; then
        print_status "devicemapper is available"
        STORAGE_DRIVER="devicemapper"
    else
        print_status "Using vfs storage driver (slower but compatible)"
        STORAGE_DRIVER="vfs"
    fi
    
    print_status "Selected storage driver: $STORAGE_DRIVER"
}

# Function to check if Docker daemon is running
check_docker_daemon() {
    if pgrep -f "dockerd" > /dev/null; then
        print_status "Docker daemon is already running"
        return 0
    else
        return 1
    fi
}

# Function to start containerd
start_containerd() {
    print_status "Starting containerd..."
    
    # Check if containerd is already running
    if pgrep -f "containerd" > /dev/null; then
        print_status "containerd is already running"
    else
        # Create containerd directories
        mkdir -p /var/lib/containerd
        mkdir -p /run/containerd
        
        # Start containerd in background
        nohup containerd > /var/log/containerd.log 2>&1 &
        sleep 3
        
        if pgrep -f "containerd" > /dev/null; then
            print_status "containerd started successfully"
        else
            print_error "Failed to start containerd"
            return 1
        fi
    fi
}

# Function to start Docker daemon with proper configuration
start_docker_daemon() {
    print_status "Starting Docker daemon..."
    
    # Check if Docker daemon is already running
    if check_docker_daemon; then
        return 0
    fi
    
    # Detect storage driver
    detect_storage_driver
    
    # Create Docker directories if they don't exist
    mkdir -p /var/lib/docker
    mkdir -p /var/log/docker
    mkdir -p /etc/docker
    
    # Create Docker daemon configuration
    cat > /etc/docker/daemon.json << EOF
{
    "storage-driver": "$STORAGE_DRIVER",
    "hosts": ["unix:///var/run/docker.sock"],
    "log-level": "info",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "tls": false,
    "experimental": false,
    "live-restore": false
}
EOF
    
    print_status "Created Docker daemon configuration with $STORAGE_DRIVER storage driver"
    
    # Kill any existing Docker processes
    pkill -f dockerd || true
    sleep 2
    
    # Start Docker daemon in background with specific configuration
    print_status "Launching dockerd in background..."
    nohup dockerd \
        --storage-driver="$STORAGE_DRIVER" \
        --host=unix:///var/run/docker.sock \
        --tls=false \
        --log-level=info \
        > /var/log/docker/dockerd.log 2>&1 &
    
    # Wait for Docker daemon to start
    print_status "Waiting for Docker daemon to start..."
    local count=0
    while [ $count -lt 60 ]; do
        if docker info > /dev/null 2>&1; then
            print_status "Docker daemon started successfully"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        if [ $((count % 10)) -eq 0 ]; then
            echo -n " (${count}s)"
        else
            echo -n "."
        fi
    done
    
    echo ""
    print_error "Docker daemon failed to start within 60 seconds"
    print_error "Checking logs..."
    tail -20 /var/log/docker/dockerd.log
    return 1
}

# Function to configure Docker permissions
configure_docker_permissions() {
    print_status "Configuring Docker permissions..."
    
    # Create docker group if it doesn't exist
    if ! getent group docker > /dev/null 2>&1; then
        groupadd docker
        print_status "Created docker group"
    fi
    
    # Add current user to docker group (if not root)
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
        print_status "Added user '$SUDO_USER' to docker group"
    fi
    
    # Add ubuntu user to docker group (common in cloud environments)
    if id "ubuntu" &>/dev/null; then
        usermod -aG docker ubuntu
        print_status "Added user 'ubuntu' to docker group"
    fi
    
    # Set permissions on Docker socket
    if [ -S /var/run/docker.sock ]; then
        chmod 666 /var/run/docker.sock
        print_status "Set permissions on Docker socket"
    fi
}

# Function to test Docker installation
test_docker() {
    print_status "Testing Docker installation..."
    
    # Test Docker version
    if docker --version; then
        print_status "Docker version check successful"
    else
        print_error "Docker version check failed"
        return 1
    fi
    
    # Test Docker info
    print_status "Getting Docker system information..."
    if docker info; then
        print_status "Docker daemon connection successful"
    else
        print_error "Cannot connect to Docker daemon"
        return 1
    fi
    
    # Try to run hello-world container
    print_status "Running Docker hello-world test..."
    if timeout 60 docker run --rm hello-world; then
        print_status "Docker hello-world test successful"
    else
        print_warning "Docker hello-world test failed or timed out"
        print_status "But basic Docker functionality is working"
    fi
}

# Function to create startup script for future use
create_startup_script() {
    print_status "Creating Docker startup script for future use..."
    
    cat > /usr/local/bin/start-docker << 'EOF'
#!/bin/bash

# Quick Docker startup script
echo "Starting Docker services..."

# Start containerd if not running
if ! pgrep -f "containerd" > /dev/null; then
    mkdir -p /var/lib/containerd /run/containerd
    nohup containerd > /var/log/containerd.log 2>&1 &
    sleep 3
fi

# Start Docker daemon if not running
if ! pgrep -f "dockerd" > /dev/null; then
    mkdir -p /var/lib/docker /var/log/docker
    
    # Detect storage driver
    if grep -q "overlay" /proc/filesystems 2>/dev/null; then
        STORAGE_DRIVER="overlay"
    elif grep -q "aufs" /proc/filesystems 2>/dev/null; then
        STORAGE_DRIVER="aufs"
    elif grep -q "devicemapper" /proc/filesystems 2>/dev/null; then
        STORAGE_DRIVER="devicemapper"
    else
        STORAGE_DRIVER="vfs"
    fi
    
    nohup dockerd \
        --storage-driver="$STORAGE_DRIVER" \
        --host=unix:///var/run/docker.sock \
        --tls=false \
        --log-level=info \
        > /var/log/docker/dockerd.log 2>&1 &
fi

# Wait for Docker to be ready
count=0
while [ $count -lt 30 ]; do
    if docker info > /dev/null 2>&1; then
        echo "Docker is ready!"
        exit 0
    fi
    sleep 1
    count=$((count + 1))
done

echo "Docker failed to start"
exit 1
EOF

    chmod +x /usr/local/bin/start-docker
    print_status "Created /usr/local/bin/start-docker for future use"
}

# Main function
main() {
    print_status "Starting Docker setup for container environment..."
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Start containerd
    start_containerd
    
    # Start Docker daemon
    start_docker_daemon
    
    # Configure permissions
    configure_docker_permissions
    
    # Create startup script for future use
    create_startup_script
    
    # Test Docker
    test_docker
    
    print_status "Docker setup completed successfully!"
    print_status "Docker is now running and ready to use"
    print_status "Use 'start-docker' command to start Docker in future sessions"
}

# Run main function
main "$@"