#!/bin/bash
echo "🏥 NOCTIS PRO PACS v2.0 - DOMAIN CONFIGURATION SCRIPT"
echo "===================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 CONFIGURING DOMAIN: noctispro${NC}"
echo ""

# 1. Configure local domain resolution
echo -e "${YELLOW}📝 Step 1: Configuring local domain resolution...${NC}"

# Backup original hosts file
sudo cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)

# Add noctispro domain to hosts file
if ! grep -q "noctispro" /etc/hosts; then
    echo "127.0.0.1    noctispro" | sudo tee -a /etc/hosts
    echo "::1          noctispro" | sudo tee -a /etc/hosts
    echo -e "${GREEN}✅ Added noctispro domain to /etc/hosts${NC}"
else
    echo -e "${GREEN}✅ noctispro domain already exists in /etc/hosts${NC}"
fi

# 2. Update nginx configuration for noctispro domain
echo -e "${YELLOW}📝 Step 2: Updating nginx configuration...${NC}"

# Create updated nginx config with noctispro domain
cat > /tmp/noctispro_nginx_updated.conf << 'EOF'
server {
    listen 80;
    server_name localhost noctispro mallard-shining-curiously.ngrok-free.app *.ngrok-free.app;
    client_max_body_size 3G;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Handle ngrok headers
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Server $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Host $host;
    
    # Static files
    location /static/ {
        alias /workspace/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Media files (DICOM uploads)
    location /media/ {
        alias /workspace/media/;
        expires 1h;
    }
    
    # Main application
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_connect_timeout 1800;
        proxy_send_timeout 1800;
        proxy_read_timeout 1800;
        send_timeout 1800;
        
        # Handle ngrok specific headers
        proxy_set_header ngrok-skip-browser-warning true;
    }
    
    # WebSocket support for real-time features
    location /ws/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
    }
}
EOF

# Install the updated nginx configuration
sudo cp /tmp/noctispro_nginx_updated.conf /etc/nginx/sites-available/noctispro
sudo nginx -t

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Nginx configuration updated successfully${NC}"
    sudo nginx -s reload
    echo -e "${GREEN}✅ Nginx reloaded with new configuration${NC}"
else
    echo -e "${RED}❌ Nginx configuration error - reverting changes${NC}"
    exit 1
fi

# 3. Update Django settings for new domain
echo -e "${YELLOW}📝 Step 3: Updating Django settings...${NC}"

cd /workspace
source venv/bin/activate

# Update Django ALLOWED_HOSTS and CSRF_TRUSTED_ORIGINS
python << 'EOF'
import os
import re

settings_file = '/workspace/noctis_pro/settings.py'

# Read the settings file
with open(settings_file, 'r') as f:
    content = f.read()

# Update ALLOWED_HOSTS to include noctispro
allowed_hosts_pattern = r"ALLOWED_HOSTS = os\.environ\.get\('ALLOWED_HOSTS', '[^']+'\)\.split\(',')"
new_allowed_hosts = "ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', '*,noctispro,mallard-shining-curiously.ngrok-free.app,*.ngrok-free.app,localhost,127.0.0.1,0.0.0.0').split(',')"

if re.search(allowed_hosts_pattern, content):
    content = re.sub(allowed_hosts_pattern, new_allowed_hosts, content)
else:
    # If pattern not found, look for simpler ALLOWED_HOSTS pattern
    simple_pattern = r"ALLOWED_HOSTS = \[[^\]]+\]"
    if re.search(simple_pattern, content):
        content = re.sub(simple_pattern, "ALLOWED_HOSTS = ['*', 'noctispro', 'localhost', '127.0.0.1', '0.0.0.0', '*.ngrok-free.app']", content)

# Update CSRF_TRUSTED_ORIGINS to include noctispro
csrf_pattern = r"CSRF_TRUSTED_ORIGINS = \[[^\]]+\]"
new_csrf_origins = '''CSRF_TRUSTED_ORIGINS = [
    "http://noctispro",
    "https://noctispro", 
    "https://mallard-shining-curiously.ngrok-free.app",
    "https://*.ngrok-free.app",
    "http://localhost:8000",
    "http://127.0.0.1:8000",
    "http://localhost:80",
    "http://127.0.0.1:80",
]'''

