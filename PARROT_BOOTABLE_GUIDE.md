# 🦜 NoctisPro PACS - Bootable Ubuntu Creation Guide for Parrot Security OS

## 📋 Overview

This guide shows you how to create a bootable Ubuntu Server 22.04 device with NoctisPro PACS pre-installed, using Parrot Security OS as your host system.

## 🎯 What You'll Create

- **Bootable USB Drive**: Ready-to-boot Ubuntu Server with NoctisPro PACS
- **Custom ISO File**: For burning to DVD or using in virtual machines
- **Automatic Installation**: No manual configuration required
- **GUI Desktop**: Auto-login with NoctisPro running in browser
- **Complete System**: Medical imaging system ready for deployment

## 🛠️ Prerequisites

### System Requirements (Parrot Security OS)
- **RAM**: 4GB+ (8GB+ recommended for smooth operation)
- **Storage**: 10GB+ free space for temporary files
- **USB Drive**: 8GB+ for bootable creation
- **Internet**: Required for downloading Ubuntu ISO (~1.5GB)

### Required Hardware
- USB drive (8GB+ capacity) **OR** DVD burner + blank DVD
- Target system for deployment (where NoctisPro will run)

## 🚀 Quick Start Guide

### Step 1: Prepare Parrot Security OS

Open a terminal in Parrot Security OS and run:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Clone or download NoctisPro PACS
git clone <repository-url> /tmp/noctispro
cd /tmp/noctispro

# Make scripts executable
chmod +x *.sh
```

### Step 2: Create Bootable Media

Run the bootable creator script:

```bash
sudo ./create_bootable_ubuntu.sh
```

The script will guide you through:
1. **Method Selection**: USB drive, ISO file, or both
2. **Device Selection**: Choose your USB drive (⚠️ **ALL DATA WILL BE ERASED!**)
3. **Installation Mode**: Automatic, semi-automatic, or manual
4. **NoctisPro Deployment**: Enable auto-deployment after OS install

### Step 3: Wait for Creation

The process includes:
- ✅ Downloading Ubuntu Server 22.04 ISO (~1.5GB)
- ✅ Extracting and modifying the ISO
- ✅ Adding NoctisPro PACS files
- ✅ Creating autoinstall configuration
- ✅ Building bootable media

**Estimated time**: 15-30 minutes (depending on internet speed)

## 📖 Detailed Instructions

### Method 1: Interactive Mode (Recommended)

```bash
sudo ./create_bootable_ubuntu.sh
```

Follow the prompts to configure your bootable media.

### Method 2: Command Line Options

```bash
# Create ISO file only
sudo ./create_bootable_ubuntu.sh --iso-only

# Create USB drive only (specify device)
sudo ./create_bootable_ubuntu.sh --usb-only --device /dev/sdb

# Show help
./create_bootable_ubuntu.sh --help
```

### Method 3: Advanced Configuration

Edit the script variables before running:

```bash
# Edit configuration
nano create_bootable_ubuntu.sh

# Modify these variables:
INSTALL_MODE="automatic"    # automatic, semi-auto, manual
AUTO_DEPLOY="y"            # y/n - auto-deploy NoctisPro
CREATE_METHOD="both"       # usb, iso, both
```

## 🔍 Device Detection and Safety

### Finding Your USB Drive

The script will show available devices:

```
Available storage devices:
==========================
NAME   SIZE   TYPE MODEL
sda    500G   disk WDC WD5000LPCX-24C6HT0
sdb    16G    disk SanDisk Ultra USB 3.0

USB devices:
============
  /dev/sdb - 16GB - SanDisk Ultra USB 3.0
```

### ⚠️ **CRITICAL WARNING**

- **ALL DATA** on the selected device will be **PERMANENTLY ERASED**
- **Double-check** the device name (e.g., `/dev/sdb`)
- **Never select** your main system drive (usually `/dev/sda`)
- **Confirm** the device size and model before proceeding

### Safety Checklist

Before selecting a device:
- [ ] Backup any important data from the USB drive
- [ ] Verify the device name matches your USB drive
- [ ] Confirm the size is correct (should be 8GB+)
- [ ] Ensure it's not your system drive

## 📁 Output Files

After successful creation, you'll find:

### USB Drive
- **Device**: Your selected USB device (e.g., `/dev/sdb`)
- **Label**: `NOCTISPRO`
- **Contents**: Bootable Ubuntu Server + NoctisPro PACS

### ISO File
- **Location**: `/tmp/noctispro_bootable/noctispro-ubuntu-server.iso`
- **Size**: ~2-3GB
- **Use**: Burn to DVD or use in virtual machines

## 🖥️ Deployment Process

### Step 1: Boot from Created Media

1. Insert USB drive or DVD into target system
2. Boot from USB/DVD (may need to change BIOS/UEFI boot order)
3. Select "Install NoctisPro PACS Server (Automatic)"

### Step 2: Automatic Installation

The system will automatically:
- ✅ Install Ubuntu Server 22.04
- ✅ Configure desktop environment
- ✅ Install NoctisPro PACS dependencies
- ✅ Set up database and services
- ✅ Configure auto-login
- ✅ Deploy NoctisPro PACS system

**Installation time**: 20-45 minutes (depending on hardware)

### Step 3: First Boot

After installation and reboot:
1. System auto-logs in as `noctispro` user
2. Desktop environment starts
3. Browser automatically opens to NoctisPro
4. System is ready for use at `http://localhost`

