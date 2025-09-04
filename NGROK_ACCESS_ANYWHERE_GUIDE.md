# 🚀 NoctisPro - Access From Anywhere with Ngrok

## 🎯 Quick Start (Choose One Option)

### Option 1: One-Command Fix (Recommended)
```bash
# Get your free auth token from https://dashboard.ngrok.com/get-started/your-authtoken
./fix_ngrok_now.sh YOUR_AUTH_TOKEN
```

### Option 2: Complete Setup (More Features)
```bash
# Full setup with autostart and monitoring
./setup_ngrok_complete.sh YOUR_AUTH_TOKEN
```

### Option 3: Use Existing Script
```bash
# Updated existing script
./quick_ngrok_fix.sh YOUR_AUTH_TOKEN
```

---

## 🔐 Getting Your Auth Token (FREE)

1. **Sign up for ngrok**: https://dashboard.ngrok.com/signup
2. **Get your auth token**: https://dashboard.ngrok.com/get-started/your-authtoken
3. **Copy the token** (looks like: `2abc123def456ghi789jkl0mn1pqr2stu3vwx4yz5`)

---

## 🌐 Your Static URLs

- **Public Access**: `https://mallard-shining-curiously.ngrok-free.app`
- **Admin Panel**: `https://mallard-shining-curiously.ngrok-free.app/admin/`
- **Local Access**: `http://localhost:8000`

---

## ⚡ Emergency Quick Fix (No Auth Token)

If you need immediate access without setting up auth token:

```bash
# This will give you a random URL
./fix_ngrok_now.sh
# Follow prompts and choose "y" for random URL
```

---

## 🔧 Manual Setup Steps

If scripts don't work, here's the manual process:

### 1. Setup Authentication
```bash
mkdir -p ~/.config/ngrok
./ngrok config add-authtoken YOUR_TOKEN_HERE
./ngrok config check  # Verify it worked
```

### 2. Start Django Server
```bash
cd /workspace/noctis_pro_deployment
source venv/bin/activate  # if venv exists
python manage.py runserver 0.0.0.0:8000 &
```

### 3. Start Ngrok Tunnel
```bash
cd /workspace
./ngrok http --url=mallard-shining-curiously.ngrok-free.app 8000 &
```

---

## 📊 Status Checking

### Check if everything is running:
```bash
# Check Django server
curl http://localhost:8000

# Check ngrok tunnel
curl https://mallard-shining-curiously.ngrok-free.app

# Check processes
ps aux | grep -E "(manage.py|ngrok)"
```

### View logs:
```bash
# Django logs
tail -f /workspace/django_server.log

# Ngrok logs  
tail -f /workspace/ngrok_output.log
tail -f /workspace/ngrok_tunnel.log
```

---

## 🛑 Stop/Restart Services

### Stop everything:
```bash
pkill -f "manage.py runserver"
pkill -f ngrok
```

### Restart Django only:
```bash
cd /workspace/noctis_pro_deployment
source venv/bin/activate
python manage.py runserver 0.0.0.0:8000 &
```

### Restart Ngrok only:
```bash
cd /workspace
./ngrok http --url=mallard-shining-curiously.ngrok-free.app 8000 &
```

---

## 🚨 Troubleshooting

### Error: ERR_NGROK_4018 (Authentication Failed)
**Solution**: You need an auth token
```bash
# Get token from: https://dashboard.ngrok.com/get-started/your-authtoken
./ngrok config add-authtoken YOUR_TOKEN
```

### Error: Django not starting
**Solution**: Check Python environment
```bash
cd /workspace/noctis_pro_deployment
python --version
pip list | grep Django
# If missing, install: pip install -r requirements.txt
```

### Error: Port 8000 already in use
**Solution**: Kill existing processes
```bash
pkill -f "manage.py runserver"
# Or find and kill specific process:
lsof -ti:8000 | xargs kill -9
```

### Error: Ngrok tunnel not accessible
**Solution**: Wait longer or check logs
```bash
# Wait 30 seconds, then test
sleep 30
curl https://mallard-shining-curiously.ngrok-free.app

# Check ngrok logs
tail -f /workspace/ngrok_output.log
```

---

## 🎉 Success Indicators

When everything works, you should see:
- ✅ Django server responds at `http://localhost:8000`
- ✅ Ngrok tunnel responds at `https://mallard-shining-curiously.ngrok-free.app`
- ✅ Admin panel accessible at the `/admin/` path
- ✅ No authentication errors in logs

---

## 🔄 Autostart on Boot

To make it start automatically when server restarts:

```bash
# Use the generated autostart script
./noctispro-autostart.sh

# Or add to crontab
crontab -e
# Add this line:
# @reboot /workspace/noctispro-autostart.sh
```

---

## 📞 Need Help?

1. **Check logs first**: Look at the log files mentioned above
2. **Try the simplest option**: Use `./fix_ngrok_now.sh` with your auth token
3. **Verify basics**: Make sure Django runs locally first
4. **Check network**: Ensure your server has internet access

---

## 🎯 Summary

**For immediate access from anywhere:**
1. Get free ngrok auth token
2. Run: `./fix_ngrok_now.sh YOUR_TOKEN`
3. Access at: `https://mallard-shining-curiously.ngrok-free.app`

**That's it! Your app is now accessible from anywhere in the world! 🌍**