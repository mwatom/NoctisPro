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

# Skip PostgreSQL - using SQLite for bulletproof reliability
echo "🔍 Using SQLite database for bulletproof reliability..."

# Install Python dependencies
echo "🐍 Installing Python environment tools..."
sudo apt install -y python3-full python3-venv python3-pip

echo "✅ SQLite database selected - no authentication issues!"

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "🐍 Creating Python virtual environment..."
    python3 -m venv venv
    if [ ! -f "venv/bin/activate" ]; then
        echo "❌ Failed to create virtual environment"
        exit 1
    fi
fi

# Install dependencies
echo "📦 Installing Python dependencies..."
source venv/bin/activate
pip install --upgrade pip

# Install core dependencies if requirements.txt doesn't exist
if [ ! -f "requirements.txt" ]; then
    echo "📋 Installing core dependencies..."
    pip install django psycopg2-binary redis channels djangorestframework django-cors-headers daphne channels-redis pillow django-redis pydicom requests numpy matplotlib plotly celery gunicorn
else
    pip install -r requirements.txt
    # Ensure critical dependencies are installed
    pip install psycopg2-binary django gunicorn pydicom pillow
fi

echo "✅ Python dependencies installed"

# Test Django works first
echo "🧪 Testing Django..."

# Generate a secure SECRET_KEY if not set
if [ -z "$SECRET_KEY" ]; then
    echo "🔑 Generating SECRET_KEY..."
    export SECRET_KEY=$(python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")
fi

# Use SQLite database for bulletproof reliability
export USE_SQLITE=true
export DATABASE_PATH="$(pwd)/db.sqlite3"

# Disable Redis for simpler setup (will use dummy cache and db sessions)
export DISABLE_REDIS=true
export USE_DUMMY_CACHE=true

# Use the main settings file instead of production settings
export DJANGO_SETTINGS_MODULE=noctis_pro.settings
python manage.py check || exit 1
echo "✅ Django works"

# Run migrations
echo "🔄 Running database migrations..."
python manage.py migrate
echo "✅ Migrations completed"

# Create superuser automatically  
echo "👤 Creating admin user..."
echo "
from django.contrib.auth import get_user_model
User = get_user_model()
admin, created = User.objects.get_or_create(username='admin')
admin.set_password('admin123')
admin.is_staff = True
admin.is_superuser = True
admin.email = 'admin@example.com'
admin.save()
print('✅ Admin user ready: admin/admin123')
" | python manage.py shell
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

# Using SQLite - no database service needed!
echo "✅ Using SQLite database - bulletproof and reliable!"

# Change to the correct directory
cd $CURRENT_DIR

# Ensure virtual environment exists
if [ ! -d "venv" ]; then
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    # Install core dependencies
    pip install django psycopg2-binary redis channels djangorestframework django-cors-headers daphne channels-redis pillow django-redis pydicom requests numpy matplotlib plotly celery gunicorn
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    fi
else
    source venv/bin/activate
    # Ensure critical dependencies are available
    pip install --upgrade psycopg2-binary django gunicorn pydicom pillow
fi

# Generate a secure SECRET_KEY if not set
if [ -z "\$SECRET_KEY" ]; then
    export SECRET_KEY=\$(python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")
fi

# Use SQLite database for bulletproof reliability
export USE_SQLITE=true
export DATABASE_PATH="$(pwd)/db.sqlite3"

# Disable Redis for simpler setup (will use dummy cache and db sessions)
export DISABLE_REDIS=true
export USE_DUMMY_CACHE=true

# Use the main settings file instead of production settings
export DJANGO_SETTINGS_MODULE=noctis_pro.settings

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
    echo "✅ DATABASE CONFIGURED WITH SQLITE - BULLETPROOF!"
    echo "✅ ADMIN USER READY!"
else
    echo "❌ Failed to start. Checking logs..."
    echo "Django logs:"
    tail -20 /tmp/noctispro.log 2>/dev/null || echo "No Django logs found"
    echo ""
    echo "Gunicorn processes:"
    ps aux | grep gunicorn || echo "No gunicorn processes"
fi