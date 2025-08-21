# NOCTIS Pro - Complete Setup Guide
## Ubuntu Desktop Development → Internet-Accessible Production

This is your complete guide for setting up NOCTIS Pro medical imaging system, from development on Ubuntu Desktop to production deployment with internet-accessible DICOM services.

## 🎯 What This System Provides

### Core Features
- **Medical Imaging Platform**: Complete DICOM workflow management
- **Facility Management**: Multi-facility support with unique AE titles
- **User Management**: Role-based access (Admin, Radiologist, Facility User)
- **Internet DICOM Access**: Secure reception of DICOM images over internet
- **Automatic Routing**: Images routed to correct facility based on AE title
- **Security**: Enhanced protection for internet-exposed services

### Facility-Based DICOM Workflow
1. **Create Facility** → Auto-generates unique AE title (e.g., "CITY_HOSPITAL")
2. **Configure DICOM Machine** → Use facility's AE title as Calling AE
3. **Send Images** → Automatically routed to correct facility
4. **Access Studies** → Facility users see only their facility's images

## 🚀 Quick Start Options

### Option 1: Development on Ubuntu Desktop
```bash
# One-command setup
./scripts/quick-start-desktop.sh

# Access: http://localhost:8000
# Admin: admin/admin123
```

### Option 2: Internet-Accessible Production
```bash
# Server setup
./scripts/setup-ubuntu-server.sh

# Configure for internet
cp .env.internet.example .env
nano .env  # Edit domain, passwords, etc.

# Deploy with internet access
./scripts/deploy-internet-access.sh

# Access: https://your-domain.com
```

## 📋 Complete Setup Process

### Phase 1: Desktop Development Setup

