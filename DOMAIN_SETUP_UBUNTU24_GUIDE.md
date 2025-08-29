# 🌐 Domain Setup Guide for Ubuntu 24.04 - NoctisPro

> **Complete Domain Configuration**: Step-by-step guide for setting up domains and DNS for your NoctisPro deployment

## 🎯 DOMAIN OPTIONS OVERVIEW

You have **3 main options** for accessing your NoctisPro system over the internet:

1. **Purchased Domain** (Recommended for production)
2. **Free Dynamic DNS** (Good for testing/personal use)
3. **Cloud Provider Domain** (For cloud deployments)

---

## 🔍 OPTION 1: PURCHASED DOMAIN SETUP

### 1.1 Prerequisites
- Domain purchased from registrar (GoDaddy, Namecheap, Cloudflare, etc.)
- Access to domain's DNS management panel
- Ubuntu server with public IP address

### 1.2 Get Your Server's Public IP
```bash
# Method 1: Simple IP check
curl -4 ifconfig.me

# Method 2: Alternative services
curl -4 icanhazip.com
curl -4 ipinfo.io/ip

# Method 3: Check network interface (if server has public IP directly)
ip addr show | grep 'inet.*global'

# Note down this IP - you'll need it for DNS configuration
```

### 1.3 Configure DNS Records

#### For GoDaddy:
1. Login to **GoDaddy Domain Manager**
2. Select your domain → **Manage DNS**
3. **Add/Edit A Record**:
   - **Type**: A
   - **Name**: `@` (for root domain) or `medical` (for subdomain)
   - **Value**: `YOUR_SERVER_PUBLIC_IP`
   - **TTL**: `300` (5 minutes)
4. **Save Changes**

#### For Namecheap:
1. Login to **Namecheap Account**
2. **Domain List** → **Manage** next to your domain
3. **Advanced DNS** tab
4. **Add New Record**:
   - **Type**: A Record
   - **Host**: `@` or `medical`
   - **Value**: `YOUR_SERVER_PUBLIC_IP`
   - **TTL**: `5 min`

#### For Cloudflare:
1. Login to **Cloudflare Dashboard**
2. Select your domain
3. **DNS** tab → **Add Record**:
   - **Type**: A
   - **Name**: `@` or `medical`
   - **IPv4 address**: `YOUR_SERVER_PUBLIC_IP`
   - **Proxy status**: 🔴 DNS only (for initial setup)
   - **TTL**: Auto

### 1.4 Verify DNS Propagation
```bash
# Check DNS propagation (replace with your domain)
nslookup yourdomain.com
dig yourdomain.com

# Check from multiple locations
curl "https://dns.google/resolve?name=yourdomain.com&type=A"

# Wait for propagation (can take 5 minutes to 48 hours)
# Typically takes 5-30 minutes for most providers
```

---

## 🆓 OPTION 2: FREE DYNAMIC DNS SETUP

### 2.1 DuckDNS Setup (Recommended Free Option)

