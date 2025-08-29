# 🚀 COMPLETE SETUP INSTRUCTIONS AFTER GIT CLONE

## Step 1: Initial Setup (Run these commands in order)

```bash
# 1. Navigate to workspace (you've already done this)
cd /workspace

# 2. Install system dependencies
sudo apt-get update -qq
sudo apt-get install -y python3 python3-pip python3-venv jq curl

# 3. Create Python virtual environment
python3 -m venv venv

# 4. Activate virtual environment
source venv/bin/activate

# 5. Upgrade pip
pip install --upgrade pip

# 6. Install Python dependencies (this may take a few minutes)
pip install -r requirements.txt
```

## Step 2: Create the start-noctispro Script

```bash
# Run the bulletproof autostart script that creates everything
./BULLETPROOF_AUTOSTART.sh
```

**OR** if you want to do it manually:

```bash
# Create the autostart script manually
sudo tee /usr/local/bin/start-noctispro > /dev/null << 'EOF'
#!/bin/bash
cd /workspace
source venv/bin/activate
export DJANGO_SETTINGS_MODULE=noctis_pro.settings_development
python manage.py runserver 0.0.0.0:8000 > /tmp/noctispro.log 2>&1 &
echo $! > /tmp/noctispro.pid
sleep 5
if ngrok config check 2>/dev/null; then
    ngrok http --domain=colt-charmed-lark.ngrok-free.app 8000 > /tmp/ngrok.log 2>&1 &
    echo $! > /tmp/ngrok.pid
fi
EOF

# Make it executable
sudo chmod +x /usr/local/bin/start-noctispro
```

## Step 3: Test the Setup

```bash
# Test Django works
source venv/bin/activate
export DJANGO_SETTINGS_MODULE=noctis_pro.settings_development
python manage.py check

# Now you can run the start script
sudo /usr/local/bin/start-noctispro

# Test if it's working
sleep 5
curl http://localhost:8000/health/
```

## Step 4: (Optional) Set Up Public Access

If you want public internet access:

```bash
# 1. Install ngrok
curl -fsSL https://raw.githubusercontent.com/ngrok/install/main/install.sh | sudo bash

# 2. Get your ngrok auth token from: https://dashboard.ngrok.com/get-started/your-authtoken
# 3. Configure ngrok (replace YOUR_TOKEN with actual token)
ngrok config add-authtoken YOUR_TOKEN_HERE

# 4. Restart the service
sudo /usr/local/bin/start-noctispro
```

## What Each Command Does:

1. **System dependencies**: Installs Python, pip, venv, and utilities
2. **Virtual environment**: Creates isolated Python environment
3. **Dependencies**: Installs all required Python packages
4. **Start script**: Creates the script that starts Django and ngrok
5. **Testing**: Verifies everything works

## After Setup is Complete:

- ✅ Local access: http://localhost:8000
- ✅ Admin panel: http://localhost:8000/admin/ (admin/admin123)
- ✅ Can run: `sudo /usr/local/bin/start-noctispro`
- ✅ Auto-starts on boot (if you ran BULLETPROOF_AUTOSTART.sh)

## Quick One-Liner Setup:

If you want to do everything at once:

```bash
cd /workspace && sudo apt-get update -qq && sudo apt-get install -y python3 python3-pip python3-venv jq curl && python3 -m venv venv && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt && ./BULLETPROOF_AUTOSTART.sh
```