1. **Install Docker on Ubuntu Desktop**:
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   # Log out and back in
   ```

2. **Start Development Environment**:
   ```bash
   git clone <your-repo> noctis-pro
   cd noctis-pro
   ./scripts/quick-start-desktop.sh
   ```

3. **Verify Functionality**:
   ```bash
   ./scripts/verify-facility-user-management.sh
   ```

4. **Develop and Test**:
   - Access web interface: http://localhost:8000
   - Create test facilities and users
   - Test DICOM connectivity locally
   - Develop and customize features

### Phase 2: Server Preparation

1. **Prepare Ubuntu Server**:
   ```bash
   # On server
   ./scripts/setup-ubuntu-server.sh
   ```

2. **Transfer Data from Desktop**:
   ```bash
   # On desktop
   ./scripts/export-for-server.sh
   
   # Transfer to server
   scp noctis-export-*.tar.gz* user@server:/tmp/
   
   # On server
   ./scripts/import-from-desktop.sh /tmp/noctis-export-*.tar.gz
   ```

### Phase 3: Internet Access Configuration

1. **Configure Environment**:
   ```bash
   cd /opt/noctis
   cp .env.internet.example .env
   nano .env
   ```

   **Critical settings**:
   ```bash
   DOMAIN_NAME=your-medical-imaging.com
   SECRET_KEY=your-strong-secret-key
   POSTGRES_PASSWORD=strong-database-password
   LETSENCRYPT_EMAIL=admin@your-domain.com
   DICOM_EXTERNAL_ACCESS=True
   ```

2. **Deploy Internet Access**:
   ```bash
   ./scripts/deploy-internet-access.sh
   ```

3. **Verify Deployment**:
   - Web interface: https://your-domain.com
   - Admin panel: https://your-domain.com/admin/
   - DICOM port: telnet your-domain.com 11112

### Phase 4: Facility and DICOM Configuration

1. **Create Real Facilities**:
   - Access: https://your-domain.com/admin/
   - Navigate to "Facility Management"
   - Create each healthcare facility:
     - **Name**: "Regional Medical Center"
     - **AE Title**: Auto-generated → "REGIONAL_MED"
     - **Contact Info**: Complete facility details
     - **License**: Medical facility license number

2. **Configure DICOM Machines**:
   
   For each facility, provide their IT team:
   ```
   DICOM Server Configuration:
   Called AE Title:    NOCTIS_SCP
   Calling AE Title:   REGIONAL_MED  (facility-specific)
   Hostname:          your-domain.com
   Port:              11112
   Protocol:          DICOM TCP/IP
   Timeout:           30 seconds
   ```

3. **Test Connectivity**:
   ```bash
   # From facility's network
   telnet your-domain.com 11112
   
   # DICOM echo test (if DCMTK available)
   echoscu -aet REGIONAL_MED -aec NOCTIS_SCP your-domain.com 11112
   ```

## 🏥 Real-World Deployment Example

### Example: Multi-Hospital Network

**Scenario**: Regional healthcare network with 3 facilities

#### Facility 1: Main Hospital
- **Name**: "Regional Medical Center"
- **Generated AE Title**: "REGIONAL_MED"
- **DICOM Config**:
  ```
  Called AE: NOCTIS_SCP
  Calling AE: REGIONAL_MED
  Host: medical-imaging.healthnet.com
  Port: 11112
  ```

#### Facility 2: Outpatient Clinic
- **Name**: "Downtown Diagnostic Clinic"
- **Generated AE Title**: "DOWNTOWN_DIAG"
- **DICOM Config**:
  ```
  Called AE: NOCTIS_SCP
  Calling AE: DOWNTOWN_DIAG
  Host: medical-imaging.healthnet.com
  Port: 11112
  ```

#### Facility 3: Emergency Center
- **Name**: "Emergency Care Center"
- **Generated AE Title**: "EMERGENCY_CARE"
- **DICOM Config**:
  ```
  Called AE: NOCTIS_SCP
  Calling AE: EMERGENCY_CARE
  Host: medical-imaging.healthnet.com
  Port: 11112
  ```

### Result
- Each facility's DICOM images automatically route to their worklist
- Facility users see only their own facility's studies
- Radiologists can access studies from all facilities
- Complete audit trail of all DICOM activity

## 🔒 Security for Internet Access

### Automatic Security Features
- **AE Title Validation**: Only registered facilities accepted
- **Rate Limiting**: Prevents connection flooding
- **IP Monitoring**: Tracks suspicious activity
- **Fail2Ban**: Automatic blocking of attack attempts
- **SSL/TLS**: All web traffic encrypted
- **Facility Isolation**: Data segregation by facility

### Security Monitoring
```bash
# Monitor DICOM security
tail -f /opt/noctis/logs/dicom_security.log

# Check blocked IPs
sudo fail2ban-client status dicom-security

# View connection attempts
docker compose logs dicom_receiver | grep "Association"
```

## 📊 Production Monitoring

### System Health
```bash
# Overall system status
docker compose -f docker-compose.internet.yml ps

# Resource usage
docker stats

# Disk usage
df -h /opt/noctis/

# Check SSL certificates
sudo certbot certificates
```

### DICOM Activity
```bash
# Real-time DICOM logs
docker compose logs -f dicom_receiver

# Recent DICOM activity
docker compose exec web python manage.py shell -c "
from worklist.models import Study
from django.utils import timezone
from datetime import timedelta

recent = Study.objects.filter(
    upload_date__gte=timezone.now() - timedelta(hours=24)
).select_related('facility', 'patient')

print('Recent DICOM Activity (24h):')
for study in recent:
    print(f'{study.upload_date} | {study.facility.name} | {study.patient.patient_id} | {study.description[:50]}')
