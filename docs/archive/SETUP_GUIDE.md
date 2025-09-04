# NoctisPro Setup Guide

## ✅ System Setup Complete!

Your NoctisPro system has been successfully configured with the following components:

### 🔧 Installed Components

1. **Python Virtual Environment** - Isolated Python environment at `/workspace/venv`
2. **Django Application** - All dependencies installed and configured
3. **PostgreSQL Database** - Running on port 5432
4. **Redis Cache** - Running on port 6379
5. **Ngrok** - Installed for external access (requires auth token)
6. **Auto-startup Scripts** - Configured to start on boot

### 🚀 Quick Start

#### Start the Service Manually:
```bash
./manage_noctispro.sh start
```

#### Check Service Status:
```bash
./manage_noctispro.sh status
```

#### Stop the Service:
```bash
./manage_noctispro.sh stop
```

#### Restart the Service:
```bash
./manage_noctispro.sh restart
```

### 🌐 Ngrok Configuration (Optional)

To enable external access via ngrok:

1. **Sign up for a free ngrok account**: https://dashboard.ngrok.com/signup
2. **Get your auth token**: https://dashboard.ngrok.com/get-started/your-authtoken
3. **Configure ngrok**:
   ```bash
   ngrok authtoken YOUR_AUTH_TOKEN_HERE
   ```
4. **Restart the service**:
   ```bash
   ./manage_noctispro.sh restart
   ```

### 🔄 Auto-Startup Configuration

The system is already configured to start automatically on boot via:
- **Cron job** - Runs at system startup
- **Init script** - `/etc/init.d/noctispro` (if supported)

To manage auto-startup:
```bash
# Remove auto-startup
./manage_noctispro.sh remove-autostart

# Reinstall auto-startup
./manage_noctispro.sh install-autostart
```

### 📊 Service Management

#### Available Scripts:

1. **`start_production.sh`** - Basic Django startup
2. **`start_with_ngrok.sh`** - Django + ngrok (requires auth)
3. **`manage_noctispro.sh`** - Full service management
4. **`noctispro_startup.sh`** - Background startup script

#### Service Commands:
```bash
# Full management
./manage_noctispro.sh {start|stop|restart|status|logs}

# Auto-startup management
./manage_noctispro.sh {install-autostart|remove-autostart}
```

### 🌍 Access Points

- **Local Access**: http://localhost:8000
- **External Access**: Via ngrok (after authentication)
- **Admin Interface**: http://localhost:8000/admin/
- **API Endpoints**: http://localhost:8000/api/

### 📝 Log Files

- **Startup Logs**: `/workspace/noctispro_startup.log`
- **Ngrok Logs**: `/workspace/ngrok.log`
- **Django Logs**: Console output (use `./manage_noctispro.sh logs`)

### 🔧 Configuration Files

- **Environment**: `.env.production`
- **Database**: PostgreSQL (noctis_pro database)
- **Cache**: Redis (localhost:6379)
- **Static Files**: `/workspace/staticfiles`
- **Media Files**: `/workspace/media`

### 📋 Troubleshooting

#### Django Not Starting:
```bash
# Check logs
./manage_noctispro.sh logs

# Run migrations manually
source venv/bin/activate
python manage.py migrate
```

#### Database Issues:
```bash
# Check PostgreSQL status
sudo service postgresql status

# Restart PostgreSQL
sudo service postgresql restart
```

#### Redis Issues:
```bash
# Check Redis status
sudo service redis-server status

# Restart Redis
sudo service redis-server restart
```

#### Ngrok Issues:
- Ensure you have a valid auth token configured
- Check ngrok.log for detailed error messages
- Free ngrok accounts have limitations

### 🛡️ Security Notes

1. **Change default secret key** in `.env.production`
2. **Update database password** for production use
3. **Configure firewall** rules as needed
4. **Use HTTPS** in production (ngrok provides this automatically)

### 🎯 Next Steps

1. **Configure ngrok** with your auth token for external access
2. **Set up your Django superuser**:
   ```bash
   source venv/bin/activate
   python manage.py createsuperuser
   ```
3. **Customize settings** in `.env.production` as needed
4. **Test the application** at http://localhost:8000

## 🎉 Your NoctisPro system is ready to use!

The service will automatically start on system boot and can be managed using the provided scripts.