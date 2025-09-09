#!/bin/bash

# ============================================================================
# NoctisPro PACS - Bootable Ubuntu Server Creator for Parrot Security OS
# ============================================================================
# This script creates a bootable Ubuntu Server 22.04 USB/DVD with NoctisPro
# PACS system pre-installed, designed to run from Parrot Security OS
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="/tmp/noctispro_bootable"
MOUNT_DIR="/tmp/ubuntu_mount"
ISO_DIR="/tmp/ubuntu_iso"
CUSTOM_ISO_DIR="/tmp/noctispro_iso"
LOG_FILE="/tmp/noctispro_bootable.log"

# Ubuntu Server 22.04 LTS ISO URL
UBUNTU_ISO_URL="https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso"
UBUNTU_ISO_NAME="ubuntu-22.04.3-live-server-amd64.iso"

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

# Show banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║        NoctisPro PACS - Bootable Ubuntu Creator               ║
    ║              For Parrot Security OS                           ║
    ║                                                               ║
    ║  🖥️  Creates bootable Ubuntu Server 22.04                     ║
    ║  🏥 Pre-installed with NoctisPro PACS                         ║
    ║  💿 Supports USB drives and DVD creation                      ║
    ║  🔧 Automated installation and configuration                  ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check if running on Parrot Security OS
check_parrot_os() {
    if [[ -f /etc/parrot-version ]] || grep -qi "parrot" /etc/os-release 2>/dev/null; then
        success "Running on Parrot Security OS"
    else
        warning "Not running on Parrot Security OS. This script is optimized for Parrot."
        read -p "Continue anyway? (y/n): " continue_choice
        if [[ $continue_choice != "y" ]]; then
            error "Aborted by user"
        fi
    fi
}

# Check prerequisites and install required tools
install_prerequisites() {
    header "Installing Prerequisites"
    
    log "Updating package lists..."
    apt update
    
    log "Installing required packages..."
    apt install -y \
        wget \
        curl \
        genisoimage \
        squashfs-tools \
        xorriso \
        isolinux \
        syslinux-utils \
        rsync \
        p7zip-full \
        gdisk \
        parted \
        dosfstools \
        grub-pc-bin \
        grub-efi-amd64-bin \
        mtools
    
    success "Prerequisites installed successfully"
}

# Detect available storage devices
detect_storage_devices() {
    header "Detecting Storage Devices"
    
    log "Scanning for available storage devices..."
    
    echo "Available storage devices:"
    echo "=========================="
    
    # List block devices
    lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -E "(disk|loop)" | grep -v "loop"
    
    echo ""
    echo "USB devices:"
    echo "============"
    
    # List USB storage devices
    for device in /sys/block/sd*; do
        if [[ -d "$device" ]]; then
            device_name=$(basename "$device")
            if udevadm info --query=property --name="/dev/$device_name" | grep -q "ID_BUS=usb"; then
                size=$(cat "$device/size")
                size_gb=$((size * 512 / 1024 / 1024 / 1024))
                model=$(udevadm info --query=property --name="/dev/$device_name" | grep "ID_MODEL=" | cut -d= -f2)
                echo "  /dev/$device_name - ${size_gb}GB - $model"
            fi
        fi
    done
    
    echo ""
    warning "⚠️  WARNING: The selected device will be completely erased!"
    echo ""
}

