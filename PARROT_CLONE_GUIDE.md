# 🦜 NoctisPro PACS - Complete Setup Guide for Parrot OS

## 📋 Step-by-Step Guide After Cloning Repository

### Step 1: Clone the Repository (You'll do this)
```bash
# Clone the repository to your Parrot OS
git clone <repository-url> noctispro-pacs
cd noctispro-pacs
```

### Step 2: Quick System Preparation
```bash
# Run the quick setup script to prepare Parrot OS
sudo ./quick_parrot_setup.sh
```

This will:
- ✅ Update your Parrot OS system
- ✅ Install all required dependencies
- ✅ Set up workspace directory
- ✅ Detect USB devices for bootable creation
- ✅ Test internet connectivity

### Step 3: Smoke Test the System (Before Deployment)
```bash
# Make the smoke test script executable and run it
chmod +x smoke_test_complete.sh
sudo ./smoke_test_complete.sh
```

This comprehensive smoke test will verify:
- ✅ All NoctisPro PACS features are working
- ✅ Database connectivity and models
- ✅ DICOM processing capabilities
- ✅ AI analysis functionality
- ✅ Web interface and API endpoints
- ✅ Security configurations
- ✅ Performance benchmarks

### Step 4: Create Bootable Media (After Smoke Test Passes)
```bash
# Create bootable Ubuntu Server with NoctisPro pre-installed
sudo ./create_bootable_ubuntu.sh
```

Choose your options:
1. **USB Drive**: Creates bootable USB (8GB+ required)
2. **ISO File**: Creates ISO for DVD burning or VMs
3. **Both**: Creates both USB and ISO

### Step 5: Deploy on Target System
1. Boot target system from created USB/DVD
2. Select "Install NoctisPro PACS Server (Automatic)"
3. Wait for automatic installation (20-45 minutes)
4. System reboots and auto-logs in with GUI
5. Browser opens automatically to NoctisPro at `http://localhost`

## 🔧 Detailed Commands for Each Step

### After Cloning - Full Setup Process

```bash
# 1. Navigate to cloned directory
cd noctispro-pacs

# 2. Make all scripts executable
chmod +x *.sh

# 3. Quick Parrot OS setup
sudo ./quick_parrot_setup.sh

# 4. Comprehensive smoke test
sudo ./smoke_test_complete.sh

# 5. If smoke test passes, create bootable media
sudo ./create_bootable_ubuntu.sh

# 6. Alternative: Direct deployment on current system
sudo ./deploy_ubuntu_gui_master.sh
```

## 🧪 What the Smoke Test Checks

### Core System Components
- ✅ **Django Framework**: Configuration and database
- ✅ **Python Dependencies**: All required packages
- ✅ **Database Models**: User accounts, worklist, DICOM data
- ✅ **Static Files**: CSS, JavaScript, images
- ✅ **Media Handling**: File uploads and DICOM storage

### NoctisPro PACS Features
- ✅ **User Authentication**: Login/logout functionality
- ✅ **Worklist Management**: Patient and study management
- ✅ **DICOM Viewer**: Medical image viewing and processing
- ✅ **AI Analysis**: Medical image analysis capabilities
- ✅ **Reports System**: Report generation and management
- ✅ **Admin Panel**: System administration interface
- ✅ **Chat System**: Communication features
- ✅ **Notifications**: Alert and notification system

### Integration Tests
- ✅ **API Endpoints**: REST API functionality
- ✅ **WebSocket Connections**: Real-time features
- ✅ **File Processing**: DICOM file handling
- ✅ **Image Processing**: Medical image manipulation
- ✅ **Security**: Authentication and authorization

### Performance Tests
- ✅ **Response Times**: Web interface performance
- ✅ **Memory Usage**: System resource consumption
- ✅ **Database Performance**: Query execution times
- ✅ **File Upload**: Large DICOM file handling

## 📊 Smoke Test Results

The smoke test will provide a detailed report showing:

```
🏥 NoctisPro PACS - Comprehensive Smoke Test Results
=====================================================

✅ System Configuration
   • Django settings: Valid
   • Database connection: Active
   • Static files: Accessible
   • Media directory: Writable

✅ Core Features
   • User authentication: Working
   • Worklist management: Functional
   • DICOM viewer: Active
   • AI analysis: Ready
   • Reports system: Operational

✅ Performance Metrics
   • Average response time: <200ms
   • Memory usage: 145MB
   • Database queries: Optimized
   • File upload speed: 15MB/s

✅ Security Checks
   • CSRF protection: Enabled
   • Authentication: Secure
   • File permissions: Correct
   • SSL configuration: Ready

🎉 All Tests Passed! System Ready for Deployment
```

## 🚨 If Smoke Test Fails

### Common Issues and Solutions

#### 1. Missing Dependencies
```bash
# Install missing Python packages
pip install -r requirements.txt

# Install system packages
sudo apt install -y python3-dev build-essential
```

