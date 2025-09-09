#!/bin/bash

# ============================================================================
# Quick Setup Script for NoctisPro Bootable Creation on Parrot Security OS
# ============================================================================
# This script quickly prepares Parrot Security OS for creating bootable
# NoctisPro PACS Ubuntu Server media
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║         🦜 NoctisPro PACS - Parrot Quick Setup 🦜             ║
    ║                                                               ║
    ║  Prepares Parrot Security OS for creating bootable           ║
    ║  Ubuntu Server with NoctisPro PACS pre-installed             ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_parrot() {
    if [[ -f /etc/parrot-version ]] || grep -qi "parrot" /etc/os-release 2>/dev/null; then
        log "✅ Running on Parrot Security OS"
        parrot_version=$(cat /etc/parrot-version 2>/dev/null || echo "Unknown")
        info "Parrot version: $parrot_version"
    else
        warning "Not running on Parrot Security OS"
        info "This script is optimized for Parrot but may work on other Debian-based systems"
        read -p "Continue anyway? (y/n): " continue_choice
        if [[ $continue_choice != "y" ]]; then
            error "Aborted by user"
        fi
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use: sudo $0"
    fi
}

check_space() {
    log "Checking available disk space..."
    
    available_space=$(df /tmp --output=avail | tail -1)
    available_gb=$((available_space / 1024 / 1024))
    
    info "Available space in /tmp: ${available_gb}GB"
    
    if [[ $available_gb -lt 5 ]]; then
        error "Insufficient disk space. Need at least 5GB free in /tmp directory"
    fi
    
    log "✅ Sufficient disk space available"
}

update_system() {
    log "Updating Parrot Security OS..."
    
    # Update package lists
    apt update
    
    # Upgrade system (optional, ask user)
    read -p "Upgrade system packages? (recommended) (y/n): " upgrade_choice
    if [[ $upgrade_choice == "y" ]]; then
        apt upgrade -y
        log "✅ System upgraded"
    else
        log "⏭️ System upgrade skipped"
    fi
}

install_dependencies() {
    log "Installing required dependencies..."
    
    # Core dependencies for ISO creation
    local packages=(
        "wget"
        "curl"
        "genisoimage"
        "squashfs-tools"
        "xorriso"
        "isolinux"
        "syslinux-utils"
        "rsync"
        "p7zip-full"
        "gdisk"
        "parted"
        "dosfstools"
        "grub-pc-bin"
        "grub-efi-amd64-bin"
        "mtools"
        "git"
    )
    
    # Install packages
    for package in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii  $package "; then
            info "✅ $package already installed"
        else
            log "Installing $package..."
            apt install -y "$package"
        fi
    done
    
    log "✅ All dependencies installed"
}

setup_workspace() {
    log "Setting up workspace..."
    
    # Create working directory
    mkdir -p /tmp/noctispro_workspace
    cd /tmp/noctispro_workspace
    
    # Copy NoctisPro files if script is run from NoctisPro directory
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$script_dir/manage.py" ]]; then
        log "Copying NoctisPro files to workspace..."
        cp -r "$script_dir"/* /tmp/noctispro_workspace/
        log "✅ NoctisPro files copied"
    else
        warning "NoctisPro files not found in script directory"
        info "You may need to manually copy NoctisPro files to the workspace"
    fi
    
    # Make scripts executable
    chmod +x *.sh 2>/dev/null || true
    
    log "✅ Workspace ready at /tmp/noctispro_workspace"
}

detect_usb_devices() {
    log "Detecting USB storage devices..."
    
    echo ""
    echo "Available USB storage devices:"
    echo "=============================="
    
    local found_usb=false
    
    for device in /sys/block/sd*; do
        if [[ -d "$device" ]]; then
            device_name=$(basename "$device")
            if udevadm info --query=property --name="/dev/$device_name" 2>/dev/null | grep -q "ID_BUS=usb"; then
                size=$(cat "$device/size" 2>/dev/null || echo "0")
                size_gb=$((size * 512 / 1024 / 1024 / 1024))
                model=$(udevadm info --query=property --name="/dev/$device_name" 2>/dev/null | grep "ID_MODEL=" | cut -d= -f2 || echo "Unknown")
                
                if [[ $size_gb -ge 8 ]]; then
                    echo "  ✅ /dev/$device_name - ${size_gb}GB - $model (Suitable)"
                    found_usb=true
                else
                    echo "  ❌ /dev/$device_name - ${size_gb}GB - $model (Too small)"
                fi
            fi
        fi
    done
    
    if ! $found_usb; then
        warning "No suitable USB devices found (need 8GB+)"
        info "Please insert a USB drive with at least 8GB capacity"
    else
        log "✅ Suitable USB devices detected"
    fi
    
    echo ""
}

test_internet() {
    log "Testing internet connectivity..."
    
    if ping -c 1 google.com &> /dev/null; then
        log "✅ Internet connection available"
    else
        warning "❌ Internet connection not available"
        info "Internet is required to download Ubuntu Server ISO (~1.5GB)"
        read -p "Continue anyway? (y/n): " continue_choice
        if [[ $continue_choice != "y" ]]; then
            error "Aborted - Internet connection required"
        fi
    fi
}

show_next_steps() {
    echo ""
    echo -e "${GREEN}🎉 Parrot Security OS is ready for NoctisPro bootable creation!${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo ""
    echo "1. Navigate to workspace:"
    echo "   cd /tmp/noctispro_workspace"
    echo ""
    echo "2. Create bootable media:"
    echo "   sudo ./create_bootable_ubuntu.sh"
    echo ""
    echo "3. Follow the interactive prompts to:"
    echo "   • Choose USB drive or ISO creation"
    echo "   • Select target USB device"
    echo "   • Configure installation options"
    echo ""
    echo -e "${CYAN}Alternative Commands:${NC}"
    echo ""
    echo "# Create ISO file only:"
    echo "sudo ./create_bootable_ubuntu.sh --iso-only"
    echo ""
    echo "# Create USB drive only:"
    echo "sudo ./create_bootable_ubuntu.sh --usb-only --device /dev/sdX"
    echo ""
    echo "# Show help:"
    echo "./create_bootable_ubuntu.sh --help"
    echo ""
    echo -e "${YELLOW}⚠️ Important Notes:${NC}"
    echo "• USB creation will ERASE ALL DATA on the selected device"
    echo "• Process takes 15-30 minutes depending on internet speed"
    echo "• Ensure 5GB+ free space in /tmp directory"
    echo "• Keep internet connection stable during download"
    echo ""
    echo -e "${GREEN}Ready to create your NoctisPro PACS bootable system!${NC}"
}

main() {
    show_banner
    
    check_root
    check_parrot
    check_space
    test_internet
    update_system
    install_dependencies
    setup_workspace
    detect_usb_devices
    
    show_next_steps
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "NoctisPro PACS Quick Setup for Parrot Security OS"
        echo ""
        echo "This script prepares Parrot Security OS for creating"
        echo "bootable Ubuntu Server media with NoctisPro PACS."
        echo ""
        echo "Usage: sudo $0"
        echo ""
        echo "What it does:"
        echo "• Updates system packages"
        echo "• Installs required dependencies"
        echo "• Sets up workspace"
        echo "• Detects USB devices"
        echo "• Prepares for bootable creation"
        exit 0
        ;;
esac

main "$@"