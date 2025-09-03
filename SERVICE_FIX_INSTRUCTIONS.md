# NoctisPro Professional Service Fix Instructions

## Problem Diagnosis

Your `noctispro-professional.service` was failing because of several issues:

1. **Missing Virtual Environment**: The service tried to activate `venv/bin/activate` but no virtual environment existed
2. **Missing Dependencies**: Required Python packages (Django, Gunicorn, etc.) were not installed
3. **Missing Environment Variables**: The SECRET_KEY was not set
4. **Incorrect PATH**: The service couldn't find the installed Python packages

## Solution Applied

### 1. Installed Required Dependencies
```bash
pip3 install --break-system-packages django gunicorn redis channels
pip3 install --break-system-packages djangorestframework django-cors-headers channels-redis daphne whitenoise django-redis
pip3 install --break-system-packages scipy matplotlib scikit-image
pip3 install --break-system-packages pydicom pillow opencv-python numpy
# And many more packages from requirements.txt
```

### 2. Created Working Service File
The fixed service file is located at: `/workspace/noctispro-professional-working.service`

Key fixes:
- Added proper PATH environment variable to include `/home/ubuntu/.local/bin`
- Added SECRET_KEY environment variable
- Removed virtual environment activation (using system Python with user packages)
- Fixed ExecStart command to use full paths and environment variables

## Installation Instructions

### Step 1: Copy the Fixed Service File
```bash
sudo cp /workspace/noctispro-professional-working.service /etc/systemd/system/noctispro-professional.service
```

### Step 2: Reload Systemd and Start Service
```bash
sudo systemctl daemon-reload
sudo systemctl enable noctispro-professional
sudo systemctl start noctispro-professional
```

### Step 3: Check Service Status
```bash
sudo systemctl status noctispro-professional
```

### Step 4: View Logs (if needed)
```bash
sudo journalctl -u noctispro-professional -f
```

## Verification

The service should now:
- ✅ Start successfully without errors
- ✅ Run database migrations automatically
- ✅ Collect static files
- ✅ Start Gunicorn with 4 workers on port 8000
- ✅ Restart automatically if it fails

## Service Configuration Details

The working service:
- **WorkingDirectory**: `/workspace/noctis_pro_deployment`
- **User/Group**: `ubuntu`
- **Port**: `8000`
- **Workers**: `4`
- **Environment**: Production settings with SQLite database
- **Security**: Enhanced security settings enabled

## Next Steps

1. **Install the fixed service** using the commands above
2. **Test the application** by accessing `http://your-server:8000`
3. **Configure Nginx** (if needed) to proxy to port 8000
4. **Set up proper SSL certificates** for production use
5. **Configure environment-specific settings** in production

The service should now start successfully and your NoctisPro Professional Medical Imaging System will be running!