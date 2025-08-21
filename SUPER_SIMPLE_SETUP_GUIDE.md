# 🏥 NOCTIS Pro - Super Simple Setup Guide
## Step-by-Step Instructions for Ubuntu Desktop

**This guide is written so simply that even a small kid can follow it!** 

We'll set up your medical imaging system on Ubuntu Desktop first, then later move it to a real server.

---

## 🎯 What We're Going to Do

1. **Install Docker** (the container system)
2. **Download your medical software**
3. **Start the system** 
4. **Create hospitals/clinics** (facilities)
5. **Test everything works**
6. **Make it accessible from internet** (optional)
7. **Later: Move to real server**

---

## 📋 What You Need Before Starting

- ✅ Ubuntu Desktop computer (18.04 or newer)
- ✅ Internet connection
- ✅ At least 4GB RAM and 20GB free disk space
- ✅ Admin/sudo access to your computer
- ✅ Basic ability to copy/paste commands

---

## 🚀 Step 1: Install Docker (The Container System)

Docker is like a magic box that runs your medical software. Let's install it!

### 1.1 Open Terminal
- Press `Ctrl + Alt + T` to open terminal
- You'll see a black window with text - this is where we type commands

### 1.2 Download and Install Docker
Copy and paste this command (press `Ctrl + Shift + V` to paste in terminal):

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
```

Press `Enter`. This downloads the Docker installer.

Now install Docker:
```bash
sudo sh get-docker.sh
```

Type your password when asked (the text won't show when you type - that's normal!).

### 1.3 Add Yourself to Docker Group
This lets you use Docker without typing `sudo` every time:

```bash
sudo usermod -aG docker $USER
```

### 1.4 Install Docker Compose
This helps manage multiple containers:

```bash
sudo apt update
sudo apt install docker-compose-plugin
```

### 1.5 Restart Your Computer
**IMPORTANT**: You must restart your computer now for Docker to work properly.

```bash
sudo reboot
```

Wait for your computer to restart, then open terminal again (`Ctrl + Alt + T`).

### 1.6 Test Docker Works
Type this to test Docker:

```bash
docker --version
```

You should see something like "Docker version 24.0.7". If you see an error, Docker didn't install correctly.

---

## 🚀 Step 2: Get Your Medical Software

### 2.1 Go to Your Home Directory
```bash
cd ~
```

### 2.2 Download the NOCTIS Pro Software
If you have the software in a folder already, go to that folder:
```bash
cd /path/to/your/noctis-pro-folder
```

If you need to download it from Git:
```bash
git clone YOUR_REPOSITORY_URL noctis-pro
cd noctis-pro
```

### 2.3 Check You're in the Right Place
Type this to see the files:
```bash
ls -la
```

You should see files like:
- `docker-compose.yml`
- `requirements.txt`
- `manage.py`
- `scripts/` folder

If you don't see these files, you're in the wrong folder!

---

## 🚀 Step 3: Start Your Medical System (Easy Way)

### 3.1 Run the Magic Setup Script
This one command does everything for you:

```bash
./scripts/quick-start-desktop.sh
```

**What this script does for you:**
- ✅ Checks Docker is working
- ✅ Creates configuration files
- ✅ Downloads all needed software
- ✅ Starts your medical system
- ✅ Creates admin user
- ✅ Sets up database

### 3.2 Wait for Everything to Start
The script will show you messages like:
- "Pulling Docker images..." (downloading software)
- "Building application image..." (preparing your software)
- "Starting services..." (starting everything)
- "Waiting for database..." (database getting ready)

**This takes 5-10 minutes the first time** - be patient!

### 3.3 Success! 
When you see:
```
🎉 NOCTIS Pro development environment is ready!

Next steps:
1. Open http://localhost:8000 in your browser
2. Login with admin/admin123
3. Start developing!
```

Your system is working! 🎉

---

## 🚀 Step 4: Access Your Medical System

### 4.1 Open Your Web Browser
Open Firefox, Chrome, or any web browser.

### 4.2 Go to Your Medical System
Type this in the address bar:
```
http://localhost:8000
```

Press Enter.

### 4.3 Login to Admin Panel
You should see a login page. Use:
- **Username**: `admin`
- **Password**: `admin123`

Click "Login".

### 4.4 You Should See the Dashboard
You'll see a medical-looking dashboard with:
- 📊 Statistics
- 🏥 Facility management
- 👥 User management
- 📋 Study worklist

**If you see this - SUCCESS!** Your medical system is running! 🎉

---

## 🚀 Step 5: Create Your First Hospital/Clinic (Facility)

Now let's create a real hospital or clinic that can send DICOM images.

### 5.1 Go to Facility Management
- Click on "Facility Management" or "ADD FACILITY" button
- Or go to: `http://localhost:8000/admin/facilities/`

