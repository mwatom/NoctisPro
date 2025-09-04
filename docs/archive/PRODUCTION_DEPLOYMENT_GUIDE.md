# Noctis Pro PACS - Production Deployment with Public Access

## 🚀 Quick Start (Recommended)

For immediate production deployment with public access:

```bash
cd /workspace
./start_production_public.sh
```

This single command will:
- ✅ Set up production environment
- ✅ Start Django with Gunicorn
- ✅ Create ngrok tunnel for public access
- ✅ Display public URLs for sharing

## 📋 Deployment Options

### Option 1: Quick Production Start (Easiest)
```bash
./start_production_public.sh
```
- **Best for**: Quick demos, testing, immediate access
- **Features**: Auto-setup, public URL, monitoring
- **Time**: ~2 minutes

### Option 2: Full Production Deployment (Most Complete)
```bash
./deploy_production_ngrok.sh
```
- **Best for**: Full production setup, multiple services
- **Features**: Gunicorn + Daphne, systemd services, comprehensive logging
- **Time**: ~5 minutes

### Option 3: ngrok Setup First (If Authentication Needed)
```bash
./setup_ngrok_auth.sh
./deploy_production_ngrok.sh
```
- **Best for**: When you have an ngrok account with authtoken
- **Features**: Custom domains, higher limits, persistent URLs

## 🔐 ngrok Authentication (Optional but Recommended)

### Free Tier (No Authentication Required)
- ✅ Works immediately
- ⚠️ Random URLs that change on restart
- ⚠️ 40 connections per minute limit
- ⚠️ URLs expire after 2 hours of inactivity

