# 🚀 ONE-LINE DEPLOYMENT TO INTERNET

Deploy your complete Noctis Pro medical imaging system to the internet with **ONE COMMAND**.

## ⚡ The Magic One-Liner

```bash
curl -sSL https://raw.githubusercontent.com/mwatom/NoctisPro/main/one-line-deploy.sh | sudo bash
```

**OR** if you have the files locally:

```bash
sudo bash one-line-deploy.sh
```

## 🎯 What This Does (Automatically)

✅ **Installs all dependencies** (Docker, PostgreSQL, Redis, Nginx, Ngrok)  
✅ **Builds your medical system** with our fixed Docker configuration  
✅ **Creates secure database** with auto-generated passwords  
✅ **Sets up internet access** via Ngrok tunnel (no domain needed)  
✅ **Enables HTTPS** automatically  
✅ **Configures firewall** and security  
✅ **Creates system services** for auto-start  

## 🌐 Result

- **Complete medical imaging system** accessible from anywhere in the world
- **Secure HTTPS URL** like `https://abc123.ngrok.io`
- **All features enabled**: DICOM viewing, AI analysis, printing, user management
- **Mobile-ready**: Works on phones, tablets, computers
- **Production-ready**: Database, caching, security configured

## ⏱️ Deployment Time

- **Total time**: Under 5 minutes
- **Your input required**: Just run the command
- **Setup complexity**: Zero - everything is automated

## 📱 After Deployment

1. **Copy the URL** shown after deployment
2. **Open in browser** (works on any device)
3. **Create admin account** on first visit
4. **Start using your medical system!**

## 🛠️ Management Commands

After deployment, use these commands:

```bash
# Show your internet URL and system status
noctis-status

# Restart the system
sudo systemctl restart noctis-instant

# View application logs
docker-compose -f /opt/noctis_pro/docker-compose.instant.yml logs -f

# Stop the system
sudo systemctl stop noctis-instant noctis-ngrok
```

## 🔐 Security Features

- ✅ **HTTPS encryption** (automatic)
- ✅ **Secure database** with random passwords
- ✅ **Firewall configured** 
- ✅ **Django security** headers enabled
- ✅ **No exposed database** ports to internet

## 🏥 Medical Features Ready

- 🩺 **DICOM Image Viewer** - View CT, MRI, X-Ray images
- 🤖 **AI Analysis** - Automated image analysis
- 🖨️ **Medical Printing** - Print images on medical printers
- 👥 **User Management** - Multiple users, roles, permissions
- 📊 **Reporting** - Generate medical reports
- 📱 **Mobile Access** - Works on all devices
- 🔄 **DICOM Network** - Receive images from medical devices

## 🆘 Troubleshooting

**Problem: Command not found**
```bash
# Make sure you're on Ubuntu 24.04
sudo apt update
sudo apt install -y curl
```

**Problem: Permission denied**
```bash
# Make sure you run with sudo
sudo bash one-line-deploy.sh
```

**Problem: Can't access URL**
```bash
# Check if services are running
noctis-status
sudo systemctl status noctis-instant
```

**Problem: Docker issues**
```bash
# Restart Docker
sudo systemctl restart docker
sudo bash one-line-deploy.sh  # Run again
```

## 🌟 Why This Is Amazing

❌ **Traditional deployment**: Hours of configuration, domain setup, SSL certificates, firewall rules, database setup...

✅ **This one-liner**: Just run the command, get a working medical imaging system accessible from anywhere in 5 minutes!

## 🎉 Perfect For

- **Quick demos** to show your medical imaging system
- **Testing** new features safely  
- **Remote access** to your system from anywhere
- **Emergency deployments** when you need it working NOW
- **Development** environments that need internet access

---

**Ready? Copy and paste this:**

```bash
sudo bash one-line-deploy.sh
```

**That's it! Your medical imaging system will be live on the internet in under 5 minutes! 🚀**