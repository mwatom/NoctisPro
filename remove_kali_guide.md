# Safe Kali Linux Removal Guide - Preserving Ubuntu

## ⚠️ IMPORTANT: Backup First!
Before proceeding, create a complete backup of:
- Important files from both Ubuntu and Kali
- Boot configuration
- Consider creating a system image backup

## Phase 1: Preparation and Assessment

### Step 1: Boot into Ubuntu (your target system)
Make sure you're running Ubuntu, not Kali, for all operations.

### Step 2: Identify Partition Layout
```bash
# Install required tools if not present
sudo apt update
sudo apt install gparted util-linux

# View current partition layout
sudo fdisk -l
# OR
sudo parted -l

# Check mounted filesystems
df -h

# View partition UUIDs and labels
sudo blkid
```

### Step 3: Identify Kali Partitions
Look for:
- Kali root partition (usually ext4, may have "kali" in label)
- Kali swap partition (if separate)
- Kali home partition (if separate)
- EFI system partition (shared between both systems)

**DO NOT DELETE:**
- Ubuntu root partition (/)
- Ubuntu home partition (if separate)
- EFI System Partition (ESP) - usually /dev/sda1 or /dev/nvme0n1p1
- Shared data partitions

## Phase 2: GRUB Bootloader Cleanup

### Step 4: Remove Kali from GRUB
```bash
# Update GRUB to remove Kali entries
sudo update-grub

# If Kali entries persist, manually edit:
sudo nano /etc/grub.d/40_custom

# Remove any manual Kali entries, then:
sudo update-grub
```

### Step 5: Backup Current GRUB Configuration
```bash
# Backup current GRUB config
sudo cp /boot/grub/grub.cfg /boot/grub/grub.cfg.backup

# Note your current Ubuntu partition info
sudo blkid | grep -E "(Ubuntu|ext4)"
```

## Phase 3: Partition Management

### Step 6: Use GParted for Safe Removal
```bash
# Launch GParted (GUI tool - safest option)
sudo gparted

# OR use command line (advanced users only)
sudo parted /dev/sda  # Replace with your actual disk
```

**In GParted:**
1. **Identify Kali partitions** (check filesystem labels and sizes)
2. **Unmount any mounted Kali partitions**
3. **Delete Kali partitions** (right-click → Delete)
4. **Resize Ubuntu partition** to claim free space
   - Right-click Ubuntu partition → Resize/Move
   - Expand to use freed space
5. **Apply all operations** (Edit → Apply All Operations)

### Step 7: Alternative Command Line Method (Advanced)
⚠️ **DANGEROUS - Only if you're experienced with partitioning**

```bash
# Example commands (ADAPT TO YOUR SYSTEM):
# Delete Kali partition (example: /dev/sda3)
sudo parted /dev/sda rm 3

# Resize Ubuntu partition to fill space
sudo parted /dev/sda resizepart 2 100%

# Resize filesystem to match partition
sudo resize2fs /dev/sda2
```

## Phase 4: Post-Removal Tasks

### Step 8: Verify System Integrity
```bash
# Check filesystem integrity
sudo fsck -f /dev/sda2  # Replace with your Ubuntu root partition

# Verify GRUB installation
sudo grub-install /dev/sda  # Replace with your disk

# Update GRUB configuration
sudo update-grub

# Check available space
df -h
```

### Step 9: Clean Up Package Cache
```bash
# Remove old kernels and packages
sudo apt autoremove
sudo apt autoclean

# Clean snap packages
sudo snap list --all | awk '/disabled/{print $1, $3}' | \
    while read snapname revision; do sudo snap remove "$snapname" --revision="$revision"; done
```

## Phase 5: Prepare for Deployment

### Step 10: Optimize Ubuntu for Deployment
```bash
# Update system
sudo apt update && sudo apt upgrade

# Install essential tools for deployment
sudo apt install ssh rsync git curl wget

# Clean temporary files
sudo apt clean
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Clear system logs (optional)
sudo journalctl --vacuum-time=1d
```

## Safety Checklist

✅ **Before starting:**
- [ ] Backup important data
- [ ] Create system recovery USB
- [ ] Note down all partition information
- [ ] Ensure Ubuntu is working properly

✅ **During process:**
- [ ] Double-check partition identification
- [ ] Never delete EFI system partition
- [ ] Test GRUB after each change
- [ ] Monitor available space

✅ **After completion:**
- [ ] Verify Ubuntu boots normally
- [ ] Check all applications work
- [ ] Confirm increased disk space
- [ ] Test system stability

## Common Partition Layouts

### Typical UEFI Dual-Boot Setup:
```
/dev/sda1: EFI System Partition (FAT32, ~500MB) - KEEP
/dev/sda2: Ubuntu Root (ext4, varies) - KEEP & EXPAND
/dev/sda3: Kali Root (ext4, varies) - DELETE
/dev/sda4: Swap (swap, varies) - CHECK OWNERSHIP
```

### Typical BIOS Dual-Boot Setup:
```
/dev/sda1: Ubuntu Root (ext4, varies) - KEEP & EXPAND
/dev/sda2: Kali Root (ext4, varies) - DELETE
/dev/sda3: Swap (swap, varies) - CHECK OWNERSHIP
```

## Troubleshooting

### If GRUB fails to boot:
1. Boot from Ubuntu Live USB
2. Mount your Ubuntu root partition
3. Reinstall GRUB from chroot environment

### If partition resize fails:
1. Use GParted Live USB for offline operations
2. Check filesystem for errors first
3. Ensure no processes are using the partition

### Recovery Steps:
```bash
# Boot from Ubuntu Live USB
sudo mount /dev/sda2 /mnt  # Your Ubuntu root
sudo mount /dev/sda1 /mnt/boot/efi  # EFI partition
sudo chroot /mnt
grub-install /dev/sda
update-grub
exit
sudo umount /mnt/boot/efi
sudo umount /mnt
```

## Final Notes

- **Space Gained**: Kali partitions will be completely removed and space added to Ubuntu
- **Boot Speed**: Faster boot with simpler GRUB menu
- **System Clean**: Single-OS setup is more stable
- **Ready for Deployment**: Clean Ubuntu ready for server migration

**Estimated Time**: 1-2 hours depending on partition sizes and system performance.

**Risk Level**: Medium - Always backup first!