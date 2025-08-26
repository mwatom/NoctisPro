# System Deployment Guide for 253GB Ext4 Partition

## Overview
This guide will help you deploy a Linux system to your 253GB partition (likely `/dev/sda4` based on your file manager). We'll assume it's already formatted as ext4 as you mentioned.

## Prerequisites
- Linux live USB/CD (Ubuntu, Debian, etc.)
- Access to the target system
- Internet connection for downloading packages
- Basic familiarity with terminal commands

## Step 1: Boot from Live Media and Identify Your Partition

1. Boot from your Linux live USB/CD
2. Open a terminal and identify your partition:

```bash
# List all block devices
sudo lsblk -f

# Check partition details
sudo fdisk -l

# Verify the 253GB partition (likely /dev/sda4)
sudo parted -l
```

## Step 2: Verify and Prepare the Ext4 Partition

```bash
# Check if the partition is ext4 (replace /dev/sda4 with your actual partition)
sudo blkid /dev/sda4

# If it's not ext4, format it (WARNING: This will erase all data!)
sudo mkfs.ext4 /dev/sda4

# Create a mount point and mount the partition
sudo mkdir -p /mnt/target
sudo mount /dev/sda4 /mnt/target

# Verify the mount
df -h /mnt/target
```

## Step 3: Choose Your Deployment Method

### Method A: Using Debootstrap (Debian/Ubuntu)

```bash
# Install debootstrap if not available
sudo apt update
sudo apt install debootstrap

# Bootstrap a minimal Debian/Ubuntu system
sudo debootstrap --arch amd64 jammy /mnt/target http://archive.ubuntu.com/ubuntu/
# Or for Debian: sudo debootstrap --arch amd64 bookworm /mnt/target http://deb.debian.org/debian/

# Mount necessary filesystems
sudo mount --bind /dev /mnt/target/dev
sudo mount --bind /proc /mnt/target/proc
sudo mount --bind /sys /mnt/target/sys
sudo mount --bind /dev/pts /mnt/target/dev/pts

# Chroot into the new system
sudo chroot /mnt/target
```

### Method B: Using Pacstrap (Arch Linux)

```bash
# If you prefer Arch Linux
pacman -S arch-install-scripts
pacstrap /mnt/target base linux linux-firmware

# Generate fstab
genfstab -U /mnt/target >> /mnt/target/etc/fstab

# Chroot into the system
arch-chroot /mnt/target
```

### Method C: Copy Existing System

```bash
# If you want to clone your current system
sudo rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / /mnt/target/
```

## Step 4: Configure the New System (After Chrooting)

```bash
# Set up package sources (for Ubuntu/Debian)
cat > /etc/apt/sources.list << EOF
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
EOF

# Update package database
apt update

# Install essential packages
apt install -y ubuntu-minimal ubuntu-standard
apt install -y linux-image-generic linux-headers-generic
apt install -y grub-pc openssh-server network-manager

# Set timezone
timedatectl set-timezone your_timezone
# or manually: ln -sf /usr/share/zoneinfo/Your_Zone /etc/localtime

# Configure hostname
echo "your-hostname" > /etc/hostname

# Configure hosts file
cat > /etc/hosts << EOF
127.0.0.1   localhost
127.0.1.1   your-hostname
EOF

# Set root password
passwd

# Create a user account
adduser your-username
usermod -aG sudo your-username

# Configure network (for Ubuntu)
cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:  # Replace with your interface name
      dhcp4: yes
EOF
```

## Step 5: Install and Configure GRUB Bootloader

```bash
# Find your boot device (usually the disk, not partition)
lsblk

# Install GRUB to the MBR (replace /dev/sda with your disk)
grub-install /dev/sda

# Generate GRUB configuration
update-grub

# If you have other operating systems, make sure they're detected
grub-mkconfig -o /boot/grub/grub.cfg
```

## Step 6: Configure fstab

```bash
# Get the UUID of your partition
blkid /dev/sda4

# Edit /etc/fstab
nano /etc/fstab

# Add this line (replace UUID with your actual UUID):
UUID=your-partition-uuid /               ext4    defaults        0       1

# Add other partitions if needed (swap, boot, etc.)
```

## Step 7: Final Steps

```bash
# Exit chroot
exit

# Unmount filesystems
sudo umount /mnt/target/dev/pts
sudo umount /mnt/target/dev
sudo umount /mnt/target/proc
sudo umount /mnt/target/sys
sudo umount /mnt/target

# Reboot and test
sudo reboot
```

## Troubleshooting

### If the system doesn't boot:
1. Boot from live media again
2. Mount your partition: `sudo mount /dev/sda4 /mnt/target`
3. Reinstall GRUB: `sudo grub-install --root-directory=/mnt/target /dev/sda`
4. Update GRUB config: `sudo chroot /mnt/target update-grub`

### If network doesn't work:
1. Check interface names: `ip link show`
2. Update netplan configuration with correct interface name
3. Apply configuration: `sudo netplan apply`

### If you can't mount the partition:
1. Check for filesystem errors: `sudo fsck.ext4 /dev/sda4`
2. Force check: `sudo fsck.ext4 -f /dev/sda4`

## Security Considerations

1. Change default passwords immediately
2. Configure SSH keys instead of password authentication
3. Enable and configure firewall (ufw)
4. Keep the system updated
5. Consider setting up automatic security updates

## Additional Notes

- Replace `/dev/sda4` with your actual partition device
- Replace `your-hostname`, `your-username`, etc. with your preferred values
- This guide assumes BIOS/MBR boot. For UEFI systems, additional EFI partition setup may be required
- Always backup important data before proceeding
- Test the deployment in a virtual machine first if possible

## Useful Commands After Deployment

```bash
# Check system information
hostnamectl
uname -a
lsb_release -a

# Check disk usage
df -h
du -sh /home/*

# Check running services
systemctl list-units --type=service --state=running

# Check logs
journalctl -f
```