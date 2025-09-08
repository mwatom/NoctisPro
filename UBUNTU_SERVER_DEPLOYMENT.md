# 🚀 NoctisPro PACS - Ubuntu 22.04 Server Deployment Guide

## Prerequisites

### Server Requirements
- **OS**: Ubuntu 22.04 LTS (Fresh installation recommended)
- **RAM**: 4GB minimum, 8GB+ recommended
- **Storage**: 50GB+ free space (more for DICOM storage)
- **Network**: Internet connection for downloads
- **Access**: SSH access with sudo privileges

### Before You Start
1. **Update your server**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Install git** (if not already installed):
   ```bash
   sudo apt install -y git curl wget
   ```

## 🔄 Method 1: One-Command Deployment (Recommended)

### Step 1: Clone the Repository
```bash
# Clone to your home directory
cd ~
git clone <YOUR_REPOSITORY_URL> noctis-pro
cd noctis-pro

# Or if you're copying files manually:
# scp -r /path/to/noctis-pro user@server-ip:~/noctis-pro
```

### Step 2: Run the Deployment Script
```bash
cd ~/noctis-pro
sudo ./deploy-ubuntu-server.sh
```

That's it! The script will handle everything automatically.

## 🛠 Method 2: Manual Step-by-Step Deployment

### Step 1: System Dependencies
```bash
sudo apt update
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    pkg-config \
    libpq-dev \
    libjpeg-dev \
    zlib1g-dev \
    libopenjp2-7 \
    libssl-dev \
    libffi-dev \
    libxml2-dev \
    libxslt1-dev \
    libcups2-dev \
    cups-common \
    postgresql \
    postgresql-contrib \
    redis-server \
    nginx \
    curl \
    wget \
    git \
    htop \
    ufw
```

### Step 2: Clone the Project
```bash
cd /opt
sudo git clone <YOUR_REPOSITORY_URL> noctis-pro
sudo chown -R $USER:$USER /opt/noctis-pro
cd /opt/noctis-pro
```

### Step 3: Database Setup
```bash
# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS noctis_pro;
DROP USER IF EXISTS noctis_user;
CREATE DATABASE noctis_pro;
CREATE USER noctis_user WITH PASSWORD 'noctis_secure_password_2024';
GRANT ALL PRIVILEGES ON DATABASE noctis_pro TO noctis_user;
ALTER DATABASE noctis_pro OWNER TO noctis_user;
\q
EOF

# Grant schema permissions
sudo -u postgres psql -d noctis_pro -c "GRANT ALL ON SCHEMA public TO noctis_user;"
```

### Step 4: Redis Setup
```bash
# Start Redis
sudo systemctl start redis-server
sudo systemctl enable redis-server

# Test Redis
redis-cli ping
```

### Step 5: Python Environment
```bash
cd /opt/noctis-pro

# Create virtual environment
python3 -m venv venv_production
source venv_production/bin/activate

# Upgrade pip and install core dependencies
pip install --upgrade pip wheel setuptools

# Install Django and core packages first
pip install Django==5.2.6 Pillow psycopg2-binary redis celery gunicorn
pip install djangorestframework django-cors-headers channels daphne
pip install pydicom pynetdicom

# Install remaining dependencies (some may fail, that's OK)
pip install -r requirements.txt || echo "Some optional packages failed, continuing..."
```

### Step 6: Django Configuration
```bash
cd /opt/noctis-pro
source venv_production/bin/activate

# Set environment variables
export DEBUG=False
export SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
export DB_ENGINE=django.db.backends.postgresql
export DB_NAME=noctis_pro
export DB_USER=noctis_user
export DB_PASSWORD=noctis_secure_password_2024
export DB_HOST=localhost
export DB_PORT=5432
export REDIS_URL=redis://localhost:6379/0
export CELERY_BROKER_URL=redis://localhost:6379/0
export CELERY_RESULT_BACKEND=redis://localhost:6379/0
export ALLOWED_HOSTS="*"

# Run migrations
python manage.py migrate --noinput

# Collect static files
python manage.py collectstatic --noinput

# Create admin user
python -c "
import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()
from django.contrib.auth import get_user_model
User = get_user_model()
User.objects.filter(username='admin').delete()
User.objects.create_superuser('admin', 'admin@noctispro.com', 'NoctisAdmin2024!')
print('✅ Admin user created: admin / NoctisAdmin2024!')
"
```

