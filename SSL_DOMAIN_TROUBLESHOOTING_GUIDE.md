# SSL Domain Troubleshooting Guide for NoctisPro

## Overview

This guide helps you diagnose and fix SSL certificate and domain naming issues in your NoctisPro deployment. Use the provided scripts and follow the step-by-step solutions below.

## Quick Diagnosis

Run the system status check to identify issues:

```bash
./check_system_status.sh
```

Run the SSL domain fix script for automated solutions:

```bash
./fix_ssl_domain_issues.sh
```

## Common SSL Domain Issues

### 1. Domain Name Issues

#### Problem: Using localhost or default hostnames
- **Symptoms**: SSL certificates fail to generate, browser warnings
- **Common values**: `localhost`, `cursor`, `noctis-server.local`
- **Solution**: Use a real domain name or proper configuration

#### Problem: Placeholder domain names
- **Symptoms**: Configuration contains `your-domain.com` or similar
- **Solution**: Replace with actual domain name

### 2. DNS Resolution Issues

#### Problem: Domain doesn't resolve to server IP
- **Symptoms**: Let's Encrypt fails, "domain not found" errors
- **Check**: `nslookup your-domain.com`
- **Solution**: Update DNS A record to point to your server's public IP

#### Problem: DNS propagation delay
- **Symptoms**: Domain resolves differently from different locations
- **Solution**: Wait 24-48 hours for DNS propagation, or use DNS propagation checker

### 3. Firewall and Network Issues

#### Problem: Ports 80/443 not accessible
- **Symptoms**: Let's Encrypt fails, connection timeouts
- **Check**: `telnet your-domain.com 80` and `telnet your-domain.com 443`
- **Solution**: Open firewall ports, check cloud provider security groups

### 4. Certificate Issues

#### Problem: Expired certificates
- **Symptoms**: Browser warnings, SSL errors
- **Check**: `openssl x509 -in /etc/letsencrypt/live/domain/fullchain.pem -noout -dates`
- **Solution**: Renew certificates with `certbot renew`

#### Problem: Certificate mismatch
- **Symptoms**: Certificate valid but for wrong domain
- **Solution**: Generate new certificate for correct domain

## Step-by-Step Solutions

### Solution 1: Public Domain with Let's Encrypt SSL

**Best for**: Production deployments with a registered domain

1. **Prerequisites**:
   - Registered domain name
   - DNS A record pointing to your server's public IP
   - Ports 80 and 443 open to the internet

2. **Get your public IP**:
   ```bash
   curl https://httpbin.org/ip
   ```

3. **Update DNS record**:
   - Log into your domain registrar
   - Create/update A record: `your-domain.com` → `YOUR_PUBLIC_IP`
   - Wait for DNS propagation (check with `nslookup your-domain.com`)

4. **Run the automated script**:
   ```bash
   export DOMAIN_NAME="your-domain.com"
   export EMAIL="your-email@example.com"
   ./fix_ssl_domain_issues.sh --auto-public
   ```

5. **Manual setup** (if script fails):
   ```bash
   # Install required packages
   sudo apt update
   sudo apt install -y nginx certbot python3-certbot-nginx
   
   # Get SSL certificate
   sudo certbot --nginx -d your-domain.com --email your-email@example.com --agree-tos
   
   # Update environment files
   echo "DOMAIN_NAME=your-domain.com" >> .env
   echo "ENABLE_SSL=true" >> .env
   ```

### Solution 2: Self-Signed Certificate (Development)

**Best for**: Development, testing, internal networks

1. **Run the automated script**:
   ```bash
   ./fix_ssl_domain_issues.sh --auto-self
   ```

2. **Manual setup**:
   ```bash
   # Create SSL directory
   sudo mkdir -p /etc/ssl/noctis
   
   # Generate private key
   sudo openssl genrsa -out /etc/ssl/noctis/noctis.key 2048
   
   # Generate certificate
   sudo openssl req -new -x509 -key /etc/ssl/noctis/noctis.key \
     -out /etc/ssl/noctis/noctis.crt -days 365 \
     -subj "/C=US/ST=State/L=City/O=NoctisPro/CN=localhost"
   
   # Set permissions
   sudo chmod 600 /etc/ssl/noctis/noctis.key
   sudo chmod 644 /etc/ssl/noctis/noctis.crt
   ```

3. **Configure Nginx**:
   ```nginx
   server {
       listen 443 ssl http2;
       server_name localhost;
       
       ssl_certificate /etc/ssl/noctis/noctis.crt;
       ssl_certificate_key /etc/ssl/noctis/noctis.key;
       
       location / {
           proxy_pass http://127.0.0.1:8000;
           proxy_set_header Host $http_host;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

### Solution 3: Ngrok for Temporary Public Access

**Best for**: Development, demos, temporary access

1. **Install ngrok**:
   ```bash
   # Using snap
   sudo snap install ngrok
   
   # Or download manually
   wget https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip
   unzip ngrok-stable-linux-amd64.zip
   sudo mv ngrok /usr/local/bin/
   ```

2. **Setup ngrok**:
   ```bash
   # Sign up at https://ngrok.com and get auth token
   ngrok authtoken YOUR_AUTH_TOKEN
   
   # Start tunnel
   ngrok http 80
   ```

3. **Use the ngrok URL** in your application configuration

### Solution 4: Internal CA for Enterprise

**Best for**: Enterprise environments, internal networks

1. **Run the interactive script**:
   ```bash
   ./fix_ssl_domain_issues.sh
   # Choose option 4: Internal network with custom CA
   ```

2. **Import CA certificate** to client browsers:
   - Download `/etc/ssl/noctis-ca/ca.crt`
   - Import to browser's trusted certificates

## Environment Configuration

### Required Environment Variables

Update your `.env` and `.env.production` files:

```bash
# Domain configuration
DOMAIN_NAME=your-domain.com
ENABLE_SSL=true