"
```

### Facility Management
- **Web Interface**: https://your-domain.com/admin/facilities/
- **View Statistics**: Studies per facility, user activity
- **Export Data**: Download facility and user reports
- **Audit Logs**: Complete activity tracking

## 🔧 Troubleshooting Real Issues

### DICOM Connection Problems

1. **Facility Cannot Connect**:
   ```bash
   # Check if facility exists and is active
   docker compose exec web python manage.py shell -c "
   from accounts.models import Facility
   f = Facility.objects.filter(ae_title='FACILITY_AE').first()
   print(f'Facility: {f.name if f else \"Not found\"}')
   print(f'Active: {f.is_active if f else \"N/A\"}')
   print(f'AE Title: {f.ae_title if f else \"N/A\"}')
   "
   
   # Check DICOM logs
   docker compose logs dicom_receiver | grep "FACILITY_AE"
   ```

2. **Images Not Appearing in Worklist**:
   ```bash
   # Check recent studies for facility
   docker compose exec web python manage.py shell -c "
   from worklist.models import Study
   from accounts.models import Facility
   
   facility = Facility.objects.get(ae_title='FACILITY_AE')
   recent_studies = Study.objects.filter(facility=facility).order_by('-upload_date')[:5]
   
   for study in recent_studies:
       print(f'{study.upload_date} | {study.patient.patient_id} | {study.description}')
   "
   ```

3. **AE Title Conflicts**:
   ```bash
   # Check for duplicate AE titles
   docker compose exec web python manage.py shell -c "
   from accounts.models import Facility
   from django.db.models import Count
   
   duplicates = Facility.objects.values('ae_title').annotate(
       count=Count('ae_title')
   ).filter(count__gt=1)
   
   for dup in duplicates:
       print(f'Duplicate AE Title: {dup[\"ae_title\"]} ({dup[\"count\"]} facilities)')
   "
   ```

### User Access Issues

1. **Cannot Access Admin Panel**:
   ```bash
   # Check admin users
   docker compose exec web python manage.py shell -c "
   from accounts.models import User
   admins = User.objects.filter(role='admin', is_active=True)
   for admin in admins:
       print(f'Admin: {admin.username} | Active: {admin.is_active}')
   "
   
   # Create admin if none exist
   docker compose exec web python manage.py createsuperuser
   ```

2. **Facility User Cannot See Studies**:
   ```bash
   # Check user-facility association
   docker compose exec web python manage.py shell -c "
   from accounts.models import User
   user = User.objects.get(username='facility_username')
   print(f'User: {user.username}')
   print(f'Role: {user.role}')
   print(f'Facility: {user.facility.name if user.facility else \"None\"}')
   print(f'Active: {user.is_active}')
   "
   ```

## 📈 Performance Optimization

### For High-Volume Facilities

1. **Increase DICOM Receiver Resources**:
   ```yaml
   # In docker-compose.internet.yml
   dicom_receiver:
     deploy:
       resources:
         limits:
           cpus: '4.0'
           memory: 2G
   ```

2. **Database Optimization**:
   ```bash
   # Monitor database performance
   docker compose exec db psql -U noctis_user -d noctis_pro -c "
   SELECT schemaname,tablename,n_tup_ins,n_tup_upd,n_tup_del 
   FROM pg_stat_user_tables 
   ORDER BY n_tup_ins DESC;
   "
   ```

3. **Storage Management**:
   ```bash
   # Monitor DICOM storage usage
   du -sh /opt/noctis/data/dicom_storage/
   
   # Storage by facility
   find /opt/noctis/data/dicom_storage/ -maxdepth 1 -type d -exec du -sh {} \;
   ```

## 🔄 Ongoing Maintenance

### Daily Tasks
- Monitor DICOM logs for errors
- Check system resource usage
- Verify backup completion

### Weekly Tasks
- Review security logs
- Check facility activity statistics
- Update system packages

### Monthly Tasks
- Audit user access and permissions
- Review and rotate logs
- Check SSL certificate status
- Backup verification and testing

## ✅ Production Readiness Checklist

### Before Going Live
- [ ] All real facilities created with proper information
- [ ] AE titles generated and documented for each facility
- [ ] DICOM machines configured at each facility
- [ ] SSL certificates installed and auto-renewal configured
- [ ] Firewall properly configured for internet access
- [ ] Security monitoring enabled (fail2ban, logging)
- [ ] Backup system operational and tested
- [ ] Admin users created and access verified
- [ ] Facility users created and permissions tested
- [ ] DICOM connectivity tested from each facility
- [ ] Performance monitoring in place
- [ ] Emergency procedures documented

### Post-Deployment
- [ ] Monitor DICOM logs for successful connections
- [ ] Verify images appear in correct facility worklists
- [ ] Test user access and permissions
- [ ] Monitor security logs for any issues
- [ ] Verify backup system is working
- [ ] Test disaster recovery procedures

## 📞 Support and Maintenance

### For System Administrators

**Daily Monitoring**:
```bash
# System status
docker compose -f docker-compose.internet.yml ps