## 🔐 Default Credentials

### System Login
- **Username**: `noctispro`
- **Password**: `noctispro123`

### NoctisPro PACS
- **Admin Username**: `admin`
- **Admin Password**: `admin123`
- **Admin URL**: `http://localhost/admin/`

## 🌐 Access Information

After deployment, access NoctisPro at:
- **Main Application**: `http://localhost`
- **Admin Panel**: `http://localhost/admin/`
- **DICOM Viewer**: `http://localhost/dicom_viewer/`
- **Worklist**: `http://localhost/worklist/`

## 🛠️ Management Commands

On the deployed system, use these commands:

```bash
# Service management
noctispro-admin start      # Start services
noctispro-admin stop       # Stop services
noctispro-admin restart    # Restart services
noctispro-admin status     # Check status
noctispro-admin logs       # View logs
noctispro-admin url        # Show URLs

# System information
systemctl status noctispro
journalctl -f -u noctispro
```

## 🔧 Troubleshooting

### Common Issues

#### 1. USB Drive Not Detected
```bash
# List all block devices
lsblk

# Check USB devices
dmesg | grep -i usb
```

#### 2. Permission Denied
```bash
# Ensure running as root
sudo ./create_bootable_ubuntu.sh

# Check script permissions
chmod +x create_bootable_ubuntu.sh
```

#### 3. Download Failures
```bash
# Check internet connection
ping google.com

# Manually download Ubuntu ISO
wget https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso
```

#### 4. Insufficient Space
```bash
# Check available space
df -h /tmp

# Clean up space
sudo apt clean
sudo apt autoremove
```

### Boot Issues

#### Target System Won't Boot from USB
1. Check BIOS/UEFI settings
2. Enable legacy boot mode if needed
3. Disable secure boot temporarily
4. Try different USB ports

#### Installation Hangs
1. Check system requirements (4GB+ RAM)
2. Verify internet connection on target system
3. Try manual installation mode

### Log Files

Check these logs for troubleshooting:
- **Creation Log**: `/tmp/noctispro_bootable.log`
- **System Log**: `/var/log/syslog` (on deployed system)
- **NoctisPro Log**: `/var/log/noctispro_*.log` (on deployed system)

## 📊 System Requirements

### Host System (Parrot Security OS)
- **OS**: Parrot Security OS (any recent version)
- **RAM**: 4GB+ (8GB+ recommended)
- **Storage**: 10GB+ free space
- **Network**: Internet connection for downloads

### Target System (Where NoctisPro Will Run)
- **Architecture**: 64-bit x86 (AMD64/Intel)
- **RAM**: 4GB minimum, 8GB+ recommended
- **Storage**: 20GB+ available space
- **Network**: Internet connection (for updates and optional features)
- **Graphics**: Any graphics card supporting 1024x768+

## 🎯 Use Cases

### 1. Hospital/Clinic Deployment
- Create multiple USB drives for different locations
- Standardized NoctisPro installation across facilities
- Quick deployment without technical expertise

### 2. Development/Testing
- Create ISO for virtual machine testing
- Consistent development environment
- Easy system replication

### 3. Disaster Recovery
- Pre-configured backup systems
- Quick restoration of NoctisPro services
- Portable deployment solution

### 4. Training/Demonstration
- Portable demo systems
- Consistent training environments
- No internet required for basic operation

## 📋 Checklist

Before creating bootable media:
- [ ] Parrot Security OS updated and ready
- [ ] USB drive (8GB+) or DVD available
- [ ] Internet connection stable
- [ ] Sufficient disk space (10GB+)
- [ ] Root/sudo access available

Before deployment:
- [ ] Target system meets requirements
- [ ] Backup any existing data
- [ ] BIOS/UEFI configured for USB/DVD boot
- [ ] Network connection available (recommended)

After deployment:
- [ ] System boots to desktop automatically
- [ ] NoctisPro accessible at http://localhost
- [ ] Admin panel accessible with default credentials
- [ ] All services running (check with `noctispro-admin status`)

## 🆘 Support

If you encounter issues:

1. **Check logs**: Look at `/tmp/noctispro_bootable.log`
2. **Verify requirements**: Ensure all prerequisites are met
3. **Try different USB drive**: Some drives may have compatibility issues
4. **Use ISO method**: If USB fails, try creating an ISO file instead
5. **Manual installation**: Use manual mode if automatic fails

## 🎉 Success!

Once completed, you'll have a professional medical imaging system that:
- ✅ Boots automatically to GUI desktop
- ✅ Runs NoctisPro PACS out of the box
- ✅ Includes all necessary dependencies
- ✅ Provides web-based interface
- ✅ Supports DICOM medical imaging
- ✅ Includes admin tools and management

Your bootable NoctisPro PACS system is ready for deployment in medical facilities, development environments, or anywhere a complete medical imaging solution is needed!

---

*This guide was created for NoctisPro PACS deployment using Parrot Security OS. For additional support or questions, refer to the system documentation or contact your system administrator.*