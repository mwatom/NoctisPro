#!/bin/bash

echo "🚀 NOCTIS PRO PACS v2.0 - SERVER DEPLOYMENT GUIDE"
echo "================================================="
echo ""
echo "This guide covers multiple deployment options for your masterpiece:"
echo ""
echo "1. 🔥 QUICK NGROK DEPLOYMENT (Immediate Access)"
echo "2. 🌐 VPS/Cloud Server Deployment (Production)"
echo "3. 🐳 Docker Deployment (Containerized)"
echo "4. ☁️  Cloud Platform Deployment (AWS/GCP/Azure)"
echo ""

# Create quick deployment script
cat > /workspace/deploy_ngrok.sh << 'EOF'
#!/bin/bash
echo "🔥 QUICK NGROK DEPLOYMENT"
echo "========================"

# Check if Django server is running
if ! pgrep -f "python manage.py runserver" > /dev/null; then
    echo "🚀 Starting Django server..."
    cd /workspace
    source venv/bin/activate
    sudo venv/bin/python manage.py runserver 0.0.0.0:80 &
    sleep 3
fi

echo "✅ Django server is running on port 80"
echo ""
echo "🌐 TO ACCESS YOUR MASTERPIECE:"
echo "1. Open a new terminal and run:"
echo "   ngrok http --url=mallard-shining-curiously.ngrok-free.app 80"
echo ""
echo "2. Visit: https://mallard-shining-curiously.ngrok-free.app"
echo "3. Login with: admin / admin123"
echo ""
echo "🏥 Your DICOM Viewer masterpiece will be available at:"
echo "   https://mallard-shining-curiously.ngrok-free.app/dicom-viewer/"
echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
EOF

chmod +x /workspace/deploy_ngrok.sh

# Create VPS deployment script
cat > /workspace/deploy_vps.sh << 'EOF'
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
EOF

chmod +x /workspace/deploy_vps.sh

# Create Docker deployment
cat > /workspace/deploy_docker.sh << 'EOF'
#!/bin/bash
echo "🐳 DOCKER DEPLOYMENT"
echo "==================="
echo ""
echo "📋 PREREQUISITES:"
echo "   • Docker and Docker Compose installed"
echo "   • 4GB+ RAM recommended"
echo "   • 20GB+ storage space"
echo ""

# Create production Dockerfile
cat > Dockerfile.production << 'DOCKER_EOF'
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    libpq-dev \
    libgdal-dev \
    gdal-bin \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install gunicorn psycopg2-binary

# Copy application code
COPY . .

# Collect static files
RUN python manage.py collectstatic --noinput