# DICOM activity
docker compose logs --tail 50 dicom_receiver

# Security events
tail -f /opt/noctis/logs/dicom_security.log

# System resources
docker stats
htop
```

**Weekly Reports**:
```bash
# Facility activity report
docker compose exec web python manage.py shell -c "
from worklist.models import Study
from accounts.models import Facility
from django.utils import timezone
from datetime import timedelta

week_ago = timezone.now() - timedelta(days=7)
for facility in Facility.objects.filter(is_active=True):
    count = Study.objects.filter(facility=facility, upload_date__gte=week_ago).count()
    print(f'{facility.name}: {count} studies this week')
"
```

### For Facility Staff

**Access Information**:
- **Web Interface**: https://your-domain.com
- **Login**: Use credentials provided during setup
- **Support**: Contact your system administrator

**DICOM Machine Configuration**:
- Use your facility's unique AE title
- Test connectivity before sending patient data
- Monitor for connection errors

## 🔗 Key URLs and Access Points

### Web Interface
- **Main Application**: https://your-domain.com
- **Admin Panel**: https://your-domain.com/admin/
- **Facility Management**: https://your-domain.com/admin/facilities/
- **User Management**: https://your-domain.com/admin/users/

### DICOM Access
- **DICOM Port**: your-domain.com:11112
- **Protocol**: DICOM TCP/IP
- **Called AE**: NOCTIS_SCP
- **Calling AE**: [Facility-specific AE title]

### Monitoring
- **System Logs**: `/opt/noctis/logs/`
- **DICOM Logs**: `docker compose logs dicom_receiver`
- **Security Logs**: `/opt/noctis/logs/dicom_security.log`

## 🎉 Success Indicators

Your system is working correctly when:

✅ **Facilities**: Can create facilities with auto-generated AE titles  
✅ **Users**: Can create and manage users with proper role assignments  
✅ **DICOM**: Machines can connect using facility AE titles  
✅ **Routing**: Images appear in correct facility worklists  
✅ **Security**: Unauthorized connections are blocked  
✅ **SSL**: Web interface accessible via HTTPS  
✅ **Monitoring**: Logs show successful DICOM activity  
✅ **Performance**: System handles expected load  

## 📋 File Reference

### Configuration Files
- `docker-compose.desktop.yml` - Development environment
- `docker-compose.internet.yml` - Internet-accessible production
- `.env.desktop.example` - Development environment template
- `.env.internet.example` - Internet production template

### Scripts
- `quick-start-desktop.sh` - One-command desktop setup
- `setup-ubuntu-server.sh` - Server preparation
- `deploy-internet-access.sh` - Internet deployment
- `verify-facility-user-management.sh` - Functionality verification
- `export-for-server.sh` - Data export for transfer
- `import-from-desktop.sh` - Data import on server
- `backup-system.sh` - System backup

### Documentation
- `DOCKER_DEPLOYMENT_GUIDE.md` - Complete Docker guide
- `INTERNET_DICOM_SETUP.md` - Internet access details
- `FACILITY_SETUP_GUIDE.md` - Guide for facility staff

---

## 🎯 Your Next Steps

1. **Start Development**: Run `./scripts/quick-start-desktop.sh` on Ubuntu Desktop
2. **Verify Functionality**: Run `./scripts/verify-facility-user-management.sh`
3. **Create Test Facilities**: Use admin panel to create actual facilities
4. **Test DICOM Locally**: Configure a local DICOM sender if available
5. **Deploy to Server**: When ready, use the transfer and deployment scripts
6. **Configure Internet Access**: Use `deploy-internet-access.sh` for production
7. **Configure Real DICOM Machines**: Provide facilities with their AE titles

Your NOCTIS Pro medical imaging system is now ready for both development and internet-accessible production deployment with real facility and patient data management!