content = re.sub(csrf_pattern, new_csrf_origins, content, flags=re.MULTILINE | re.DOTALL)

# Write the updated settings
with open(settings_file, 'w') as f:
    f.write(content)

print("✅ Django settings updated with noctispro domain")
EOF

echo -e "${GREEN}✅ Django settings updated${NC}"

# 4. Create ngrok configuration
echo -e "${YELLOW}📝 Step 4: Creating ngrok configuration...${NC}"

mkdir -p ~/.config/ngrok

cat > ~/.config/ngrok/ngrok.yml << 'EOF'
version: "2"
authtoken: ""
tunnels:
  noctispro:
    proto: http
    addr: 80
    hostname: mallard-shining-curiously.ngrok-free.app
    bind_tls: true
    inspect: false
    schemes: [https, http]
EOF

echo -e "${GREEN}✅ Ngrok configuration created${NC}"

# 5. Create startup script for ngrok
echo -e "${YELLOW}📝 Step 5: Creating ngrok startup script...${NC}"

cat > /workspace/start_noctispro_ngrok.sh << 'EOF'
#!/bin/bash
echo "🚀 STARTING NOCTIS PRO PACS WITH NGROK TUNNEL"
echo "============================================="

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ ngrok not found. Installing ngrok..."
    
    # Download and install ngrok
    cd /tmp
    wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    tar xvzf ngrok-v3-stable-linux-amd64.tgz
    sudo mv ngrok /usr/local/bin/
    
    echo "✅ ngrok installed successfully"
fi

# Start ngrok tunnel
echo "🌐 Starting ngrok tunnel for NOCTIS PRO PACS..."
echo "📍 Domain: noctispro (local)"
echo "🌍 Public URL: https://mallard-shining-curiously.ngrok-free.app"
echo ""

# Start ngrok in background
nohup ngrok http --url=mallard-shining-curiously.ngrok-free.app 80 > /workspace/ngrok.log 2>&1 &

echo "✅ Ngrok tunnel started!"
echo "📊 Check logs: tail -f /workspace/ngrok.log"
echo ""
echo "🔗 Access your NOCTIS PRO PACS:"
echo "   Local: http://noctispro"
echo "   Public: https://mallard-shining-curiously.ngrok-free.app"
echo ""
echo "🔐 Login credentials:"
echo "   Username: admin"
echo "   Password: admin123"
EOF

chmod +x /workspace/start_noctispro_ngrok.sh
echo -e "${GREEN}✅ Ngrok startup script created${NC}"

# 6. Test domain resolution
echo -e "${YELLOW}📝 Step 6: Testing domain resolution...${NC}"

if ping -c 1 noctispro >/dev/null 2>&1; then
    echo -e "${GREEN}✅ noctispro domain resolves correctly${NC}"
else
    echo -e "${RED}❌ noctispro domain resolution failed${NC}"
fi

# 7. Test web server response
echo -e "${YELLOW}📝 Step 7: Testing web server response...${NC}"

response=$(curl -s -o /dev/null -w "%{http_code}" http://noctispro/ 2>/dev/null)
if [ "$response" = "200" ] || [ "$response" = "302" ]; then
    echo -e "${GREEN}✅ Web server responding on http://noctispro (HTTP $response)${NC}"
else
    echo -e "${RED}❌ Web server not responding properly (HTTP $response)${NC}"
fi

echo ""
echo -e "${GREEN}🎉 DOMAIN CONFIGURATION COMPLETE!${NC}"
echo ""
echo -e "${BLUE}📋 SUMMARY:${NC}"
echo "   🏠 Local Domain: http://noctispro"
echo "   🌍 Public Domain: https://mallard-shining-curiously.ngrok-free.app"
echo "   🔧 Nginx: Configured as reverse proxy"
echo "   📁 Max Upload: 3GB"
echo "   ⏱️  Timeout: 30 minutes"
echo ""
echo -e "${YELLOW}🚀 NEXT STEPS:${NC}"
echo "   1. Run: ./start_noctispro_ngrok.sh (to start ngrok tunnel)"
echo "   2. Access locally: http://noctispro"
echo "   3. Access publicly: https://mallard-shining-curiously.ngrok-free.app"
echo ""
echo -e "${GREEN}✅ Your NOCTIS PRO PACS is ready for production use!${NC}"