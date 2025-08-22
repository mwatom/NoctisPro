# NoctisPro Deployment Guide for Ubuntu 24.04 LTS

## 🚀 Ubuntu 24.04 LTS Deployment with Enhanced DICOM Printing

This guide provides step-by-step instructions for deploying NoctisPro on **Ubuntu 24.04 LTS** with full support for **multi-layout DICOM printing** on both **paper and medical film**.

### ✨ Ubuntu 24.04 Enhancements
- **Automatic compatibility detection** and fixes
- **Enhanced Docker configuration** for Ubuntu 24.04
- **Advanced printing layouts** for all DICOM modalities
- **Medical film printing** support
- **Improved security** with latest Ubuntu features

## 📋 Pre-Deployment Checklist

- [ ] **Ubuntu 24.04 LTS Server** installed and updated
- [ ] **Root access** or sudo privileges
- [ ] **Network connectivity** for package downloads
- [ ] **Printer(s)** connected (photo printer and/or film printer)
- [ ] **Print media** loaded (glossy paper and/or medical film)
- [ ] **Domain name** (optional but recommended)

## 🔧 Step-by-Step Deployment

### Step 1: System Preparation

```bash
# Update Ubuntu 24.04 system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y lsb-release curl wget git unzip software-properties-common

# Verify Ubuntu version
lsb_release -a

# Expected output: Ubuntu 24.04.x LTS
```

### Step 2: Clone NoctisPro Repository

```bash
# Clone the latest version
git clone https://github.com/mwatom/NoctisPro.git
cd NoctisPro

# Make all scripts executable
chmod +x *.sh
chmod +x scripts/*.sh

# Verify we have the enhanced deployment script
ls -la deploy_noctis_production.sh setup_printer.sh
```

### Step 3: 🖨️ Pre-Configure Printing (Recommended)

**For optimal results, set up printing before main deployment:**

```bash
# Run the dedicated printer setup script
sudo ./setup_printer.sh

# This will:
# ✅ Install CUPS and all printer drivers
# ✅ Detect and configure your printers
# ✅ Set up glossy paper and film settings
# ✅ Test printing functionality
```

### Step 4: Main Deployment

```bash
# Run the enhanced deployment script
sudo ./deploy_noctis_production.sh

# The script automatically detects Ubuntu 24.04 and:
# ✅ Applies compatibility fixes for Docker
# ✅ Installs optimized packages for Ubuntu 24.04
# ✅ Configures enhanced printing system
# ✅ Sets up all services with Ubuntu 24.04 optimizations
```

**Expected Output:**
```
[INFO] Detected Ubuntu version: 24.04
[INFO] Applying Ubuntu 24.04 compatibility fixes...
[SUCCESS] Ubuntu 24.04 compatibility fixes applied
[INFO] Installing Docker Engine...
[INFO] Configuring Docker for Ubuntu 24.04...
[SUCCESS] Docker configured successfully
...
[SUCCESS] NoctisPro deployment completed successfully!
```

### Step 5: Validation

```bash
# Run enhanced validation script
sudo python3 validate_deployment_with_printing.py

# Expected result: All checks pass ✅
```

## 🖨️ Enhanced Printing Features

### Print Medium Options

**📄 Paper Printing:**
- **Glossy Photo Paper**: Best for detailed diagnostic images
- **Matte Paper**: Good for reports and documentation
- **Plain Paper**: Basic printing for drafts

**🎞️ Medical Film Printing:**
- **Blue-Base Film**: Standard medical film for X-rays
- **Clear-Base Film**: High-contrast imaging
- **Medical Film**: General purpose diagnostic film

### Layout Options by Modality

**CT Scans:**
- **Single Image**: Full-page detailed view
- **Quad Layout**: 4 slices for comparison
- **CT Axial Grid**: 16 axial slices in grid format
- **CT MPR Trio**: Axial, Sagittal, Coronal views

**MRI:**
- **Single Image**: Full-page detailed view
- **Quad Layout**: 4 images for comparison
- **MRI Sequences**: Multiple sequences comparison
- **MRI MPR Trio**: Axial, Sagittal, Coronal views

**X-Ray (CR/DX/DR):**
- **Single Image**: Full-page radiograph
- **Quad Layout**: Multiple views
- **PA & Lateral**: Standard chest X-ray layout

**Ultrasound:**
- **Single Image**: Full-page ultrasound
- **Quad Layout**: Multiple views
- **US with Measurements**: Measurement overlay included

**Mammography:**
- **Single Image**: Full-page mammogram
- **CC & MLO Views**: Standard mammography layout

**PET:**
- **Single Image**: PET scan view
- **PET Fusion**: PET with CT fusion overlay

### Film Printing Configuration

**Recommended Film Printers:**
- **Agfa DryPix series**
- **Kodak DryView series** 
- **Fuji DryPix series**
- **Generic DICOM film printers**

**Film Setup in CUPS:**
```bash
# Add film printer
sudo lpadmin -p FilmPrinter -E -v "ipp://film-printer-ip/ipp/print" -m everywhere

# Configure for film
sudo lpadmin -p FilmPrinter -o media-type=film
sudo lpadmin -p FilmPrinter -o print-quality=5
sudo lpadmin -p FilmPrinter -o ColorModel=Grayscale
sudo lpadmin -p FilmPrinter -o Resolution=600dpi

# Test film printing
echo "Film test" | lp -d FilmPrinter -o media-type=film
```