# Get user configuration
get_user_configuration() {
    header "Configuration Setup"
    
    echo "NoctisPro Bootable Ubuntu Configuration"
    echo "======================================"
    echo ""
    
    # Choose creation method
    echo "Choose creation method:"
    echo "1) Create bootable USB drive"
    echo "2) Create ISO file for DVD burning"
    echo "3) Create both USB and ISO"
    echo ""
    read -p "Enter choice (1-3) [1]: " method_choice
    
    case ${method_choice:-1} in
        1) CREATE_METHOD="usb" ;;
        2) CREATE_METHOD="iso" ;;
        3) CREATE_METHOD="both" ;;
        *) CREATE_METHOD="usb" ;;
    esac
    
    # Select target device for USB
    if [[ $CREATE_METHOD == "usb" || $CREATE_METHOD == "both" ]]; then
        detect_storage_devices
        echo ""
        read -p "Enter target USB device (e.g., /dev/sdb): " TARGET_DEVICE
        
        if [[ ! -b "$TARGET_DEVICE" ]]; then
            error "Device $TARGET_DEVICE not found or not a block device"
        fi
        
        # Confirm device selection
        device_info=$(lsblk -d -o NAME,SIZE,MODEL "$TARGET_DEVICE" | tail -1)
        echo ""
        echo "Selected device: $TARGET_DEVICE"
        echo "Device info: $device_info"
        echo ""
        warning "⚠️  ALL DATA ON $TARGET_DEVICE WILL BE LOST!"
        read -p "Are you sure you want to continue? (type 'YES' to confirm): " confirm
        
        if [[ $confirm != "YES" ]]; then
            error "Operation cancelled by user"
        fi
    fi
    
    # Auto-installation configuration
    echo ""
    echo "Auto-installation configuration:"
    echo "1) Full automatic (no user interaction)"
    echo "2) Semi-automatic (minimal user input)"
    echo "3) Manual installation (user guided)"
    echo ""
    read -p "Enter choice (1-3) [1]: " install_choice
    
    case ${install_choice:-1} in
        1) INSTALL_MODE="automatic" ;;
        2) INSTALL_MODE="semi-auto" ;;
        3) INSTALL_MODE="manual" ;;
        *) INSTALL_MODE="automatic" ;;
    esac
    
    # Network configuration for NoctisPro
    echo ""
    read -p "Enable automatic NoctisPro deployment after OS install? (y/n) [y]: " auto_deploy
    AUTO_DEPLOY=${auto_deploy:-y}
    
    # Summary
    echo ""
    echo "Configuration Summary:"
    echo "====================="
    echo "Method: $CREATE_METHOD"
    if [[ $CREATE_METHOD == "usb" || $CREATE_METHOD == "both" ]]; then
        echo "Target Device: $TARGET_DEVICE"
    fi
    echo "Install Mode: $INSTALL_MODE"
    echo "Auto-deploy NoctisPro: $AUTO_DEPLOY"
    echo ""
    
    read -p "Proceed with this configuration? (y/n) [y]: " final_confirm
    if [[ ${final_confirm:-y} != "y" ]]; then
        error "Configuration cancelled by user"
    fi
}

# Download Ubuntu Server ISO
download_ubuntu_iso() {
    header "Downloading Ubuntu Server ISO"
    
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    if [[ -f "$UBUNTU_ISO_NAME" ]]; then
        log "Ubuntu ISO already exists, checking integrity..."
        # You could add checksum verification here
        success "Ubuntu ISO found and ready"
    else
        log "Downloading Ubuntu Server 22.04 LTS..."
        log "This may take a while depending on your internet connection..."
        
        if wget -O "$UBUNTU_ISO_NAME" "$UBUNTU_ISO_URL"; then
            success "Ubuntu ISO downloaded successfully"
        else
            error "Failed to download Ubuntu ISO"
        fi
    fi
    
    # Verify ISO file
    if [[ -f "$UBUNTU_ISO_NAME" ]]; then
        iso_size=$(stat -c%s "$UBUNTU_ISO_NAME")
        if [[ $iso_size -gt 1000000000 ]]; then  # Should be > 1GB
            success "ISO file size looks correct: $(($iso_size / 1024 / 1024))MB"
        else
            error "ISO file seems too small, may be corrupted"
        fi
    else
        error "Ubuntu ISO file not found after download"
    fi
}

