# 🏥 NOCTIS Pro - Simple Setup Checklist

**Print this page and check off each step as you complete it!**

---

## ✅ Before You Start

- [ ] I have Ubuntu Desktop (18.04 or newer)
- [ ] I have internet connection
- [ ] I have at least 4GB RAM and 20GB free disk space
- [ ] I can use sudo/admin commands
- [ ] I have the NOCTIS Pro software folder

---

## ✅ Step 1: Install Docker

- [ ] Open terminal (`Ctrl + Alt + T`)
- [ ] Run: `curl -fsSL https://get.docker.com -o get-docker.sh`
- [ ] Run: `sudo sh get-docker.sh`
- [ ] Run: `sudo usermod -aG docker $USER`
- [ ] Run: `sudo apt install docker-compose-plugin`
- [ ] **RESTART COMPUTER** (very important!)
- [ ] Test Docker: `docker --version`

---

## ✅ Step 2: Get Software Ready

- [ ] Open terminal (`Ctrl + Alt + T`)
- [ ] Go to NOCTIS Pro folder: `cd /path/to/noctis-pro`
- [ ] Check files exist: `ls -la` (should see docker-compose.yml, manage.py, etc.)

---

## ✅ Step 3: Start Your Medical System

- [ ] Run the magic command: `./scripts/super-simple-start.sh`
- [ ] Wait patiently (5-10 minutes first time)
- [ ] Look for "🎉 NOCTIS PRO IS READY!" message

---

## ✅ Step 4: Test Web Access

- [ ] Open web browser
- [ ] Go to: `http://localhost:8000`
- [ ] Login with username: `admin` and password: `admin123`
- [ ] See the medical dashboard

---

## ✅ Step 5: Create Your First Hospital

- [ ] Click "Facility Management" or "ADD FACILITY"
- [ ] Fill in real hospital information:
  - [ ] Facility Name: `_________________`
  - [ ] Address: `_____________________`
  - [ ] Phone: `______________________`
  - [ ] Email: `______________________`
  - [ ] License Number: `______________`
- [ ] Click "Create Facility"
- [ ] **Write down the AE Title:** `_______________`

---

## ✅ Step 6: Create More Facilities (If Needed)

**Facility 2:**
- [ ] Name: `_________________________`
- [ ] AE Title: `____________________`

**Facility 3:**
- [ ] Name: `_________________________`
- [ ] AE Title: `____________________`

**Facility 4:**
- [ ] Name: `_________________________`
- [ ] AE Title: `____________________`

---

## ✅ Step 7: Test DICOM Connection

- [ ] Open terminal
- [ ] Test DICOM port: `telnet localhost 11112`
- [ ] Should say "Connected to localhost"
- [ ] Press `Ctrl + C` to exit

---

## ✅ Step 8: Configure DICOM Machine (If You Have One)

**DICOM Machine Settings:**
- [ ] Called AE Title: `NOCTIS_SCP`
- [ ] Calling AE Title: `[Your facility's AE Title]`
- [ ] IP Address: `localhost` or `[your computer's IP]`
- [ ] Port: `11112`
- [ ] Timeout: `30 seconds`

---

## ✅ Step 9: Create Users

**Admin User (already created):**
- [ ] Username: `admin`
- [ ] Password: `admin123`

**Additional Users:**
- [ ] User 1: `_____________` Role: `_____________` Facility: `_____________`
- [ ] User 2: `_____________` Role: `_____________` Facility: `_____________`
- [ ] User 3: `_____________` Role: `_____________` Facility: `_____________`

---

## ✅ Step 10: Verify Everything Works

- [ ] Can access web interface: `http://localhost:8000`
- [ ] Can login to admin panel
- [ ] Can see facilities in facility list
- [ ] Can see users in user list
- [ ] DICOM port responds to telnet test
- [ ] All Docker containers show "Up" status

---

## 🌍 When Ready for Internet Access

- [ ] Export data: `./scripts/export-for-server.sh`
- [ ] Set up Ubuntu Server
- [ ] Import data on server
- [ ] Configure domain name
- [ ] Deploy internet access
- [ ] Configure SSL certificates
- [ ] Test from real DICOM machines

---

## 📞 Important Information to Remember

**Web Access:**
- URL: `http://localhost:8000`
- Admin: `admin` / `admin123`

**DICOM Access:**
- Port: `11112`
- Called AE: `NOCTIS_SCP`

**Your Computer's IP:** `___________________`

**Facility AE Titles:**
1. `________________________________`
2. `________________________________`
3. `________________________________`
4. `________________________________`

---

## 🆘 If Something Goes Wrong

**Docker not working:**
- [ ] Check Docker installed: `docker --version`
- [ ] Check permissions: `docker ps`
- [ ] Restart computer if needed

**Can't access website:**
- [ ] Check containers running: `docker compose -f docker-compose.desktop.yml ps`
- [ ] Restart system: `docker compose -f docker-compose.desktop.yml restart`
- [ ] Wait 2-3 minutes and try again

**DICOM port not working:**
- [ ] Check DICOM service: `docker compose -f docker-compose.desktop.yml logs dicom_receiver`
- [ ] Test port: `telnet localhost 11112`

**Forgot admin password:**
- [ ] It's `admin123` (unless you changed it)
- [ ] Reset if needed: `docker compose -f docker-compose.desktop.yml exec web python manage.py changepassword admin`

---

## 🎯 Success Indicators

✅ **You know it's working when:**
- [ ] Web browser shows medical dashboard at `http://localhost:8000`
- [ ] You can login with admin/admin123
- [ ] You can create facilities and they get AE titles
- [ ] You can create users and assign them to facilities
- [ ] `telnet localhost 11112` connects successfully
- [ ] All Docker containers show "Up" in status

---

## 📋 Useful Commands to Remember

**Check if system is running:**
```bash
docker compose -f docker-compose.desktop.yml ps
```

**Start the system:**
```bash
docker compose -f docker-compose.desktop.yml up -d
```

**Stop the system:**
```bash
docker compose -f docker-compose.desktop.yml down
```

**See what's happening:**
```bash
docker compose -f docker-compose.desktop.yml logs -f
```

**Restart everything:**
```bash
docker compose -f docker-compose.desktop.yml restart
```

---

## 🎉 Congratulations!

When you can check all the boxes above, you have successfully set up your NOCTIS Pro medical imaging system!

**What you've accomplished:**
✅ Medical imaging system running on your desktop  
✅ Web interface for managing facilities and users  
✅ DICOM receiver ready for medical machines  
✅ Automatic facility routing by AE titles  
✅ User management with role-based access  
✅ Ready to receive real medical images  

**Next step:** When ready, move everything to a real server for production use!

---

*Keep this checklist handy - you can use it again if you need to set up the system on another computer!*