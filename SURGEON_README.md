# 🚨 EMERGENCY SURGEON DEPLOYMENT - NOCTIS PACS 🚨

## FOR IMMEDIATE HOSPITAL USE

### 🏥 FASTEST DEPLOYMENT (30 seconds)

After cloning the repository:

```bash
cd NoctisPro
./HOSPITAL_DEPLOY_NOW.sh
```

**DONE!** Access at: **http://noctispro2.duckdns.org:8000**

---

### 🚀 ALTERNATIVE METHODS

#### Method 1: One-Line Deployment
```bash
cd NoctisPro && ./SURGEON_DEPLOY_ONELINE.sh
```

#### Method 2: Emergency Multi-Method
```bash
cd NoctisPro && ./EMERGENCY_HOSPITAL_DEPLOY.sh
```

#### Method 3: Manual (if scripts fail)
```bash
cd NoctisPro
python3 -m venv venv
source venv/bin/activate
pip install django pillow pydicom
python manage.py migrate
echo "from django.contrib.auth import get_user_model; User=get_user_model(); User.objects.create_superuser('admin','admin@hospital.com','admin123')" | python manage.py shell
python manage.py runserver 0.0.0.0:8000
```

---

## 🔑 SURGEON ACCESS

- **URL**: http://noctispro2.duckdns.org:8000
- **Admin Panel**: http://noctispro2.duckdns.org:8000/admin/
- **Username**: `admin`
- **Password**: `admin123`
- **Email**: `admin@hospital.com`

---

## 🏥 HOSPITAL FEATURES

✅ **DICOM Viewer** - View medical images  
✅ **Worklist Management** - Patient scheduling  
✅ **Admin Panel** - Full system control  
✅ **Internet Access** - Available worldwide  
✅ **Mobile Ready** - Works on tablets/phones  

---

## 🚨 TROUBLESHOOTING

### If deployment fails:
1. Ensure port 8000 is available: `sudo lsof -ti:8000 | xargs -r sudo kill -9`
2. Check Python version: `python3 --version` (needs 3.8+)
3. Try manual method above
4. Contact support if still failing

### If can't access from internet:
1. Check if server is running: `curl http://localhost:8000`
2. Verify DuckDNS: `nslookup noctispro2.duckdns.org`
3. Check firewall: `sudo ufw allow 8000`

---

## 📞 EMERGENCY SUPPORT

If surgeons cannot access the system:

1. **Check server status**: `ps aux | grep python`
2. **Restart if needed**: Kill process and re-run deployment script
3. **Alternative access**: Use local IP if DuckDNS fails

**The system MUST be accessible for surgical procedures!**

---

*Deployment scripts created for emergency hospital use*