### 5.2 Click "Add Facility"
You'll see a form to create a new facility.

### 5.3 Fill in Real Information
**Example for a real hospital:**

```
Facility Name: City General Hospital
Address: 123 Medical Center Drive
         Downtown, State 12345
Phone: (555) 123-4567
Email: admin@citygeneralhospital.com
License Number: MED-12345-2024
AE Title: (leave blank - it will auto-generate "CITY_GENERAL")
```

**The AE Title is VERY IMPORTANT** - this is what DICOM machines will use to identify themselves.

### 5.4 Optional: Create Facility User
- Check the box "Create a facility user account"
- Username: `cityhospital` (or leave blank for auto-generation)
- Email: `staff@citygeneralhospital.com`
- Password: (leave blank for auto-generation)

### 5.5 Save the Facility
Click "Create Facility" button.

### 5.6 Note the AE Title
After saving, you'll see the facility with its AE Title (like "CITY_GENERAL"). 

**WRITE THIS DOWN** - you'll need it for DICOM machine configuration!

---

## 🚀 Step 6: Create More Facilities (If Needed)

Repeat Step 5 for each hospital/clinic that will send DICOM images:

### Example Facility 2:
```
Facility Name: Regional Diagnostic Center
AE Title: REGIONAL_DIAG (auto-generated)
```

### Example Facility 3:
```
Facility Name: Downtown Medical Clinic
AE Title: DOWNTOWN_MED (auto-generated)
```

**Each facility gets a unique AE Title** - this is how the system knows which hospital sent which images.

---

## 🚀 Step 7: Test DICOM Connection (Local Testing)

### 7.1 Check DICOM Port is Working
In terminal, type:
```bash
telnet localhost 11112
```

You should see:
```
Trying 127.0.0.1...
Connected to localhost.
```

Press `Ctrl + C` to exit.

**If it says "Connection refused"** - something is wrong. Check that your system is running:
```bash
docker compose -f docker-compose.desktop.yml ps
```

All services should show "Up".

### 7.2 Check Your Facilities
Go back to your browser: `http://localhost:8000/admin/facilities/`

You should see all the facilities you created with their AE Titles.

---

## 🚀 Step 8: Make It Work Like a Real Server (Optional)

If you want to test how it will work on a real server, let's make your desktop accessible from other computers.

### 8.1 Find Your Computer's IP Address
```bash
ip addr show | grep "inet " | grep -v "127.0.0.1"
```

You'll see something like `192.168.1.100` - this is your computer's IP address.

### 8.2 Update Configuration for Network Access
```bash
# Stop the current system
docker compose -f docker-compose.desktop.yml down

# Edit environment file
nano .env
```

In the file, find this line:
```
ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0
```

Change it to include your IP:
```
ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0,192.168.1.100
```

(Replace `192.168.1.100` with your actual IP)

Save the file: `Ctrl + X`, then `Y`, then `Enter`.

### 8.3 Start System Again
```bash
docker compose -f docker-compose.desktop.yml up -d
```

### 8.4 Test from Another Computer
From another computer on your network, try:
- Web: `http://192.168.1.100:8000`
- DICOM: `telnet 192.168.1.100 11112`

---

## 🚀 Step 9: Configure a Real DICOM Machine (If You Have One)

If you have access to a real DICOM machine (CT, MRI, X-ray, etc.), here's how to configure it:

### 9.1 Get Your Facility's AE Title
- Go to: `http://localhost:8000/admin/facilities/`
- Find your facility
- Note the AE Title (like "CITY_GENERAL")

### 9.2 Configure the DICOM Machine
In your DICOM machine's network settings:

```
DICOM Store (SCP) Configuration:
Called AE Title:    NOCTIS_SCP
Calling AE Title:   CITY_GENERAL    (your facility's AE title)
IP Address:         192.168.1.100   (your computer's IP)
Port:              11112
Timeout:           30 seconds
```

### 9.3 Test the Connection
1. **Send C-ECHO** (ping test) from DICOM machine
2. **Send test image** if echo works
3. **Check web interface** to see if image appears

---

## 🚀 Step 10: Check Everything is Working

### 10.1 Run the Verification Script
```bash
./scripts/verify-facility-user-management.sh
```

This checks:
- ✅ System is running
- ✅ Database is working
- ✅ Facilities can be created
- ✅ Users can be managed
- ✅ DICOM port is accessible
- ✅ AE title generation works