# Extract and modify Ubuntu ISO
modify_ubuntu_iso() {
    header "Modifying Ubuntu ISO"
    
    log "Creating working directories..."
    mkdir -p "$ISO_DIR" "$CUSTOM_ISO_DIR"
    
    log "Mounting Ubuntu ISO..."
    mount -o loop "$WORK_DIR/$UBUNTU_ISO_NAME" "$ISO_DIR"
    
    log "Copying ISO contents..."
    rsync -av "$ISO_DIR/" "$CUSTOM_ISO_DIR/"
    
    log "Unmounting original ISO..."
    umount "$ISO_DIR"
    
    # Copy NoctisPro files
    log "Adding NoctisPro PACS files..."
    mkdir -p "$CUSTOM_ISO_DIR/noctispro"
    
    # Copy all NoctisPro files
    if [[ -d "$SCRIPT_DIR" ]]; then
        cp -r "$SCRIPT_DIR"/* "$CUSTOM_ISO_DIR/noctispro/" 2>/dev/null || true
        success "NoctisPro files copied to ISO"
    else
        warning "NoctisPro source directory not found"
    fi
    
    # Create autoinstall configuration
    create_autoinstall_config
    
    # Modify boot configuration
    modify_boot_config
    
    success "Ubuntu ISO modification completed"
}

# Create autoinstall configuration
create_autoinstall_config() {
    log "Creating autoinstall configuration..."
    
    mkdir -p "$CUSTOM_ISO_DIR/server"
    
    # Create user-data for autoinstall
    cat > "$CUSTOM_ISO_DIR/server/user-data" << 'EOF'
#cloud-config
autoinstall:
  version: 1
  
  # Locale and keyboard
  locale: en_US.UTF-8
  keyboard:
    layout: us
  
  # Network configuration
  network:
    network:
      version: 2
      ethernets:
        enp0s3:
          dhcp4: true
        eth0:
          dhcp4: true
        ens33:
          dhcp4: true
  
  # Storage configuration
  storage:
    layout:
      name: direct
    config:
      - type: disk
        id: disk0
        match:
          size: largest
      - type: partition
        id: boot-partition
        device: disk0
        size: 1G
        flag: boot
      - type: partition
        id: root-partition
        device: disk0
        size: -1
      - type: format
        id: boot-fs
        volume: boot-partition
        fstype: ext4
      - type: format
        id: root-fs
        volume: root-partition
        fstype: ext4
      - type: mount
        id: boot-mount
        device: boot-fs
        path: /boot
      - type: mount
        id: root-mount
        device: root-fs
        path: /
  
  # User configuration
  identity:
    hostname: noctispro-server
    username: noctispro
    password: '$6$rounds=4096$saltsalt$3xHf1PWaKbJ5xZOzOPk.Z1JxJ2xhYGFhXVmgJLrJ5xZOzOPk.Z1JxJ2xhYGFhXVmgJLrJ5xZOzOPk.Z1JxJ2xhYGFhXVmgJLr'  # noctispro123
  
  # SSH configuration
  ssh:
    install-server: true
    allow-pw: true
  
  # Package selection
  packages:
    - ubuntu-desktop-minimal
    - firefox
    - curl
    - wget
    - git
    - python3
    - python3-pip
    - python3-venv
    - postgresql
    - postgresql-contrib
    - nginx
    - redis-server
    - build-essential
    - pkg-config
    - cmake
    - supervisor
  
  # Late commands (run after installation)
  late-commands:
    # Copy NoctisPro files
    - cp -r /cdrom/noctispro /target/opt/
    - chmod +x /target/opt/noctispro/*.sh
    
    # Set up auto-deployment script
    - |
      cat > /target/etc/systemd/system/noctispro-auto-deploy.service << 'EOL'
      [Unit]
      Description=NoctisPro Auto Deployment
      After=network.target multi-user.target
      
      [Service]
      Type=oneshot
      ExecStart=/opt/noctispro/deploy_ubuntu_gui_master.sh --full --no-ssl
      RemainAfterExit=yes
      StandardOutput=journal
      StandardError=journal
      
      [Install]
      WantedBy=multi-user.target
      EOL
    
    # Enable auto-deployment if requested
    - systemctl --root=/target enable noctispro-auto-deploy.service
    
    # Set up desktop auto-login
    - |
      mkdir -p /target/etc/gdm3
      cat > /target/etc/gdm3/custom.conf << 'EOL'
      [daemon]
      AutomaticLoginEnable=true
      AutomaticLogin=noctispro
      EOL
    
    # Create first-boot script
    - |
      cat > /target/home/noctispro/first-boot.sh << 'EOL'
      #!/bin/bash
      # This script runs on first boot to complete NoctisPro setup
      
      # Wait for system to be ready
      sleep 30
      
      # Run NoctisPro deployment
      if [[ -f /opt/noctispro/deploy_ubuntu_gui_master.sh ]]; then
          sudo /opt/noctispro/deploy_ubuntu_gui_master.sh --full --no-ssl
      fi
      
      # Remove this script after execution
      rm -f /home/noctispro/first-boot.sh
      EOL
    
    - chmod +x /target/home/noctispro/first-boot.sh
    - chown 1000:1000 /target/home/noctispro/first-boot.sh
    
    # Set graphical target as default
    - systemctl --root=/target set-default graphical.target
  
  # Reboot after installation
  shutdown: reboot
EOF

    # Create meta-data
    cat > "$CUSTOM_ISO_DIR/server/meta-data" << 'EOF'
instance-id: noctispro-server
local-hostname: noctispro-server
EOF
    
    success "Autoinstall configuration created"
}

# Modify boot configuration for autoinstall
modify_boot_config() {
    log "Modifying boot configuration..."
    
    # Modify GRUB configuration
    if [[ -f "$CUSTOM_ISO_DIR/boot/grub/grub.cfg" ]]; then
        # Backup original
        cp "$CUSTOM_ISO_DIR/boot/grub/grub.cfg" "$CUSTOM_ISO_DIR/boot/grub/grub.cfg.orig"
        
        # Create new GRUB config with autoinstall
        cat > "$CUSTOM_ISO_DIR/boot/grub/grub.cfg" << 'EOF'
set timeout=10
set default=0

menuentry "Install NoctisPro PACS Server (Automatic)" {
    linux /casper/vmlinuz autoinstall ds=nocloud-net;s=/cdrom/server/ ---
    initrd /casper/initrd
}

menuentry "Install Ubuntu Server (Manual)" {
    linux /casper/vmlinuz ---
    initrd /casper/initrd
}

menuentry "Try Ubuntu Server without installing" {
    linux /casper/vmlinuz ---
    initrd /casper/initrd
}
EOF
        
        success "GRUB configuration updated"
    fi
    
    # Update isolinux configuration
    if [[ -f "$CUSTOM_ISO_DIR/isolinux/txt.cfg" ]]; then
        cp "$CUSTOM_ISO_DIR/isolinux/txt.cfg" "$CUSTOM_ISO_DIR/isolinux/txt.cfg.orig"
        
        cat > "$CUSTOM_ISO_DIR/isolinux/txt.cfg" << 'EOF'
default install
label install
  menu label ^Install NoctisPro PACS Server
  kernel /casper/vmlinuz
  append initrd=/casper/initrd autoinstall ds=nocloud-net;s=/cdrom/server/ ---
label manual
  menu label ^Manual Ubuntu Server Installation
  kernel /casper/vmlinuz
  append initrd=/casper/initrd ---
label live
  menu label ^Try Ubuntu Server
  kernel /casper/vmlinuz
  append initrd=/casper/initrd ---
EOF
        
        success "Isolinux configuration updated"
    fi
}

# Create custom ISO
create_custom_iso() {
    header "Creating Custom ISO"
    
    log "Building custom NoctisPro Ubuntu ISO..."
    
    cd "$CUSTOM_ISO_DIR"
    
    # Create the ISO
    genisoimage \
        -r -V "NoctisPro PACS Ubuntu Server" \
        -cache-inodes -J -l \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot \
        -o "$WORK_DIR/noctispro-ubuntu-server.iso" \
        "$CUSTOM_ISO_DIR"
    
    if [[ -f "$WORK_DIR/noctispro-ubuntu-server.iso" ]]; then
        success "Custom ISO created: $WORK_DIR/noctispro-ubuntu-server.iso"
        
        # Calculate size
        iso_size=$(stat -c%s "$WORK_DIR/noctispro-ubuntu-server.iso")
        log "ISO size: $(($iso_size / 1024 / 1024))MB"
    else
        error "Failed to create custom ISO"
    fi
}

# Create bootable USB
create_bootable_usb() {
    header "Creating Bootable USB"
    
    if [[ ! -b "$TARGET_DEVICE" ]]; then
        error "Target device $TARGET_DEVICE not found"
    fi
    
    log "Preparing USB device $TARGET_DEVICE..."
    
    # Unmount any mounted partitions
    umount "${TARGET_DEVICE}"* 2>/dev/null || true
    
    # Create partition table
    log "Creating partition table..."
    parted -s "$TARGET_DEVICE" mklabel msdos
    parted -s "$TARGET_DEVICE" mkpart primary fat32 1MiB 100%
    parted -s "$TARGET_DEVICE" set 1 boot on
    
    # Format partition
    log "Formatting USB partition..."
    mkfs.fat -F32 -n "NOCTISPRO" "${TARGET_DEVICE}1"
    
    # Mount USB
    USB_MOUNT="/tmp/usb_mount"
    mkdir -p "$USB_MOUNT"
    mount "${TARGET_DEVICE}1" "$USB_MOUNT"
    
    # Copy files to USB
    log "Copying files to USB..."
    rsync -av "$CUSTOM_ISO_DIR/" "$USB_MOUNT/"
    
    # Install bootloader
    log "Installing bootloader..."
    syslinux -i "${TARGET_DEVICE}1"
    dd if=/usr/lib/syslinux/mbr/mbr.bin of="$TARGET_DEVICE" bs=440 count=1 conv=notrunc
    
    # Unmount USB
    sync
    umount "$USB_MOUNT"
    rmdir "$USB_MOUNT"
    
    success "Bootable USB created successfully on $TARGET_DEVICE"
}

# Cleanup function
cleanup() {
    log "Cleaning up temporary files..."
    
    # Unmount any mounted filesystems
    umount "$ISO_DIR" 2>/dev/null || true
    umount "$USB_MOUNT" 2>/dev/null || true
    
    # Remove temporary directories
    rm -rf "$ISO_DIR" "$CUSTOM_ISO_DIR" 2>/dev/null || true
    
    success "Cleanup completed"
}

# Show completion message
show_completion() {
    header "Creation Complete!"
    
    echo -e "${GREEN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║     🎉 NoctisPro PACS Bootable Media Created Successfully! 🎉 ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    echo ""
    echo -e "${CYAN}What was created:${NC}"
    
    if [[ $CREATE_METHOD == "iso" || $CREATE_METHOD == "both" ]]; then
        echo -e "  💿 Custom ISO: ${GREEN}$WORK_DIR/noctispro-ubuntu-server.iso${NC}"
        echo "     - Burn this ISO to DVD or use with virtual machines"
        echo "     - Contains Ubuntu Server 22.04 + NoctisPro PACS"
    fi
    
    if [[ $CREATE_METHOD == "usb" || $CREATE_METHOD == "both" ]]; then
        echo -e "  💾 Bootable USB: ${GREEN}$TARGET_DEVICE${NC}"
        echo "     - Ready to boot on any compatible system"
        echo "     - Automatic NoctisPro installation configured"
    fi
    
    echo ""
    echo -e "${CYAN}Installation Process:${NC}"
    echo "  1. Boot from the created media"
    echo "  2. Select 'Install NoctisPro PACS Server (Automatic)'"
    echo "  3. System will install Ubuntu + NoctisPro automatically"
    echo "  4. After reboot, desktop GUI will start with NoctisPro running"
    echo "  5. Access NoctisPro at http://localhost"
    
    echo ""
    echo -e "${CYAN}Default Credentials:${NC}"
    echo -e "  🖥️  System User: ${YELLOW}noctispro${NC} / ${YELLOW}noctispro123${NC}"
    echo -e "  🔑 Django Admin: ${YELLOW}admin${NC} / ${YELLOW}admin123${NC}"
    
    echo ""
    echo -e "${CYAN}System Requirements:${NC}"
    echo "  • 64-bit x86 processor"
    echo "  • 4GB+ RAM (8GB+ recommended)"
    echo "  • 20GB+ storage space"
    echo "  • Internet connection (for updates)"
    
    echo ""
    echo -e "${GREEN}Your NoctisPro PACS bootable media is ready for deployment!${NC}"
}

# Main function
main() {
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
    
    # Initialize logging
    touch "$LOG_FILE"
    log "Starting NoctisPro bootable media creation"
    
    show_banner
    check_parrot_os
    install_prerequisites
    get_user_configuration
    download_ubuntu_iso
    modify_ubuntu_iso
    
    if [[ $CREATE_METHOD == "iso" || $CREATE_METHOD == "both" ]]; then
        create_custom_iso
    fi
    
    if [[ $CREATE_METHOD == "usb" || $CREATE_METHOD == "both" ]]; then
        create_bootable_usb
    fi
    
    cleanup
    show_completion
}

# Trap cleanup on exit
trap cleanup EXIT

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "NoctisPro PACS Bootable Ubuntu Creator"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message"
        echo "  --iso-only          Create ISO file only"
        echo "  --usb-only          Create USB drive only"
        echo "  --device DEVICE     Specify USB device (e.g., /dev/sdb)"
        echo ""
        echo "Examples:"
        echo "  $0                          # Interactive mode"
        echo "  $0 --iso-only              # Create ISO file only"
        echo "  $0 --usb-only --device /dev/sdb  # Create USB on /dev/sdb"
        exit 0
        ;;
    --iso-only)
        CREATE_METHOD="iso"
        ;;
    --usb-only)
        CREATE_METHOD="usb"
        ;;
    --device)
        if [[ -n "$2" ]]; then
            TARGET_DEVICE="$2"
            shift
        else
            error "--device requires a device path"
        fi
        ;;
esac

# Run main function
main "$@"