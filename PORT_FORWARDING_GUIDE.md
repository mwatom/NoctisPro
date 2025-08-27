# 🌐 Port Forwarding Configuration Guide

## Overview
Your NoctisPro server is configured to accept connections on multiple ports:
- **Port 80**: Standard HTTP traffic
- **Port 2222**: Custom forwarded port for external access

## Router Configuration

### 1. Basic Port Forwarding Setup
Configure your router to forward external traffic to your internal server:

```
External Port: 2222
Internal IP: 192.168.100.15
Internal Port: 2222
Protocol: TCP
```

### 2. Alternative Configuration (Port Translation)
If you want external port 80 to forward to internal port 2222:

```
External Port: 80
Internal IP: 192.168.100.15
Internal Port: 2222
Protocol: TCP
```

## Access URLs

### Internal Network Access
- Standard: `http://192.168.100.15`
- Custom Port: `http://192.168.100.15:2222`
- Admin Panel: `http://192.168.100.15/admin` or `http://192.168.100.15:2222/admin`

### External Access (after router configuration)
- If forwarding external port 2222: `http://YOUR_PUBLIC_IP:2222`
- If forwarding external port 80 to internal 2222: `http://YOUR_PUBLIC_IP`

## Firewall Configuration
The deployment script automatically configures:
- UFW rule: `ufw allow 2222/tcp`
- Nginx listening on port 2222
- Both IPv4 and IPv6 support

## Testing Port Configuration

### 1. Test Internal Access
```bash
# Test port 80
curl -I http://192.168.100.15

# Test port 2222
curl -I http://192.168.100.15:2222
```

### 2. Check if Port is Open
```bash
# Check if Nginx is listening on port 2222
sudo netstat -tlnp | grep :2222

# Check firewall status
sudo ufw status
```

### 3. Test External Access (from outside network)
```bash
# Replace YOUR_PUBLIC_IP with your actual public IP
curl -I http://YOUR_PUBLIC_IP:2222
```

## Common Router Brands Configuration

### Linksys/Cisco
1. Access router admin panel (usually 192.168.1.1)
2. Go to "Advanced" → "Port Forwarding"
3. Add new rule with the configuration above

### Netgear
1. Access router admin panel
2. Go to "Dynamic DNS" → "Port Forwarding/Port Triggering"
3. Add port forwarding rule

### TP-Link
1. Access router admin panel
2. Go to "Advanced" → "NAT Forwarding" → "Port Forwarding"
3. Add new entry

### Generic Steps
1. Find your router's admin interface (usually 192.168.1.1 or 192.168.0.1)
2. Look for "Port Forwarding", "Virtual Server", or "NAT" settings
3. Add a new rule:
   - Service Name: NoctisPro
   - External Port: 2222
   - Internal IP: 192.168.100.15
   - Internal Port: 2222
   - Protocol: TCP

## Security Considerations

### 1. Change Default Passwords
- Change the default admin password from `admin123`
- Access: `http://192.168.100.15:2222/admin`

### 2. Enable HTTPS (Recommended for External Access)
```bash
# Run the secure access setup
sudo ./setup_secure_access.sh
```

### 3. Consider VPN Access Instead
For better security, consider using VPN instead of direct port forwarding:
```bash
# Setup VPN server
sudo ./setup_secure_access.sh
# Choose option 3 (VPN Server)
```

## Troubleshooting

### Port 2222 Not Accessible
1. Check if Nginx is running: `sudo systemctl status nginx`
2. Check firewall: `sudo ufw status`
3. Check if port is listening: `sudo netstat -tlnp | grep :2222`
4. Restart Nginx: `sudo systemctl restart nginx`

### Router Configuration Issues
1. Verify your internal IP: `ip addr show`
2. Check if router supports the port range
3. Try different external port (like 8080 → 2222)
4. Restart router after configuration

### External Access Not Working
1. Find your public IP: `curl ifconfig.me`
2. Check if ISP blocks the port
3. Test with online port checker tools
4. Verify router WAN settings

## Support Commands

```bash
# Check all listening ports
sudo netstat -tlnp

# Test local connectivity
curl -I http://localhost:2222

# Check Nginx configuration
sudo nginx -t

# View Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Restart all services
sudo systemctl restart nginx
sudo systemctl restart noctis-django
```

---
**Note**: Replace `YOUR_PUBLIC_IP` with your actual public IP address, which you can find by running `curl ifconfig.me` from your server.