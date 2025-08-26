#!/bin/bash

# Quick System Deployment Script for 253GB Ext4 Partition
# WARNING: Review and customize this script before running!

set -e  # Exit on any error

# Configuration - MODIFY THESE VALUES
TARGET_PARTITION="/dev/sda4"  # Your 253GB partition
TARGET_MOUNT="/mnt/target"
HOSTNAME="my-system"
USERNAME="myuser"
TIMEZONE="America/New_York"  # Change to your timezone

echo "=== System Deployment Script ==="
echo "Target partition: $TARGET_PARTITION"
echo "Mount point: $TARGET_MOUNT"
echo "Hostname: $HOSTNAME"
echo "Username: $USERNAME"
echo ""
read -p "Press Enter to continue or Ctrl+C to abort..."

# Step 1: Verify partition
echo "=== Step 1: Verifying partition ==="
sudo blkid $TARGET_PARTITION
sudo parted $TARGET_PARTITION print

# Step 2: Mount the partition
echo "=== Step 2: Mounting partition ==="
sudo mkdir -p $TARGET_MOUNT
sudo mount $TARGET_PARTITION $TARGET_MOUNT
df -h $TARGET_MOUNT

# Step 3: Install debootstrap (Ubuntu/Debian method)
echo "=== Step 3: Installing debootstrap ==="
sudo apt update
sudo apt install -y debootstrap

# Step 4: Bootstrap the system
echo "=== Step 4: Bootstrapping Ubuntu system ==="
sudo debootstrap --arch amd64 jammy $TARGET_MOUNT http://archive.ubuntu.com/ubuntu/

# Step 5: Mount necessary filesystems
echo "=== Step 5: Mounting filesystems ==="
sudo mount --bind /dev $TARGET_MOUNT/dev
sudo mount --bind /proc $TARGET_MOUNT/proc
sudo mount --bind /sys $TARGET_MOUNT/sys
sudo mount --bind /dev/pts $TARGET_MOUNT/dev/pts

# Step 6: Create configuration script to run in chroot
echo "=== Step 6: Creating chroot configuration script ==="
cat > /tmp/configure_system.sh << 'EOF'
#!/bin/bash
set -e

# Set up package sources
cat > /etc/apt/sources.list << 'APT_EOF'
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
APT_EOF

# Update and install essential packages
apt update
apt install -y ubuntu-minimal ubuntu-standard
apt install -y linux-image-generic linux-headers-generic
apt install -y grub-pc openssh-server network-manager nano curl wget

# Configure timezone
ln -sf /usr/share/zoneinfo/TIMEZONE_PLACEHOLDER /etc/localtime

# Configure hostname
echo "HOSTNAME_PLACEHOLDER" > /etc/hostname

# Configure hosts
cat > /etc/hosts << 'HOSTS_EOF'
127.0.0.1   localhost
127.0.1.1   HOSTNAME_PLACEHOLDER
HOSTS_EOF

# Configure network
cat > /etc/netplan/01-netcfg.yaml << 'NET_EOF'
network:
  version: 2
  renderer: networkd
  ethernets:
    ens3:
      dhcp4: yes
    enp0s3:
      dhcp4: yes
    eth0:
      dhcp4: yes
NET_EOF

echo "Root password setup:"
passwd

echo "Creating user USERNAME_PLACEHOLDER:"
adduser USERNAME_PLACEHOLDER
usermod -aG sudo USERNAME_PLACEHOLDER

# Install GRUB
grub-install DISK_PLACEHOLDER
update-grub

echo "System configuration completed!"
EOF

# Replace placeholders in the configuration script
sed -i "s/TIMEZONE_PLACEHOLDER/$TIMEZONE/g" /tmp/configure_system.sh
sed -i "s/HOSTNAME_PLACEHOLDER/$HOSTNAME/g" /tmp/configure_system.sh
sed -i "s/USERNAME_PLACEHOLDER/$USERNAME/g" /tmp/configure_system.sh
sed -i "s|DISK_PLACEHOLDER|${TARGET_PARTITION%?}|g" /tmp/configure_system.sh  # Remove last character (partition number)

# Copy script to chroot environment and make executable
sudo cp /tmp/configure_system.sh $TARGET_MOUNT/tmp/configure_system.sh
sudo chmod +x $TARGET_MOUNT/tmp/configure_system.sh

echo "=== Step 7: Entering chroot environment ==="
echo "The configuration script is ready at /tmp/configure_system.sh"
echo "Run it with: /tmp/configure_system.sh"
echo "After configuration, exit the chroot and run the cleanup commands."
echo ""
echo "Manual chroot commands to run:"
echo "sudo chroot $TARGET_MOUNT"
echo "/tmp/configure_system.sh"
echo "exit"
echo ""
echo "Cleanup commands (after exiting chroot):"
echo "sudo umount $TARGET_MOUNT/dev/pts"
echo "sudo umount $TARGET_MOUNT/dev"
echo "sudo umount $TARGET_MOUNT/proc"
echo "sudo umount $TARGET_MOUNT/sys"
echo "sudo umount $TARGET_MOUNT"
echo ""
echo "Then reboot your system!"

# Don't auto-chroot for safety - let user do it manually
echo "=== Manual intervention required ==="
echo "Please run the chroot command manually for safety."