# 🌐 NoctisPro Internet Deployment Guide

Deploy your medical imaging system to the internet with SSL in minutes!

## 🚀 Quick Start (2 commands)

```bash
# 1. Clone and enter repository
git clone <your-noctispro-repository-url>
cd <repository-name>

# 2. Run internet deployment
sudo bash deploy-internet.sh
```

## 📋 What You Need

- **Ubuntu 24.04 server** (cloud VPS or dedicated server)
- **Root access** (sudo privileges)
- **Internet connection**
- **One of these for domain access:**
  - Custom domain (like noctispro.com)
  - Free DuckDNS account
  - Free Ngrok account

## 🌐 Domain Options

### Option 1: noctispro.com (Your Choice)
- Perfect if you own or want to use `noctispro.com`
- **Important**: Make sure the domain points to your server's IP
- The script will automatically get SSL certificate

### Option 2: DuckDNS (Free & Easy)
- Get a free subdomain like `mynoctis.duckdns.org`
- Visit https://www.duckdns.org and create account
- No domain purchase needed!
- Automatic SSL setup

### Option 3: Ngrok (Instant Access)
- Get instant internet access with a tunnel
- Visit https://ngrok.com and get free auth token
- No domain setup needed
- Perfect for testing

### Option 4: Your Own Domain
- If you have any other domain
- Point your domain to server IP first

## 📱 Step-by-Step Instructions

### 1. Get Your Server Ready

**Get an Ubuntu 24.04 server from any provider:**
- DigitalOcean, AWS, Google Cloud, Vultr, etc.
- Minimum: 2GB RAM, 20GB disk
- Note your server IP address

### 2. Connect to Your Server

```bash
ssh root@your-server-ip
# or
ssh ubuntu@your-server-ip
```

### 3. Clone Repository

```bash
git clone <your-repository-url>
cd <repository-directory>
```

### 4. Run Deployment Script

```bash
sudo bash deploy-internet.sh
```

### 5. Choose Your Domain Option

The script will ask you to choose:
```
🌐 Domain Setup Options:
   1) Use noctispro.com (you mentioned this)
   2) Use DuckDNS free subdomain (automatic setup)  
   3) Use ngrok tunnel (instant access)
   4) I have my own domain
Choose option (1-4):
```

**For noctispro.com**: Choose option 1

### 6. Follow the Prompts

- Enter domain information if needed
- Wait for installation (5-10 minutes)
- Create admin user when prompted

### 7. Access Your System

Your system will be live at:
- **noctispro.com**: `https://noctispro.com`
- **DuckDNS**: `https://yourname.duckdns.org`
- **Ngrok**: The script will show you the URL
- **Custom**: `https://yourdomain.com`

## 🔧 What the Script Does

1. **System Setup**
   - Updates Ubuntu packages
   - Installs Python, PostgreSQL, Redis, Nginx
   - Creates virtual environment

2. **Application Setup**
   - Installs all Python dependencies
   - Creates database and user
   - Runs Django migrations
   - Collects static files

3. **Production Configuration**
   - Creates systemd service
   - Configures Nginx reverse proxy
   - Sets up SSL certificates
   - Configures firewall

4. **Domain Configuration**
   - Sets up chosen domain option
   - Configures SSL/HTTPS
   - Sets up auto-renewal

## 🛠️ Troubleshooting

### "python: command not found"
```bash
sudo ln -sf /usr/bin/python3 /usr/bin/python
```

### SSL Certificate Failed
```bash
# Make sure your domain points to server IP first
sudo certbot --nginx -d your-domain.com
```

### Service Not Starting
```bash
# Check logs
sudo journalctl -u noctis-pro -f

# Restart services
sudo systemctl restart noctis-pro nginx
```

### Can't Access Website
```bash
# Check firewall
sudo ufw status

# Allow ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### Domain Not Working
1. **Check DNS**: Make sure domain points to server IP
2. **Wait**: DNS changes can take up to 24 hours
3. **Try HTTP first**: `http://your-domain.com`

## 📊 Post-Deployment

### Access Admin Panel
- URL: `https://your-domain.com/admin`
- Use the admin credentials you created

### Monitor Your System
```bash
# View application logs
sudo journalctl -u noctis-pro -f

# View web server logs  
sudo tail -f /var/log/nginx/error.log

# Check service status
sudo systemctl status noctis-pro nginx postgresql redis
```

### Manage Your Services
```bash
# Restart application
sudo systemctl restart noctis-pro

# Restart web server
sudo systemctl restart nginx

# Update application (after git pull)
cd /opt/noctis_pro
sudo -u www-data bash -c 'source venv/bin/activate && python manage.py migrate && python manage.py collectstatic --noinput'
sudo systemctl restart noctis-pro
```

## 🔐 Security Features

- **Automatic SSL certificates** (Let's Encrypt)
- **Firewall configured** (only necessary ports open)
- **Secure database** with random passwords
- **Production Django settings**
- **SSL auto-renewal** setup

## 📁 Important Locations

```
/opt/noctis_pro/          # Application directory
/opt/noctis_pro/.env      # Configuration file
/opt/noctis_pro/logs/     # Application logs
/opt/noctis_pro/media/    # Uploaded files
/etc/nginx/sites-available/noctis-pro  # Nginx config
/etc/systemd/system/noctis-pro.service # Service config
```

## 💡 Tips for noctispro.com

Since you want to use `noctispro.com`:

1. **If you own the domain:**
   - Point it to your server IP in DNS settings
   - Choose option 1 in the script
   - SSL will be automatic

2. **If you don't own it:**
   - Consider `mynoctis.duckdns.org` instead (option 2)
   - Or use ngrok for testing (option 3)

3. **For testing first:**
   - Use ngrok (option 3) to test everything works
   - Then switch to your preferred domain later

## 🆘 Need Help?

If something goes wrong:

1. **Check the logs** first
2. **Take a screenshot** of any error messages
3. **Note your chosen options** (domain type, etc.)
4. **Try the troubleshooting steps** above

## 🎉 Success!

Once deployed successfully, you'll have:
- ✅ Professional medical imaging system
- ✅ Internet accessible with HTTPS
- ✅ Automatic SSL renewal
- ✅ Production-ready configuration
- ✅ Secure and scalable setup

Your NoctisPro system is now live on the internet! 🚀