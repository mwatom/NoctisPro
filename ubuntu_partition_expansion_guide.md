# Ubuntu Partition Expansion Guide

This guide will help you expand your Ubuntu partition to use space from other partitions without deleting data in those partitions.

## ⚠️ IMPORTANT SAFETY WARNINGS

1. **ALWAYS BACKUP YOUR DATA** before making any partition changes
2. **Boot from a live USB/CD** to safely resize partitions
3. **Never resize mounted partitions** (especially the root filesystem)
4. **Test your backups** before proceeding

## Prerequisites

Before starting, you'll need:
- Ubuntu Live USB or CD
- External storage for backups
- At least 2-3 hours of time
- Understanding of your current partition layout

## Step 1: Analyze Your Current Disk Layout

Boot from your Ubuntu Live USB and run these commands to understand your current setup:

```bash
# View partition layout
sudo fdisk -l

# View filesystem information
sudo lsblk -f

# Check disk usage
sudo df -h
```

## Step 2: Identify Expansion Options

You have several options for expanding Ubuntu without data loss:

### Option A: Use Unallocated Space
If you have unallocated space on your disk:
- This is the safest option
- Simply extend your Ubuntu partition into the free space

### Option B: Shrink Adjacent Partitions
If you want to use space from other partitions:
- Shrink the source partition (Windows, data partition, etc.)
- Move the freed space to your Ubuntu partition
- **Data in the shrunk partition will be preserved**

### Option C: Move Partitions
Sometimes you need to move partitions to create contiguous space:
- This is more complex but still safe when done properly
- Useful when Ubuntu partition is not adjacent to free space

## Step 3: Backup Critical Data

**Essential backups:**
```bash
# Backup your home directory
rsync -av /home/username/ /backup/location/home/

# Backup system configuration
sudo tar -czf /backup/location/etc-backup.tar.gz /etc/

# Create a system image (optional but recommended)
sudo dd if=/dev/sdX of=/backup/location/system-backup.img bs=4M status=progress
```

## Step 4: Resize Partitions Using GParted

GParted is the recommended tool for safe partition resizing:

### Install GParted (if not available)
```bash
sudo apt update
sudo apt install gparted
```

### Using GParted GUI:
1. **Launch GParted**: `sudo gparted`
2. **Select your disk** from the dropdown
3. **Right-click the partition** you want to shrink
4. **Select "Resize/Move"**
5. **Drag the partition handle** to shrink it
6. **Apply the operation**
7. **Right-click your Ubuntu partition**
8. **Select "Resize/Move"**
9. **Expand into the new free space**
10. **Apply all operations**

## Step 5: Alternative Command Line Method

If you prefer command line tools:

### Using parted:
```bash
# Start parted on your disk
sudo parted /dev/sdX

# Print current partition table
print

# Resize partition (example: resize partition 2 to end at 50GB)
resizepart 2 50GB

# Quit parted
quit

# Resize the filesystem to match the partition
sudo resize2fs /dev/sdX2
```

### Using fdisk (more advanced):
```bash
# Delete and recreate partition with larger size
sudo fdisk /dev/sdX
# Use 'd' to delete partition
# Use 'n' to create new partition with same start but different end
# Use 'w' to write changes

# Resize filesystem
sudo resize2fs /dev/sdX2
```

## Step 6: Handle Different Filesystem Types

### For ext4 filesystems (most Ubuntu installations):
```bash
# Check filesystem before resizing
sudo e2fsck -f /dev/sdX2

# Resize filesystem
sudo resize2fs /dev/sdX2
```

### For LVM (Logical Volume Manager):
```bash
# Extend physical volume
sudo pvresize /dev/sdX2

# Extend logical volume
sudo lvextend -l +100%FREE /dev/mapper/ubuntu-root

# Resize filesystem
sudo resize2fs /dev/mapper/ubuntu-root
```

## Step 7: Verify the Expansion

After completing the resize:

```bash
# Check new partition sizes
lsblk

# Check filesystem sizes
df -h

# Verify filesystem integrity
sudo fsck /dev/sdX2
```

## Common Scenarios and Solutions

### Scenario 1: Ubuntu is between two other partitions
1. Shrink the partition after Ubuntu
2. Move it to create contiguous free space
3. Expand Ubuntu into the free space

### Scenario 2: Windows and Ubuntu dual boot
1. Boot from Ubuntu Live USB
2. Use GParted to shrink Windows partition
3. Expand Ubuntu partition into freed space
4. Update GRUB if necessary

### Scenario 3: Ubuntu on LVM
1. Extend the physical volume
2. Extend the logical volume
3. Resize the filesystem

## Troubleshooting

### If GParted shows warnings:
- Run filesystem check: `sudo e2fsck -f /dev/sdX`
- Clear journal: `sudo tune2fs -O ^has_journal /dev/sdX`

### If boot fails after resize:
- Boot from live USB
- Mount your Ubuntu partition
- Reinstall GRUB: `sudo grub-install /dev/sdX`
- Update GRUB config: `sudo update-grub`

### If filesystem is corrupted:
- Run: `sudo e2fsck -y /dev/sdX`
- If severe: restore from backup

## Best Practices

1. **Always work with unmounted partitions**
2. **Start with the rightmost partition** when shrinking
3. **Leave some free space** (10-20%) after expansion
4. **Test thoroughly** after changes
5. **Keep your live USB handy** for emergencies

## Recovery Options

If something goes wrong:
1. **Boot from live USB**
2. **Use TestDisk** to recover partition table
3. **Restore from backup** if necessary
4. **Seek professional help** for critical data

Remember: Patience and preparation are key to successful partition expansion!