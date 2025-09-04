# 🛡️ SERVICE DEPLOYMENT INSTRUCTIONS

## ✅ Answer to Your Questions:

**"WHEN I RUN THIS ACT CD WORKSPACE WILL IT WORK?"**  
❌ No, `sudo /usr/local/bin/start-noctispro` will NOT work immediately after git clone.

**"HOW DO I MAKE IT WORK AFTER GIT CLONE IS DONE AND CD WORKSPACE?"**  
✅ Follow the BULLETPROOF service deployment process below!

## 🚀 BULLETPROOF SERVICE DEPLOYMENT

You were following the README instructions for bulletproof autostart. Here's the complete process:

### Step 1: Setup Virtual Environment (if not done)
```bash
cd /workspace
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install django pillow python-dotenv daphne djangorestframework channels django-cors-headers django-widget-tweaks pydicom requests numpy
```

### Step 2: Run BULLETPROOF_AUTOSTART.sh
```bash
./BULLETPROOF_AUTOSTART.sh
```

This script will:
- ✅ Test Django functionality
- ✅ Create `/usr/local/bin/start-noctispro` script
- ✅ Set up auto-start on boot (crontab + rc.local)
- ✅ Start the service immediately
- ✅ Configure ngrok tunnel
- ✅ Test everything works

### Step 3: Configure Ngrok (Optional for Public Access)
```bash
# Get your token from: https://dashboard.ngrok.com/get-started/your-authtoken
ngrok config add-authtoken YOUR_TOKEN_HERE

# Restart to enable public tunnel
sudo /usr/local/bin/start-noctispro
```

## 🔧 Service Management Commands

After running BULLETPROOF_AUTOSTART.sh, you can use:

### Start/Stop/Restart
```bash
# Start NoctisPro
sudo /usr/local/bin/start-noctispro

# Stop NoctisPro
sudo pkill -f "manage.py runserver"
sudo pkill -f "ngrok"

# Check if running
curl http://localhost:8000/health/
```

### Check Status
```bash
# Check Django process
ps aux | grep "manage.py runserver"

# Check ngrok process
ps aux | grep "ngrok"

# Check logs
tail -f /tmp/noctispro.log
tail -f /tmp/ngrok.log
```

## 🌐 Access URLs

After setup:
- **Local**: http://localhost:8000
- **Admin**: http://localhost:8000/admin/
- **Health**: http://localhost:8000/health/
- **Public**: https://mallard-shining-curiously.ngrok-free.app (after ngrok auth)

### Default Login
- **Username**: admin
- **Password**: admin123

## 🔄 Auto-Start Features

The BULLETPROOF setup provides:
- ✅ **Crontab entry**: `@reboot /usr/local/bin/start-noctispro`
- ✅ **rc.local backup**: Starts on system boot
- ✅ **Ngrok integration**: Automatic public access
- ✅ **Health checking**: Tests if everything works

## 📊 Alternative: Systemd Service

If you prefer systemd service (more professional):

### Install the Service
```bash
# Copy service file
sudo cp noctispro-production-current.service /etc/systemd/system/

# Reload systemd (if available)
sudo systemctl daemon-reload

# Enable auto-start
sudo systemctl enable noctispro-production-current.service

# Start service
sudo systemctl start noctispro-production-current.service

# Check status
sudo systemctl status noctispro-production-current.service
```

### Service Management
```bash
# Start
sudo systemctl start noctispro-production-current.service

# Stop
sudo systemctl stop noctispro-production-current.service

# Restart
sudo systemctl restart noctispro-production-current.service

# Check logs
sudo journalctl -u noctispro-production-current.service -f
```

## 🆘 Troubleshooting

### If start-noctispro doesn't exist
```bash
# Run the bulletproof setup
./BULLETPROOF_AUTOSTART.sh
```

### If Django won't start
```bash
# Check virtual environment
source venv/bin/activate
python manage.py check

# Check dependencies
pip install django pillow python-dotenv
```

### If ngrok fails
```bash
# Check if ngrok is installed
which ngrok

# Install ngrok if missing
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install ngrok

# Configure auth token
ngrok config add-authtoken YOUR_TOKEN
```

## 🎯 Summary

The README bulletproof deployment you were following:

1. **Creates**: `/usr/local/bin/start-noctispro` script
2. **Sets up**: Auto-start on boot (crontab + rc.local)
3. **Configures**: Ngrok tunnel for public access
4. **Tests**: Everything works immediately
5. **Provides**: Professional service management

**To use it**: Run `./BULLETPROOF_AUTOSTART.sh` and you're done! 🚀