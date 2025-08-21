#!/bin/bash
set -e

# Comprehensive Docker Installation Script
# This script handles common installation issues and provides better error handling

echo "=== Docker Installation Script ==="
echo "Starting Docker installation process..."

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

# Function to check if running as root or with sudo
check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root or with sudo"
        print_status "Please run: sudo $0"
        exit 1
    fi
}

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        print_status "Detected OS: $OS $VER"
    else
        print_error "Cannot detect OS version"
        exit 1
    fi
}

# Function to update package manager
update_packages() {
    print_status "Updating package manager..."
    
    if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y ca-certificates curl gnupg lsb-release
    elif command -v yum >/dev/null 2>&1; then
        yum update -y
        yum install -y yum-utils device-mapper-persistent-data lvm2
    elif command -v dnf >/dev/null 2>&1; then
        dnf update -y
        dnf install -y dnf-plugins-core
    else
        print_error "Unsupported package manager"
        exit 1
    fi
}

# Function to remove old Docker installations
remove_old_docker() {
    print_status "Removing old Docker installations..."
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get remove -y docker docker-engine docker.io containerd runc docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
    elif command -v yum >/dev/null 2>&1; then
        yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine 2>/dev/null || true
    fi
}

# Function to install Docker on Ubuntu/Debian
install_docker_ubuntu() {
    print_status "Installing Docker on Ubuntu/Debian..."
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add the repository to Apt sources
    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index
    apt-get update -y
    
    # Install Docker Engine
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Function to install Docker on CentOS/RHEL
install_docker_centos() {
    print_status "Installing Docker on CentOS/RHEL..."
    
    # Add Docker repository
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install Docker Engine
    yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Function to install Docker on Fedora
install_docker_fedora() {
    print_status "Installing Docker on Fedora..."
    
    # Add Docker repository
    dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    
    # Install Docker Engine
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Function to start and enable Docker service
start_docker_service() {
    print_status "Starting and enabling Docker service..."
    
    systemctl start docker
    systemctl enable docker
    
    # Check if Docker service is running
    if systemctl is-active --quiet docker; then
        print_status "Docker service is running successfully"
    else
        print_error "Failed to start Docker service"
        exit 1
    fi
}

# Function to add user to docker group
configure_docker_permissions() {
    print_status "Configuring Docker permissions..."
    
    # Create docker group if it doesn't exist
    groupadd -f docker
    
    # Add current user to docker group (if not root)
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
        print_status "Added user '$SUDO_USER' to docker group"
        print_warning "You may need to log out and back in for group changes to take effect"
    fi
    
    # Add ubuntu user to docker group (common in cloud environments)
    if id "ubuntu" &>/dev/null; then
        usermod -aG docker ubuntu
        print_status "Added user 'ubuntu' to docker group"
    fi
}

# Function to test Docker installation
test_docker() {
    print_status "Testing Docker installation..."
    
    # Test with current user if not root
    if [ -n "$SUDO_USER" ]; then
        sudo -u $SUDO_USER docker --version
        print_status "Docker version check successful"
        
        # Try to run hello-world container
        print_status "Running Docker hello-world test..."
        sudo -u $SUDO_USER docker run --rm hello-world
    else
        docker --version
        print_status "Docker version check successful"
        
        # Try to run hello-world container
        print_status "Running Docker hello-world test..."
        docker run --rm hello-world
    fi
}

# Function to install Docker Compose (if not already installed)
install_docker_compose() {
    print_status "Checking Docker Compose installation..."
    
    if ! command -v docker-compose >/dev/null 2>&1; then
        print_status "Installing Docker Compose..."
        
        # Get latest version
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
        
        # Download and install
        curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        
        # Create symlink for easier access
        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
        
        print_status "Docker Compose installed successfully"
    else
        print_status "Docker Compose is already installed"
    fi
}

# Main installation process
main() {
    print_status "Starting Docker installation..."
    
    # Check privileges
    check_privileges
    
    # Detect OS
    detect_os
    
    # Update packages
    update_packages
    
    # Remove old Docker installations
    remove_old_docker
    
    # Install Docker based on OS
    case "$OS" in
        *"Ubuntu"*|*"Debian"*)
            install_docker_ubuntu
            ;;
        *"CentOS"*|*"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
            install_docker_centos
            ;;
        *"Fedora"*)
            install_docker_fedora
            ;;
        *)
            print_warning "Unsupported OS: $OS. Trying generic installation..."
            # Fall back to the existing get-docker.sh script
            if [ -f "/workspace/get-docker.sh" ]; then
                chmod +x /workspace/get-docker.sh
                sh /workspace/get-docker.sh
            else
                print_error "No fallback installation method available"
                exit 1
            fi
            ;;
    esac
    
    # Start Docker service
    start_docker_service
    
    # Configure permissions
    configure_docker_permissions
    
    # Install Docker Compose
    install_docker_compose
    
    # Test installation
    test_docker
    
    print_status "Docker installation completed successfully!"
    print_status "Docker version: $(docker --version)"
    print_status "Docker Compose version: $(docker-compose --version)"
    
    print_warning "If you added users to the docker group, they may need to log out and back in"
    print_status "You can now use Docker without sudo (after re-login if needed)"
}

# Run main function
main "$@"