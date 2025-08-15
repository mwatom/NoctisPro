# Complete Ubuntu Server 24.04 Docker Setup Guide for Noctis Pro

This guide provides step-by-step instructions to install Docker on Ubuntu Server 24.04 and run the Noctis Pro DICOM system from start to finish.

## 📋 Prerequisites

- Fresh Ubuntu Server 24.04 LTS installation
- Root or sudo access
- Internet connection
- At least 4GB RAM and 20GB free disk space

## 🔧 Step 1: Update Ubuntu System

```bash
# Update package list and upgrade system
sudo apt update && sudo apt upgrade -y

# Install basic utilities
sudo apt install -y curl wget gnupg lsb-release ca-certificates
```

## 🐳 Step 2: Install Docker Engine

### Method 1: Official Docker Installation (Recommended)

```bash
# Remove any old Docker installations
sudo apt remove -y docker docker-engine docker.io containerd runc

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package list
sudo apt update

# Install Docker Engine, CLI, and plugins
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Verify Docker installation
docker --version
```

### Method 2: Quick Installation Script

```bash
# Alternative: Use Docker's convenience script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Clean up
rm get-docker.sh
```

## 👤 Step 3: Configure Docker User Permissions

```bash
# Add current user to docker group (avoids using sudo with docker)
sudo usermod -aG docker $USER

# Apply group changes (logout and login, or use newgrp)
newgrp docker

# Test Docker without sudo
docker run hello-world
```

**Note**: If the hello-world test fails, logout and login again, or reboot the server.

## 🚀 Step 4: Start and Enable Docker Service

```bash
# Start Docker service
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker

# Check Docker service status
sudo systemctl status docker

# Verify Docker Compose is available
docker compose version
```

## 📥 Step 5: Download Noctis Pro Source Code

### Option A: Clone from GitHub (if you have a repository)

```bash
# Install git if not already installed
sudo apt install -y git

# Clone the repository (replace with your actual repo URL)
git clone https://github.com/yourusername/NoctisPro.git
cd NoctisPro
```

### Option B: If you have the source code locally

```bash
# Create project directory
mkdir -p ~/NoctisPro
cd ~/NoctisPro

# Copy your source code here, or upload via SCP/SFTP
# scp -r /path/to/local/NoctisPro/* user@server:~/NoctisPro/
```

## ⚙️ Step 6: Configure Environment

```bash
# Copy the Docker environment template
cp .env.docker .env

# Edit the environment file with your settings
nano .env
```

### Essential Configuration Changes

Edit the `.env` file and modify these important settings:

```bash
# Security Settings (REQUIRED for production)
SECRET_KEY=your-very-long-random-secret-key-change-this-now
POSTGRES_PASSWORD=your-secure-database-password-here

# Admin User (for initial access)
ADMIN_USER=admin
ADMIN_EMAIL=admin@yourdomain.com
ADMIN_PASS=your-secure-admin-password

# Production Settings (if this is production)
DEBUG=False
BUILD_TARGET=production

# Domain Settings (if you have a domain)
DOMAIN_NAME=your-domain.com
USE_SSL=true
```

### Generate a Secure Secret Key

```bash
# Generate a random secret key
python3 -c "import secrets; print('SECRET_KEY=' + secrets.token_urlsafe(50))"
```

Copy the output and paste it into your `.env` file.

## 🔒 Step 7: Set Secure File Permissions

```bash
# Set secure permissions for environment file
chmod 600 .env

# Ensure Docker files are readable
chmod +r Dockerfile docker-compose.yml
```

## 🏗️ Step 8: Build and Start the System

```bash
# Build Docker images (this may take several minutes)
docker compose build

# Start all services in background
docker compose up -d

# Monitor the startup process
docker compose logs -f
```

### Expected Startup Output

You should see output similar to:

```
✅ Database ready
✅ Redis ready  
✅ Django migrations applied
✅ Static files collected
🚀 Starting Noctis Pro Development Server...
📡 Web Interface: http://localhost:8000
🔧 Admin Panel: http://localhost:8000/admin-panel/
📋 Worklist: http://localhost:8000/worklist/
🏥 DICOM Port: localhost:11112
```

