#!/bin/bash

# Kali Linux Removal Helper Script
# This script helps identify partitions and assists with safe removal

set -e  # Exit on any error

echo "=================================="
echo "  Kali Linux Removal Helper"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if running as root for certain operations
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. Please be extra careful!"
    fi
}

# Check current OS
check_current_os() {
    print_info "Checking current operating system..."
    
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo "Current OS: $PRETTY_NAME"
        
        if [[ "$ID" == "kali" ]]; then
            print_error "You are currently running Kali Linux!"
            print_error "Please boot into Ubuntu before running this script."
            exit 1
        elif [[ "$ID" == "ubuntu" ]]; then
            print_success "Running Ubuntu - Good!"
        else
            print_warning "Unknown OS detected: $ID"
        fi
    else
        print_warning "Cannot determine current OS"
    fi
    echo ""
}

# Display current partition layout
show_partitions() {
    print_info "Current partition layout:"
    echo ""
    
    # Try different commands to show partitions
    if command -v lsblk >/dev/null 2>&1; then
        echo "=== Block devices (lsblk -f) ==="
        lsblk -f
        echo ""
    fi
    
    if command -v fdisk >/dev/null 2>&1; then
        echo "=== Partition table (fdisk -l) ==="
        sudo fdisk -l 2>/dev/null | grep -E "(Disk |Device|/dev/)"
        echo ""
    fi
    
    if command -v parted >/dev/null 2>&1; then
        echo "=== Partition information (parted -l) ==="
        sudo parted -l 2>/dev/null
        echo ""
    fi
    
    echo "=== Currently mounted filesystems ==="
    df -h
    echo ""
    
    echo "=== Partition UUIDs and labels ==="
    sudo blkid 2>/dev/null
    echo ""
}

# Identify potential Kali partitions
identify_kali_partitions() {
    print_info "Analyzing partitions for Kali Linux indicators..."
    echo ""
    
    # Look for Kali-related labels and mount points
    echo "=== Potential Kali partitions ==="
    
    # Check blkid output for kali-related labels
    if sudo blkid 2>/dev/null | grep -i kali; then
        print_warning "Found partitions with 'kali' in label/UUID"
    else
        print_info "No obvious Kali labels found in blkid output"
    fi
    
    # Check for common Kali mount points if system is running
    if mount | grep -E "(kali|/media/.*kali)" 2>/dev/null; then
        print_warning "Found mounted Kali-related filesystems"
    fi
    
    # Look for Kali-specific directories if mounted
    for mount_point in /media/* /mnt/*; do
        if [ -d "$mount_point/etc" ] && [ -f "$mount_point/etc/os-release" ]; then
            if grep -q "kali" "$mount_point/etc/os-release" 2>/dev/null; then
                print_warning "Kali filesystem detected at: $mount_point"
            fi
        fi
    done
    
    echo ""
    print_warning "MANUAL VERIFICATION REQUIRED:"
    print_warning "Please manually verify which partitions belong to Kali by:"
    print_warning "1. Checking partition sizes against your memory"
    print_warning "2. Looking at filesystem labels"
    print_warning "3. Mounting and checking /etc/os-release if unsure"
    echo ""
}

# Check GRUB configuration
check_grub() {
    print_info "Checking GRUB configuration for Kali entries..."
    echo ""
    
    if [ -f /boot/grub/grub.cfg ]; then
        if grep -i kali /boot/grub/grub.cfg >/dev/null 2>&1; then
            print_warning "Found Kali entries in GRUB configuration"
            echo "Kali GRUB entries found:"
            grep -i kali /boot/grub/grub.cfg | head -5
        else
            print_info "No Kali entries found in current GRUB configuration"
        fi
    else
        print_warning "GRUB configuration file not found"
    fi
    echo ""
}

# Backup current system state
create_backup_info() {
    print_info "Creating backup of current system information..."
    
    BACKUP_DIR="/tmp/kali_removal_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup partition information
    sudo fdisk -l > "$BACKUP_DIR/fdisk_output.txt" 2>/dev/null || true
    sudo parted -l > "$BACKUP_DIR/parted_output.txt" 2>/dev/null || true
    lsblk -f > "$BACKUP_DIR/lsblk_output.txt" 2>/dev/null || true
    sudo blkid > "$BACKUP_DIR/blkid_output.txt" 2>/dev/null || true
    df -h > "$BACKUP_DIR/df_output.txt"
    
    # Backup GRUB configuration
    if [ -f /boot/grub/grub.cfg ]; then
        sudo cp /boot/grub/grub.cfg "$BACKUP_DIR/"
    fi
    
    # Backup fstab
    if [ -f /etc/fstab ]; then
        cp /etc/fstab "$BACKUP_DIR/"
    fi
    
    print_success "System information backed up to: $BACKUP_DIR"
    echo ""
}

# Main menu
show_menu() {
    echo "Choose an option:"
    echo "1) Show current partition layout"
    echo "2) Identify potential Kali partitions"
    echo "3) Check GRUB for Kali entries"
    echo "4) Create backup of system information"
    echo "5) Update GRUB (remove Kali entries)"
    echo "6) Show complete system analysis"
    echo "7) Exit"
    echo ""
}

# Update GRUB to remove Kali entries
update_grub() {
    print_info "Updating GRUB configuration..."
    
    # Backup current GRUB config
    if [ -f /boot/grub/grub.cfg ]; then
        sudo cp /boot/grub/grub.cfg /boot/grub/grub.cfg.backup
        print_info "GRUB configuration backed up"
    fi
    
    # Update GRUB
    sudo update-grub
    
    print_success "GRUB updated. Kali entries should be removed on next boot."
    echo ""
}

# Complete system analysis
complete_analysis() {
    echo "========================================"
    echo "    COMPLETE SYSTEM ANALYSIS"
    echo "========================================"
    check_current_os
    show_partitions
    identify_kali_partitions
    check_grub
    create_backup_info
    
    echo "========================================"
    echo "    ANALYSIS COMPLETE"
    echo "========================================"
    print_warning "NEXT STEPS:"
    print_warning "1. Review the partition information above"
    print_warning "2. Identify which partitions belong to Kali"
    print_warning "3. Use GParted or similar tool to remove Kali partitions"
    print_warning "4. Expand Ubuntu partition to reclaim space"
    print_warning "5. Update GRUB configuration"
    echo ""
}

# Main script execution
main() {
    check_root
    check_current_os
    
    while true; do
        show_menu
        read -p "Enter your choice (1-7): " choice
        echo ""
        
        case $choice in
            1)
                show_partitions
                ;;
            2)
                identify_kali_partitions
                ;;
            3)
                check_grub
                ;;
            4)
                create_backup_info
                ;;
            5)
                read -p "Are you sure you want to update GRUB? (y/N): " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    update_grub
                else
                    print_info "GRUB update cancelled"
                fi
                ;;
            6)
                complete_analysis
                ;;
            7)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1-7."
                ;;
        esac
        
        echo "Press Enter to continue..."
        read
        clear
    done
}

# Run main function
main