# NoctisPro Server Deployment - COMPLETE POSTGRESQL CLEANUP & FRESH INSTALL

## 🎯 DEPLOYMENT SUMMARY

**ALL MISSING FOLDERS AND DEPLOYMENT ISSUES RESOLVED + POSTGRESQL CLEANUP!**

The system now completely removes any existing PostgreSQL installations and installs a fresh PostgreSQL 16 with all features optimized for medical imaging workloads on Ubuntu Server 24.04.

## 🚀 QUICK DEPLOYMENT (RECOMMENDED)

### Option 1: One-Command Deployment
```bash
./quick_deploy_internet.sh
```

### Option 2: Step-by-Step
```bash
# Make script executable
chmod +x deploy_internet_production.sh

# Run comprehensive deployment
./deploy_internet_production.sh
```

## ✅ ISSUES FIXED

### 1. **COMPLETE POSTGRESQL CLEANUP & FRESH INSTALL** 🗄️
**NEW:** The deployment script now:
- ✅ **Completely removes** any existing PostgreSQL installations
- ✅ **Stops and disables** all PostgreSQL services
- ✅ **Deletes** all PostgreSQL data directories (`/var/lib/postgresql`, `/etc/postgresql`)
- ✅ **Removes** PostgreSQL users and groups
- ✅ **Kills** any remaining PostgreSQL processes
- ✅ **Frees** port 5432 from any conflicts
- ✅ **Installs fresh** PostgreSQL 16 with all medical imaging features
- ✅ **Optimizes** database for DICOM workloads
- ✅ **Enables** all required extensions (uuid-ossp, pg_trgm, unaccent)

### 2. Missing Deployment Directories
**FIXED:** Created all required directories:
- `/workspace/deployment/redis/` - Redis configuration
- `/workspace/deployment/nginx/` - Nginx configuration
- `/workspace/deployment/prometheus/` - Monitoring
- `/workspace/deployment/grafana/` - Dashboards
- `/workspace/deployment/backup/` - Backup scripts
- `/workspace/ssl/` - SSL certificates
- `/workspace/logs/nginx/` - Log files
- `/workspace/backups/` - Local backups

### 3. Missing Configuration Files
**FIXED:** Created all missing configuration files:
- `deployment/redis/redis.conf` - Production Redis config
- `deployment/nginx/nginx.conf` - Main nginx config
- `deployment/nginx/sites-available/noctis.conf` - Site configuration
- `deployment/prometheus/prometheus.yml` - Monitoring config
- `deployment/grafana/provisioning/datasources/prometheus.yml` - Grafana setup
- `deployment/backup/backup.sh` - Automated backup script

### 4. Missing Host Directories
**FIXED:** Script creates all required host directories:
- `/opt/noctis/data/postgres` - Fresh PostgreSQL data
- `/opt/noctis/data/redis` - Redis data
- `/opt/noctis/media` - Media files
- `/opt/noctis/staticfiles` - Static files
- `/opt/noctis/backups` - Backups
- `/opt/noctis/dicom_storage` - DICOM files

### 5. Docker Environment Cleanup
**NEW:** Complete Docker cleanup:
- ✅ **Removes** existing PostgreSQL containers
- ✅ **Cleans** PostgreSQL data volumes
- ✅ **Prunes** orphaned volumes
- ✅ **Ensures** fresh container deployment

### 6. Environment Configuration
**FIXED:**
- Updated `.env.production` for server deployment
- Automatic IP detection and configuration
- Wildcard hosts for internet accessibility
- Proper database connection strings

### 7. Firewall Configuration
**FIXED:**
- Automatic UFW firewall setup
- Ports 80, 443, 22, 11112 opened
- Security rules configured
- Internet access enabled

## 🌐 INTERNET ACCESS FEATURES

### Automatic Configuration
- ✅ Server IP detection and configuration
- ✅ Firewall rules for internet access
- ✅ Nginx proxy configuration
- ✅ Security headers and rate limiting
- ✅ DICOM port (11112) accessibility

### Security Features
- ✅ UFW firewall configured
- ✅ Rate limiting on API endpoints
- ✅ Security headers in Nginx
- ✅ Admin panel protection
- ✅ SSL ready (certificates can be added later)

