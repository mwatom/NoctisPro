# 🏥 NOCTIS PRO PACS v2.0 - Manual Deployment Guide with Ngrok

## 📋 Overview
This guide will walk you through manually deploying NOCTIS PRO PACS system on Ubuntu server with ngrok reverse proxy for public access.

## ✅ Prerequisites Completed
- ✅ Python 3.13 installed
- ✅ Virtual environment created
- ✅ Core dependencies installed
- ✅ Ngrok installed
- ✅ Nginx installed
- ✅ System packages ready

## 🚀 Step-by-Step Manual Deployment

### Step 1: Setup Ngrok Authentication
```bash
# Sign up for ngrok account at: https://dashboard.ngrok.com/signup
# Get your authtoken from: https://dashboard.ngrok.com/get-started/your-authtoken

# Configure ngrok with your authtoken
ngrok authtoken YOUR_AUTHTOKEN_HERE
```

### Step 2: Initialize Django Database
```bash
cd /workspace
source venv/bin/activate
python manage.py migrate
python manage.py collectstatic --noinput
python manage.py createsuperuser
```

### Step 3: Start Django Application Server
```bash
# Start Gunicorn in background
source venv/bin/activate
nohup gunicorn noctis_pro.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers 3 \
    --timeout 1800 \
    --max-requests 1000 \
    --max-requests-jitter 100 \
    --preload \
    --access-logfile /workspace/gunicorn_access.log \
    --error-logfile /workspace/gunicorn_error.log \
    --daemon
```

### Step 4: Configure Nginx (Optional - for local domain)
```bash
# Create nginx configuration
sudo tee /etc/nginx/sites-available/noctispro << 'EOF'
server {
    listen 80;
    server_name noctispro localhost;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 100M;
    }
    
    location /static/ {
        alias /workspace/staticfiles/;
    }
    
    location /media/ {
        alias /workspace/media/;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/noctispro /etc/nginx/sites-enabled/
sudo nginx -t && sudo nginx -s reload
```

### Step 5: Start Ngrok Tunnel
```bash
# Option A: With custom domain (requires paid plan)
ngrok http --url=YOUR-CUSTOM-DOMAIN.ngrok-free.app 8000

# Option B: Random domain (free)
ngrok http 8000

# Option C: Through nginx (if configured)
ngrok http 80
```

### Step 6: Test the System
```bash
# Check if gunicorn is running
ps aux | grep gunicorn

# Check if nginx is running (if configured)
ps aux | grep nginx

# Check if ngrok is running
ps aux | grep ngrok

# Test local access
curl http://localhost:8000

# Check ngrok public URL
curl -I http://YOUR-NGROK-URL
```

## 🔧 Automated Startup Scripts

### Create Production Startup Script
```bash
cat > /workspace/start_noctispro_manual.sh << 'EOF'
#!/bin/bash
echo "🏥 NOCTIS PRO PACS v2.0 - Manual Production Start"
echo "=============================================="

cd /workspace

# Activate virtual environment
source venv/bin/activate

# Start Gunicorn
echo "🐍 Starting Django application server..."
pkill -f gunicorn 2>/dev/null
sleep 2

nohup gunicorn noctis_pro.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers 3 \
    --timeout 1800 \
    --max-requests 1000 \
    --preload \
    --access-logfile /workspace/gunicorn_access.log \
    --error-logfile /workspace/gunicorn_error.log \
    --daemon

sleep 3
if pgrep -f "gunicorn.*noctis_pro" > /dev/null; then
    echo "✅ Gunicorn running on port 8000"
else
    echo "❌ Failed to start Gunicorn"
    exit 1
fi

# Start Nginx (optional)
echo "🌐 Starting Nginx..."
sudo nginx -t && sudo nginx -s reload 2>/dev/null || sudo nginx

# Instructions for ngrok
echo ""
echo "🌍 Next steps:"
echo "1. Configure ngrok: ngrok authtoken YOUR_TOKEN"
echo "2. Start ngrok tunnel: ngrok http 8000"
echo "3. Access via ngrok URL provided"
echo ""
echo "✅ Django application ready!"
EOF

chmod +x /workspace/start_noctispro_manual.sh
```

