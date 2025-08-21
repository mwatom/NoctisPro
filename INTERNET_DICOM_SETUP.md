# NOCTIS Pro - Internet DICOM Access Setup Guide

## Overview

This guide helps you configure NOCTIS Pro for internet access, allowing DICOM machines from healthcare facilities to send medical images directly to your server over the internet. Each facility gets a unique AE Title during facility creation that must be configured on their DICOM machines.

## 🌍 Internet Access Architecture

```
DICOM Machine (Hospital A) ──┐
                             │
DICOM Machine (Hospital B) ──┼──► Internet ──► Your Server:11112 ──► NOCTIS Pro
                             │                   (DICOM Receiver)
DICOM Machine (Clinic C) ────┘
```

## 🏥 Facility-Based DICOM Routing

Your system automatically:
1. **Creates unique AE titles** when facilities are created
2. **Routes DICOM images** to the correct facility based on AE title
3. **Enforces security** by only accepting images from registered facilities
4. **Tracks all activity** for audit and monitoring

## 🚀 Quick Start for Internet Access

### 1. Verify Current System

```bash
# Check if facility and user management is working
./scripts/verify-facility-user-management.sh
```

### 2. Deploy with Internet Access

```bash
# Copy internet configuration
cp .env.internet.example .env
nano .env  # Configure your domain and settings

# Deploy with internet access
./scripts/deploy-internet-access.sh
```

### 3. Create Facilities

1. Access admin panel: `https://your-domain.com/admin/`
2. Go to "Facility Management"
3. Create facilities for each hospital/clinic
4. Note the auto-generated AE titles

### 4. Configure DICOM Machines

Provide each facility with their DICOM configuration:
- **Called AE Title**: `NOCTIS_SCP`
- **Calling AE Title**: `[Their facility's AE Title]`
- **Hostname**: `your-domain.com`
- **Port**: `11112`

## 📋 Detailed Setup Process

### Step 1: Prepare Your Server

1. **Domain Setup**:
   - Point your domain to your server IP
   - Ensure DNS is properly configured
   - Consider using a subdomain like `dicom.yourdomain.com`

2. **Server Requirements**:
   - Ubuntu Server 18.04+ or 20.04+
   - Minimum 4GB RAM (8GB recommended)
   - At least 100GB disk space
   - Static IP address
   - Proper internet connectivity

### Step 2: Configure Environment

```bash
# Copy internet environment template
cp .env.internet.example .env

# Edit configuration
nano .env
```

**Critical settings to configure**:
```bash
# Your domain name
DOMAIN_NAME=your-domain.com

# Strong passwords
SECRET_KEY=generate-a-strong-secret-key
POSTGRES_PASSWORD=strong-database-password

# SSL configuration
LETSENCRYPT_EMAIL=your-email@domain.com

# Security settings
DICOM_EXTERNAL_ACCESS=True
FACILITY_AE_VALIDATION=True
```

### Step 3: Deploy Internet-Accessible System

```bash
# Run the internet deployment script
./scripts/deploy-internet-access.sh
```

This script automatically:
- Configures firewall for internet access
- Sets up SSL certificates
- Deploys enhanced security measures
- Starts DICOM receiver with internet access
- Configures fail2ban for protection

### Step 4: Create Facilities

1. **Access Admin Panel**:
   - URL: `https://your-domain.com/admin/`
   - Login with your admin credentials

2. **Create Each Facility**:
   - Navigate to "Facility Management"
   - Click "Add Facility"
   - Fill in facility information:
     - **Name**: "City General Hospital"
     - **Address**: Full facility address
     - **Phone**: Contact number
     - **Email**: Facility contact email
     - **License Number**: Medical facility license
     - **AE Title**: Auto-generated (e.g., "CITY_GENERAL")
   
3. **Optional Facility User**:
   - Check "Create facility user account"
   - This creates a login for the facility staff
   - They can view only their facility's studies

### Step 5: Configure DICOM Machines

For each facility, provide their IT staff with:

#### Configuration Template
```
DICOM Server Configuration:
==========================
Called AE Title:    NOCTIS_SCP
Calling AE Title:   [FACILITY_AE_TITLE]
Hostname:          your-domain.com
Port:              11112
Protocol:          DICOM TCP/IP
Timeout:           30 seconds
```

#### Example: City General Hospital
```
Called AE Title:    NOCTIS_SCP
Calling AE Title:   CITY_GENERAL
Hostname:          your-domain.com
Port:              11112
```

### Step 6: Test Connectivity

1. **From DICOM Machine**:
   ```bash
   # Test basic connectivity
   telnet your-domain.com 11112
   
   # Test DICOM echo (if DCMTK tools available)
   echoscu -aet CITY_GENERAL -aec NOCTIS_SCP your-domain.com 11112
   ```

2. **Send Test Image**:
   - Send a test DICOM image from the machine
   - Verify it appears in the facility's worklist
   - Check that patient data is properly parsed

## 🔒 Security Features

### Automatic Security Measures

1. **AE Title Validation**: Only registered facilities can send images
2. **Rate Limiting**: Prevents connection flooding
3. **IP Monitoring**: Tracks and blocks suspicious activity
4. **Fail2Ban Integration**: Automatic intrusion prevention
5. **SSL/TLS**: All web traffic encrypted
6. **Facility Isolation**: Images only visible to the sending facility

### Monitoring and Alerts

- **Connection Logs**: All DICOM connections logged
- **Security Events**: Suspicious activity alerts
- **Failed Attempts**: Automatic blocking of repeated failures
- **Audit Trail**: Complete facility and user activity tracking

