# NoctisPro Automatic Startup System

This system ensures your NoctisPro application with ngrok tunnel starts automatically on boot, survives power outages, and recovers from failures.

## 🚀 Quick Setup

**One-command setup:**
```bash
sudo ./quick_autostart_setup.sh
```

This will:
1. Configure ngrok authentication (if needed)
2. Set up automatic startup service
3. Enable robust error recovery
4. Start monitoring systems

## 📋 Manual Setup Steps

If you prefer step-by-step setup:

### 1. Configure Ngrok Authentication
```bash
./configure_ngrok_auth.sh
```
- Get your auth token from: https://dashboard.ngrok.com/get-started/your-authtoken
- The script will guide you through the process

### 2. Set Up Complete Autostart
```bash
sudo ./setup_complete_autostart.sh
```
- Creates systemd service for auto-startup
- Sets up robust error handling and recovery
- Configures monitoring and logging

## 🔍 Check Status

**Quick status check:**
```bash
./check_autostart_status.sh
```

**Detailed service status:**
```bash
sudo systemctl status noctispro-complete
```

**View live logs:**
```bash
sudo journalctl -u noctispro-complete -f
```

## 🌐 Getting Your URLs

**Current ngrok URL:**
```bash
cat /workspace/current_ngrok_url.txt
```

**Local access:**
- http://localhost:80

## 🔧 Service Management

**Start the service:**
```bash
sudo systemctl start noctispro-complete
```

**Stop the service:**
```bash
sudo systemctl stop noctispro-complete
```

**Restart the service:**
```bash
sudo systemctl restart noctispro-complete
```

**Disable autostart (if needed):**
```bash
sudo systemctl disable noctispro-complete
```

**Re-enable autostart:**
```bash
sudo systemctl enable noctispro-complete
```

## 📊 Key Features

### ✅ Automatic Startup
- Starts on system boot
- Survives power outages and reboots
- No manual intervention required

### ✅ Robust Error Recovery
- Automatic restart on failures
- Retry logic for ngrok connections
- Service dependency management
- Network connectivity waiting

### ✅ Smart Ngrok Management
- Uses your configured static URL (if available)
- Falls back to dynamic URLs
- Automatic reconnection on failures
- URL tracking and logging

### ✅ Comprehensive Monitoring
- Service health checks
- Process monitoring
- Automatic restarts for failed components
- Detailed logging

### ✅ Production Ready
- Proper service isolation
- Security constraints
- Comprehensive error handling
- Performance optimized

## 📁 Important Files

| File | Purpose |
|------|---------|
| `quick_autostart_setup.sh` | One-command complete setup |
| `configure_ngrok_auth.sh` | Configure ngrok authentication |
| `setup_complete_autostart.sh` | Complete autostart installation |
| `check_autostart_status.sh` | Check system status |
| `start_robust_system.sh` | Robust startup script with recovery |
| `stop_robust_system.sh` | Clean shutdown script |
| `ngrok_watchdog.sh` | Ngrok monitoring and recovery |
| `current_ngrok_url.txt` | Current accessible URL |

## 📝 Log Files

| Log File | Content |
|----------|---------|
| `/workspace/noctispro_complete.log` | Main system logs |
| `/workspace/ngrok.log` | Ngrok tunnel logs |
| `/workspace/django.log` | Django application logs |
| `/workspace/ngrok_watchdog.log` | Ngrok monitoring logs |
| System logs: `journalctl -u noctispro-complete` | Service management logs |

## 🔧 Configuration

### Ngrok Settings
Edit `/workspace/.env.ngrok`:
```bash
# Use static URL (recommended for production)
NGROK_USE_STATIC=true
NGROK_STATIC_URL=your-static-url.ngrok-free.app

# Server settings
DJANGO_PORT=80
DJANGO_HOST=0.0.0.0
```

### Service Settings
The systemd service is configured in `/etc/systemd/system/noctispro-complete.service`

## 🆘 Troubleshooting

### Service Won't Start
1. Check service status: `sudo systemctl status noctispro-complete`
2. View logs: `sudo journalctl -u noctispro-complete -n 50`
3. Check dependencies: `./check_autostart_status.sh`

### Ngrok Issues
1. Verify auth token: `ngrok config check`
2. Check ngrok logs: `tail -f /workspace/ngrok.log`
3. Reconfigure if needed: `./configure_ngrok_auth.sh`

### Database Connection Issues
1. Check PostgreSQL: `sudo systemctl status postgresql`
2. Check Redis: `sudo systemctl status redis-server`
3. Restart dependencies: `sudo systemctl restart postgresql redis-server`

### Can't Access Application
1. Check if service is running: `sudo systemctl is-active noctispro-complete`
2. Get current URL: `cat /workspace/current_ngrok_url.txt`
3. Try local access: http://localhost:80

## 🔄 Manual Recovery

If something goes wrong, you can manually restart everything:

```bash
# Stop everything
sudo systemctl stop noctispro-complete
pkill -f "manage.py runserver"
pkill -f "ngrok"

# Start fresh
sudo systemctl start noctispro-complete

# Or start manually for debugging
cd /workspace
./start_robust_system.sh
```

## 🛡️ Security Notes

- Service runs as `ubuntu` user (not root)
- Temporary files are isolated
- No unnecessary privileges
- Comprehensive logging for audit

## 🎯 After Power Outage

The system will automatically:
1. Wait for network connectivity
2. Start required services (PostgreSQL, Redis)
3. Initialize the Django application
4. Establish ngrok tunnel
5. Begin monitoring and recovery

**No manual intervention required!**

## 📞 Support

If you encounter issues:
1. Run: `./check_autostart_status.sh`
2. Check logs: `sudo journalctl -u noctispro-complete -f`
3. Review configuration files
4. Restart the service: `sudo systemctl restart noctispro-complete`

Your NoctisPro system is now bulletproof and will start automatically every time! 🎉