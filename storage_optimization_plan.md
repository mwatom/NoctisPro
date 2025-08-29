# NoctisPro Storage Optimization Deployment Plan

## Current Storage Analysis

### Host Machine Storage (from lsblk -f output):
- **sda2**: EFI boot partition (~969MB available) - Not suitable for application data
- **sda7**: Root partition (~3GB free, 81% used) - Limited space for deployment
- **sdb**: Optical drive (UDF filesystem) - Not suitable for persistent storage

### Storage Optimization Strategy

#### 1. Efficient Directory Structure
```bash
# Optimize space usage in /opt/noctis_pro
/opt/noctis_pro/
├── app/                    # Django application (minimal space)
├── media/                  # DICOM files (largest space requirement)
│   ├── dicom/
│   │   ├── studies/        # Organized by study
│   │   └── temp/           # Temporary processing
│   └── reports/            # Generated reports
├── static/                 # Static files (compressed)
├── logs/                   # Log files (with rotation)
├── backups/                # Database backups (compressed)
└── cache/                  # Redis cache files
```

#### 2. Space-Saving Configurations

##### Database Optimization
- Use PostgreSQL with optimized settings for limited space
- Enable database compression
- Implement automatic backup rotation
- Configure WAL file cleanup

##### DICOM File Management
- Implement DICOM file compression
- Use hierarchical storage management
- Automatic cleanup of temporary files
- Optional: Implement cloud storage integration for archival

##### Application Optimization
- Use compressed static files
- Implement log rotation
- Use Redis for caching (memory-based)
- Optimize Docker images if using containers

#### 3. Deployment Steps for Limited Space

1. **Pre-deployment Cleanup**
   ```bash
   # Clean package cache
   sudo apt clean
   sudo apt autoremove
   
   # Clean temporary files
   sudo rm -rf /tmp/*
   sudo rm -rf /var/tmp/*
   
   # Clean old logs
   sudo journalctl --vacuum-time=7d
   ```

2. **Efficient Installation**
   ```bash
   # Install only essential packages
   # Use lightweight database configuration
   # Minimize Python dependencies
   ```

3. **Storage Monitoring**
   ```bash
   # Implement disk usage monitoring
   # Set up alerts for low disk space
   # Automatic cleanup scripts
   ```

#### 4. Alternative Storage Solutions

If current partitions are insufficient, consider:

1. **External Storage**
   - Mount external USB drive for DICOM files
   - Use network-attached storage (NAS)
   - Cloud storage integration

2. **Partition Expansion**
   - If unallocated space exists, expand sda7
   - Move some directories to alternative locations

3. **Symbolic Links**
   - Link large directories to external storage
   - Maintain application structure while using remote storage

#### 5. Recommended Minimum Requirements

- **Root partition**: 10GB free minimum
- **DICOM storage**: 20GB+ (depending on usage)
- **Database**: 1-5GB (depending on number of studies)
- **Application files**: 1-2GB
- **Logs and temporary**: 1GB

## Next Steps

1. Identify additional storage options
2. Confirm available space on mentioned "other 2 partitions"
3. Configure deployment script for optimized storage usage
4. Implement monitoring and cleanup automation