#### 2. Database Issues
```bash
# Reset database
python manage.py migrate --run-syncdb
python manage.py createsuperuser
```

#### 3. Permission Problems
```bash
# Fix file permissions
sudo chown -R $USER:$USER .
chmod +x *.sh
```

#### 4. Port Conflicts
```bash
# Check for running processes
sudo netstat -tulpn | grep :8000
sudo killall python3
```

## 🎯 Next Steps After Smoke Test

### If All Tests Pass ✅
1. **Create Bootable Media**: Use `create_bootable_ubuntu.sh`
2. **Deploy to Target System**: Boot from created media
3. **Access NoctisPro**: Open browser to `http://localhost`
4. **Configure for Production**: Set up HTTPS, backups, etc.

### If Tests Fail ❌
1. **Review Error Log**: Check `/tmp/smoke_test.log`
2. **Fix Issues**: Address specific problems found
3. **Re-run Test**: Execute smoke test again
4. **Get Support**: Check documentation or contact support

## 📁 File Structure After Cloning

```
noctispro-pacs/
├── 📁 Core System
│   ├── manage.py                    # Django management
│   ├── requirements.txt             # Python dependencies
│   ├── db.sqlite3                   # Database (created after setup)
│   └── noctis_pro/                  # Django settings
│
├── 📁 Applications
│   ├── accounts/                    # User management
│   ├── worklist/                    # Patient management
│   ├── dicom_viewer/               # Medical imaging
│   ├── ai_analysis/                # AI features
│   ├── reports/                    # Report system
│   ├── admin_panel/                # Administration
│   ├── chat/                       # Communication
│   └── notifications/              # Alerts
│
├── 📁 Deployment Scripts
│   ├── quick_parrot_setup.sh       # Parrot OS preparation
│   ├── smoke_test_complete.sh      # System testing
│   ├── create_bootable_ubuntu.sh   # Bootable media creation
│   ├── deploy_ubuntu_gui_master.sh # Direct deployment
│   └── ssl_setup.sh                # HTTPS configuration
│
├── 📁 Documentation
│   ├── README.md                   # Main documentation
│   ├── PARROT_BOOTABLE_GUIDE.md    # Bootable creation guide
│   └── PARROT_CLONE_GUIDE.md       # This guide
│
└── 📁 Static & Media
    ├── static/                     # CSS, JS, images
    ├── templates/                  # HTML templates
    └── media/                      # Uploaded files
```

## 🔐 Default Credentials (After Setup)

### System Access
- **System User**: `noctispro` / `noctispro123`
- **SSH Access**: Enabled (if configured)

### NoctisPro PACS
- **Admin User**: `admin` / `admin123`
- **Admin Panel**: `http://localhost/admin/`
- **Main App**: `http://localhost`

### Database
- **SQLite**: Default (no credentials needed)
- **PostgreSQL**: `noctispro_user` / `noctispro_pass` (if configured)

## 🌐 Access URLs (After Deployment)

- **Main Application**: `http://localhost`
- **Admin Panel**: `http://localhost/admin/`
- **DICOM Viewer**: `http://localhost/dicom_viewer/`
- **Worklist**: `http://localhost/worklist/`
- **AI Analysis**: `http://localhost/ai_analysis/`
- **Reports**: `http://localhost/reports/`
- **API Documentation**: `http://localhost/api/`

## 🛠️ Management Commands

### Service Management
```bash
# Start services
noctispro-admin start

# Stop services
noctispro-admin stop

# Restart services
noctispro-admin restart

# Check status
noctispro-admin status

# View logs
noctispro-admin logs

# Show URLs
noctispro-admin url
```

### Django Management
```bash
# Database migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Collect static files
python manage.py collectstatic

# Run development server
python manage.py runserver
```

## 🎉 Success Indicators

### You'll know everything is working when:
1. ✅ Smoke test shows all green checkmarks
2. ✅ Web interface loads at `http://localhost`
3. ✅ Admin panel is accessible
4. ✅ DICOM files can be uploaded and viewed
5. ✅ User login/logout works correctly
6. ✅ All menu items are functional
7. ✅ No error messages in logs

## 🆘 Troubleshooting

### If You Encounter Issues:

1. **Check Logs**:
   ```bash
   tail -f /tmp/smoke_test.log
   tail -f logs/noctis_pro.log
   ```

2. **Verify Dependencies**:
   ```bash
   pip list | grep -i django
   python manage.py check
   ```

3. **Test Database**:
   ```bash
   python manage.py dbshell
   python manage.py showmigrations
   ```

4. **Check Permissions**:
   ```bash
   ls -la
   whoami
   ```

5. **Restart Services**:
   ```bash
   sudo systemctl restart noctispro
   sudo systemctl status noctispro
   ```

## 📞 Support

If you need help:
1. Check the smoke test log for specific errors
2. Review the deployment documentation
3. Verify system requirements are met
4. Ensure all dependencies are installed

---

**Ready to get started? Follow the steps above after cloning the repository to your Parrot OS system!** 🚀