#!/bin/bash

# BULLETPROOF NOCTISPRO AUTOSTART
# This WILL work - no more bullshit

echo "🚀 BULLETPROOF NOCTISPRO AUTOSTART SETUP"
echo "========================================"

# Kill everything
pkill -f "manage.py" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true

cd /workspace

# Test Django works first
echo "🧪 Testing Django..."
source venv/bin/activate
export DJANGO_SETTINGS_MODULE=noctis_pro.settings_development
python manage.py check || exit 1
echo "✅ Django works"

# Create the autostart script
echo "📝 Creating autostart script..."
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

sudo chmod +x /usr/local/bin/start-noctispro

# Add to crontab for @reboot
echo "⚡ Setting up boot autostart..."
(crontab -l 2>/dev/null; echo "@reboot /usr/local/bin/start-noctispro") | crontab -

# Also add to rc.local as backup
sudo tee -a /etc/rc.local > /dev/null << 'EOF'
# NoctisPro autostart
/usr/local/bin/start-noctispro &
EOF

sudo chmod +x /etc/rc.local

# Start it NOW
echo "🚀 STARTING NOCTISPRO..."
/usr/local/bin/start-noctispro

sleep 5

# Test it
echo "🧪 Testing service..."
if curl -s http://localhost:8000/health/ >/dev/null 2>&1; then
    echo "✅ SUCCESS! NoctisPro is running!"
    echo ""
    echo "🌐 Local: http://localhost:8000"
    echo "🌐 Public: https://colt-charmed-lark.ngrok-free.app"
    echo "👤 Admin: http://localhost:8000/admin/ (admin/admin123)"
    echo ""
    echo "✅ WILL AUTO-START ON BOOT!"
else
    echo "❌ Failed to start. Checking logs..."
    cat /tmp/noctispro.log 2>/dev/null || echo "No logs found"
fi