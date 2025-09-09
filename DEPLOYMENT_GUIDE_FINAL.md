# NoctisPro PACS - Final Deployment Guide

## 🚀 Quick Start (Recommended)

### One-Command Auto Deployment
```bash
./deploy_auto.sh
```
This script will:
- ✅ Auto-detect your domain (using public IP + nip.io or localhost)
- ✅ Set default email (admin@noctispro.local)
- ✅ Choose best deployment method (Docker or Native)
- ✅ Fix potential 500 errors automatically
- ✅ Clean up unnecessary files
- ✅ Create admin user (admin/admin123)

### Docker-Only Deployment
```bash
./deploy_docker.sh
```

## 🌐 Static HTTPS URL Setup

### Option 1: Auto HTTPS (Recommended)
```bash
DOMAIN=your-domain.com EMAIL=your-email@domain.com ./deploy_https_quick.sh
```

### Option 2: Manual Domain Override
```bash
FORCE_DOMAIN=pacs.hospital.com FORCE_EMAIL=admin@hospital.com ./deploy_auto.sh
```

## 📋 What's Been Cleaned Up

### ✅ Removed Unnecessary Scripts:
- `deploy_ngrok_one_command.sh`
- `deploy_quick.sh`
- `deploy_ubuntu_gui_master.sh`
- `deploy-one-command.sh`
- `deploy-simple.sh`
- `quick_parrot_setup.sh`
- `create_bootable_ubuntu.sh`
- `ubuntu_gui_deployment.sh`

### ✅ Essential Scripts Kept:
- `deploy_auto.sh` - **Main auto-deployment script**
- `deploy_docker.sh` - **Docker-specific deployment**
- `deploy_https_quick.sh` - **HTTPS setup**
- `deploy_master.sh` - **Advanced deployment**
- `deploy_noctispro.sh` - **Native deployment**

## 🔧 Auto-Detection Features

### Domain Detection:
1. **Environment Variable**: `FORCE_DOMAIN` or `NGROK_URL`
2. **Public IP**: Auto-detects public IP and creates `noctispro-IP.nip.io`
3. **Hostname**: Uses system hostname if available
4. **Fallback**: Uses `localhost`

### Email Detection:
1. **Environment Variable**: `FORCE_EMAIL` or `EMAIL`
2. **Git Config**: Uses `git config user.email`
3. **Default**: `admin@noctispro.local`

### Deployment Type Detection:
1. **Kubernetes**: If `kubectl` is available and cluster is accessible
2. **Docker**: If Docker and Docker Compose are installed
3. **Native**: If systemd is available (Linux)

## 🛠️ 500 Error Prevention

The system automatically:
- ✅ Creates necessary directories (`logs`, `media`, `static`, `staticfiles`)
- ✅ Generates secure `.env` file with proper SECRET_KEY
- ✅ Sets correct file permissions
- ✅ Runs database migrations
- ✅ Collects static files
- ✅ Creates admin superuser
- ✅ Validates Django app configurations

## 🐳 Docker Deployment Features

### Optimized Configuration:
- **Multi-stage health checks**
- **Automatic database setup**
- **Static file collection**
- **Admin user creation**
- **Nginx reverse proxy**
- **Rate limiting**
- **Security headers**
- **Gzip compression**

### Docker Compose Files:
- `docker-compose.optimized.yml` - **Production-ready setup**
- `docker-compose.yml` - **Basic setup**

## 📊 Access Information

After deployment, access your PACS at:

### Web Interface:
- **Local**: http://localhost:8000
- **External**: http://your-detected-domain
- **Admin Panel**: /admin/
- **Worklist**: /worklist/

### Default Credentials:
- **Username**: admin
- **Password**: admin123

### DICOM Configuration:
- **AE Title**: NOCTIS_SCP
- **Port**: 11112
- **Protocol**: DICOM TCP/IP

## 🔒 Security Features

### Automatic Security:
- ✅ Secure SECRET_KEY generation
- ✅ Debug mode disabled in production
- ✅ Security headers (XSS, CSRF, etc.)
- ✅ Rate limiting on sensitive endpoints
- ✅ Secure file permissions
- ✅ SQL injection protection

### HTTPS Ready:
- ✅ Let's Encrypt integration
- ✅ Automatic certificate renewal
- ✅ SSL redirect configuration
- ✅ HSTS headers

## 🚨 Troubleshooting

### Common Issues:

#### Deployment Fails:
```bash
# Check logs
./deploy_auto.sh 2>&1 | tee deployment.log

# Force specific deployment type
DEPLOYMENT_TYPE=docker ./deploy_auto.sh
```

#### Docker Issues:
```bash
# Check container status
docker-compose -f docker-compose.optimized.yml ps

# View logs
docker-compose -f docker-compose.optimized.yml logs -f

# Rebuild containers
docker-compose -f docker-compose.optimized.yml up --build -d
```

#### 500 Errors:
```bash
# Run fix script
python3 fix_500_errors.py

# Check Django logs
tail -f logs/noctis_pro.log
```

#### Port Conflicts:
```bash
# Check what's using ports
sudo lsof -i :8000
sudo lsof -i :11112

# Kill conflicting processes
sudo pkill -f gunicorn
sudo pkill -f dicom_receiver
```

## 📈 Performance Optimization

### Automatic Optimizations:
- **Worker processes**: CPU-based calculation
- **Memory limits**: RAM-aware allocation
- **Connection pooling**: Database optimization
- **Static file caching**: Nginx optimization
- **Gzip compression**: Reduced bandwidth usage

### Resource Requirements:
- **Minimum**: 1GB RAM, 1 CPU, 5GB storage
- **Recommended**: 4GB RAM, 2 CPU, 20GB storage
- **Production**: 8GB RAM, 4 CPU, 100GB storage

## 🎯 Next Steps

1. **Deploy**: Run `./deploy_auto.sh`
2. **Access**: Open http://localhost:8000/admin/
3. **Login**: Use admin/admin123
4. **Configure**: Set up your facility and users
5. **HTTPS**: Run `./deploy_https_quick.sh` for production
6. **DICOM**: Configure your modalities to send to port 11112

## 📞 Support

If you encounter issues:
1. Check this guide first
2. Look at the logs in the `logs/` directory
3. Run the auto-deployment script again
4. Check Docker container status if using Docker

---

**🎉 Your NoctisPro PACS is now ready for deployment!**

The system will auto-detect your environment and deploy with the best configuration for your setup. Both Docker and native deployments are fully tested and optimized for production use.