### Create System Status Script
```bash
cat > /workspace/check_noctispro_status.sh << 'EOF'
#!/bin/bash
echo "🏥 NOCTIS PRO PACS - System Status"
echo "================================="

# Check Gunicorn
if pgrep -f "gunicorn.*noctis_pro" > /dev/null; then
    echo "✅ Gunicorn: Running"
    echo "   Process: $(pgrep -f 'gunicorn.*noctis_pro' | head -1)"
else
    echo "❌ Gunicorn: Not running"
fi

# Check Nginx
if pgrep -f nginx > /dev/null; then
    echo "✅ Nginx: Running"
else
    echo "❌ Nginx: Not running"
fi

# Check Ngrok
if pgrep -f ngrok > /dev/null; then
    echo "✅ Ngrok: Running"
    echo "   Check URL: curl http://localhost:4040/api/tunnels"
else
    echo "❌ Ngrok: Not running"
fi

# Check ports
echo ""
echo "🔌 Port Status:"
netstat -tlnp 2>/dev/null | grep -E ":80|:8000|:4040" || ss -tlnp | grep -E ":80|:8000|:4040"

# Check logs
echo ""
echo "📝 Recent Logs:"
echo "Gunicorn errors (last 5 lines):"
tail -5 /workspace/gunicorn_error.log 2>/dev/null || echo "No error log found"
EOF

chmod +x /workspace/check_noctispro_status.sh
```

## 🌐 Access Information

### Local Access
- **Direct Django**: http://localhost:8000
- **Through Nginx**: http://localhost (if configured)
- **Local Domain**: http://noctispro (if nginx configured with hosts file)

### Public Access (via Ngrok)
- **Ngrok Dashboard**: http://localhost:4040
- **Public URL**: Provided by ngrok when started
- **API to get URL**: `curl http://localhost:4040/api/tunnels`

## 🔐 Default Credentials
- **Username**: admin
- **Password**: (set during createsuperuser step)

## 📊 Monitoring Commands

```bash
# Check system status
./check_noctispro_status.sh

# View real-time logs
tail -f /workspace/gunicorn_error.log
tail -f /workspace/gunicorn_access.log

# Check ngrok tunnels
curl http://localhost:4040/api/tunnels | python -m json.tool

# Restart services
./start_noctispro_manual.sh
```

## 🔧 Troubleshooting

### Common Issues and Solutions

1. **Gunicorn won't start**
   ```bash
   source venv/bin/activate
   python manage.py check
   python manage.py migrate
   ```

2. **Ngrok authentication error**
   ```bash
   ngrok authtoken YOUR_TOKEN
   ngrok config check
   ```

3. **Port already in use**
   ```bash
   sudo netstat -tlnp | grep :8000
   pkill -f gunicorn
   ```

4. **Permission denied**
   ```bash
   chmod +x /workspace/*.sh
   sudo chown -R $USER:$USER /workspace
   ```

## 🚀 Quick Start Commands

```bash
# 1. Start the system
cd /workspace
./start_noctispro_manual.sh

# 2. Setup ngrok (first time only)
ngrok authtoken YOUR_TOKEN

# 3. Start ngrok tunnel
ngrok http 8000

# 4. Check status
./check_noctispro_status.sh
```

## 📱 Mobile/Remote Access
Once ngrok is running, you can access the system from anywhere using the provided ngrok URL.

## 🔒 Security Notes
- Change default Django SECRET_KEY in production
- Use HTTPS in production (ngrok provides this automatically)
- Consider using ngrok's custom domains for consistent URLs
- Set up proper firewall rules for production deployment

## 📞 Support
- Check logs in `/workspace/gunicorn_*.log`
- Use `./check_noctispro_status.sh` for system status
- Ngrok dashboard at `http://localhost:4040`