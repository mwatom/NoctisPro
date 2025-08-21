#!/bin/bash
set -e

# Docker startup script for non-systemd environments (containers, etc.)
# This script manually starts Docker daemon and services

echo "=== Docker Startup Script (Non-systemd) ==="

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

# Function to check if Docker daemon is running
check_docker_daemon() {
    if pgrep -f "dockerd" > /dev/null; then
        print_status "Docker daemon is already running"
        return 0
    else
        print_warning "Docker daemon is not running"
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
        # Start containerd in background
        nohup containerd > /var/log/containerd.log 2>&1 &
        sleep 2
        
        if pgrep -f "containerd" > /dev/null; then
            print_status "containerd started successfully"
        else
            print_error "Failed to start containerd"
            return 1
        fi
    fi
}

# Function to start Docker daemon
start_docker_daemon() {
    print_status "Starting Docker daemon..."
    
    # Check if Docker daemon is already running
    if check_docker_daemon; then
        return 0
    fi
    
    # Create Docker directories if they don't exist
    mkdir -p /var/lib/docker
    mkdir -p /var/log/docker
    
    # Start Docker daemon in background
    print_status "Launching dockerd in background..."
    nohup dockerd \
        --host=unix:///var/run/docker.sock \
        --host=tcp://0.0.0.0:2376 \
        --storage-driver=overlay2 \
        > /var/log/docker/dockerd.log 2>&1 &
    
    # Wait for Docker daemon to start
    print_status "Waiting for Docker daemon to start..."
    local count=0
    while [ $count -lt 30 ]; do
        if docker info > /dev/null 2>&1; then
            print_status "Docker daemon started successfully"
            return 0
        fi
        sleep 1
        count=$((count + 1))
        echo -n "."
    done
    
    echo ""
    print_error "Docker daemon failed to start within 30 seconds"
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
    if docker info > /dev/null 2>&1; then
        print_status "Docker daemon connection successful"
    else
        print_error "Cannot connect to Docker daemon"
        return 1
    fi
    
    # Try to run hello-world container
    print_status "Running Docker hello-world test..."
    if docker run --rm hello-world; then
        print_status "Docker hello-world test successful"
    else
        print_warning "Docker hello-world test failed, but basic Docker is working"
    fi
}

# Function to create Docker service script
create_docker_service_script() {
    print_status "Creating Docker service management script..."
    
    cat > /usr/local/bin/docker-service << 'EOF'
#!/bin/bash

case "$1" in
    start)
        echo "Starting Docker services..."
        
        # Start containerd if not running
        if ! pgrep -f "containerd" > /dev/null; then
            nohup containerd > /var/log/containerd.log 2>&1 &
            sleep 2
        fi
        
        # Start Docker daemon if not running
        if ! pgrep -f "dockerd" > /dev/null; then
            mkdir -p /var/lib/docker /var/log/docker
            nohup dockerd \
                --host=unix:///var/run/docker.sock \
                --host=tcp://0.0.0.0:2376 \
                --storage-driver=overlay2 \
                > /var/log/docker/dockerd.log 2>&1 &
        fi
        
        # Wait for Docker to be ready
        count=0
        while [ $count -lt 30 ]; do
            if docker info > /dev/null 2>&1; then
                echo "Docker services started successfully"
                exit 0
            fi
            sleep 1
            count=$((count + 1))
        done
        
        echo "Failed to start Docker services"
        exit 1
        ;;
    stop)
        echo "Stopping Docker services..."
        pkill -f "dockerd" || true
        pkill -f "containerd" || true
        echo "Docker services stopped"
        ;;
    restart)
        $0 stop
        sleep 2
        $0 start
        ;;
    status)
        if pgrep -f "dockerd" > /dev/null; then
            echo "Docker daemon is running"
            docker info
        else
            echo "Docker daemon is not running"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF

    chmod +x /usr/local/bin/docker-service
    print_status "Docker service script created at /usr/local/bin/docker-service"
}

# Main function
main() {
    print_status "Starting Docker setup for non-systemd environment..."
    
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
    
    # Create service management script
    create_docker_service_script
    
    # Test Docker
    test_docker
    
    print_status "Docker setup completed successfully!"
    print_status "You can manage Docker using: /usr/local/bin/docker-service {start|stop|restart|status}"
    print_status "Docker daemon is running and ready to use"
    
    # Show Docker info
    docker info
}

# Run main function
main "$@"