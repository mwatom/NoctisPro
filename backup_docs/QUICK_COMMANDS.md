# 🚀 NOCTIS PRO PACS - Quick Command Reference

## 🎯 Essential Commands

### Start System
```bash
./start_noctispro_manual.sh
```

### Check Status
```bash
./check_noctispro_status.sh
```

### Setup Ngrok (First Time)
```bash
# Get token from: https://dashboard.ngrok.com/get-started/your-authtoken
ngrok authtoken YOUR_TOKEN_HERE
```

### Start Public Access
```bash
ngrok http 8000
```

### Create Admin User
```bash
source venv/bin/activate
python manage.py createsuperuser
```

## 🔧 Troubleshooting

### Restart Everything
```bash
pkill -f gunicorn
pkill -f ngrok
./start_noctispro_manual.sh
ngrok http 8000
```

### View Logs
```bash
tail -f /workspace/gunicorn_error.log
tail -f /workspace/gunicorn_access.log
```

### Get Ngrok URL
```bash
curl http://localhost:4040/api/tunnels | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['tunnels'][0]['public_url']) if data.get('tunnels') else print('No active tunnels')"
```

## 🌐 Access URLs

- **Local Django**: http://localhost:8000
- **Local Nginx**: http://localhost:80  
- **Ngrok Dashboard**: http://localhost:4040
- **Admin Panel**: http://localhost:8000/admin/
- **Public URL**: Provided by ngrok

## 📊 System Health

### Quick Health Check
```bash
curl -I http://localhost:8000
```

### Process Check
```bash
ps aux | grep -E "(gunicorn|nginx|ngrok)"
```

### Port Check
```bash
ss -tlnp | grep -E ":80|:8000|:4040"
```

## 🔄 Common Workflows

### Daily Startup
1. `./start_noctispro_manual.sh`
2. `ngrok http 8000`
3. Share ngrok URL with users

### System Check
1. `./check_noctispro_status.sh`
2. Verify all services green ✅

### Emergency Restart
1. `pkill -f gunicorn`
2. `./start_noctispro_manual.sh`
3. `ngrok http 8000`

---
**💡 Tip**: Bookmark this page for quick reference!