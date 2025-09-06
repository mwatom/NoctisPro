# 🚀 Noctis Pro PACS - Ngrok Deployment Guide

## Overview
This guide provides complete instructions for deploying Noctis Pro PACS with ngrok for secure remote access and testing.

## 📋 Prerequisites

### System Requirements
- Python 3.9+
- Django 5.2.5
- SQLite3 (default) or PostgreSQL
- Ngrok account and authtoken

### Ngrok Setup
1. **Install ngrok:**
   ```bash
   # Linux/Mac
   curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
   echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
   sudo apt update && sudo apt install ngrok
   
   # Or download directly
   wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
   tar xvzf ngrok-v3-stable-linux-amd64.tgz
   ```

2. **Configure ngrok:**
   ```bash
   ngrok config add-authtoken YOUR_AUTHTOKEN_HERE
   ```

## 🔧 Environment Configuration

### 1. Create Environment File
Create `.env` file in your project root:

```bash
# Production settings
DEBUG=False
SECRET_KEY=your-super-secret-key-here-change-this-in-production

# Ngrok configuration
NGROK_URL=https://your-ngrok-subdomain.ngrok-free.app
ALLOWED_HOSTS=*,your-ngrok-subdomain.ngrok-free.app,localhost,127.0.0.1

# Database (SQLite for simplicity, PostgreSQL for production)
DB_ENGINE=django.db.backends.sqlite3
DB_NAME=db.sqlite3

# Security (adjusted for ngrok)
SECURE_SSL_REDIRECT=False
SESSION_COOKIE_SECURE=False
CSRF_COOKIE_SECURE=False

# File uploads
FILE_UPLOAD_MAX_MEMORY_SIZE=3221225472  # 3GB
DATA_UPLOAD_MAX_MEMORY_SIZE=3221225472  # 3GB

# Media files
SERVE_MEDIA_FILES=True
```

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Database Setup
```bash
python manage.py makemigrations
python manage.py migrate
python manage.py collectstatic --noinput
python manage.py createsuperuser  # Create admin user
```

## 🌐 Ngrok Deployment Options

### Option 1: Basic HTTP Tunnel
```bash
# Start Django server
python manage.py runserver 0.0.0.0:8000

# In another terminal, start ngrok
ngrok http 8000
```

### Option 2: Custom Subdomain (Paid Plan)
```bash
# Start Django server
python manage.py runserver 0.0.0.0:8000

# Start ngrok with custom subdomain
ngrok http --subdomain=noctispro 8000
```

### Option 3: Production with Gunicorn
```bash
# Install gunicorn
pip install gunicorn

# Start with gunicorn
gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:8000 --workers 3

# Start ngrok
ngrok http 8000
```

### Option 4: HTTPS with Custom Domain (Business Plan)
```bash
# Start Django server
python manage.py runserver 0.0.0.0:8000

# Start ngrok with custom domain
ngrok http --hostname=noctispro.yourdomain.com 8000
```

## 🔒 Security Configuration

The settings.py file automatically detects ngrok usage and applies appropriate security settings:

### Automatic Ngrok Detection
```python
# Detects ngrok from environment variables or allowed hosts
IS_NGROK = bool(NGROK_URL) or any('ngrok' in host for host in ALLOWED_HOSTS)
```

### Security Adjustments for Ngrok
- ✅ **CORS**: Automatically allows ngrok origins
- ✅ **CSRF**: Adds ngrok URLs to trusted origins
- ✅ **X-Frame-Options**: Set to SAMEORIGIN for ngrok compatibility
- ✅ **SSL**: Disabled SSL redirect for ngrok tunnels
- ✅ **Cookies**: Adjusted for HTTP/HTTPS mixed environments

### Production Security (Non-Ngrok)
- 🔒 **HSTS**: HTTP Strict Transport Security
- 🔒 **SSL Redirect**: Force HTTPS
- 🔒 **Secure Cookies**: HTTPOnly and Secure flags
- 🔒 **XSS Protection**: Browser XSS filter enabled