## 🐛 Ubuntu 24.04 Specific Troubleshooting

### Docker Issues on Ubuntu 24.04

**Issue: Docker containers fail to start**
```bash
# Check Docker daemon status
sudo systemctl status docker

# If using snap Docker (not recommended), remove it:
sudo snap remove docker

# Reinstall Docker using apt:
sudo ./deploy_noctis_production.sh  # Re-run deployment
```

**Issue: Network connectivity problems**
```bash
# Reset Docker networks
sudo docker network prune -f

# Restart Docker with new configuration
sudo systemctl restart docker

# Check Docker daemon logs
sudo journalctl -u docker -f
```

**Issue: Storage driver problems**
```bash
# Check Docker info
sudo docker info | grep "Storage Driver"

# If issues persist, edit Docker config:
sudo nano /etc/docker/daemon.json

# Ensure it contains:
{
    "storage-driver": "overlay2",
    "iptables": true,
    "ip-forward": true
}

sudo systemctl restart docker
```

### Printing Issues on Ubuntu 24.04

**Issue: CUPS service fails to start**
```bash
# Check CUPS status
sudo systemctl status cups

# Restart CUPS
sudo systemctl restart cups

# Check CUPS configuration
sudo nano /etc/cups/cupsd.conf

# Ensure these lines exist:
Listen localhost:631
Listen /var/run/cups/cups.sock
```

**Issue: Film printer not detected**
```bash
# Check printer connectivity
lpstat -p -d

# For network film printers, try:
sudo lpadmin -p FilmPrinter -E -v "socket://printer-ip:9100" -m everywhere

# For USB film printers:
sudo lpadmin -p FilmPrinter -E -v "usb://auto" -m everywhere
```

**Issue: Print quality poor on Ubuntu 24.04**
```bash
# Update printer drivers
sudo apt update
sudo apt install -y printer-driver-all printer-driver-hplip

# Reconfigure printer with optimal settings
sudo lpadmin -p YourPrinter -o print-quality=5 -o Resolution=1200dpi
```

## 🔄 Ubuntu 24.04 Maintenance

### System Updates
```bash
# Regular Ubuntu 24.04 updates
sudo apt update && sudo apt upgrade -y

# Update NoctisPro
cd /opt/noctis_pro
sudo -u noctis git pull origin main
sudo systemctl restart noctis-django noctis-daphne noctis-celery
```

### Docker Maintenance
```bash
# Clean Docker system (Ubuntu 24.04 safe)
sudo docker system prune -f

# Update Docker Compose
sudo apt update && sudo apt install -y docker-compose-plugin
```

### Printing System Maintenance
```bash
# Clean print queues
cancel -a

# Update printer drivers
sudo apt update && sudo apt install -y printer-driver-all

# Test all configured printers
for printer in $(lpstat -p | awk '{print $2}'); do
    echo "Testing $printer..."
    echo "Test print - $(date)" | lp -d "$printer"
done
```

## 🎯 Ubuntu 24.04 Deployment Validation

### Automated Validation
```bash
# Run comprehensive validation
sudo python3 validate_deployment_with_printing.py

# Expected output for Ubuntu 24.04:
# ✅ Ubuntu 24.04 compatibility: OK
# ✅ Docker configuration: OK
# ✅ All services running: OK
# ✅ Enhanced printing: OK
# ✅ Film printing support: OK
# ✅ Multi-layout printing: OK
```

### Manual Testing Checklist

**Ubuntu 24.04 Specific:**
- [ ] Docker runs without iptables errors
- [ ] All containers start successfully
- [ ] Network connectivity works properly
- [ ] Storage driver functions correctly

**Enhanced Printing Features:**
- [ ] Print medium selection works (Paper/Film)
- [ ] Layout options load for each modality
- [ ] Glossy paper printing produces high quality
- [ ] Film printing works (if film printer available)
- [ ] Modality-specific layouts render correctly
- [ ] All paper sizes supported (A4, Letter, Film sizes)

## 🚀 Quick Start for Ubuntu 24.04

```bash
# One-command deployment for Ubuntu 24.04
git clone https://github.com/mwatom/NoctisPro.git && \
cd NoctisPro && \
sudo ./deploy_noctis_production.sh && \
sudo python3 validate_deployment_with_printing.py

# Expected completion time: 20-30 minutes
# Access: http://localhost:8000 or https://your-domain.com
# Admin: admin/admin123 (change immediately)
```

## 📞 Ubuntu 24.04 Support

### Common Ubuntu 24.04 Commands
```bash
# Check Ubuntu version
lsb_release -a

# Check system status
sudo /usr/local/bin/noctis-status.sh

# View system logs
sudo journalctl --since "1 hour ago" | grep -i error

# Monitor system performance
htop
```

### Ubuntu 24.04 Specific Logs
```bash
# Docker logs
sudo journalctl -u docker -f

# CUPS logs  
sudo journalctl -u cups -f

# NoctisPro application logs
sudo journalctl -u noctis-django -f
```

---

## ✅ Deployment Success Indicators

**System Ready When You See:**
- All services show "active (running)" status
- Web interface loads at http://localhost:8000
- DICOM viewer opens without errors
- Print dialog shows available printers and layouts
- Test prints succeed on both paper and film (if available)

**🎉 Congratulations! NoctisPro is now ready for production use on Ubuntu 24.04 with enhanced DICOM printing capabilities.**

---

*For additional support or Ubuntu 24.04 specific issues, refer to the main README.md troubleshooting section.*