## 📊 Monitoring Your System

### Real-Time Monitoring

```bash
# View DICOM receiver logs
docker compose -f docker-compose.internet.yml logs -f dicom_receiver

# View security logs
tail -f /opt/noctis/logs/dicom_security.log

# Check system status
docker compose -f docker-compose.internet.yml ps

# Monitor system resources
docker stats
```

### Web-Based Monitoring

- **Admin Dashboard**: `https://your-domain.com/admin/`
- **DICOM Status**: `https://dicom.your-domain.com/`
- **Facility Management**: View all facilities and their AE titles
- **User Activity**: Monitor user logins and activity

## 🏥 Facility Management

### Creating New Facilities

1. **Access Admin Panel**: `https://your-domain.com/admin/`
2. **Navigate to Facilities**: Click "Facility Management"
3. **Add New Facility**: Click "Add Facility"
4. **Fill Information**:
   - Facility name (required)
   - Complete address (required)
   - Contact information
   - Medical license number
   - **AE Title**: Auto-generated from name, can be customized
5. **Optional User Account**: Create login for facility staff
6. **Save**: Facility is immediately available for DICOM

### Managing Existing Facilities

- **Edit Facility**: Update information, change AE title
- **Deactivate**: Temporarily disable DICOM reception
- **View Statistics**: See study counts and activity
- **Export Data**: Download facility information

## 👥 User Management

### User Roles

1. **Administrator**: Full system access, manage all facilities
2. **Radiologist**: Read studies, create reports, cross-facility access
3. **Facility User**: Access only their facility's studies

### Creating Users

1. **Access User Management**: `https://your-domain.com/admin/users/`
2. **Add New User**: Click "Create User"
3. **Set Role and Facility**: Assign appropriate permissions
4. **Configure Access**: Set verification and activation status

## 🔧 Troubleshooting

### Common DICOM Connection Issues

1. **Connection Refused**:
   ```bash
   # Check if DICOM service is running
   docker compose ps dicom_receiver
   
   # Check firewall
   sudo ufw status
   
   # Test port accessibility
   telnet your-domain.com 11112
   ```

2. **Unknown AE Title Error**:
   - Verify facility is created and active
   - Check AE title spelling (case-insensitive)
   - Ensure DICOM machine uses correct Calling AE Title

3. **Images Not Appearing**:
   ```bash
   # Check DICOM logs
   docker compose logs dicom_receiver
   
   # Verify facility association
   # Check user permissions for facility access
   ```

### Security Issues

1. **IP Blocked**:
   ```bash
   # Check security logs
   tail -f /opt/noctis/logs/dicom_security.log
   
   # Check fail2ban status
   sudo fail2ban-client status dicom-security
   
   # Unblock legitimate IP
   sudo fail2ban-client set dicom-security unbanip IP_ADDRESS
   ```

2. **Rate Limited**:
   - Reduce connection frequency from DICOM machine
   - Check for multiple simultaneous connections
   - Review rate limiting settings in environment

### Facility Management Issues

1. **Cannot Create Facility**:
   - Check database connectivity
   - Verify admin user permissions
   - Check for duplicate license numbers

2. **AE Title Conflicts**:
   - System automatically handles conflicts
   - Manual AE titles must be unique
   - Use facility edit to change AE title

## 📈 Performance Optimization

### For High-Volume Facilities

1. **Increase Resources**:
   ```bash
   # Edit docker-compose.internet.yml
   # Increase memory and CPU limits for dicom_receiver service
   ```

2. **Optimize Database**:
   - Regular maintenance and optimization
   - Monitor connection pool usage
   - Consider read replicas for reporting

3. **Storage Management**:
   - Monitor disk usage
   - Implement automated cleanup policies
   - Consider cloud storage for archival

## 🔄 Maintenance

### Regular Tasks

1. **Daily**:
   - Monitor DICOM logs for errors
   - Check system resource usage
   - Verify backup completion

2. **Weekly**:
   - Review security logs
   - Check facility activity statistics
   - Update system packages

3. **Monthly**:
   - Review and rotate logs
   - Check SSL certificate status
   - Audit user access and permissions

### Backup and Recovery

```bash
# Create system backup
./scripts/backup-system.sh

# List available backups
ls -la /opt/noctis/backups/

# Restore from backup (if needed)
./scripts/restore-system.sh backup-file.tar.gz
```

## 📞 Support

### For System Administrators

- **System Logs**: `/opt/noctis/logs/`
- **DICOM Logs**: `docker compose logs dicom_receiver`
- **Security Logs**: `/opt/noctis/logs/dicom_security.log`
- **Admin Panel**: `https://your-domain.com/admin/`

### For Facility Staff

- **Web Interface**: `https://your-domain.com/`
- **Facility Login**: Use credentials provided during setup
- **DICOM Status**: Check connection status and configuration
- **Support Contact**: Your system administrator

### Emergency Contacts

- **System Down**: Contact your server administrator
- **DICOM Issues**: Check facility AE title configuration
- **Security Alerts**: Review security logs and contact admin

---

## ✅ Verification Checklist

Before going live with internet access:

- [ ] All facilities created with proper AE titles
- [ ] Admin users configured and tested
- [ ] SSL certificates installed and working
- [ ] Firewall configured for internet access
- [ ] DICOM connectivity tested from each facility
- [ ] Security monitoring enabled
- [ ] Backup system operational
- [ ] Facility staff trained on system access
- [ ] DICOM machine operators trained on configuration
- [ ] Emergency procedures documented

---

**Your NOCTIS Pro system is now ready for internet-accessible DICOM operations with actual production data and real healthcare facilities.**