# 🚀 NoctisPro Masterpiece Deployment Guide

## Quick Deployment (One Command)

```bash
# Deploy everything with auto-start
./masterpiece_deploy.sh
```

## Manual Deployment Steps

### 1. Configure Ngrok (First Time Only)
```bash
# Get your auth token from: https://dashboard.ngrok.com/get-started/your-authtoken
./ngrok config add-authtoken YOUR_TOKEN_HERE
```

### 2. Deploy the Service
```bash
# Full deployment with auto-start
./deploy_masterpiece_service.sh deploy
```

### 3. Manage the Service
```bash
# Check status
./deploy_masterpiece_service.sh status

# Start service
./deploy_masterpiece_service.sh start

# Stop service
./deploy_masterpiece_service.sh stop

# Restart service
./deploy_masterpiece_service.sh restart

# Setup auto-start only
./deploy_masterpiece_service.sh setup-autostart
```

## 🌐 Access Your Application

After deployment, your application will be available at:
- **Main App**: https://colt-charmed-lark.ngrok-free.app
- **Admin Panel**: https://colt-charmed-lark.ngrok-free.app/admin/
- **Default Login**: admin / admin123

## 🔧 Auto-Start Configuration

The deployment script automatically configures auto-start for different system types:

### Modern Systems (systemd)
- Creates systemd service: `/etc/systemd/system/noctispro-masterpiece.service`
- Enables auto-start on boot
- Managed with: `systemctl start/stop/status noctispro-masterpiece`

### Older Systems (init.d)
- Creates init.d script: `/etc/init.d/noctispro-masterpiece`
- Configures runlevel auto-start
- Managed with: `service noctispro-masterpiece start/stop/status`

### Legacy/Container Systems
- Cron job: Starts service on system boot
- Profile scripts: Auto-start on login
- Tmux sessions: Persistent service management

## 🔍 Troubleshooting

### Service Not Starting
```bash
# Check logs
tail -f /workspace/noctispro-masterpiece.log
tail -f /workspace/ngrok_noctispro-masterpiece.log

# Check system status
./deploy_masterpiece_service.sh status

# Manual restart
./deploy_masterpiece_service.sh restart
```

### Ngrok Issues
```bash
# Check ngrok configuration
./ngrok config check

# View ngrok logs
tail -f /workspace/ngrok_noctispro-masterpiece.log

# Test ngrok manually
./ngrok http 8000 --hostname=colt-charmed-lark.ngrok-free.app
```

### Port Conflicts
```bash
# Check what's using port 8000
lsof -i :8000

# Kill conflicting processes
pkill -f "manage.py runserver"
pkill -f "ngrok.*http"
```

## 📊 Service Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Auto-Start    │    │  Tmux Session   │    │  Ngrok Tunnel   │
│   (Boot Time)   │───▶│  (Persistent)   │───▶│ (Static URL)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         └─────────────▶│ Django Server   │◀─────────────┘
                        │  (Port 8000)    │
                        └─────────────────┘
```

## 🛡️ Security Features

- CSRF protection enabled
- Secure admin authentication
- Static URL with ngrok authentication
- Process isolation with tmux
- Automatic service recovery

## 📁 File Structure

```
/workspace/
├── deploy_masterpiece_service.sh     # Main service manager
├── masterpiece_deploy.sh             # Quick deployment wrapper
├── noctis_pro_deployment/             # Refined system directory
├── noctispro-masterpiece.pid          # Service PID file
├── noctispro-masterpiece.log          # Service logs
├── ngrok_noctispro-masterpiece.log    # Ngrok logs
└── autostart_masterpiece.sh           # Auto-start script
```

## 🔄 System Compatibility

### ✅ Supported Systems
- **Ubuntu 18.04+** (systemd)
- **CentOS 7+** (systemd)
- **Debian 9+** (systemd)
- **RHEL 7+** (systemd/init.d)
- **Legacy Linux** (init.d)
- **Docker Containers** (profile-based)

### 📋 Requirements
- Python 3.6+
- tmux (for session management)
- curl (for health checks)
- Internet connection (for ngrok)
- Ngrok auth token

## 🚀 Performance Optimizations

- Virtual environment isolation
- Static file serving optimization
- Database migration automation
- Graceful service restarts
- Resource monitoring

## 📞 Support

If you encounter issues:
1. Check the service status: `./deploy_masterpiece_service.sh status`
2. Review logs in `/workspace/*.log`
3. Verify ngrok configuration: `./ngrok config check`
4. Test manual deployment steps

---

**🎉 Your NoctisPro Masterpiece is now ready for production deployment!**