## 📊 User Role Permissions

### Admin Users
- ✅ View all studies from all facilities
- ✅ Delete studies and attachments
- ✅ Write/edit reports
- ✅ Manage users and facilities
- ✅ Upload DICOM files to any facility

### Radiologist Users  
- ✅ View all studies from all facilities
- ✅ Delete studies and attachments
- ✅ Write/edit reports
- ❌ Cannot manage users/facilities
- ✅ Upload DICOM files to any facility

### Facility Users
- ✅ View studies from their facility only
- ✅ View/delete attachments from their facility only
- ❌ Cannot delete studies
- ❌ Cannot write reports
- ✅ Upload DICOM files to their facility
- ✅ Print studies

## 🚀 Quick Start Commands

### Development with Ngrok
```bash
# Terminal 1: Start Django
python manage.py runserver 0.0.0.0:8000

# Terminal 2: Start ngrok and get URL
ngrok http 8000

# Copy the ngrok URL and update your .env file:
echo "NGROK_URL=https://abc123.ngrok-free.app" >> .env

# Restart Django to apply new settings
```

### Production with Ngrok
```bash
# Set production environment
export DEBUG=False
export SECRET_KEY=your-production-secret-key

# Start with gunicorn
gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:8000 --workers 3 --timeout 120

# Start ngrok with auth
ngrok http 8000 --basic-auth="username:password"
```

## 🔧 Troubleshooting

### Common Issues

1. **403 Forbidden Error**
   - Check CSRF_TRUSTED_ORIGINS includes your ngrok URL
   - Verify ALLOWED_HOSTS includes your ngrok domain

2. **Static Files Not Loading**
   ```bash
   python manage.py collectstatic --noinput
   ```

3. **Large File Upload Issues**
   - Increase ngrok timeout: `ngrok http 8000 --timeout 120s`
   - Check FILE_UPLOAD_MAX_MEMORY_SIZE setting

4. **Database Locked Errors**
   - Use PostgreSQL for production instead of SQLite
   - Reduce concurrent connections

### Performance Optimization

1. **Use Gunicorn for Production:**
   ```bash
   gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:8000 --workers 3 --timeout 120 --keep-alive 5
   ```

2. **Enable Gzip Compression:**
   ```bash
   ngrok http 8000 --gzip
   ```

3. **Use PostgreSQL Database:**
   ```bash
   # Install PostgreSQL
   sudo apt-get install postgresql postgresql-contrib python3-psycopg2
   
   # Update .env
   DB_ENGINE=django.db.backends.postgresql
   DB_NAME=noctispro
   DB_USER=noctis_user
   DB_PASSWORD=secure_password
   DB_HOST=localhost
   DB_PORT=5432
   ```

## 📈 Monitoring and Logs

### Log Files Location
- **Application Logs**: `logs/noctis_pro.log`
- **Security Logs**: `logs/security.log`
- **Django Logs**: Console output in development

### Monitoring Commands
```bash
# Watch application logs
tail -f logs/noctis_pro.log

# Watch security logs
tail -f logs/security.log

# Check ngrok status
curl http://127.0.0.1:4040/api/tunnels
```

## 🎯 Best Practices

### Security
1. Always use strong SECRET_KEY in production
2. Set DEBUG=False in production
3. Use HTTPS ngrok tunnels for sensitive data
4. Implement basic auth for ngrok tunnels
5. Regularly rotate ngrok URLs for security

### Performance
1. Use gunicorn with multiple workers
2. Enable database connection pooling
3. Compress static files
4. Use PostgreSQL for production databases
5. Monitor resource usage

### Deployment
1. Use environment variables for configuration
2. Automate deployment with scripts
3. Set up proper logging and monitoring
4. Test thoroughly before production use
5. Have backup and recovery procedures

## 📞 Support

For issues or questions:
- Check the troubleshooting section above
- Review Django and ngrok documentation
- Contact your system administrator

---

**🏥 Noctis Pro PACS - Professional Medical Imaging System**
*Configured for secure ngrok deployment with role-based access control*