## 🌐 Step 9: Configure Firewall (UFW)

```bash
# Install and configure UFW firewall
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (replace 22 with your SSH port if different)
sudo ufw allow ssh

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow Noctis Pro ports
sudo ufw allow 8000/tcp   # Web interface
sudo ufw allow 11112/tcp  # DICOM receiver

# Enable firewall
sudo ufw --force enable

# Check firewall status
sudo ufw status
```

## 🔍 Step 10: Verify Installation

### Check Service Status

```bash
# Check all containers are running
docker compose ps

# Expected output:
# NAME           IMAGE              STATUS
# noctis_web     noctispro_web      Up (healthy)
# noctis_db      postgres:15        Up (healthy)
# noctis_redis   redis:7-alpine     Up (healthy)
# noctis_celery  noctispro_celery   Up
# noctis_dicom   noctispro_dicom    Up
```

### Test System Access

```bash
# Get server IP address
hostname -I

# Test web interface (replace with your server IP)
curl -f http://YOUR_SERVER_IP:8000/

# Check if admin panel is accessible
curl -I http://YOUR_SERVER_IP:8000/admin-panel/
```

## 🌍 Step 11: Access the System

### From Your Local Computer

Open a web browser and navigate to:

- **Main Interface**: `http://YOUR_SERVER_IP:8000`
- **Admin Panel**: `http://YOUR_SERVER_IP:8000/admin-panel/`
- **Worklist**: `http://YOUR_SERVER_IP:8000/worklist/`

Replace `YOUR_SERVER_IP` with your Ubuntu server's actual IP address.

### Initial Login

Use the credentials you set in the `.env` file:
- Username: `admin` (or what you set in ADMIN_USER)
- Password: (what you set in ADMIN_PASS)

## 🔧 Step 12: Essential Management Commands

### Daily Operations

```bash
# View system status
docker compose ps

# View logs
docker compose logs -f

# Restart specific service
docker compose restart web

# Stop all services
docker compose down

# Start all services
docker compose up -d

# Update system (if you have new code)
docker compose down
git pull  # if using git
docker compose build
docker compose up -d
```

### Database Management

```bash
# Create database backup
docker compose exec db pg_dump -U noctis_user noctis_pro > backup_$(date +%Y%m%d).sql

# Access database shell
docker compose exec db psql -U noctis_user -d noctis_pro

# View database logs
docker compose logs db
```

### System Monitoring

```bash
# Monitor resource usage
docker stats

# Check disk usage
docker system df

# View container details
docker compose config
```

## 🔄 Step 13: Enable GitHub Auto-Updates (Optional)

If you want automatic updates when code changes on GitHub:

### 1. Configure GitHub Webhook

```bash
# Add webhook secret to environment
echo "WEBHOOK_SECRET=your-webhook-secret-here" >> .env

# Start the webhook service
docker compose up -d github_webhook
```

### 2. Set Up GitHub Repository Webhook

In your GitHub repository:
1. Go to Settings → Webhooks
2. Add webhook with URL: `http://YOUR_SERVER_IP:9000/webhook`
3. Set Content type: `application/json`
4. Set Secret: (same as WEBHOOK_SECRET in .env)
5. Select: "Just the push event"

### 3. Test Auto-Update

```bash
# Check webhook logs
docker compose logs -f github_webhook

# Test by pushing to your repository
# The system should automatically update
```

## 🛡️ Step 14: Production Security Hardening

### SSL/TLS Setup (Production)

```bash
# Install Certbot for Let's Encrypt
sudo apt install -y certbot

# Get SSL certificate (replace with your domain)
sudo certbot certonly --standalone -d yourdomain.com

# Update docker-compose.yml to use SSL
# Enable nginx service with SSL configuration
docker compose --profile production up -d
```

### Additional Security

