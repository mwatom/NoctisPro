#!/bin/bash
echo "🌐 VPS/CLOUD SERVER DEPLOYMENT"
echo "=============================="
echo ""
echo "📋 PREREQUISITES:"
echo "   • Ubuntu 20.04+ or CentOS 8+ server"
echo "   • Root or sudo access"
echo "   • Domain name (optional but recommended)"
echo "   • SSL certificate (Let's Encrypt recommended)"
echo ""
echo "🔧 STEP 1: Server Setup"
echo "----------------------"
echo "# Update system"
echo "sudo apt update && sudo apt upgrade -y"
echo ""
echo "# Install required packages"
echo "sudo apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib supervisor git"
echo ""
echo "# Install Docker (optional)"
echo "curl -fsSL https://get.docker.com -o get-docker.sh"
echo "sudo sh get-docker.sh"
echo ""
echo "🗄️ STEP 2: Database Setup (PostgreSQL)"
echo "-------------------------------------"
echo "sudo -u postgres createdb noctispro"
echo "sudo -u postgres createuser --interactive noctispro"
echo "sudo -u postgres psql -c \"ALTER USER noctispro PASSWORD 'your_secure_password';\""
echo ""
echo "📁 STEP 3: Deploy Application"
echo "----------------------------"
echo "# Clone or upload your application"
echo "cd /opt"
echo "sudo mkdir noctispro"
echo "sudo chown \$USER:www-data noctispro"
echo "# Copy your workspace files to /opt/noctispro/"
echo ""
echo "# Setup virtual environment"
echo "cd /opt/noctispro"
echo "python3 -m venv venv"
echo "source venv/bin/activate"
echo "pip install -r requirements.txt"
echo "pip install gunicorn psycopg2-binary"
echo ""
echo "# Configure environment"
echo "cp .env.production .env"
echo "# Edit .env with your database credentials and domain"
echo ""
echo "# Setup database"
echo "python manage.py migrate"
echo "python manage.py collectstatic --noinput"
echo "python manage.py createsuperuser"
echo ""
echo "🔧 STEP 4: Configure Gunicorn"
echo "----------------------------"

# Create gunicorn config
cat > gunicorn.conf.py << 'GUNICORN_EOF'
bind = "127.0.0.1:8000"
workers = 3
worker_class = "sync"
worker_connections = 1000
max_requests = 1000
max_requests_jitter = 100
timeout = 30
keepalive = 2
user = "www-data"
group = "www-data"
tmp_upload_dir = None
secure_scheme_headers = {
    'X-FORWARDED-PROTOCOL': 'ssl',
    'X-FORWARDED-PROTO': 'https',
    'X-FORWARDED-SSL': 'on'
}
GUNICORN_EOF

echo ""
echo "🔧 STEP 5: Configure Supervisor"
echo "------------------------------"

# Create supervisor config
cat > /etc/supervisor/conf.d/noctispro.conf << 'SUPERVISOR_EOF'
[program:noctispro]
command=/opt/noctispro/venv/bin/gunicorn noctis_pro.wsgi:application -c /opt/noctispro/gunicorn.conf.py
directory=/opt/noctispro
user=www-data
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/supervisor/noctispro.log
environment=DJANGO_SETTINGS_MODULE=noctis_pro.settings
SUPERVISOR_EOF

echo "sudo supervisorctl reread"
echo "sudo supervisorctl update"
echo "sudo supervisorctl start noctispro"
echo ""
echo "🌐 STEP 6: Configure Nginx"
echo "-------------------------"

# Create nginx config
cat > /etc/nginx/sites-available/noctispro << 'NGINX_EOF'
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com www.your-domain.com;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # File upload size for DICOM files
    client_max_body_size 500M;

    location = /favicon.ico { access_log off; log_not_found off; }
    
    location /static/ {
        root /opt/noctispro;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        root /opt/noctispro;
        expires 1y;
        add_header Cache-Control "public";
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
NGINX_EOF

echo "sudo ln -s /etc/nginx/sites-available/noctispro /etc/nginx/sites-enabled/"
echo "sudo nginx -t"
echo "sudo systemctl restart nginx"
echo ""
echo "🔒 STEP 7: SSL Certificate (Let's Encrypt)"
echo "-----------------------------------------"
echo "sudo apt install certbot python3-certbot-nginx"
echo "sudo certbot --nginx -d your-domain.com -d www.your-domain.com"
echo ""
echo "✅ DEPLOYMENT COMPLETE!"
echo "Your DICOM viewer masterpiece is now running on your server!"
