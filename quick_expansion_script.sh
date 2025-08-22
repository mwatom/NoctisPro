#!/bin/bash

# Ubuntu Partition Expansion Quick Reference Script
# This script provides commands for common partition expansion scenarios
# WARNING: Do NOT run this script directly - use commands individually after understanding them

echo "=== Ubuntu Partition Expansion Quick Reference ==="
echo "⚠️  IMPORTANT: Boot from Ubuntu Live USB before running these commands!"
echo "⚠️  ALWAYS backup your data first!"
echo ""

# Function to display current disk layout
show_disk_layout() {
    echo "=== Current Disk Layout ==="
    echo "1. View partition table:"
    echo "   sudo fdisk -l"
    echo ""
    echo "2. View filesystem info:"
    echo "   sudo lsblk -f"
    echo ""
    echo "3. Check disk usage:"
    echo "   sudo df -h"
    echo ""
}

# Function for GParted approach (recommended)
gparted_approach() {
    echo "=== GParted Approach (Recommended) ==="
    echo "1. Install GParted (if needed):"
    echo "   sudo apt update && sudo apt install gparted"
    echo ""
    echo "2. Launch GParted:"
    echo "   sudo gparted"
    echo ""
    echo "3. In GParted GUI:"
    echo "   - Select your disk from dropdown"
    echo "   - Right-click partition to shrink → Resize/Move"
    echo "   - Drag to shrink and create free space"
    echo "   - Right-click Ubuntu partition → Resize/Move"
    echo "   - Drag to expand into free space"
    echo "   - Apply all operations"
    echo ""
}

# Function for command line approach
command_line_approach() {
    echo "=== Command Line Approach ==="
    echo "Replace /dev/sdX with your actual disk (e.g., /dev/sda)"
    echo "Replace X2 with your actual partition number (e.g., sda2)"
    echo ""
    echo "1. Check filesystem before resizing:"
    echo "   sudo e2fsck -f /dev/sdX2"
    echo ""
    echo "2. Using parted to resize partition:"
    echo "   sudo parted /dev/sdX"
    echo "   print"
    echo "   resizepart 2 [NEW_END_SIZE]"
    echo "   quit"
    echo ""
    echo "3. Resize filesystem to match partition:"
    echo "   sudo resize2fs /dev/sdX2"
    echo ""
    echo "4. Verify the changes:"
    echo "   lsblk"
    echo "   df -h"
    echo ""
}

# Function for LVM systems
lvm_approach() {
    echo "=== LVM System Approach ==="
    echo "If your Ubuntu uses LVM (check with 'sudo lvdisplay'):"
    echo ""
    echo "1. Extend physical volume:"
    echo "   sudo pvresize /dev/sdX2"
    echo ""
    echo "2. Extend logical volume:"
    echo "   sudo lvextend -l +100%FREE /dev/mapper/ubuntu--vg-root"
    echo ""
    echo "3. Resize filesystem:"
    echo "   sudo resize2fs /dev/mapper/ubuntu--vg-root"
    echo ""
    echo "4. Verify:"
    echo "   df -h"
    echo ""
}

# Function for backup commands
backup_commands() {
    echo "=== Essential Backup Commands ==="
    echo "Run these BEFORE making any changes:"
    echo ""
    echo "1. Backup home directory:"
    echo "   rsync -av /home/\$USER/ /path/to/backup/home/"
    echo ""
    echo "2. Backup system config:"
    echo "   sudo tar -czf /path/to/backup/etc-backup.tar.gz /etc/"
    echo ""
    echo "3. Create partition table backup:"
    echo "   sudo sfdisk -d /dev/sdX > /path/to/backup/partition-table.txt"
    echo ""
    echo "4. (Optional) Full disk image:"
    echo "   sudo dd if=/dev/sdX of=/path/to/backup/disk-image.img bs=4M status=progress"
    echo ""
}

# Function for troubleshooting
troubleshooting() {
    echo "=== Troubleshooting Commands ==="
    echo ""
    echo "1. Fix filesystem errors:"
    echo "   sudo e2fsck -y /dev/sdX2"
    echo ""
    echo "2. Reinstall GRUB (if boot fails):"
    echo "   sudo mount /dev/sdX2 /mnt"
    echo "   sudo grub-install --root-directory=/mnt /dev/sdX"
    echo "   sudo update-grub"
    echo ""
    echo "3. Check partition table:"
    echo "   sudo parted /dev/sdX print"
    echo ""
    echo "4. Restore partition table (if backed up):"
    echo "   sudo sfdisk /dev/sdX < /path/to/backup/partition-table.txt"
    echo ""
}

# Main menu
echo "Choose an option:"
echo "1. Show current disk layout"
echo "2. GParted approach (recommended)"
echo "3. Command line approach"
echo "4. LVM system approach"
echo "5. Backup commands"
echo "6. Troubleshooting commands"
echo "7. Show all"
echo ""

case "${1:-7}" in
    1) show_disk_layout ;;
    2) gparted_approach ;;
    3) command_line_approach ;;
    4) lvm_approach ;;
    5) backup_commands ;;
    6) troubleshooting ;;
    7) 
        show_disk_layout
        echo ""
        backup_commands
        echo ""
        gparted_approach
        echo ""
        command_line_approach
        echo ""
        lvm_approach
        echo ""
        troubleshooting
        ;;
    *) echo "Invalid option. Use: $0 [1-7]" ;;
esac

echo ""
echo "=== IMPORTANT REMINDERS ==="
echo "• Boot from Ubuntu Live USB before making changes"
echo "• Never resize mounted partitions"
echo "• Always backup important data first"
echo "• Test your backups before proceeding"
echo "• Take your time and double-check everything"
echo "• Keep the Live USB handy for recovery"