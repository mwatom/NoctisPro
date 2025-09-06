# 🏥 NoctisPro V2 - Production PACS System

A bulletproof, zero-error DICOM PACS system with integrated dashboard and universal DICOM viewer.

## ✨ Features

- **Zero 500 Errors**: Bulletproof error handling and fallbacks
- **Universal DICOM Viewer**: Single integrated viewer for all studies
- **Professional Dashboard**: Modern worklist interface with real-time updates
- **Static Ngrok URL**: Persistent public access via `colt-charmed-lark.ngrok-free.app`
- **Production Ready**: Optimized for Ubuntu Server 24.04
- **Auto-Startup**: Systemd services for automatic startup on boot

## 🚀 Quick Deployment

### One-Command Deployment
```bash
cd /workspace/noctis_pro_v2
./deploy_v2.sh
```

### Manual Setup
1. **Install Dependencies**
   ```bash
   sudo apt update
   sudo apt install python3 python3-pip python3-venv sqlite3 curl
   ```

2. **Setup Environment**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

3. **Configure Django**
   ```bash
   python manage.py migrate
   python manage.py collectstatic --noinput
   python manage.py createsuperuser
   ```

4. **Start Services**
   ```bash
   sudo systemctl enable noctispro-v2.service
   sudo systemctl start noctispro-v2.service
   ```

## 🌐 Access URLs

- **Local**: http://localhost:8000
- **Public**: https://colt-charmed-lark.ngrok-free.app
- **Admin**: https://colt-charmed-lark.ngrok-free.app/admin/

## 👤 Default Credentials

- **Username**: admin
- **Password**: admin123

## 🛠️ Management Commands

After deployment, use these commands to manage the system:

```bash
# Start services
./start_v2.sh

# Stop services
./stop_v2.sh

# Check status
./status_v2.sh

# View logs
./logs_v2.sh
```

## 📋 System Requirements

- **OS**: Ubuntu Server 24.04 LTS
- **Python**: 3.10+
- **Memory**: 2GB+ RAM
- **Storage**: 10GB+ free space
- **Network**: Internet connection for ngrok

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Ngrok Tunnel  │────│  Django Server   │────│  SQLite DB      │
│  (Public URL)   │    │  (Port 8000)     │    │  (Local File)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
            ┌───────────────┐   ┌───────────────┐
            │   Worklist    │   │ DICOM Viewer  │
            │   Dashboard   │   │  (Universal)  │
            └───────────────┘   └───────────────┘
```

## 📁 Directory Structure

```
noctis_pro_v2/
├── apps/                    # Django applications
│   ├── accounts/           # User management
│   ├── worklist/           # Study worklist
│   ├── dicom_viewer/       # Universal DICOM viewer
│   └── ...
├── noctis_pro/             # Django project settings
├── templates/              # HTML templates
├── static/                 # Static files (CSS, JS, images)
├── media/                  # Uploaded files
├── logs/                   # Application logs
├── requirements.txt        # Python dependencies
├── deploy_v2.sh           # Deployment script
└── manage.py              # Django management
```

## 🔧 Configuration

### Environment Variables
Copy `.env.example` to `.env` and configure:

```bash
SECRET_KEY=your-secret-key
DEBUG=False
ALLOWED_HOSTS=localhost,colt-charmed-lark.ngrok-free.app
NGROK_AUTHTOKEN=your-ngrok-token
```

### Ngrok Setup
1. Sign up at https://ngrok.com
2. Get your authtoken from the dashboard
3. Configure ngrok:
   ```bash
   /workspace/ngrok config add-authtoken YOUR_TOKEN
   ```

## 🔍 Troubleshooting

### Common Issues

1. **Service won't start**
   ```bash
   sudo systemctl status noctispro-v2.service
   sudo journalctl -u noctispro-v2.service -f
   ```

2. **Database issues**
   ```bash
   cd /workspace/noctis_pro_v2
   source venv/bin/activate
   python manage.py migrate
   ```

3. **Static files not loading**
   ```bash
   python manage.py collectstatic --noinput
   ```

4. **Ngrok tunnel issues**
   ```bash
   /workspace/ngrok config check
   sudo systemctl restart noctispro-v2-ngrok.service
   ```

### Log Files

- **Django**: `sudo journalctl -u noctispro-v2.service`
- **Ngrok**: `sudo journalctl -u noctispro-v2-ngrok.service`
- **Application**: `/workspace/noctis_pro_v2/logs/noctis_pro.log`

## 🔒 Security Features

- CSRF protection enabled
- Secure session handling
- SQL injection protection
- XSS protection
- HTTPS via ngrok tunnel
- User authentication required

## 🚀 Performance Optimizations

- SQLite with WAL mode
- Static file compression
- Optimized database queries
- Efficient DICOM handling
- Memory-based caching

## 📊 Monitoring

The system includes built-in health checks:

- **Health endpoint**: `/health/`
- **Simple check**: `/health/simple/`
- **Service status**: Use `./status_v2.sh`

## 🆘 Support

For issues or questions:

1. Check the logs: `./logs_v2.sh`
2. Verify status: `./status_v2.sh`
3. Restart services: `./stop_v2.sh && ./start_v2.sh`

## 📄 License

NoctisPro V2 - Production PACS System
Built for reliable medical imaging workflow management.