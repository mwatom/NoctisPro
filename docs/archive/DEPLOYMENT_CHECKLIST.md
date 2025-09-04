# 🏥 NoctisPro Ubuntu Server 24.04 Deployment Checklist

## ✅ Pre-Deployment Requirements

### System Requirements
- [ ] Ubuntu Server 24.04 LTS (or 25.04) installed
- [ ] Minimum 8GB RAM (16GB+ recommended)
- [ ] Minimum 100GB storage (500GB+ recommended)
- [ ] 4+ CPU cores (8+ recommended)
- [ ] Internet connectivity available
- [ ] Root/sudo access confirmed

### Network Requirements
- [ ] Server IP address documented
- [ ] Domain name configured (optional, for HTTPS)
- [ ] DNS records pointing to server (if using domain)
- [ ] Firewall rules planned (ports 80, 443, 22)

### Preparation Steps
- [ ] System updated: `sudo apt update && sudo apt upgrade -y`
- [ ] Essential tools installed: `sudo apt install -y curl wget git`
- [ ] Timezone configured: `sudo timedatectl set-timezone America/New_York`
- [ ] Hostname set: `sudo hostnamectl set-hostname noctis-production`

## 🚀 Deployment Process

### Option A: Automated Production Deployment

#### Step 1: Repository Setup
- [ ] Repository cloned: `git clone https://github.com/mwatom/NoctisPro.git`
- [ ] Directory changed: `cd NoctisPro`
- [ ] Scripts made executable: `chmod +x *.sh scripts/*.sh`

#### Step 2: Configuration
- [ ] Domain configured in `deploy_noctis_production.sh` (line 20)
- [ ] Server IP verified in configuration
- [ ] Environment variables reviewed

#### Step 3: Production Deployment
- [ ] Production script executed: `sudo ./deploy_noctis_production.sh`
- [ ] Deployment completed without errors
- [ ] All services started successfully

#### Step 4: HTTPS Configuration (Recommended)
- [ ] Secure access script executed: `sudo ./setup_secure_access.sh`
- [ ] Option 1 selected (Domain with HTTPS)
- [ ] SSL certificate obtained and configured
- [ ] HTTPS redirect enabled

### Option B: Docker-Based Deployment

#### Step 1: Environment Setup
- [ ] Environment file created: `cp .env.example .env`
- [ ] Environment variables configured in `.env`
- [ ] Docker directories created

#### Step 2: Docker Deployment
- [ ] Production containers started: `sudo docker compose -f docker-compose.production.yml up -d`
- [ ] All containers running: `sudo docker compose -f docker-compose.production.yml ps`
- [ ] Health checks passing

## 🔍 Post-Deployment Validation

### System Services
- [ ] Django service active: `sudo systemctl status noctis-django`
- [ ] Daphne service active: `sudo systemctl status noctis-daphne`
- [ ] Celery service active: `sudo systemctl status noctis-celery`
- [ ] PostgreSQL active: `sudo systemctl status postgresql`
- [ ] Redis active: `sudo systemctl status redis-server`
- [ ] Nginx active: `sudo systemctl status nginx`
- [ ] CUPS active: `sudo systemctl status cups`

### Network Connectivity
- [ ] HTTP access working: `curl -I http://server-ip`
- [ ] HTTPS access working: `curl -I https://domain-name` (if configured)
- [ ] Admin panel accessible: `http://server-ip/admin`
- [ ] API documentation accessible: `http://server-ip/api/docs/`

### Security Configuration
- [ ] Firewall active: `sudo ufw status verbose`
- [ ] Fail2ban running: `sudo fail2ban-client status`
- [ ] SSL certificate valid: `sudo certbot certificates` (if HTTPS)
- [ ] Security headers present: `curl -I https://domain-name | grep -E "(Strict-Transport|X-Frame)"`

### Application Functionality
- [ ] Login working with admin/admin123
- [ ] Admin password changed from default
- [ ] DICOM viewer accessible
- [ ] File upload functionality working
- [ ] Database connectivity confirmed
- [ ] Cache system operational

### Validation Script
- [ ] Comprehensive validation completed: `python3 validate_production_ubuntu24.py`
- [ ] All validation tests passed
- [ ] Performance benchmarks acceptable

## 🏥 Medical Features Verification

### DICOM Processing
- [ ] DICOM file upload working
- [ ] Image viewer displaying correctly
- [ ] Measurement tools functional
- [ ] Window/level controls working
- [ ] 3D reconstruction available (if applicable)

### Worklist Management
- [ ] Patient management accessible
- [ ] Study organization working
- [ ] Search functionality operational
- [ ] Report generation available

### Printing System
- [ ] CUPS service configured
- [ ] Printer drivers installed
- [ ] Print functionality tested (if printer available)
- [ ] Print queue management working

