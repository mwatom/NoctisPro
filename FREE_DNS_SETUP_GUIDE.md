# 🆓 Free DNS Setup Guide for NoctisPro - Ubuntu 24.04

> **Complete Free DNS Configuration**: Step-by-step guide for setting up free DNS services to access your NoctisPro Medical Imaging Platform over the internet

## 🎯 FREE DNS OPTIONS OVERVIEW

**Best Free DNS Services for NoctisPro:**

1. **🦆 DuckDNS** - Most reliable, easy setup
2. **🌐 No-IP** - Popular, good uptime
3. **📡 FreeDNS (afraid.org)** - Many domain options
4. **⚡ ngrok** - Great for testing/demos
5. **🔗 Serveo** - SSH-based tunneling

---

## 🦆 OPTION 1: DuckDNS (RECOMMENDED)

### Why DuckDNS?
- ✅ **100% Free forever**
- ✅ **Easy 5-minute setup**
- ✅ **Reliable uptime**
- ✅ **SSL certificate compatible**
- ✅ **Multiple subdomain options**
- ✅ **API for automation**

### Step 1: Create DuckDNS Account

1. **Visit**: https://www.duckdns.org/
2. **Sign in** with one of these options:
   - Google Account
   - GitHub Account
   - Reddit Account
   - Twitter Account

### Step 2: Create Your Subdomain

1. **Choose a subdomain name** (examples):
   - `myclinic.duckdns.org`
   - `hospitalxray.duckdns.org`
   - `medicalimaging.duckdns.org`
   - `noctispro.duckdns.org`

