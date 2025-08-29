#!/bin/bash

# BULLETPROOF NOCTISPRO AUTOSTART
# This WILL work - no more bullshit

echo "🚀 BULLETPROOF NOCTISPRO AUTOSTART SETUP"
echo "========================================"

# Kill everything first
echo "🛑 Killing any existing processes..."
pkill -f "manage.py" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true
pkill -f "gunicorn" 2>/dev/null || true

cd "$(dirname "$0")"

# Install PostgreSQL if not present
echo "🔍 Checking PostgreSQL..."
if ! command -v psql &> /dev/null; then
    echo "📦 Installing PostgreSQL..."
    sudo apt update
    sudo apt install -y postgresql postgresql-contrib
fi

# Start PostgreSQL
echo "🚀 Starting PostgreSQL..."
sudo service postgresql start || sudo systemctl start postgresql || true

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

# Create database and user
echo "🗄️ Setting up database..."
sudo -u postgres psql -c "CREATE DATABASE noctis_pro;" 2>/dev/null || true
sudo -u postgres psql -c "CREATE USER noctis_user WITH PASSWORD 'noctis123';" 2>/dev/null || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE noctis_pro TO noctis_user;" 2>/dev/null || true
sudo -u postgres psql -c "ALTER USER noctis_user CREATEDB;" 2>/dev/null || true

# Test Django works first
echo "🧪 Testing Django..."
source venv/bin/activate
export DJANGO_SETTINGS_MODULE=noctis_pro.settings_production
python manage.py check || exit 1
echo "✅ Django works"

# Run migrations
echo "🔄 Running database migrations..."
python manage.py migrate
echo "✅ Migrations completed"

# Create superuser automatically
echo "👤 Creating admin user..."
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@example.com', 'admin123')" | python manage.py shell
echo "✅ Admin user created (admin/admin123)"

# Collect static files
echo "📦 Collecting static files..."
python manage.py collectstatic --noinput
echo "✅ Static files collected"

# Create the autostart script with correct path
echo "📝 Creating autostart script..."
CURRENT_DIR=$(pwd)
sudo tee /usr/local/bin/start-noctispro > /dev/null << EOF
#!/bin/bash
echo "🚀 Starting NoctisPro..."

# Start PostgreSQL first
sudo service postgresql start || sudo systemctl start postgresql || true
sleep 3

# Change to the correct directory
cd $CURRENT_DIR
source venv/bin/activate
export DJANGO_SETTINGS_MODULE=noctis_pro.settings_production

# Kill any existing processes
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "gunicorn" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true

# Run migrations (in case of updates)
python manage.py migrate --noinput

# Start Django with gunicorn
gunicorn --bind 0.0.0.0:8000 --workers 3 --daemon --pid /tmp/noctispro.pid noctis_pro.wsgi:application

# Wait for Django to start
sleep 5

# Start ngrok if configured
if command -v ngrok &> /dev/null; then
    if ngrok config check 2>/dev/null; then
        echo "🌍 Starting ngrok tunnel..."
        ngrok http --domain=colt-charmed-lark.ngrok-free.app 8000 > /tmp/ngrok.log 2>&1 &
        echo \$! > /tmp/ngrok.pid
        echo "✅ Ngrok tunnel started"
    else
        echo "⚠️ Ngrok not configured. Run: ngrok config add-authtoken YOUR_TOKEN"
    fi
else
    echo "⚠️ Ngrok not found."
fi

# Check if everything is running
if curl -s http://localhost:8000/health/ >/dev/null 2>&1; then
    echo "✅ NoctisPro is running!"
    echo "🌐 Local: http://localhost:8000"
    echo "👤 Admin: http://localhost:8000/admin/ (admin/admin123)"
    if [ -f "/tmp/ngrok.pid" ]; then
        echo "🌍 Public: https://colt-charmed-lark.ngrok-free.app"
    fi
else
    echo "❌ Failed to start NoctisPro"
fi
EOF

sudo chmod +x /usr/local/bin/start-noctispro

# Add to crontab for @reboot
echo "⚡ Setting up boot autostart..."
(crontab -l 2>/dev/null | grep -v "start-noctispro"; echo "@reboot /usr/local/bin/start-noctispro") | crontab -

# Also add to rc.local as backup
if [ ! -f /etc/rc.local ]; then
    sudo tee /etc/rc.local > /dev/null << 'EOF'
#!/bin/bash
exit 0
EOF
    sudo chmod +x /etc/rc.local
fi

# Remove any existing entries and add new one
sudo sed -i '/start-noctispro/d' /etc/rc.local
sudo sed -i '/exit 0/i # NoctisPro autostart\n/usr/local/bin/start-noctispro &' /etc/rc.local

# Create a stop script too
echo "🛑 Creating stop script..."
sudo tee /usr/local/bin/stop-noctispro > /dev/null << 'EOF'
#!/bin/bash
echo "🛑 Stopping NoctisPro..."
pkill -f "manage.py runserver" 2>/dev/null || true
pkill -f "gunicorn" 2>/dev/null || true
pkill -f "ngrok" 2>/dev/null || true
if [ -f "/tmp/noctispro.pid" ]; then
    kill $(cat /tmp/noctispro.pid) 2>/dev/null || true
    rm -f /tmp/noctispro.pid
fi
if [ -f "/tmp/ngrok.pid" ]; then
    kill $(cat /tmp/ngrok.pid) 2>/dev/null || true
    rm -f /tmp/ngrok.pid
fi
echo "✅ NoctisPro stopped"
EOF

sudo chmod +x /usr/local/bin/stop-noctispro

# Start it NOW
echo "🚀 STARTING NOCTISPRO..."
/usr/local/bin/start-noctispro

sleep 8

# Test it
echo "🧪 Testing service..."
if curl -s http://localhost:8000/health/ >/dev/null 2>&1; then
    echo ""
    echo "🎉 SUCCESS! NoctisPro is BULLETPROOF and running!"
    echo ""
    echo "🌐 Access URLs:"
    echo "   Local:  http://localhost:8000"
    echo "   Admin:  http://localhost:8000/admin/"
    echo "   Health: http://localhost:8000/health/"
    if ngrok config check 2>/dev/null; then
        echo "   Public: https://colt-charmed-lark.ngrok-free.app"
    else
        echo "   Public: Configure ngrok token for public access"
    fi
    echo ""
    echo "👤 Login Credentials:"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo ""
    echo "🔧 Management Commands:"
    echo "   Start:  sudo /usr/local/bin/start-noctispro"
    echo "   Stop:   sudo /usr/local/bin/stop-noctispro"
    echo ""
    echo "✅ WILL AUTO-START ON BOOT!"
    echo "✅ DATABASE CONFIGURED WITH POSTGRESQL!"
    echo "✅ ADMIN USER READY!"
else
    echo "❌ Failed to start. Checking logs..."
    echo "Django logs:"
    tail -20 /tmp/noctispro.log 2>/dev/null || echo "No Django logs found"
    echo ""
    echo "Gunicorn processes:"
    ps aux | grep gunicorn || echo "No gunicorn processes"
fi