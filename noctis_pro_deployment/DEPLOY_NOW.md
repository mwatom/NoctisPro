# 🚀 DEPLOY NOCTISPRO NOW - Simple Steps

## ⚡ QUICK DEPLOYMENT (15 minutes total)

### STEP 1: Boot into Ubuntu (2 minutes)
```bash
# Make sure you're running Ubuntu (not Kali)
# If you're in Kali, restart and select Ubuntu from GRUB menu
```

### STEP 2: Open Terminal and Navigate (1 minute)
```bash
# Open terminal (Ctrl + Alt + T)
cd /path/to/your/noctispro/folder
# or wherever you have the NoctisPro files

# Verify you're in the right place
ls -la
# You should see: deploy_noctis_production.sh, manage.py, etc.
```

### STEP 3: Make Scripts Executable (30 seconds)
```bash
chmod +x deploy_noctis_production.sh
chmod +x global_access_setup.sh
```

### STEP 4: Choose Your Deployment Method

## 🌐 METHOD A: GLOBAL ACCESS (Recommended)
**Makes your system accessible from anywhere in the world**

```bash
# Run the global access setup
./global_access_setup.sh
```

**Follow these prompts:**
1. Choose option **1** (DuckDNS - Free)
2. Go to https://www.duckdns.org
3. Sign in with Google/GitHub
4. Create a subdomain (e.g., "myclinic" → myclinic.duckdns.org)
5. Copy your token
6. Enter subdomain and token when prompted
7. Wait 10-15 minutes for complete setup

**Result:** Your system will be accessible at `https://yourname.duckdns.org`

---

## 🏠 METHOD B: LOCAL NETWORK ONLY
**Only accessible from your local network**

```bash
# Run the standard deployment
sudo ./deploy_noctis_production.sh
```

**Result:** Your system will be accessible at `http://your-local-ip:8000`

---

## 🔧 STEP 5: Verify Deployment

### Check if services are running:
```bash
# Check main service
sudo systemctl status noctis_pro

# Check database
sudo systemctl status postgresql

# Check web server (if global deployment)
sudo systemctl status nginx
```

### Test access:
```bash
# For global deployment
curl -I https://yourname.duckdns.org

# For local deployment
curl -I http://localhost:8000
```

---

## 🎉 STEP 6: Access Your System

### Global Deployment:
- Open browser
- Go to: `https://yourname.duckdns.org`
- Create your admin account
- Start using NoctisPro!

### Local Deployment:
- Open browser
- Go to: `http://your-computer-ip:8000`
- Create your admin account
- Use within your network only

---

## 🆘 IF SOMETHING GOES WRONG

### Problem: "Permission denied"
```bash
# Make sure you're in the right directory
pwd
ls -la *.sh

# Make scripts executable
chmod +x *.sh
```

### Problem: "Script not found"
```bash
# Find your NoctisPro folder
find ~ -name "deploy_noctis_production.sh" 2>/dev/null
cd /path/to/found/folder
```

### Problem: "Port 8000 already in use"
```bash
# Kill any existing processes
sudo pkill -f "python.*manage.py"
sudo pkill -f "gunicorn"

# Try deployment again
```

### Problem: "Database connection failed"
```bash
# Restart PostgreSQL
sudo systemctl restart postgresql

# Try deployment again
```

---

## 📞 QUICK HELP COMMANDS

```bash
# Check what's running
sudo systemctl status noctis_pro nginx postgresql

# View logs if something's wrong
sudo journalctl -u noctis_pro -f

# Restart everything
sudo systemctl restart noctis_pro nginx postgresql

# Check if ports are open
sudo netstat -tlnp | grep -E ':(80|443|8000|5432)'
```

---

## 🎯 WHAT YOU GET AFTER DEPLOYMENT

### ✅ NoctisPro Features:
- 🩺 **DICOM Image Viewer** - View medical images
- 🖨️ **Medical Image Printing** - Print on glossy paper
- 👥 **User Management** - Multiple users and roles
- 📊 **Reporting System** - Generate medical reports
- 🤖 **AI Analysis** - Automated image analysis
- 📱 **Mobile Access** - Works on phones/tablets
- 🔒 **Secure Access** - HTTPS and authentication

### ✅ Access URLs:
- **Global**: `https://yourname.duckdns.org`
- **Local**: `http://your-ip:8000`

### ✅ Default Login:
- Create admin account on first visit
- Access admin panel at `/admin`

---

## 🚀 MOST COMMON DEPLOYMENT (RECOMMENDED)

**For 99% of users, do this:**

```bash
# 1. Make sure you're in Ubuntu
# 2. Open terminal
# 3. Navigate to NoctisPro folder
cd /path/to/noctispro

# 4. Run global deployment
./global_access_setup.sh

# 5. Choose option 1 (DuckDNS)
# 6. Follow prompts
# 7. Wait 15 minutes
# 8. Access at https://yourname.duckdns.org
```

**That's it! Your medical imaging system is now live and accessible from anywhere in the world!**

---

## 📋 PRE-DEPLOYMENT CHECKLIST

Before you start, make sure:
- [ ] You're booted into Ubuntu (not Kali)
- [ ] You have internet connection
- [ ] You have the NoctisPro files
- [ ] You can run `sudo` commands
- [ ] You have at least 10GB free disk space

---

## ⏱️ TIME ESTIMATES

- **Global Deployment**: 15 minutes
- **Local Deployment**: 10 minutes
- **First-time setup**: Add 5 minutes
- **Testing and verification**: 5 minutes

**Total**: 20-30 minutes for a complete production system!

---

**Ready? Let's deploy! Start with Step 1 above. 🚀**