### With Authentication (Recommended)
1. Sign up at [ngrok.com](https://ngrok.com/signup)
2. Get your authtoken from [dashboard](https://dashboard.ngrok.com/get-started/your-authtoken)
3. Run: `./setup_ngrok_auth.sh`
4. Enter your authtoken when prompted

### Premium Features (Paid Plans)
- 🎯 Custom domains (e.g., `yourcompany.ngrok.io`)
- 🔒 Password protection
- 📊 Higher connection limits
- 🔄 Reserved URLs that don't change

## 🌐 Access Information

### Public URLs (via ngrok)
- **Main Application**: `https://random-name.ngrok-free.app`
- **Admin Panel**: `https://random-name.ngrok-free.app/admin`
- **DICOM Viewer**: `https://random-name.ngrok-free.app/dicom-viewer/`
- **Worklist**: `https://random-name.ngrok-free.app/worklist/`
- **API**: `https://random-name.ngrok-free.app/api/`

### Local URLs
- **Main Application**: `http://localhost:8000`
- **ngrok Dashboard**: `http://localhost:4040`

### Default Credentials
- **Administrator**: `admin` / `NoctisPro2024!`
- **Doctor**: `doctor` / `doctor123`
- **Radiologist**: `radiologist` / `radio123`
- **Technician**: `technician` / `tech123`

## 🛡️ Security Features

### Production Security Settings
- ✅ DEBUG = False
- ✅ HTTPS enforced via ngrok
- ✅ CSRF protection enabled
- ✅ Secure session configuration
- ✅ XSS protection headers
- ✅ Content type sniffing protection

### File Upload Security
- ✅ 100MB file size limit
- ✅ DICOM file validation
- ✅ Secure file storage
- ✅ Path traversal protection

### Database Security
- ✅ Connection pooling
- ✅ Query optimization
- ✅ Backup-ready configuration

## 🔧 System Architecture

### Production Stack
```
Internet → ngrok → Gunicorn → Django → SQLite
                 ↘ Daphne → WebSocket Support
```

### Process Management
- **Gunicorn**: 2-4 worker processes for HTTP requests
- **Daphne**: ASGI server for WebSocket connections
- **ngrok**: Secure tunnel for public access

### File Structure
```
/workspace/
├── db.sqlite3              # Database
├── staticfiles/            # Static files (CSS, JS, images)
├── media/                  # Uploaded files and DICOM storage
├── logs/                   # Application logs
├── venv/                   # Python virtual environment
└── deployment_info.txt     # Deployment details
```

## 📊 Monitoring and Logs

### Log Files
```bash
# Django application logs
tail -f django.log
tail -f logs/django.log

# ngrok tunnel logs
tail -f ngrok.log
tail -f logs/ngrok.log

# Access logs (HTTP requests)
tail -f logs/access.log

# Error logs
tail -f logs/error.log
```

### Monitoring Dashboard
- **ngrok Dashboard**: `http://localhost:4040`
  - View tunnel status
  - See request/response details
  - Monitor connection statistics

### Health Checks
- **Simple Health**: `/health/simple/`
- **Detailed Health**: `/health/`
- **System Status**: `/health/ready/`

## 🔄 Management Commands

### Starting Services
```bash
# Quick start (recommended)
./start_production_public.sh

# Full deployment
./deploy_production_ngrok.sh

# Manual start
source venv/bin/activate
gunicorn --bind 0.0.0.0:8000 noctis_pro.wsgi:application &
./ngrok http 8000 &
```

### Stopping Services
```bash
# Stop all services
pkill -f gunicorn
pkill -f ngrok

# Or use the generated stop script
./stop_production.sh
```

### Restarting Services
```bash
# Stop and restart
pkill -f gunicorn && pkill -f ngrok
sleep 3
./start_production_public.sh
```

### Database Management
```bash
source venv/bin/activate
python manage.py migrate                    # Apply migrations
python manage.py createsuperuser           # Create admin user
python manage.py collectstatic --noinput   # Update static files
python manage.py shell                     # Django shell
```

## 🌍 Sharing Access

### For Team Members
1. Start the production system
2. Share the ngrok URL (e.g., `https://abc123.ngrok-free.app`)
3. Provide login credentials
4. Team members can access from anywhere

### For Clients/Demos
1. Use the public ngrok URL
2. Create demo accounts with limited permissions
3. Share specific feature URLs:
   - DICOM Viewer: `/dicom-viewer/`
   - Worklist: `/worklist/`
   - Reports: `/reports/`

### For Development Teams
1. Share the repository
2. Each developer can run their own instance
3. Use ngrok for sharing development progress

## 🚨 Troubleshooting

### Common Issues

#### ngrok Tunnel Not Starting
```bash
# Check if ngrok is running
ps aux | grep ngrok

# Check ngrok logs
tail -f ngrok.log

# Restart ngrok
pkill -f ngrok
./ngrok http 8000 &
```

#### Django Not Responding
```bash
# Check Django process
ps aux | grep gunicorn

# Check Django logs
tail -f django.log

# Restart Django
pkill -f gunicorn
source venv/bin/activate
gunicorn --bind 0.0.0.0:8000 noctis_pro.wsgi:application &
```

#### Database Issues
```bash
# Check database file
ls -la db.sqlite3

# Reset database (WARNING: loses data)
rm db.sqlite3
python manage.py migrate
python manage.py createsuperuser
```

#### Port Already in Use
```bash
# Find process using port 8000
lsof -i :8000

# Kill process
pkill -f "8000"

# Or use different port
gunicorn --bind 0.0.0.0:8001 noctis_pro.wsgi:application &
./ngrok http 8001 &
```

### Performance Issues

#### Slow Response Times
- Increase Gunicorn workers: `--workers 4`
- Check database queries in Django admin
- Monitor system resources: `htop`

#### High Memory Usage
- Reduce Gunicorn workers
- Clear DICOM cache: restart application
- Monitor with: `free -h`

#### Connection Limits
- Upgrade ngrok plan for higher limits
- Use connection pooling
- Implement request queuing

## 📈 Scaling and Optimization

### For Higher Traffic
1. **Increase Workers**: Modify Gunicorn workers count
2. **Add Load Balancer**: Use nginx or similar
3. **Database Optimization**: Switch to PostgreSQL
4. **Caching**: Add Redis for session/cache storage
5. **CDN**: Use CDN for static files

### For Better Performance
1. **Static Files**: Use WhiteNoise or CDN
2. **Database**: Optimize queries and add indexes
3. **DICOM Processing**: Implement background tasks
4. **Monitoring**: Add application performance monitoring

### For Production Deployment
1. **SSL Certificate**: Use proper SSL (not just ngrok)
2. **Domain**: Use custom domain instead of ngrok
3. **Database**: PostgreSQL with backups
4. **Monitoring**: Comprehensive logging and alerting
5. **Security**: Regular security audits and updates

## 📞 Support

### Getting Help
- Check logs first: `tail -f *.log`
- Review this guide
- Check Django documentation
- Review ngrok documentation

### Reporting Issues
Include in your report:
- Error messages from logs
- Steps to reproduce
- System information
- Deployment method used

## 🎯 Next Steps

After successful deployment:

1. **Customize**: Update branding, colors, logos
2. **Configure**: Set up DICOM modalities and workstations
3. **Train**: Train users on the system
4. **Monitor**: Set up monitoring and alerting
5. **Backup**: Implement regular backups
6. **Scale**: Plan for growth and higher usage

---

## 🎉 Success!

Your Noctis Pro PACS system is now running in production mode with public access via ngrok. The system provides:

- ✅ Complete DICOM PACS functionality
- ✅ Web-based DICOM viewer
- ✅ Worklist management
- ✅ User authentication and authorization
- ✅ RESTful API access
- ✅ Real-time WebSocket support
- ✅ Professional medical imaging interface
- ✅ Public internet access via secure HTTPS tunnel

Share the ngrok URL with your team and start using your professional PACS system immediately!