```bash
# Install fail2ban for intrusion prevention
sudo apt install -y fail2ban

# Configure automatic security updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

## 📊 Step 15: Set Up Monitoring

### Log Rotation

```bash
# Configure log rotation
sudo tee /etc/logrotate.d/noctis-docker << EOF
/var/lib/docker/containers/*/*-json.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF
```

### System Health Monitoring

```bash
# Create health check script
sudo tee /usr/local/bin/noctis-health << 'EOF'
#!/bin/bash
echo "=== Noctis Pro Health Check ==="
echo "Date: $(date)"
echo ""

echo "Docker Services:"
docker compose ps

echo ""
echo "System Resources:"
df -h /
free -h

echo ""
echo "Web Service Health:"
curl -s http://localhost:8000/health/ || echo "❌ Web service unhealthy"

echo ""
echo "Database Health:"
docker compose exec -T db pg_isready -U noctis_user || echo "❌ Database unhealthy"
EOF

sudo chmod +x /usr/local/bin/noctis-health

# Run health check
noctis-health
```

## 🚨 Troubleshooting Common Issues

### Docker Installation Issues

```bash
# If Docker installation fails
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Restart Docker service
sudo systemctl restart docker

# Check Docker daemon status
sudo systemctl status docker
```

### Permission Issues

```bash
# Fix Docker permissions
sudo chmod 666 /var/run/docker.sock

# Or restart and re-add user to docker group
sudo systemctl restart docker
sudo usermod -aG docker $USER
newgrp docker
```

### Port Conflicts

```bash
# Check what's using port 8000
sudo netstat -tulpn | grep :8000

# Kill conflicting process (if needed)
sudo fuser -k 8000/tcp
```

### Database Connection Issues

```bash
# Reset database
docker compose down -v
docker volume prune -f
docker compose up -d

# Check database logs
docker compose logs db
```

### Out of Disk Space

```bash
# Clean Docker system
docker system prune -a -f
docker volume prune -f

# Remove unused images
docker image prune -a -f
```

## 📱 Step 16: Access from External Networks

### Configure Router/Firewall (if behind NAT)

If your server is behind a router, forward these ports:
- Port 8000 → Ubuntu Server IP:8000 (Web Interface)
- Port 11112 → Ubuntu Server IP:11112 (DICOM)
- Port 22 → Ubuntu Server IP:22 (SSH - optional)

### Dynamic DNS (Optional)

```bash
# Install Dynamic DNS client (if you have dynamic IP)
sudo apt install -y ddclient

# Configure with your DDNS provider
sudo nano /etc/ddclient.conf
```

## ✅ Final Verification Checklist

- [ ] Docker and Docker Compose installed
- [ ] All services running (`docker compose ps`)
- [ ] Web interface accessible
- [ ] Admin panel accessible
- [ ] Database healthy
- [ ] Firewall configured
- [ ] SSL certificate installed (production)
- [ ] Backups configured
- [ ] Monitoring set up
- [ ] Documentation saved

## 🎉 Congratulations!

Your Noctis Pro DICOM system is now running on Ubuntu Server 24.04 with Docker!

### Quick Access Summary

- **Web Interface**: `http://YOUR_SERVER_IP:8000`
- **Admin Panel**: `http://YOUR_SERVER_IP:8000/admin-panel/`
- **Worklist**: `http://YOUR_SERVER_IP:8000/worklist/`
- **DICOM Port**: `YOUR_SERVER_IP:11112`

### Next Steps

1. **Import DICOM data** through the web interface
2. **Configure user accounts** in the admin panel
3. **Set up regular backups** using the provided scripts
4. **Monitor system performance** with the health check tools
5. **Configure DICOM devices** to send to port 11112

### Getting Help

- Check logs: `docker compose logs -f`
- Health check: `noctis-health`
- System status: `docker compose ps`
- Documentation: `DOCKER_SETUP.md`

---

**Important**: Always keep your system updated and monitor the logs regularly. For production use, ensure you've changed all default passwords and enabled SSL/TLS encryption.