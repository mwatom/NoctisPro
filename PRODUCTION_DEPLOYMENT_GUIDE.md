# 🚀 NoctisPro Production Deployment Guide

## Quick Setup (One Command)

To deploy NoctisPro in production mode on your server:

```bash
./start_production.sh
```

## 🎯 What This Does

The production deployment:
- ✅ Stops any existing development servers
- ✅ Starts Redis in daemon mode
- ✅ Runs Django with Gunicorn (production WSGI server)
- ✅ Creates ngrok tunnel for external access
- ✅ Runs everything in background processes
- ✅ Saves process IDs for easy management
- ✅ Creates detailed logs

## 📋 Management Commands

### Start Services
```bash
./start_production.sh
```

### Stop Services
```bash
./stop_production.sh
```

### Check Status
```bash
./status_production.sh
```

### Get Current URL
```bash
./get_ngrok_url.sh
```

### Restart Services
```bash
./stop_production.sh && ./start_production.sh
```

## 📊 Service Information

### Processes
- **Django/Gunicorn**: Runs on port 8000 with 3 workers
- **Ngrok**: Creates secure tunnel to external world
- **Redis**: Backend cache and session storage

### Log Files
- `logs/gunicorn-access.log` - HTTP access logs
- `logs/gunicorn-error.log` - Django application errors
- `logs/gunicorn.log` - General Gunicorn logs
- `logs/ngrok.log` - Ngrok tunnel logs

### PID Files
- `django.pid` - Django/Gunicorn process ID
- `ngrok.pid` - Ngrok process ID

## 🌐 Access URLs

After starting, your application will be available at:
- **Public URL**: `https://[random].ngrok-free.app`
- **Admin Panel**: `https://[random].ngrok-free.app/admin/`
- **Local URL**: `http://localhost:8000`
- **Ngrok Inspector**: `http://localhost:4040`

## 🔧 Configuration

### Environment Variables
The production setup uses these settings:
- `USE_SQLITE=true` (uses local SQLite database)
- `DEBUG=false` (production mode)
- Static files served from `/workspace/staticfiles`

### Database
- Uses existing SQLite database: `db.sqlite3`
- Automatically runs migrations on startup
- Admin user should already exist: `admin` / `admin123`

## 🚀 Auto-Start on Server Boot

### Method 1: Add to User's Crontab
```bash
crontab -e
```
Add this line:
```
@reboot cd /workspace && ./start_production.sh
```

### Method 2: Add to System Startup Script
Add to `/etc/rc.local` (before `exit 0`):
```bash
su - ubuntu -c 'cd /workspace && ./start_production.sh'
```

### Method 3: Create a User Service (if systemd available)
```bash
# Copy the provided systemd files
sudo cp noctispro-production-current.service /etc/systemd/system/
sudo cp noctispro-ngrok-current.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable noctispro-production-current.service
sudo systemctl enable noctispro-ngrok-current.service
```

## 🛠 Troubleshooting

### Check Service Status
```bash
./status_production.sh
```

### View Live Logs
```bash
# Django logs
tail -f logs/gunicorn*.log

# Ngrok logs
tail -f logs/ngrok.log
```

### Common Issues

**Django not starting:**
```bash
# Check Django logs
cat logs/gunicorn-error.log

# Try manual start
source venv/bin/activate
export USE_SQLITE=true
python manage.py runserver 0.0.0.0:8000
```

**Ngrok not connecting:**
```bash
# Check ngrok logs
cat logs/ngrok.log

# Verify ngrok auth token
ngrok config check
```

**Port already in use:**
```bash
# Find what's using port 8000
sudo lsof -i :8000

# Stop conflicting processes
./stop_production.sh
```

### Reset Everything
```bash
./stop_production.sh
rm -f django.pid ngrok.pid
rm -rf logs/*
./start_production.sh
```

## 📈 Production Considerations

### Performance
- Gunicorn runs with 3 worker processes
- Redis handles caching and sessions
- Static files are collected and served efficiently

### Security
- DEBUG mode is disabled in production
- Static files are served from dedicated directory
- Database uses local SQLite (consider PostgreSQL for heavy use)

### Monitoring
- All services log to dedicated files
- Process IDs are tracked for easy management
- Health check available via status script

### Scaling
- To increase workers: edit `start_production.sh` and change `--workers 3`
- For database scaling: switch to PostgreSQL in production
- For high availability: consider multiple server instances

## 🔄 Updates and Maintenance

### Update Application Code
```bash
./stop_production.sh
git pull  # or however you update your code
./start_production.sh
```

### Database Maintenance
```bash
source venv/bin/activate
export USE_SQLITE=true
python manage.py migrate
python manage.py collectstatic --noinput
```

### Log Rotation
Consider setting up logrotate for the log files:
```bash
sudo nano /etc/logrotate.d/noctispro
```

## 💡 Tips

1. **Bookmark the ngrok URL** - it changes each time ngrok restarts
2. **Monitor logs regularly** - use `tail -f logs/*.log`
3. **Set up automated backups** of your SQLite database
4. **Test the startup scripts** after any server maintenance
5. **Keep your ngrok authtoken secure** - it's in your config

---

## 🎉 You're All Set!

Your NoctisPro application is now running in production mode with:
- ✅ Professional WSGI server (Gunicorn)
- ✅ External access via ngrok tunnel  
- ✅ Background process management
- ✅ Comprehensive logging
- ✅ Easy management scripts

Run `./get_ngrok_url.sh` anytime to get your current public URL!