#### Step 1: Create DuckDNS Account
1. Visit: **https://www.duckdns.org/**
2. **Sign in** with Google, GitHub, or Reddit account
3. **Create a subdomain**: `yourclinic.duckdns.org`
4. **Copy your token** (you'll need this)

#### Step 2: Install DuckDNS on Ubuntu
```bash
# Create DuckDNS directory
mkdir ~/duckdns
cd ~/duckdns

# Create update script (replace SUBDOMAIN and TOKEN)
cat > duck.sh << 'EOF'
#!/bin/bash
# DuckDNS Update Script
# Replace YOURCLINIC with your subdomain name
# Replace YOUR_TOKEN with your actual token from DuckDNS

SUBDOMAIN="YOURCLINIC"
TOKEN="YOUR_TOKEN"

echo url="https://www.duckdns.org/update?domains=${SUBDOMAIN}&token=${TOKEN}&ip=" | curl -k -o ~/duckdns/duck.log -K -

# Log the update
echo "$(date): DuckDNS update completed" >> ~/duckdns/update.log
EOF

# Make script executable
chmod 700 duck.sh

# Test the script
./duck.sh

# Check if it worked
cat duck.log
```

#### Step 3: Automate Updates
```bash
# Add to crontab for automatic updates every 5 minutes
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1") | crontab -

# Verify crontab entry
crontab -l

# Check DuckDNS status
cat ~/duckdns/duck.log
```

### 2.2 No-IP Setup (Alternative Free Option)

#### Step 1: Create No-IP Account
1. Visit: **https://www.noip.com/**
2. **Create free account**
3. **Add hostname**: `yourclinic.ddns.net`
4. **Point to your server IP**

#### Step 2: Install No-IP Client
```bash
# Download No-IP client
cd /usr/local/src
sudo wget http://www.no-ip.com/client/linux/noip-duc-linux.tar.gz

# Extract and compile
sudo tar xzf noip-duc-linux.tar.gz
cd noip-2.1.9-1
sudo make
sudo make install

# Configure No-IP client (enter your No-IP credentials)
sudo /usr/local/bin/noip2 -C

# Start the service
sudo /usr/local/bin/noip2
```

#### Step 3: Create Systemd Service
```bash
# Create systemd service file
sudo nano /etc/systemd/system/noip.service

# Add this content:
[Unit]
Description=No-IP Dynamic DNS Update Client
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/noip2
Restart=always

[Install]
WantedBy=multi-user.target

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable noip
sudo systemctl start noip
```

---

## ☁️ OPTION 3: CLOUD PROVIDER DOMAINS

### 3.1 AWS Route 53
```bash
# If using AWS EC2, you can use Route 53
# 1. Purchase domain through Route 53
# 2. Create hosted zone
# 3. Add A record pointing to EC2 public IP
```

### 3.2 Google Cloud DNS
```bash
# If using Google Cloud Compute Engine
# 1. Use Cloud DNS service
# 2. Create DNS zone
# 3. Add A record pointing to instance external IP
```

### 3.3 DigitalOcean Domains
```bash
# If using DigitalOcean Droplets
# 1. Add domain in DigitalOcean control panel
# 2. Create A record pointing to droplet IP
# 3. Update nameservers if needed
```

---

## 🔧 UBUNTU 24.04 NETWORK CONFIGURATION

### Check Network Configuration
```bash
# Check current network configuration
ip addr show
ip route show

# Check if server has public IP directly assigned
curl -4 ifconfig.me
hostname -I

# Check firewall status
sudo ufw status verbose

# Check if ports are accessible from outside
sudo netstat -tlnp | grep -E ':80|:443'
```

### Configure Static IP (if needed)
```bash
# Edit netplan configuration
sudo nano /etc/netplan/50-cloud-init.yaml

# Example static IP configuration:
network:
  version: 2
  ethernets:
    enp0s3:  # Replace with your interface name
      dhcp4: false
      addresses:
        - 192.168.1.100/24  # Your static IP
      gateway4: 192.168.1.1   # Your gateway
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

# Apply configuration
sudo netplan apply
```

---

## 🔍 DOMAIN VERIFICATION AND TESTING

### Test Domain Resolution
```bash
# Test DNS resolution
nslookup your-domain.com
dig your-domain.com

# Test HTTP connectivity
curl -I http://your-domain.com

# Test if domain points to your server
ping your-domain.com

# Advanced DNS testing
dig +trace your-domain.com
```

### Check from Multiple Locations
```bash
# Use online tools to check DNS propagation:
# - https://dnschecker.org/
# - https://whatsmydns.net/
# - https://dnsmap.io/

# Command line testing from different DNS servers
dig @8.8.8.8 your-domain.com
dig @1.1.1.1 your-domain.com
dig @208.67.222.222 your-domain.com
```

---

## 🚨 TROUBLESHOOTING DOMAIN ISSUES

### Common Problems and Solutions

#### 1. Domain Not Resolving
```bash
# Check if DNS records are correct
dig your-domain.com

# Check if nameservers are correct
dig NS your-domain.com

# Flush local DNS cache
sudo systemctl flush-dns
```

#### 2. Wrong IP Returned
```bash
# Verify DNS record at registrar
# Check TTL settings (lower TTL = faster updates)
# Wait for propagation (up to 48 hours)

# Check current IP vs expected IP
dig your-domain.com | grep -A1 "ANSWER SECTION"
curl -4 ifconfig.me
```

#### 3. DuckDNS Not Updating
```bash
# Check DuckDNS log
cat ~/duckdns/duck.log

# Test update manually
cd ~/duckdns
./duck.sh
cat duck.log

# Check crontab
crontab -l
sudo systemctl status cron
```

#### 4. Firewall Blocking Access
```bash
# Check UFW status
sudo ufw status verbose

# Allow HTTP/HTTPS if blocked
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check if ports are listening
sudo netstat -tlnp | grep -E ':80|:443'
```

---

## 🔒 SECURITY CONSIDERATIONS

### DNS Security
```bash
# Use secure DNS providers
# Configure DNS over HTTPS (DoH) if needed
sudo nano /etc/systemd/resolved.conf

# Add these lines:
DNS=1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google
DNSOverTLS=yes
DNSSEC=yes

# Restart service
sudo systemctl restart systemd-resolved
```

### Domain Protection
```bash
# Enable domain lock at registrar
# Set up domain monitoring alerts
# Use strong passwords for domain account
# Enable 2FA on domain registrar account
```

---

## 📊 MONITORING DOMAIN STATUS

### Create Domain Monitor Script
```bash
# Create monitoring script
cat > ~/monitor_domain.sh << 'EOF'
#!/bin/bash
DOMAIN="your-domain.com"
EXPECTED_IP="YOUR_SERVER_IP"

CURRENT_IP=$(dig +short $DOMAIN)

if [ "$CURRENT_IP" = "$EXPECTED_IP" ]; then
    echo "$(date): Domain $DOMAIN is correctly pointing to $EXPECTED_IP"
else
    echo "$(date): WARNING - Domain $DOMAIN is pointing to $CURRENT_IP instead of $EXPECTED_IP"
    # Add email notification here if needed
fi
EOF

chmod +x ~/monitor_domain.sh

# Add to crontab for hourly checks
(crontab -l 2>/dev/null; echo "0 * * * * ~/monitor_domain.sh >> ~/domain_monitor.log") | crontab -
```

---

## ✅ DOMAIN SETUP VERIFICATION

### Final Checklist
- ✅ Domain resolves to correct IP address
- ✅ DNS propagation is complete
- ✅ Domain accessible via HTTP (before SSL setup)
- ✅ Firewall allows HTTP/HTTPS traffic
- ✅ Dynamic DNS updates working (if applicable)
- ✅ Domain monitoring in place

### Success Commands
```bash
# These should all work after successful setup:
ping your-domain.com
curl -I http://your-domain.com
nslookup your-domain.com
```

---

🎉 **Domain Setup Complete!** Your domain is now ready for NoctisPro deployment with HTTPS certificates.