# SSL-specific settings
SECURE_SSL_REDIRECT=true
SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https

# CORS settings for HTTPS
CORS_ALLOWED_ORIGINS=https://your-domain.com
```

### Django Settings

Ensure your Django settings include:

```python
# settings.py or settings_production.py
if os.getenv('ENABLE_SSL', 'false').lower() == 'true':
    SECURE_SSL_REDIRECT = True
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
```

## Nginx Configuration Examples

### Basic HTTPS Configuration

```nginx
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Docker Compose with SSL

```yaml
version: '3.8'
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - web
      
  web:
    build: .
    environment:
      - DOMAIN_NAME=your-domain.com
      - ENABLE_SSL=true
```

## Troubleshooting Commands

### Check SSL Certificate
```bash
# Check certificate expiry
openssl x509 -in /etc/letsencrypt/live/domain/fullchain.pem -noout -dates

# Check certificate details
openssl x509 -in /etc/letsencrypt/live/domain/fullchain.pem -noout -text

# Test SSL connection
openssl s_client -connect your-domain.com:443 -servername your-domain.com
```

### Check DNS Resolution
```bash
# Check A record
nslookup your-domain.com

# Check from different DNS servers
nslookup your-domain.com 8.8.8.8
nslookup your-domain.com 1.1.1.1

# Check DNS propagation
dig your-domain.com @8.8.8.8
```

### Check Network Connectivity
```bash
# Check if ports are open
telnet your-domain.com 80
telnet your-domain.com 443

# Check from external server
curl -I http://your-domain.com
curl -I https://your-domain.com
```

### Check Nginx Configuration
```bash
# Test nginx configuration
sudo nginx -t

# Check nginx status
sudo systemctl status nginx

# Check nginx logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

### Check Certbot
```bash
# List certificates
sudo certbot certificates

# Test renewal
sudo certbot renew --dry-run

# Check certbot logs
sudo tail -f /var/log/letsencrypt/letsencrypt.log
```

## Common Error Messages and Solutions

### "Domain validation failed"
- **Cause**: Domain doesn't resolve to server or port 80 not accessible
- **Solution**: Check DNS and firewall settings

### "Certificate already exists"
- **Cause**: Trying to create duplicate certificate
- **Solution**: Use `certbot renew` or `certbot delete` first

### "Connection refused"
- **Cause**: Service not running or wrong port
- **Solution**: Check service status and port configuration

### "SSL certificate problem: self signed certificate"
- **Cause**: Using self-signed certificate with strict SSL verification
- **Solution**: Add certificate to trusted store or use `-k` flag with curl

### "Mixed content warnings"
- **Cause**: Loading HTTP resources on HTTPS page
- **Solution**: Update all URLs to use HTTPS or relative URLs

## Monitoring and Maintenance

### SSL Certificate Monitoring
```bash
# Create monitoring script
cat > /usr/local/bin/ssl-check.sh << 'EOF'
#!/bin/bash
DOMAIN="your-domain.com"
EXPIRY=$(openssl x509 -in /etc/letsencrypt/live/$DOMAIN/fullchain.pem -noout -enddate | cut -d= -f2)
EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
CURRENT_EPOCH=$(date +%s)
DAYS_LEFT=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))

if [ $DAYS_LEFT -lt 30 ]; then
    echo "WARNING: SSL certificate expires in $DAYS_LEFT days"
    # Send alert here
fi
EOF

chmod +x /usr/local/bin/ssl-check.sh

# Add to cron
echo "0 9 * * * /usr/local/bin/ssl-check.sh" | crontab -
```

### Auto-renewal Setup
```bash
# Ensure auto-renewal is configured
sudo crontab -l | grep certbot || (
    (sudo crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'") | sudo crontab -
)
```

## Security Best Practices

1. **Use strong SSL configuration**:
   - TLS 1.2+ only
   - Strong cipher suites
   - HSTS headers

2. **Regular certificate renewal**:
   - Monitor certificate expiry
   - Test renewal process
   - Have backup certificates

3. **Secure private keys**:
   - Proper file permissions (600)
   - Secure storage
   - Regular rotation

4. **Monitor SSL health**:
   - SSL Labs testing
   - Certificate transparency monitoring
   - Regular security audits

## Getting Help

If you continue to have issues:

1. **Check the logs**:
   - Nginx: `/var/log/nginx/error.log`
   - Certbot: `/var/log/letsencrypt/letsencrypt.log`
   - System: `journalctl -u nginx`

2. **Run the diagnostic script**: `./check_system_status.sh`

3. **Use online tools**:
   - SSL Labs SSL Test
   - DNS propagation checkers
   - Port connectivity testers

4. **Common support resources**:
   - Let's Encrypt community forum
   - Nginx documentation
   - NoctisPro documentation

## Script Usage Summary

```bash
# Check system status
./check_system_status.sh

# Interactive SSL setup
./fix_ssl_domain_issues.sh

# Automated public SSL setup
DOMAIN_NAME="your-domain.com" EMAIL="your@email.com" ./fix_ssl_domain_issues.sh --auto-public

# Automated self-signed SSL setup
./fix_ssl_domain_issues.sh --auto-self

# Show help
./fix_ssl_domain_issues.sh --help
```

This guide covers the most common SSL and domain issues you'll encounter. Start with the automated scripts and use the manual steps when more control is needed.