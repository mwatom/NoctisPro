# Noctis Pro PACS - Deployment Instructions

## 🚀 One-Line Deployment

### Simple Local Deployment
```bash
bash /workspace/deploy.sh
```

### Deployment with Public Access (via tunnel)
```bash
bash /workspace/deploy-with-tunnel.sh
```

## 🌐 Public Access Options

### Option 1: ngrok (Recommended)
1. Sign up for free at: https://ngrok.com/
2. Get your authtoken from: https://dashboard.ngrok.com/get-started/your-authtoken
3. Run:
```bash
ngrok config add-authtoken YOUR_AUTHTOKEN_HERE
ngrok http 8000
```

### Option 2: localtunnel
```bash
npm install -g localtunnel
lt --port 8000
```

### Option 3: cloudflared (Cloudflare Tunnel)
```bash
# Install cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Create tunnel
cloudflared tunnel --url http://localhost:8000
```

## 📋 System Access URLs

### Local Access
- Main System: http://localhost:8000/
- Admin Panel: http://localhost:8000/admin-panel/
- Worklist: http://localhost:8000/worklist/

### Service Status
- Django/Daphne: Port 8000
- DICOM Receiver: Port 11112
- Redis: Port 6379

## 🔧 Admin User Creation
```bash
ADMIN_USER=admin ADMIN_EMAIL=admin@example.com ADMIN_PASS=admin123 /workspace/deploy.sh
```

## 🛠 Troubleshooting

### Check Services
```bash
ps aux | grep -E "(daphne|celery|dicom_receiver)"
```

### View Logs
```bash
tail -f /workspace/noctis_pro.log
tail -f /workspace/daphne.log
tail -f /workspace/celery.log
tail -f /workspace/dicom_receiver.log
```

### Restart Services
```bash
pkill -f "daphne.*noctis_pro.asgi"
pkill -f "celery.*worker"
pkill -f "dicom_receiver.py"
bash /workspace/deploy.sh
```