### 10.2 Check the Web Interface
Open `http://localhost:8000` and verify:
- ✅ You can login
- ✅ You can see facilities
- ✅ You can create new facilities
- ✅ You can create new users
- ✅ Dashboard shows statistics

### 10.3 Check DICOM Functionality
```bash
# Check DICOM service is running
docker compose -f docker-compose.desktop.yml ps dicom_receiver

# Check DICOM logs
docker compose -f docker-compose.desktop.yml logs dicom_receiver
```

---

## 🚀 Step 11: Prepare for Real Server Deployment

When you're ready to move to a real server:

### 11.1 Export Your Data
```bash
./scripts/export-for-server.sh
```

This creates a file like `noctis-export-20240101_120000.tar.gz` with all your:
- 🏥 Facilities and their AE titles
- 👥 Users and their permissions  
- 📊 Any test data you created
- ⚙️ Configuration files

### 11.2 Transfer to Server
Copy the export file to your server:
```bash
scp noctis-export-*.tar.gz user@your-server-ip:/tmp/
```

### 11.3 Import on Server
On your server:
```bash
./scripts/import-from-desktop.sh /tmp/noctis-export-*.tar.gz
```

---

## 🌍 Step 12: Enable Internet Access (For Real DICOM Machines)

When you want DICOM machines from the internet to connect:

### 12.1 Configure for Internet
```bash
# Copy internet configuration
cp .env.internet.example .env

# Edit with your real domain
nano .env
```

Change these important settings:
```bash
DOMAIN_NAME=your-medical-domain.com
SECRET_KEY=make-this-very-strong-and-secret
POSTGRES_PASSWORD=make-this-very-strong-too
LETSENCRYPT_EMAIL=your-email@domain.com
```

### 12.2 Deploy Internet Access
```bash
./scripts/deploy-internet-access.sh
```

This automatically:
- 🔒 Sets up security
- 🌐 Configures internet access
- 🔐 Installs SSL certificates
- 🛡️ Enables protection systems

---

## 🎉 Success Checklist

After following all steps, you should have:

### ✅ Working System
- [ ] Can access `http://localhost:8000`
- [ ] Can login with admin/admin123
- [ ] Can see dashboard with statistics
- [ ] Can create facilities
- [ ] Can create users

### ✅ DICOM Functionality  
- [ ] DICOM port 11112 is accessible
- [ ] Facilities have unique AE titles
- [ ] Can test DICOM connectivity
- [ ] DICOM logs show activity

### ✅ Ready for Production
- [ ] Can export data for server transfer
- [ ] Configuration files ready for internet access
- [ ] Security measures in place
- [ ] Backup system ready

---

## 🆘 If Something Goes Wrong

### Problem: "Docker command not found"
**Solution**: Docker didn't install correctly.
```bash
# Try installing again
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Restart computer
sudo reboot
```

### Problem: "Permission denied" when using Docker
**Solution**: You're not in the docker group.
```bash
sudo usermod -aG docker $USER
# Log out and back in, or restart computer
```

### Problem: "Cannot connect to localhost:8000"
**Solution**: System isn't running.
```bash
# Check if containers are running
docker compose -f docker-compose.desktop.yml ps

# If not running, start them
docker compose -f docker-compose.desktop.yml up -d

# Wait 2-3 minutes, then try again
```

### Problem: "Database error" or "500 error"
**Solution**: Database isn't ready.
```bash
# Check database status
docker compose -f docker-compose.desktop.yml logs db

# Restart everything
docker compose -f docker-compose.desktop.yml down
docker compose -f docker-compose.desktop.yml up -d

# Wait 5 minutes for everything to start
```

### Problem: Scripts don't run
**Solution**: Make them executable.
```bash
chmod +x scripts/*.sh
```

### Problem: "Port already in use"
**Solution**: Something else is using the port.
```bash
# See what's using port 8000
sudo netstat -tlnp | grep 8000

# Kill the process or change the port in docker-compose.desktop.yml
```

---

## 🔧 Useful Commands to Remember

### Check if System is Running
```bash
docker compose -f docker-compose.desktop.yml ps
```

### Start the System
```bash
docker compose -f docker-compose.desktop.yml up -d
```

### Stop the System  
```bash
docker compose -f docker-compose.desktop.yml down
```

### See What's Happening (Logs)
```bash
docker compose -f docker-compose.desktop.yml logs -f
```

### Get into the System (Advanced)
```bash
docker compose -f docker-compose.desktop.yml exec web bash
```

### Restart Everything
```bash
docker compose -f docker-compose.desktop.yml restart
```

---

## 📱 Step-by-Step Screenshots Guide

### What You Should See:

**1. Terminal after Docker install:**
```
$ docker --version
Docker version 24.0.7, build afdd53b
```

