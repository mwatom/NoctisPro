#!/bin/bash

# FINAL NOCTISPRO AUTOSTART DEPLOYMENT
# Run this ONCE and it's done - auto-starts on boot forever

set -e

echo "🚀 FINAL NOCTISPRO AUTOSTART DEPLOYMENT"
echo "======================================"
echo ""

# Kill everything first
sudo pkill -f "manage.py" || true
sudo pkill -f "ngrok" || true
sudo pkill -f "noctis" || true

cd /workspace

# Create the ONE script that runs everything
cat > /usr/local/bin/noctispro-autostart << 'EOF'
#!/bin/bash

# THE ONLY SCRIPT THAT MATTERS
cd /workspace
source venv/bin/activate
export DJANGO_SETTINGS_MODULE=noctis_pro.settings_development
export DJANGO_DEBUG=false
export ALLOWED_HOSTS="*,colt-charmed-lark.ngrok-free.app,localhost,127.0.0.1"

# Start Django
nohup python manage.py runserver 0.0.0.0:8000 > /var/log/noctispro.log 2>&1 &

# Start ngrok with static domain (if auth token exists)
if ngrok config check 2>/dev/null; then
    sleep 5
    nohup ngrok http --domain=colt-charmed-lark.ngrok-free.app 8000 > /var/log/ngrok.log 2>&1 &
fi

echo "$(date): NoctisPro started" >> /var/log/noctispro-autostart.log
EOF

sudo chmod +x /usr/local/bin/noctispro-autostart

# Add to rc.local for boot startup
sudo bash -c 'cat > /etc/rc.local << "EOF"
#!/bin/bash
# NoctisPro autostart
sleep 30
su - ubuntu -c "/usr/local/bin/noctispro-autostart" &
exit 0
EOF'

sudo chmod +x /etc/rc.local

# Create systemd service as backup
sudo bash -c 'cat > /etc/systemd/system/noctispro.service << "EOF"
[Unit]
Description=NoctisPro Auto Service
After=network.target

[Service]
Type=forking
User=ubuntu
ExecStart=/usr/local/bin/noctispro-autostart
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

# Enable systemd service
if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl daemon-reload
    sudo systemctl enable noctispro.service
fi

# Start it NOW
echo "🚀 STARTING NOCTISPRO NOW..."
sudo /usr/local/bin/noctispro-autostart

sleep 10

echo ""
echo "🎉 DONE! NOCTISPRO IS RUNNING AND WILL AUTO-START ON BOOT!"
echo "=========================================================="
echo ""
echo "✅ Local access: http://localhost:8000"
echo "✅ Static domain: https://colt-charmed-lark.ngrok-free.app"
echo "✅ Admin: http://localhost:8000/admin/ (admin/admin123)"
echo ""
echo "📋 To add ngrok auth token for public access:"
echo "   ngrok config add-authtoken YOUR_TOKEN"
echo "   sudo /usr/local/bin/noctispro-autostart"
echo ""
echo "✅ SYSTEM WILL AUTO-START ON BOOT - NO MORE MANUAL STARTING!"