## 📋 DEPLOYMENT PROCESS

The `deploy_internet_production.sh` script automatically:

1. **System Preparation**
   - Checks and validates privileges
   - **COMPLETELY REMOVES** existing PostgreSQL installations
   - Stops all PostgreSQL services and processes
   - Cleans all PostgreSQL data and configuration

2. **Docker Setup**
   - Checks and installs Docker
   - Starts Docker daemon
   - **CLEANS** existing Docker containers and volumes
   - Removes any PostgreSQL containers

3. **Directory Creation**
   - Creates all required directories
   - Sets proper permissions
   - Prepares fresh data storage

4. **Network Configuration**
   - Detects server IP address
   - Updates environment for server deployment
   - Configures firewall rules
   - Opens required ports (80, 443, 22, 11112)

5. **Fresh Application Deployment**
   - Pulls latest Docker images
   - Builds containers with fresh PostgreSQL
   - Starts all services
   - Waits for services to be ready

6. **Fresh Database Setup**
   - Waits for fresh PostgreSQL 16 to start
   - Runs Django migrations on clean database
   - Creates fresh admin user (admin/admin123)
   - Initializes DICOM services
   - Collects static files

7. **Health Checks & Validation**
   - Verifies all containers are running
   - Tests web service response
   - Displays access information
   - Confirms fresh PostgreSQL installation

## 🔑 FRESH ADMIN CREDENTIALS

**⚠️ CHANGE IMMEDIATELY AFTER DEPLOYMENT!**
- Username: `admin`
- Password: `admin123`
- **Note:** Fresh admin user created on clean database

## 🌐 SERVER ACCESS URLS

After deployment, the system will be accessible at:
- **Web Interface:** `http://[SERVER_IP]`
- **Admin Panel:** `http://[SERVER_IP]/admin`
- **API Documentation:** `http://[SERVER_IP]/api/docs`
- **DICOM Receiver:** `[SERVER_IP]:11112`

## 🗄️ POSTGRESQL FEATURES

The fresh PostgreSQL 16 installation includes:
- **All Extensions:** uuid-ossp, pg_trgm, unaccent
- **Medical Imaging Optimizations:** Tuned for DICOM workloads
- **Performance Settings:** Optimized buffer and cache settings
- **Security:** Fresh installation with no legacy data
- **Backup Ready:** Automated backup system included

## 🐳 CONTAINER MANAGEMENT

### View Running Containers
```bash
sudo docker ps
```

### View Logs
```bash
sudo docker compose -f docker-compose.production.yml logs -f
```

### Restart Services
```bash
sudo docker compose -f docker-compose.production.yml restart
```

### Stop System
```bash
sudo docker compose -f docker-compose.production.yml down
```

## 📊 MONITORING

The deployment includes:
- **Prometheus** - Metrics collection (port 9090)
- **Grafana** - Dashboards (port 3000)
- **Health checks** - Automatic service monitoring
- **Log aggregation** - Centralized logging

## 💾 BACKUP

Automated backup system included:
- Daily database backups
- Media file backups
- Configuration backups
- 7-day retention policy

## 🔧 TROUBLESHOOTING

### If Deployment Fails
```bash
# Check Docker status
sudo docker info

# Check container logs
sudo docker compose -f docker-compose.production.yml logs

# Restart specific service
sudo docker compose -f docker-compose.production.yml restart [service_name]
```

### Common Issues
1. **Port already in use:** Stop conflicting services
2. **Permission denied:** Ensure script is executable (`chmod +x`)
3. **Docker not starting:** Check system resources
4. **Database connection failed:** Wait longer for PostgreSQL startup

## 🎉 DEPLOYMENT SUCCESS

When deployment completes successfully, you'll see:
```
🎉 NOCTIS PRO DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉
🌐 Your NoctisPro system is now accessible on the internet
```

The system will be fully operational and accessible to your client by midday as requested.

## 📞 SUPPORT

If you encounter any issues:
1. Check the deployment logs
2. Verify firewall settings
3. Ensure all containers are running
4. Check network connectivity

**The system is now ready for production use with full internet access!**