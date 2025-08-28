# NoctisPro Autostart Setup Instructions

## 🎯 **Goal**: Make NoctisPro start automatically on boot/reboot

## 📍 **Current Status**
- ❌ Autostart is **NOT** configured (confirmed via `./check_autostart_status.sh`)
- ✅ System runs successfully with `./start_with_ngrok.sh`
- ✅ Ngrok configuration is present with static URL: `colt-charmed-lark.ngrok-free.app`

## 🚀 **Quick Setup (Recommended)**

From your NoctisPro directory (`/home/noctispro/NoctisPro/`), run:

```bash
sudo ./quick_autostart_setup.sh
```

This single command will:
1. ✅ Configure ngrok authentication (if needed)
2. ✅ Set up systemd service for automatic startup
3. ✅ Enable robust error recovery and monitoring
4. ✅ Configure automatic restart after failures
5. ✅ Set up comprehensive logging

## 📋 **Manual Setup (Alternative)**

If you prefer step-by-step setup:

### Step 1: Configure Ngrok (if not already done)
```bash
./configure_ngrok_auth.sh
```

### Step 2: Set Up Complete Autostart
```bash
sudo ./setup_complete_autostart.sh
```

## 🔍 **Verify Setup**

After running the setup, check the status:

```bash
# Quick status check
./check_autostart_status.sh

# Detailed service status
sudo systemctl status noctispro-complete

# View live logs
sudo journalctl -u noctispro-complete -f
```

## 🎉 **What This Gives You**

Once configured, your NoctisPro system will:
- ✅ **Start automatically on boot/reboot**
- ✅ **Survive power outages** 
- ✅ **Auto-recover from failures**
- ✅ **Maintain ngrok tunnel** with retry logic
- ✅ **Monitor and auto-restart** if issues occur
- ✅ **Provide comprehensive logging**

## 🌍 **Access After Autostart**

Your system will be available at:
- **External**: https://colt-charmed-lark.ngrok-free.app
- **Local**: http://localhost:8000

## 🛠️ **Management Commands**

After autostart is configured:

```bash
# Check service status
sudo systemctl status noctispro-complete

# Start service manually
sudo systemctl start noctispro-complete

# Stop service 
sudo systemctl stop noctispro-complete

# Restart service
sudo systemctl restart noctispro-complete

# View logs
sudo journalctl -u noctispro-complete -f

# Get current ngrok URL
cat /workspace/current_ngrok_url.txt
```

## 🔧 **Troubleshooting**

If autostart doesn't work:

1. **Check service status**: `sudo systemctl status noctispro-complete`
2. **View error logs**: `sudo journalctl -u noctispro-complete -n 50`
3. **Test manual start**: `./start_with_ngrok.sh`
4. **Re-run setup**: `sudo ./quick_autostart_setup.sh`

## 📞 **Need Help?**

Run `./check_autostart_status.sh` to see current configuration and get specific recommendations.