2. **Enter your subdomain** in the text box
3. **Click "add domain"**
4. **Copy your token** (you'll need this!)

### Step 3: Install DuckDNS on Ubuntu

```bash
# Get your server's public IP first
curl -4 ifconfig.me

# Create DuckDNS directory
mkdir ~/duckdns
cd ~/duckdns

# Create the update script (replace YOUR_SUBDOMAIN and YOUR_TOKEN)
cat > duck.sh << 'EOF'
#!/bin/bash

# DuckDNS Configuration
SUBDOMAIN="YOUR_SUBDOMAIN"  # Replace with your actual subdomain (without .duckdns.org)
TOKEN="YOUR_TOKEN"          # Replace with your actual token from DuckDNS

# Update DuckDNS with current IP
echo url="https://www.duckdns.org/update?domains=${SUBDOMAIN}&token=${TOKEN}&ip=" | curl -k -o ~/duckdns/duck.log -K -

# Log the update
echo "$(date): DuckDNS update completed - $(cat ~/duckdns/duck.log)" >> ~/duckdns/update.log
EOF

# Make script executable
chmod 700 duck.sh

# Edit the script with your actual values
nano duck.sh
# Replace YOUR_SUBDOMAIN with your chosen name (e.g., myclinic)
# Replace YOUR_TOKEN with the token from DuckDNS dashboard

# Test the script
./duck.sh

# Check if it worked (should show "OK")
cat duck.log
```

### Step 4: Automate DuckDNS Updates

```bash
# Add to crontab for automatic updates every 5 minutes
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab -

# Verify crontab entry
crontab -l

# Check update log
tail -f ~/duckdns/update.log
```

### Step 5: Test Your Domain

```bash
# Test DNS resolution (replace with your actual subdomain)
nslookup YOUR_SUBDOMAIN.duckdns.org
dig YOUR_SUBDOMAIN.duckdns.org

# Should return your server's public IP
```

---

## 🌐 OPTION 2: No-IP Free DNS

### Step 1: Create No-IP Account

1. **Visit**: https://www.noip.com/
2. **Click "Sign Up"** 
3. **Choose "Free"** plan
4. **Verify your email**

### Step 2: Create Hostname

1. **Login to No-IP dashboard**
2. **Go to "Dynamic DNS" → "No-IP Hostnames"**
3. **Click "Create Hostname"**
4. **Choose hostname** (examples):
   - `myclinic.ddns.net`
   - `medicalcenter.hopto.org`
   - `noctispro.zapto.org`
5. **Enter your server's public IP**
6. **Save hostname**

### Step 3: Install No-IP Client

```bash
# Download No-IP client
cd /tmp
wget http://www.no-ip.com/client/linux/noip-duc-linux.tar.gz

# Extract and compile
tar xzf noip-duc-linux.tar.gz
cd noip-2.1.9-1/
make

# Install (requires sudo)
sudo make install

# Configure No-IP client (enter your No-IP username and password)
sudo /usr/local/bin/noip2 -C

# Start the client
sudo /usr/local/bin/noip2
```

### Step 4: Create Auto-Start Service

```bash
# Create systemd service
sudo nano /etc/systemd/system/noip.service

# Add this content:
[Unit]
Description=No-IP Dynamic DNS Update Client
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/noip2
Restart=always
User=nobody

[Install]
WantedBy=multi-user.target

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable noip
sudo systemctl start noip

# Check status
sudo systemctl status noip
```

---

## 📡 OPTION 3: FreeDNS (afraid.org)

### Step 1: Create Account

1. **Visit**: https://freedns.afraid.org/
2. **Click "For free sign up"**
3. **Create account and verify email**

### Step 2: Create Subdomain

1. **Login to FreeDNS**
2. **Go to "Subdomains"**
3. **Click "Add a subdomain"**
4. **Choose from available domains**:
   - `yourname.mooo.com`
   - `yourname.chickenkiller.com`
   - `yourname.redirectme.net`
   - And many more!
5. **Enter your server's public IP**

### Step 3: Setup Auto-Update

```bash
# Get your update URL from FreeDNS account
# Go to "Dynamic DNS" → Copy your update URL

# Create update script
mkdir ~/freedns
cd ~/freedns

cat > update.sh << 'EOF'
#!/bin/bash
# Replace with your actual FreeDNS update URL
curl "https://freedns.afraid.org/dynamic/update.php?YOUR_UPDATE_CODE_HERE"
echo "$(date): FreeDNS updated" >> ~/freedns/update.log
EOF

chmod +x update.sh

# Test update
./update.sh

# Add to crontab
(crontab -l 2>/dev/null; echo "*/10 * * * * ~/freedns/update.sh >/dev/null 2>&1") | crontab -
```

---

## ⚡ OPTION 4: ngrok (Great for Testing)

### Perfect for Demos and Testing

```bash
# Install ngrok
wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
tar xvzf ngrok-v3-stable-linux-amd64.tgz
sudo mv ngrok /usr/local/bin

# Create free ngrok account at https://ngrok.com/
# Get your auth token from dashboard

# Configure ngrok
ngrok config add-authtoken YOUR_AUTH_TOKEN

# Expose NoctisPro (assuming it runs on port 8000)
ngrok http 8000

# ngrok will give you URLs like:
# https://abc123.ngrok.io → your server
```

### Make ngrok Permanent

```bash
# Create ngrok service
sudo nano /etc/systemd/system/ngrok.service

[Unit]
Description=ngrok tunnel
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/usr/local/bin/ngrok http 8000
Restart=always

[Install]
WantedBy=multi-user.target

# Enable service
sudo systemctl enable ngrok
sudo systemctl start ngrok
```

---

## 🔗 OPTION 5: Serveo (SSH-based)

### No Account Required!

```bash
# Create SSH tunnel (replace with your domain preference)
ssh -R 80:localhost:8000 serveo.net

# Or with custom subdomain
ssh -R myclinic:80:localhost:8000 serveo.net

# Your site will be available at:
# https://myclinic.serveo.net
```

### Make Serveo Permanent

```bash
# Create SSH key for automatic connection
ssh-keygen -t rsa -f ~/.ssh/serveo -N ""

# Create serveo service
sudo nano /etc/systemd/system/serveo.service

[Unit]
Description=Serveo SSH Tunnel
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=/usr/bin/ssh -R myclinic:80:localhost:8000 -i /home/ubuntu/.ssh/serveo -o StrictHostKeyChecking=no serveo.net
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target

# Enable service
sudo systemctl enable serveo
sudo systemctl start serveo
```

---

## 🛠️ CONFIGURE NOCTISPRO WITH FREE DNS

### Update Deployment Script

```bash
# Edit the NoctisPro deployment script
cd /opt/noctis_pro
sudo nano deploy_noctis_production.sh

# Change the domain line to your free DNS:
DOMAIN_NAME="yourclinic.duckdns.org"     # For DuckDNS
# OR
DOMAIN_NAME="yourclinic.ddns.net"        # For No-IP
# OR  
DOMAIN_NAME="yourclinic.mooo.com"        # For FreeDNS
```

### Update Quick Deploy Script

```bash
# When running the quick deploy script, enter your free domain:
sudo bash QUICK_MANUAL_DEPLOY_UBUNTU24.sh

# When prompted for domain, enter:
# myclinic.duckdns.org
# or your chosen free domain
```

---

## 🔒 SSL CERTIFICATES WITH FREE DNS

### Let's Encrypt Works with Free DNS!

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Generate SSL certificate for your free domain
sudo certbot --nginx -d yourclinic.duckdns.org

# Test automatic renewal
sudo certbot renew --dry-run
```

---

## 🧪 TESTING YOUR FREE DNS SETUP

### Verification Commands

```bash
# Test DNS resolution
nslookup yourclinic.duckdns.org
dig yourclinic.duckdns.org

# Test HTTP access
curl -I http://yourclinic.duckdns.org

# Test HTTPS access (after SSL setup)
curl -I https://yourclinic.duckdns.org

# Check if domain points to your server
ping yourclinic.duckdns.org
```

### Complete Test Script

```bash
# Create test script
cat > test_dns.sh << 'EOF'
#!/bin/bash

DOMAIN="yourclinic.duckdns.org"  # Replace with your domain
SERVER_IP=$(curl -s -4 ifconfig.me)

echo "Testing DNS setup for: $DOMAIN"
echo "Server IP: $SERVER_IP"
echo

# Test DNS resolution
echo "1. Testing DNS resolution..."
RESOLVED_IP=$(dig +short $DOMAIN | head -n1)
echo "Domain resolves to: $RESOLVED_IP"

if [ "$RESOLVED_IP" = "$SERVER_IP" ]; then
    echo "✅ DNS is correctly configured!"
else
    echo "❌ DNS mismatch! Check your DNS service."
    exit 1
fi

# Test HTTP
echo
echo "2. Testing HTTP access..."
if curl -s -I http://$DOMAIN | grep -q "200\|302\|301"; then
    echo "✅ HTTP access working!"
else
    echo "❌ HTTP access failed"
fi

# Test HTTPS
echo
echo "3. Testing HTTPS access..."
if curl -s -I https://$DOMAIN | grep -q "200\|302\|301"; then
    echo "✅ HTTPS access working!"
else
    echo "⚠️  HTTPS not working (normal before SSL setup)"
fi

echo
echo "DNS setup test completed!"
EOF

chmod +x test_dns.sh
./test_dns.sh
```

---

## 🚨 TROUBLESHOOTING FREE DNS

### Common Issues

#### 1. DNS Not Updating
```bash
# For DuckDNS - check update log
cat ~/duckdns/duck.log
cat ~/duckdns/update.log

# Manually run update
cd ~/duckdns
./duck.sh

# Check if cron is running
sudo systemctl status cron
crontab -l
```

#### 2. Domain Not Resolving
```bash
# Clear DNS cache
sudo systemctl flush-dns

# Try different DNS servers
dig @8.8.8.8 yourclinic.duckdns.org
dig @1.1.1.1 yourclinic.duckdns.org

# Check online DNS propagation
# Visit: https://dnschecker.org/
```

#### 3. SSL Certificate Issues
```bash
# Check if domain is accessible first
curl -I http://yourclinic.duckdns.org

# Try manual certificate generation
sudo certbot certonly --standalone -d yourclinic.duckdns.org

# Check certificate status
sudo certbot certificates
```

---

## 📊 MONITORING FREE DNS

### Create Monitoring Script

```bash
cat > ~/monitor_dns.sh << 'EOF'
#!/bin/bash

DOMAIN="yourclinic.duckdns.org"  # Replace with your domain
LOG_FILE="$HOME/dns_monitor.log"
EXPECTED_IP=$(curl -s -4 ifconfig.me)

check_dns() {
    CURRENT_IP=$(dig +short $DOMAIN | head -n1)
    
    if [ "$CURRENT_IP" = "$EXPECTED_IP" ]; then
        echo "$(date): ✅ DNS OK - $DOMAIN → $CURRENT_IP" >> "$LOG_FILE"
        return 0
    else
        echo "$(date): ❌ DNS ISSUE - $DOMAIN → $CURRENT_IP (expected: $EXPECTED_IP)" >> "$LOG_FILE"
        
        # Try to update (for DuckDNS)
        if [ -f ~/duckdns/duck.sh ]; then
            ~/duckdns/duck.sh
            echo "$(date): 🔄 Attempted DuckDNS update" >> "$LOG_FILE"
        fi
        
        return 1
    fi
}

check_http() {
    if curl -s -I http://$DOMAIN | grep -q "200\|302\|301"; then
        echo "$(date): ✅ HTTP OK - $DOMAIN" >> "$LOG_FILE"
        return 0
    else
        echo "$(date): ❌ HTTP FAILED - $DOMAIN" >> "$LOG_FILE"
        return 1
    fi
}

# Run checks
check_dns
check_http

# Email alerts (optional - configure sendmail first)
# if ! check_dns || ! check_http; then
#     echo "DNS/HTTP issue detected for $DOMAIN" | mail -s "NoctisPro DNS Alert" admin@youremail.com
# fi
EOF

chmod +x ~/monitor_dns.sh

# Add to crontab for hourly monitoring
(crontab -l 2>/dev/null; echo "0 * * * * ~/monitor_dns.sh") | crontab -

# View monitoring log
tail -f ~/dns_monitor.log
```

---

## ✅ FREE DNS RECOMMENDATION

### **🦆 DuckDNS is the Best Choice Because:**

1. **✅ Most Reliable** - 99%+ uptime
2. **✅ Easiest Setup** - 5 minutes total
3. **✅ SSL Compatible** - Works perfectly with Let's Encrypt
4. **✅ API Access** - Easy automation
5. **✅ No Ads** - Clean, professional
6. **✅ Multiple Subdomains** - Create several if needed
7. **✅ Long History** - Stable service since 2014

### Quick DuckDNS Setup for NoctisPro:

```bash
# 1. Go to https://www.duckdns.org/ and create account
# 2. Create subdomain: myclinic.duckdns.org
# 3. Copy your token
# 4. Run this setup:

mkdir ~/duckdns && cd ~/duckdns
echo '#!/bin/bash
echo url="https://www.duckdns.org/update?domains=myclinic&token=YOUR_TOKEN&ip=" | curl -k -o ~/duckdns/duck.log -K -' > duck.sh
chmod +x duck.sh
./duck.sh
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab -

# 5. Use myclinic.duckdns.org in your NoctisPro deployment
```

🎉 **Your NoctisPro Medical Imaging Platform will now be accessible at your free domain with full HTTPS support!**