### Step 7: System Services
```bash
# Create Gunicorn service
sudo tee /etc/systemd/system/noctis-web.service > /dev/null << EOF
[Unit]
Description=NoctisPro PACS Web Application
After=network.target postgresql.service redis.service

[Service]
Type=notify
User=root
Group=root
WorkingDirectory=/opt/noctis-pro
Environment=DEBUG=False
Environment=SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
Environment=DB_ENGINE=django.db.backends.postgresql
Environment=DB_NAME=noctis_pro
Environment=DB_USER=noctis_user
Environment=DB_PASSWORD=noctis_secure_password_2024
Environment=DB_HOST=localhost
Environment=DB_PORT=5432
Environment=REDIS_URL=redis://localhost:6379/0
Environment=ALLOWED_HOSTS=*
ExecStart=/opt/noctis-pro/venv_production/bin/gunicorn --bind 0.0.0.0:8000 --workers 4 --timeout 120 noctis_pro.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create Celery service
sudo tee /etc/systemd/system/noctis-celery.service > /dev/null << EOF
[Unit]
Description=NoctisPro PACS Celery Worker
After=network.target postgresql.service redis.service

[Service]
Type=forking
User=root
Group=root
WorkingDirectory=/opt/noctis-pro
Environment=DEBUG=False
Environment=SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
Environment=DB_ENGINE=django.db.backends.postgresql
Environment=DB_NAME=noctis_pro
Environment=DB_USER=noctis_user
Environment=DB_PASSWORD=noctis_secure_password_2024
Environment=DB_HOST=localhost
Environment=DB_PORT=5432
Environment=REDIS_URL=redis://localhost:6379/0
Environment=CELERY_BROKER_URL=redis://localhost:6379/0
Environment=CELERY_RESULT_BACKEND=redis://localhost:6379/0
ExecStart=/opt/noctis-pro/venv_production/bin/celery -A noctis_pro worker --loglevel=info --detach
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create DICOM service
sudo tee /etc/systemd/system/noctis-dicom.service > /dev/null << EOF
[Unit]
Description=NoctisPro PACS DICOM Receiver
After=network.target postgresql.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/noctis-pro
Environment=DEBUG=False
Environment=SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
Environment=DB_ENGINE=django.db.backends.postgresql
Environment=DB_NAME=noctis_pro
Environment=DB_USER=noctis_user
Environment=DB_PASSWORD=noctis_secure_password_2024
Environment=DB_HOST=localhost
Environment=DB_PORT=5432
Environment=REDIS_URL=redis://localhost:6379/0
ExecStart=/opt/noctis-pro/venv_production/bin/python dicom_receiver.py --port 11112 --aet NOCTIS_SCP --bind 0.0.0.0
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable services
sudo systemctl daemon-reload
sudo systemctl enable noctis-web noctis-celery noctis-dicom
```

### Step 8: Nginx Configuration
```bash
# Create Nginx configuration
sudo tee /etc/nginx/sites-available/noctis > /dev/null << EOF
server {
    listen 80;
    server_name _;
    
    client_max_body_size 100M;
    client_body_timeout 120s;
    client_header_timeout 120s;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    location /static/ {
        alias /opt/noctis-pro/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location /media/ {
        alias /opt/noctis-pro/media/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/noctis /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and start Nginx
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx
```

### Step 9: Firewall Configuration
```bash
# Configure UFW firewall
sudo ufw --force enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 11112/tcp
sudo ufw reload
```

### Step 10: Start Services
```bash
# Start all services
sudo systemctl start noctis-web noctis-celery noctis-dicom

# Check service status
sudo systemctl status noctis-web noctis-celery noctis-dicom
```

## 🌐 Public Access Setup (Optional)