# Create non-root user
RUN adduser --disabled-password --gecos '' appuser
RUN chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Run gunicorn
CMD ["gunicorn", "noctis_pro.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
DOCKER_EOF

# Create docker-compose for production
cat > docker-compose.production.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: noctispro
      POSTGRES_USER: noctispro
      POSTGRES_PASSWORD: your_secure_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U noctispro"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - redis_data:/data

  web:
    build:
      context: .
      dockerfile: Dockerfile.production
    environment:
      - DEBUG=False
      - DATABASE_URL=postgresql://noctispro:your_secure_password@db:5432/noctispro
      - REDIS_URL=redis://redis:6379/0
      - ALLOWED_HOSTS=your-domain.com,www.your-domain.com
    volumes:
      - static_volume:/app/staticfiles
      - media_volume:/app/media
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health/"]
      interval: 30s
      timeout: 10s
      retries: 3

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - static_volume:/app/staticfiles
      - media_volume:/app/media
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - web
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
  static_volume:
  media_volume:
COMPOSE_EOF

echo ""
echo "🚀 DEPLOYMENT COMMANDS:"
echo "----------------------"
echo "# Build and start services"
echo "docker-compose -f docker-compose.production.yml up -d --build"
echo ""
echo "# Run migrations"
echo "docker-compose -f docker-compose.production.yml exec web python manage.py migrate"
echo ""
echo "# Create superuser"
echo "docker-compose -f docker-compose.production.yml exec web python manage.py createsuperuser"
echo ""
echo "# View logs"
echo "docker-compose -f docker-compose.production.yml logs -f"
echo ""
echo "✅ Docker deployment files created!"
EOF

chmod +x /workspace/deploy_docker.sh

# Create cloud deployment guide
cat > /workspace/deploy_cloud.sh << 'EOF'
#!/bin/bash
echo "☁️  CLOUD PLATFORM DEPLOYMENT"
echo "============================"
echo ""
echo "🔥 AWS DEPLOYMENT (Recommended)"
echo "------------------------------"
echo "1. Launch EC2 instance (t3.medium or larger)"
echo "2. Use Ubuntu 20.04 LTS AMI"
echo "3. Configure security group:"
echo "   - HTTP (80): 0.0.0.0/0"
echo "   - HTTPS (443): 0.0.0.0/0"
echo "   - SSH (22): Your IP"
echo "4. Use Elastic IP for static IP"
echo "5. Setup RDS PostgreSQL database"
echo "6. Use S3 for media file storage"
echo "7. CloudFront for CDN (optional)"
echo ""
echo "💙 AZURE DEPLOYMENT"
echo "------------------"
echo "1. Create App Service (Python 3.11)"
echo "2. Configure PostgreSQL database"
echo "3. Setup Application Insights"
echo "4. Configure custom domain and SSL"
echo "5. Use Azure Blob Storage for media"
echo ""
echo "🌟 GOOGLE CLOUD DEPLOYMENT"
echo "-------------------------"
echo "1. Use Cloud Run for serverless deployment"
echo "2. Cloud SQL for PostgreSQL"
echo "3. Cloud Storage for media files"
echo "4. Cloud Load Balancer with SSL"
echo "5. Cloud CDN for performance"
EOF

chmod +x /workspace/deploy_cloud.sh

# Create environment configuration
cat > /workspace/.env.production.template << 'EOF'
# Production Environment Configuration
DEBUG=False
SECRET_KEY=your-super-secret-key-here-make-it-long-and-random
ALLOWED_HOSTS=your-domain.com,www.your-domain.com

# Database Configuration
DATABASE_URL=postgresql://username:password@localhost:5432/noctispro

# Security Settings
SECURE_SSL_REDIRECT=True
SECURE_HSTS_SECONDS=31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS=True
SECURE_HSTS_PRELOAD=True
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True

# Email Configuration (for notifications)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password

# Redis (for caching and sessions)
REDIS_URL=redis://localhost:6379/0

# File Storage (for production)
USE_S3=False
AWS_ACCESS_KEY_ID=your-aws-key
AWS_SECRET_ACCESS_KEY=your-aws-secret
AWS_STORAGE_BUCKET_NAME=your-bucket-name

# Monitoring and Logging
SENTRY_DSN=your-sentry-dsn-for-error-tracking
EOF

echo ""
echo "📊 DEPLOYMENT OPTIONS SUMMARY:"
echo "=============================="
echo ""
echo "🔥 OPTION 1: Quick Ngrok (Development/Demo)"
echo "   • Instant deployment"
echo "   • Perfect for testing and demos"
echo "   • Run: ./deploy_ngrok.sh"
echo ""
echo "🌐 OPTION 2: VPS/Cloud Server (Production)"
echo "   • Full production deployment"
echo "   • Your own domain and SSL"
echo "   • Guide: ./deploy_vps.sh"
echo ""
echo "🐳 OPTION 3: Docker (Containerized)"
echo "   • Easy scaling and management"
echo "   • Isolated environment"
echo "   • Guide: ./deploy_docker.sh"
echo ""
echo "☁️  OPTION 4: Cloud Platforms (Enterprise)"
echo "   • AWS, Azure, Google Cloud"
echo "   • Auto-scaling and managed services"
echo "   • Guide: ./deploy_cloud.sh"
echo ""
echo "🎯 RECOMMENDATION:"
echo "   • For immediate access: Use Option 1 (Ngrok)"
echo "   • For production: Use Option 2 (VPS) or Option 4 (Cloud)"
echo "   • For development teams: Use Option 3 (Docker)"
echo ""
echo "🎉 ALL DEPLOYMENT GUIDES CREATED!"
echo "Choose your preferred option and follow the guide."