### AI Analysis
- [ ] AI analysis modules loaded
- [ ] Automated analysis functional
- [ ] Analysis reports generating

## 🛡️ Security Checklist

### Network Security
- [ ] UFW firewall configured and active
- [ ] Only necessary ports open (22, 80, 443)
- [ ] SSH access secured
- [ ] Fail2ban monitoring active
- [ ] Rate limiting configured

### Application Security
- [ ] HTTPS enforced (if configured)
- [ ] Security headers enabled
- [ ] CSRF protection active
- [ ] Session security configured
- [ ] Database access restricted
- [ ] File upload security enabled

### Access Control
- [ ] Default admin password changed
- [ ] User roles and permissions configured
- [ ] Audit logging enabled
- [ ] Session timeout configured

## 📊 Performance and Monitoring

### System Performance
- [ ] Resource usage acceptable: `htop`
- [ ] Disk space sufficient: `df -h`
- [ ] Database performance optimized
- [ ] Cache hit rates acceptable
- [ ] Response times under 2 seconds

### Monitoring Setup
- [ ] System status script available: `/usr/local/bin/noctis-status.sh`
- [ ] Log rotation configured
- [ ] Backup system operational: `/usr/local/bin/noctis-backup.sh`
- [ ] Monitoring alerts configured (optional)

### Backup System
- [ ] Automated backup script created
- [ ] Database backup tested
- [ ] Media files backup tested
- [ ] Backup retention policy configured
- [ ] Restore procedure documented

## 🔄 Maintenance and Updates

### Update Mechanism
- [ ] GitHub webhook configured (optional)
- [ ] Manual update procedure documented
- [ ] Rollback procedure planned
- [ ] Update testing process defined

### Regular Maintenance
- [ ] Daily status checks scheduled
- [ ] Weekly maintenance tasks defined
- [ ] Monthly security updates planned
- [ ] Quarterly performance reviews scheduled

## 📞 Documentation and Support

### System Documentation
- [ ] Server configuration documented
- [ ] Network setup documented
- [ ] Security configuration recorded
- [ ] User accounts and permissions documented

### Critical Information Saved
- [ ] Database password secured
- [ ] Django secret key secured
- [ ] Redis password secured
- [ ] SSL certificate details recorded
- [ ] Domain configuration documented

### Access Information
- [ ] Web interface URL documented
- [ ] Admin panel URL documented
- [ ] API documentation URL documented
- [ ] Default credentials changed and new ones secured

## 🎯 Go-Live Checklist

### Final Verification
- [ ] All services running and stable
- [ ] Performance testing completed
- [ ] Security audit passed
- [ ] User acceptance testing completed
- [ ] Backup and recovery tested

### User Training
- [ ] Admin users trained
- [ ] End-user documentation provided
- [ ] Support procedures established
- [ ] Troubleshooting guide available

### Production Readiness
- [ ] Load testing completed
- [ ] Disaster recovery plan in place
- [ ] Support contacts established
- [ ] Monitoring and alerting active

## 🚨 Troubleshooting Quick Reference

### Common Issues
- **Docker not starting**: Check iptables compatibility (Ubuntu 24.04/25.04)
  ```bash
  sudo apt install -y iptables-persistent
  sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
  sudo systemctl restart docker
  ```

- **Services not starting**: Check dependencies
  ```bash
  sudo systemctl status postgresql redis-server
  sudo journalctl -u noctis-django --no-pager -l
  ```

- **Permission issues**: Fix ownership
  ```bash
  sudo chown -R noctis:noctis /opt/noctis_pro
  ```

- **SSL certificate issues**: Check domain configuration
  ```bash
  sudo certbot certificates
  nslookup your-domain.com
  ```

### Log Locations
- Application logs: `/opt/noctis_pro/logs/`
- System logs: `sudo journalctl -u noctis-django`
- Nginx logs: `/var/log/nginx/`
- Database logs: `sudo journalctl -u postgresql`

### Emergency Commands
- Restart all services: `sudo systemctl restart noctis-django noctis-daphne noctis-celery nginx`
- Check system status: `sudo /usr/local/bin/noctis-status.sh`
- Create backup: `sudo /usr/local/bin/noctis-backup.sh`
- View real-time logs: `sudo journalctl -u noctis-django -f`

---

## ✅ Deployment Complete

When all items in this checklist are completed:

🎉 **Congratulations!** Your NoctisPro medical imaging platform is successfully deployed and ready for production use.

### Final System Access
- **Web Interface**: `http://your-server-ip` or `https://your-domain.com`
- **Admin Panel**: `http://your-server-ip/admin` or `https://your-domain.com/admin`
- **API Documentation**: `http://your-server-ip/api/docs/`

### Next Steps
1. Begin user training and onboarding
2. Start regular maintenance schedule
3. Monitor system performance
4. Plan for future scaling and updates

**🏥 NoctisPro is now ready to serve your medical imaging needs!**