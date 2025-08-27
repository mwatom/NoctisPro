# 🌐 NoctisPro - ngrok Reverse Proxy Setup Guide

This guide will help you set up ngrok as a reverse proxy for your NoctisPro application, making it accessible from anywhere on the internet.

## 🎯 Current Status

✅ **Django Application**: Running on http://localhost:8000  
✅ **Dependencies**: All required packages installed  
✅ **Database**: SQLite database set up and migrated  
✅ **ngrok**: Installed and ready for configuration  

## 🔧 Quick Setup (2 minutes)

### Step 1: Get ngrok Account & Token
1. **Sign up for free**: https://dashboard.ngrok.com/signup
2. **Get your authtoken**: https://dashboard.ngrok.com/get-started/your-authtoken
3. **Copy the token** (looks like: `2a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t`)

### Step 2: Configure ngrok
```bash
# Install your authtoken (replace with your actual token)
ngrok config add-authtoken YOUR_TOKEN_HERE
```

### Step 3: Start the tunnel
```bash
# Create public tunnel to your Django app
ngrok http 8000
```

### Step 4: Access your app!
After running the ngrok command, you'll see output like:
```
Session Status                online
Account                       your-email@example.com
Version                       3.26.0
Region                        United States (us)
Latency                       -
Web Interface                 http://127.0.0.1:4040
Forwarding                    https://abc123.ngrok.io -> http://localhost:8000
```

Your app is now accessible at: **https://abc123.ngrok.io**

## 🚀 Automated Setup Script

Run the setup script for guidance:
```bash
./setup_ngrok.sh
```

## 🔍 Testing Your Setup

### Local Testing
```bash
# Health check
curl http://localhost:8000/health/

# Main page
curl http://localhost:8000/
```

### Public Testing (after ngrok is running)
```bash
# Replace with your actual ngrok URL
curl https://your-ngrok-url.ngrok.io/health/
```

## 📋 Application Endpoints

| Endpoint | Description | URL |
|----------|-------------|-----|
| **Home** | Main application page | `/` |
| **Health** | Health check endpoint | `/health/` |
| **Admin** | Django admin panel | `/admin/` |

## 🎛️ ngrok Web Interface

When ngrok is running, you can access the web interface at:
- **Local**: http://localhost:4040
- **Features**: Request inspection, replay, tunnel status

## ⚙️ Configuration Details

### Django Settings
- **Debug Mode**: Enabled for development
- **Allowed Hosts**: `*` (accepts all hosts)
- **Database**: SQLite (local file)
- **Static Files**: Served by whitenoise

### ngrok Configuration
- **Protocol**: HTTP
- **Local Port**: 8000
- **Public Access**: HTTPS tunnel
- **Free Tier**: 1 tunnel, limited sessions

## 🛠️ Troubleshooting

### Django Not Starting
```bash
# Check if Django is running
ps aux | grep runserver

# View Django logs
tail -f django.log

# Restart Django
cd /workspace
source venv/bin/activate
export DJANGO_SETTINGS_MODULE=noctis_pro.settings_simple
python manage.py runserver 0.0.0.0:8000
```

### ngrok Authentication Issues
```bash
# Verify authtoken is installed
ngrok config check

# Re-add authtoken
ngrok config add-authtoken YOUR_TOKEN
```

### Connection Issues
```bash
# Test local connection
curl http://localhost:8000/health/

# Check ngrok status
curl http://localhost:4040/api/tunnels
```

## 🔐 Security Considerations

### Development Mode
- ⚠️ **Current setup is for development/demo only**
- ⚠️ **Debug mode is enabled**
- ⚠️ **No authentication required**

### Production Considerations
- 🔒 Disable debug mode
- 🔒 Add proper authentication
- 🔒 Use environment variables for secrets
- 🔒 Configure HTTPS redirects
- 🔒 Set up proper database

## 📈 Scaling Up

### For Production Use
1. **Database**: Switch to PostgreSQL/MySQL
2. **Media Files**: Use cloud storage (AWS S3, etc.)
3. **Security**: Add authentication and CSRF protection
4. **Monitoring**: Add logging and monitoring
5. **SSL**: Configure proper SSL certificates

### Alternative Tunneling Solutions
- **LocalTunnel**: `npm install -g localtunnel`
- **Serveo**: SSH-based tunneling
- **Pagekite**: Alternative tunneling service
- **CloudFlare Tunnel**: Enterprise solution

## 🎉 Success!

Once everything is working, you'll have:
- ✅ NoctisPro running locally
- ✅ Public HTTPS access via ngrok
- ✅ Real-time tunnel monitoring
- ✅ Internet-accessible medical imaging platform

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review Django and ngrok logs
3. Verify all prerequisites are met
4. Test local connectivity first

---

**Happy tunneling! 🚀**