**2. When starting system:**
```
✅ Docker installation verified
✅ Environment file created
✅ Starting services...
✅ Database is ready
✅ Web application is ready
🎉 NOCTIS Pro development environment is ready!
```

**3. Web interface login page:**
- Should see NOCTIS Pro logo
- Login form with username/password fields
- Dark medical theme

**4. After login - Dashboard:**
- Statistics cards showing 0 studies, 0 facilities
- Navigation menu with Facilities, Users, etc.
- Medical imaging theme

**5. Facility creation page:**
- Form with fields for facility name, address, etc.
- AE Title field (auto-fills when you type facility name)
- Save button

**6. After creating facility:**
- Should see facility in list
- AE Title should be generated (like "CITY_GENERAL")
- Status should show "Active"

---

## 🎯 What Each Step Actually Does

### Step 1 (Docker Install):
- Downloads Docker software
- Installs container system
- Gives you permission to use it

### Step 2 (Get Software):
- Gets your NOCTIS Pro medical software
- Makes sure you have all the files

### Step 3 (Start System):
- Creates database for storing medical data
- Starts web server for accessing system
- Starts DICOM receiver for medical images
- Creates admin user for you

### Step 4 (Access System):
- Opens web interface in browser
- Logs you in as administrator
- Shows you the main dashboard

### Step 5 (Create Facilities):
- Adds hospitals/clinics to system
- Generates unique AE titles for DICOM
- Creates user accounts for facility staff

---

## 🌍 Making It Internet Accessible (Advanced)

When you're ready for real DICOM machines to connect from internet:

### Step A: Get a Domain Name
- Buy a domain like `your-medical-center.com`
- Point it to your server's IP address

### Step B: Move to Real Server
- Use export/import scripts to transfer data
- Deploy on Ubuntu Server with internet access

### Step C: Configure DICOM Machines
Give each hospital this configuration:
```
Called AE Title:   NOCTIS_SCP
Calling AE Title:  CITY_GENERAL (their specific AE title)
Hostname:         your-medical-center.com  
Port:             11112
```

---

## 🎓 Understanding What You Built

### Your Medical System Has:

**🏥 Facility Management**
- Each hospital/clinic is a "facility"
- Each facility gets unique AE title
- Facility users can only see their own images

**👥 User Management**  
- Administrators: Manage everything
- Radiologists: Read images, write reports
- Facility Users: See only their facility's images

**🖼️ DICOM Image Processing**
- Receives medical images from CT, MRI, X-ray machines
- Automatically routes images to correct facility
- Stores images securely with patient information

**🔒 Security**
- Only registered facilities can send images
- User authentication and permissions
- Audit logging of all activities

### How DICOM Routing Works:
1. Hospital creates facility → Gets AE title "CITY_GENERAL"
2. Hospital configures CT machine with AE title "CITY_GENERAL"  
3. CT machine sends image with "CITY_GENERAL" identifier
4. Your system receives image and routes to City General Hospital
5. Only City General Hospital users can see their images

---

## 🎯 Final Success Check

After completing all steps, verify everything works:

### ✅ System Access
- [ ] Can open `http://localhost:8000`
- [ ] Can login with admin/admin123
- [ ] Can see dashboard

### ✅ Facility Management
- [ ] Can create new facilities
- [ ] AE titles are auto-generated
- [ ] Can edit existing facilities
- [ ] Can see facility list

### ✅ User Management  
- [ ] Can create new users
- [ ] Can assign users to facilities
- [ ] Can set user roles (admin, radiologist, facility)
- [ ] Can see user list

### ✅ DICOM Functionality
- [ ] DICOM port 11112 responds to telnet
- [ ] DICOM receiver logs show it's running
- [ ] System ready to receive medical images

### ✅ Ready for Production
- [ ] Can export data with export script
- [ ] Configuration files ready for server
- [ ] Understanding of how to move to real server

---

## 🎉 Congratulations!

You now have a fully working medical imaging system running on your Ubuntu Desktop! 

**What you can do now:**
- ✅ Create real hospitals and clinics as facilities
- ✅ Manage users for each facility  
- ✅ Receive DICOM images from medical machines
- ✅ Route images to correct facilities automatically
- ✅ Access everything through web browser
- ✅ Export everything to move to real server later

**Your system is ready for:**
- 🏥 Real healthcare facilities
- 📷 Real DICOM medical images  
- 👥 Real users and staff
- 🌍 Internet access (when you move to server)

**Next step**: When ready, use the export/import scripts to move everything to a real Ubuntu Server for production use!

---

*This guide was written to be so simple that anyone can follow it. If you get stuck on any step, go back and read it again carefully, or ask for help!*