### Option 1: Cloudflare Tunnels (Free)
```bash
# Install cloudflared
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
rm cloudflared.deb

# Start tunnels
nohup cloudflared tunnel --url http://localhost:80 > tunnel_web.log 2>&1 &
nohup cloudflared tunnel --url http://localhost:11112 > tunnel_dicom.log 2>&1 &

# Get public URLs (wait 30 seconds)
sleep 30
echo "Web URL: $(grep -o 'https://[^[:space:]]*' tunnel_web.log | head -1)"
echo "DICOM URL: $(grep -o 'https://[^[:space:]]*' tunnel_dicom.log | head -1)"
```

### Option 2: Domain + SSL (Recommended for Production)
```bash
# Install certbot
sudo apt install -y certbot python3-certbot-nginx

# Get SSL certificate (replace your-domain.com)
sudo certbot --nginx -d your-domain.com

# Auto-renewal
sudo systemctl enable certbot.timer
```

## ✅ Verification & Testing

### Health Checks
```bash
# Test web application
curl -f http://localhost/health/

# Test database connection
sudo -u postgres psql -d noctis_pro -c "SELECT 1;"

# Test Redis
redis-cli ping

# Test DICOM port
telnet localhost 11112
```

### Service Status
```bash
# Check all services
sudo systemctl status noctis-web noctis-celery noctis-dicom postgresql redis-server nginx

# View logs
sudo journalctl -u noctis-web -f
sudo journalctl -u noctis-celery -f
sudo journalctl -u noctis-dicom -f
```

## 🎉 Access Your System

### Local Access
- **Web Application**: `http://your-server-ip/`
- **Admin Panel**: `http://your-server-ip/admin/`
- **Health Check**: `http://your-server-ip/health/`

### Default Credentials
- **Username**: `admin`
- **Password**: `NoctisAdmin2024!`

### DICOM Configuration
- **Port**: `11112`
- **AET**: `NOCTIS_SCP`
- **IP**: Your server IP

## 🔧 Post-Deployment Tasks

### 1. Change Default Password
```bash
cd /opt/noctis-pro
source venv_production/bin/activate
python manage.py changepassword admin
```

### 2. Configure DICOM Nodes
Access admin panel and add your DICOM devices under "DICOM Nodes"

### 3. Set Up Backups
```bash
# Create backup script
sudo tee /etc/cron.daily/noctis-backup << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/noctis/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"
sudo -u postgres pg_dump noctis_pro > "$BACKUP_DIR/database.sql"
tar -czf "$BACKUP_DIR/media.tar.gz" -C /opt/noctis-pro media/
find /backup/noctis/ -type d -mtime +7 -exec rm -rf {} + 2>/dev/null
EOF
sudo chmod +x /etc/cron.daily/noctis-backup
```

### 4. Monitor Resources
```bash
# Install monitoring tools
sudo apt install -y htop iotop nethogs

# Check disk usage
df -h
du -sh /opt/noctis-pro/media/
```

## 🚨 Troubleshooting

### Services Won't Start
```bash
# Check logs
sudo journalctl -u noctis-web --no-pager -l
sudo journalctl -u postgresql --no-pager -l

# Check ports
sudo netstat -tlnp | grep :8000
sudo netstat -tlnp | grep :5432
```

### Database Issues
```bash
# Reset database
sudo systemctl stop noctis-web noctis-celery
sudo -u postgres dropdb noctis_pro
sudo -u postgres createdb noctis_pro
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE noctis_pro TO noctis_user;"
cd /opt/noctis-pro && source venv_production/bin/activate && python manage.py migrate
sudo systemctl start noctis-web noctis-celery
```

### Permission Issues
```bash
# Fix permissions
sudo chown -R root:root /opt/noctis-pro
sudo chmod +x /opt/noctis-pro/manage.py
sudo chmod +x /opt/noctis-pro/dicom_receiver.py
```

## 📞 Support

Your NoctisPro PACS system is now running on Ubuntu 22.04! 

**Key Files:**
- **Project**: `/opt/noctis-pro/`
- **Logs**: `sudo journalctl -u noctis-web -f`
- **Config**: `/etc/nginx/sites-available/noctis`
- **Services**: `/etc/systemd/system/noctis-*.service`

**Next Steps:**
1. Change default password
2. Configure your DICOM devices
3. Set up SSL certificate
4. Configure backups
5. Add monitoring

Your medical imaging system is ready for production use! 🏥✨