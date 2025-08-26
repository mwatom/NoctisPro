# 🚀 NoctisPro Ubuntu 24.04 Deployment Instructions

## Quick Start

1. **Transfer this folder to your Ubuntu 24.04 server:**
   ```bash
   # Option 1: Using SCP
   scp -r noctis_pro_deployment user@your-server:/home/user/
   
   # Option 2: Using rsync
   rsync -av noctis_pro_deployment/ user@your-server:/home/user/noctis_pro_deployment/
   ```

2. **Connect to your server and run deployment:**
   ```bash
   ssh user@your-server
   cd noctis_pro_deployment
   sudo bash deploy-ubuntu-24.sh
   ```

3. **Choose your deployment type:**
   - **Option 1**: Development server (port 8000) - Good for testing
   - **Option 2**: Production server (Nginx) - Good for internal use
   - **Option 3**: Production with SSL - Good for internet access
   - **Option 4**: Docker deployment - Containerized deployment

## Deployment Options Explained

### 1. Development Deployment
- Uses Django development server
- Accessible on port 8000
- Good for testing and development
- **Command**: Choose option 1 in the script

### 2. Production Deployment
- Uses Gunicorn + Nginx
- Professional production setup
- Accessible on port 80
- **Command**: Choose option 2 in the script

### 3. SSL Production Deployment
- Same as production + SSL certificate
- Requires a domain name pointing to your server
- Accessible via HTTPS
- **Command**: Choose option 3 in the script

### 4. Docker Deployment
- Containerized deployment
- Includes PostgreSQL, Redis, and Nginx
- Easy to manage and scale
- **Command**: Choose option 4 in the script

## Requirements

- Ubuntu 24.04 LTS server
- Root access (sudo)
- For SSL: Domain name pointing to server
- Internet connection

## Manual Deployment (if script fails)

If the automatic script fails, you can deploy manually:

```bash
# 1. Update system
sudo apt update && sudo apt upgrade -y

# 2. Install Python and dependencies
sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential
sudo ln -sf /usr/bin/python3 /usr/bin/python

# 3. Install database
sudo apt install -y postgresql postgresql-contrib redis-server

# 4. Create virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 5. Setup database
sudo -u postgres createdb noctis_pro
sudo -u postgres createuser noctis_pro

# 6. Configure Django
python manage.py migrate
python manage.py collectstatic --noinput
python manage.py createsuperuser

# 7. Run development server
python manage.py runserver 0.0.0.0:8000
```

## Troubleshooting

### Common Issues:

1. **"python: command not found"**
   ```bash
   sudo ln -sf /usr/bin/python3 /usr/bin/python
   ```

2. **Permission denied errors**
   ```bash
   sudo chown -R www-data:www-data /opt/noctis_pro
   sudo chmod -R 755 /opt/noctis_pro
   ```

3. **Database connection errors**
   ```bash
   sudo systemctl restart postgresql
   sudo -u postgres psql -c "ALTER USER noctis_pro WITH PASSWORD 'newpassword';"
   ```

4. **Port already in use**
   ```bash
   sudo netstat -tulpn | grep :8000
   sudo kill -9 <process_id>
   ```

5. **Firewall blocking connections**
   ```bash
   sudo ufw allow 8000/tcp  # For development
   sudo ufw allow 80/tcp    # For production
   sudo ufw allow 443/tcp   # For SSL
   ```

## Post-Deployment

After successful deployment:

1. **Access your application:**
   - Development: `http://your-server-ip:8000`
   - Production: `http://your-server-ip`
   - SSL: `https://your-domain.com`

2. **Admin panel:**
   - URL: Add `/admin` to your URL
   - Use the admin credentials you created during setup

3. **Monitor logs:**
   ```bash
   # Application logs
   sudo journalctl -u noctis-pro -f
   
   # Nginx logs (for production)
   sudo tail -f /var/log/nginx/error.log
   ```

4. **Manage services:**
   ```bash
   # Restart application
   sudo systemctl restart noctis-pro
   
   # Restart web server
   sudo systemctl restart nginx
   
   # Check status
   sudo systemctl status noctis-pro
   ```

## Support

If you encounter issues:
1. Check the logs for error messages
2. Ensure all services are running
3. Verify firewall settings
4. Check database connectivity

For additional help, refer to the included documentation files.
