# 🚀 NoctisPro Complete Deployment Guide

## Complete Steps After Git Cloning

This guide provides all steps needed to deploy NoctisPro after cloning the repository.

### 📋 Prerequisites

- Ubuntu/Debian Linux system
- Internet connection
- sudo access

### 🔧 Step 1: Initial Setup

```bash
# Navigate to the cloned repository
cd /path/to/noctispro

# Make sure you're in the right directory
pwd
# Should show: /workspace (or your clone path)

# Check if required files exist
ls -la | grep -E "(quick_deploy|requirements.txt|manage.py)"
```

### 🚀 Step 2: Run the Fixed Deployment Script

**Option A: Complete Automated Setup**
```bash
# Run the fixed deployment script (recommended)
sudo chmod +x quick_deploy_fixed.sh
sudo ./quick_deploy_fixed.sh
```

**Option B: Manual Step-by-Step Setup**
```bash
# 1. Install system dependencies
sudo apt update
sudo apt install -y python3 python3-pip python3-venv jq curl

# 2. Install ngrok
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update
sudo apt install -y ngrok

# 3. Set up Python environment
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 4. Configure environment variables
export USE_SQLITE=true
export DEBUG=False
export ALLOWED_HOSTS=*
export DISABLE_REDIS=true
export USE_DUMMY_CACHE=true

# 5. Set up Django
mkdir -p media/dicom staticfiles
python manage.py collectstatic --noinput
python manage.py migrate --noinput

# 6. Create admin user
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin', 'admin@noctispro.local', 'admin123')" | python manage.py shell
```

### 🚇 Step 3: Configure Ngrok (IMPORTANT!)

```bash
# Add your ngrok auth token (replace with your actual token)
ngrok config add-authtoken YOUR_AUTH_TOKEN_HERE

# Set up static subdomain configuration
./setup_ngrok_static.sh
```

**Get your ngrok auth token:**
1. Go to https://dashboard.ngrok.com/get-started/your-authtoken
2. Sign up for a free account if you don't have one
3. Copy your auth token
4. Run: `ngrok config add-authtoken YOUR_TOKEN`

### 🎯 Step 4: Start the Application

**Option A: Static URL (Recommended)**
```bash
# Start with static ngrok subdomain
./start_noctispro_static.sh
```

**Option B: Simple Start (Dynamic URL)**
```bash
# Start with dynamic ngrok URL
./start_noctispro_simple.sh
```

**Option C: Local Only (No Ngrok)**
```bash
# Start Django server only (local access)
source venv/bin/activate
export USE_SQLITE=true
export DEBUG=False
export ALLOWED_HOSTS=*
export DISABLE_REDIS=true
export USE_DUMMY_CACHE=true
python manage.py runserver 0.0.0.0:8000
```

### 🌐 Step 5: Access Your Application

Once started, you can access NoctisPro at:

**Static URLs (Option A):**
- **Primary**: https://noctispro-live.ngrok-free.app
- **Fallback**: https://noctispro-production.ngrok-free.app
- **Admin Panel**: https://noctispro-live.ngrok-free.app/admin/
- **Local**: http://localhost:8000

**Dynamic URL (Option B):**
- Check the console output for the ngrok URL
- **Admin Panel**: [YOUR_NGROK_URL]/admin/
- **Local**: http://localhost:8000

**Local Only (Option C):**
- **Main App**: http://localhost:8000
- **Admin Panel**: http://localhost:8000/admin/

### 🔑 Default Login Credentials

```
Username: admin
Password: admin123
Email: admin@noctispro.local
```

### 🛑 Stop the Application

```bash
# Stop all services
./stop_noctispro_simple.sh

# Or press Ctrl+C in the terminal where it's running
```

### 📊 Check Status

```bash
# Check application status
./check_status.sh

# Check ngrok tunnels
curl -s http://localhost:4040/api/tunnels | jq

# Check processes
ps aux | grep -E "(python|ngrok)"
```

### 🔧 Available Management Scripts

After deployment, you'll have these scripts available:

```bash
./start_noctispro_static.sh      # Start with static ngrok URL
./start_noctispro_simple.sh      # Start with dynamic ngrok URL  
./stop_noctispro_simple.sh       # Stop all services
./check_status.sh                # Check system status
./setup_ngrok_static.sh          # Configure static ngrok domains
./quick_deploy_fixed.sh          # Complete redeployment
```

### 🚨 Troubleshooting

**Problem: Admin page redirects or doesn't load**
- ✅ **FIXED**: The admin URL redirect issue has been resolved
- The admin panel should now work at `/admin/`

**Problem: Ngrok authentication failed**
```bash
# Configure your auth token
ngrok config add-authtoken YOUR_TOKEN
```

**Problem: Django server won't start**
```bash
# Check if environment variables are set
echo $USE_SQLITE
echo $ALLOWED_HOSTS

# Restart with proper environment
source venv/bin/activate
export USE_SQLITE=true
export DEBUG=False
export ALLOWED_HOSTS=*
python manage.py runserver 0.0.0.0:8000
```

**Problem: Static files not loading**
```bash
# Recollect static files
source venv/bin/activate
export USE_SQLITE=true
python manage.py collectstatic --noinput
```

**Problem: Database errors**
```bash
# Reset database (WARNING: This will delete all data)
rm -f db.sqlite3
source venv/bin/activate
export USE_SQLITE=true
python manage.py migrate --noinput
# Recreate admin user
echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@noctispro.local', 'admin123')" | python manage.py shell
```

**Problem: Port already in use**
```bash
# Kill existing processes
pkill -f "manage.py runserver"
pkill -f "ngrok"
# Then restart
```

### 🎯 Quick One-Liner Deployment

For the fastest deployment after git clone:

```bash
# Complete deployment in one command (after setting ngrok token)
sudo ./quick_deploy_fixed.sh && ngrok config add-authtoken YOUR_TOKEN && ./start_noctispro_static.sh
```

### 📱 Application Features

Once deployed, NoctisPro includes:

- **Django Admin Interface** (`/admin/`)
- **DICOM Viewer** (`/dicom-viewer/`)
- **Worklist Management** (`/worklist/`)
- **Reports System** (`/reports/`)
- **Chat System** (`/chat/`)
- **AI Analysis** (`/ai/`)
- **Admin Panel** (`/admin-panel/`)
- **Health Checks** (`/health/`)

### 🔒 Security Notes

- Change the default admin password after first login
- Update the SECRET_KEY in production
- Configure proper ALLOWED_HOSTS for production
- Use environment files for sensitive configuration

### 📞 Support

If you encounter issues:

1. Check the console output for error messages
2. Verify ngrok auth token is configured
3. Ensure all dependencies are installed
4. Check the troubleshooting section above
5. Review Django logs for detailed error information

---

## 🎉 Success Checklist

- [ ] Repository cloned
- [ ] Dependencies installed
- [ ] Ngrok auth token configured
- [ ] Django server starts without errors
- [ ] Admin panel accessible at `/admin/`
- [ ] Can login with admin/admin123
- [ ] Ngrok tunnel established
- [ ] Application accessible via public URL

**Congratulations! NoctisPro is now fully deployed and ready to use! 🚀**