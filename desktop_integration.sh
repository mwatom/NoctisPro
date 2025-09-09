#!/bin/bash

# ============================================================================
# NoctisPro PACS Desktop Integration Script
# ============================================================================
# Creates desktop applications, shortcuts, and GUI integration for NoctisPro
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SYSTEM_USER="noctispro"
APP_DIR="/opt/noctispro"

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Create NoctisPro icon
create_app_icon() {
    log "Creating NoctisPro application icon..."
    
    # Create icon directory
    mkdir -p /usr/share/pixmaps
    
    # Create a simple SVG icon for NoctisPro
    cat > /usr/share/pixmaps/noctispro.svg << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1e3a8a;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#3b82f6;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="64" height="64" rx="8" fill="url(#bg)"/>
  <circle cx="32" cy="32" r="20" fill="none" stroke="white" stroke-width="3"/>
  <circle cx="32" cy="32" r="12" fill="none" stroke="white" stroke-width="2"/>
  <circle cx="32" cy="32" r="4" fill="white"/>
  <text x="32" y="52" text-anchor="middle" fill="white" font-family="Arial" font-size="8" font-weight="bold">PACS</text>
</svg>
EOF
    
    # Convert SVG to PNG for compatibility
    if command -v convert &> /dev/null; then
        convert /usr/share/pixmaps/noctispro.svg /usr/share/pixmaps/noctispro.png
    fi
}

# Create desktop applications
create_desktop_applications() {
    log "Creating desktop applications..."
    
    # Main NoctisPro application
    cat > /usr/share/applications/noctispro.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=NoctisPro PACS
GenericName=Medical Imaging System
Comment=Picture Archiving and Communication System for Medical Imaging
Exec=firefox http://localhost
Icon=noctispro
Terminal=false
Categories=Office;Medical;Science;
Keywords=medical;imaging;dicom;pacs;radiology;
StartupNotify=true
MimeType=application/dicom;
EOF
    
    # Admin panel application
    cat > /usr/share/applications/noctispro-admin-panel.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=NoctisPro Admin Panel
GenericName=PACS Administration
Comment=Administrative interface for NoctisPro PACS
Exec=firefox http://localhost/admin/
Icon=noctispro
Terminal=false
Categories=System;Settings;
Keywords=admin;administration;settings;configuration;
StartupNotify=true
EOF
    
    # DICOM Viewer application
    cat > /usr/share/applications/noctispro-viewer.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=DICOM Viewer
GenericName=Medical Image Viewer
Comment=View and analyze DICOM medical images
Exec=firefox http://localhost/dicom_viewer/
Icon=noctispro
Terminal=false
Categories=Graphics;Viewer;Medical;
Keywords=dicom;viewer;medical;imaging;radiology;
StartupNotify=true
MimeType=application/dicom;
EOF
    
    # Worklist application
    cat > /usr/share/applications/noctispro-worklist.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=NoctisPro Worklist
GenericName=Patient Worklist
Comment=Manage patients and medical studies
Exec=firefox http://localhost/worklist/
Icon=noctispro
Terminal=false
Categories=Office;Medical;
Keywords=worklist;patients;studies;medical;
StartupNotify=true
EOF
    
    # System terminal
    cat > /usr/share/applications/noctispro-terminal.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=NoctisPro Terminal
GenericName=System Administration Terminal
Comment=Terminal access for NoctisPro system administration
Exec=gnome-terminal --title="NoctisPro Admin Terminal" -- bash -c "echo 'NoctisPro PACS Administration Terminal'; echo '=========================================='; echo ''; echo 'Available commands:'; echo '  noctispro-admin {start|stop|restart|status|logs|url}'; echo '  noctispro-ssl {renew|status|test}'; echo '  systemctl status noctispro noctispro-ngrok'; echo ''; bash"
Icon=utilities-terminal
Terminal=false
Categories=System;TerminalEmulator;
Keywords=terminal;admin;system;command;
StartupNotify=true
EOF
}

# Create user desktop shortcuts
create_user_shortcuts() {
    log "Creating desktop shortcuts for user $SYSTEM_USER..."
    
    # Ensure desktop directory exists
    sudo -u "$SYSTEM_USER" mkdir -p /home/$SYSTEM_USER/Desktop
    
    # Copy desktop files to user desktop
    sudo -u "$SYSTEM_USER" cp /usr/share/applications/noctispro.desktop /home/$SYSTEM_USER/Desktop/
    sudo -u "$SYSTEM_USER" cp /usr/share/applications/noctispro-admin-panel.desktop /home/$SYSTEM_USER/Desktop/
    sudo -u "$SYSTEM_USER" cp /usr/share/applications/noctispro-viewer.desktop /home/$SYSTEM_USER/Desktop/
    sudo -u "$SYSTEM_USER" cp /usr/share/applications/noctispro-worklist.desktop /home/$SYSTEM_USER/Desktop/
    sudo -u "$SYSTEM_USER" cp /usr/share/applications/noctispro-terminal.desktop /home/$SYSTEM_USER/Desktop/
    
    # Make desktop files executable
    chmod +x /home/$SYSTEM_USER/Desktop/*.desktop
    chown "$SYSTEM_USER:$SYSTEM_USER" /home/$SYSTEM_USER/Desktop/*.desktop
}

# Create autostart applications
create_autostart() {
    log "Creating autostart applications..."
    
    # Create autostart directory
    sudo -u "$SYSTEM_USER" mkdir -p /home/$SYSTEM_USER/.config/autostart
    
    # Auto-start browser with NoctisPro
    cat > /home/$SYSTEM_USER/.config/autostart/noctispro-browser.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=NoctisPro PACS Browser
Comment=Automatically open NoctisPro PACS in browser
Exec=bash -c "sleep 10 && firefox http://localhost"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=10
EOF
    
    # Auto-start system status notification
    cat > /home/$SYSTEM_USER/.config/autostart/noctispro-status.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=NoctisPro Status Notification
Comment=Show NoctisPro system status on startup
Exec=bash -c "sleep 15 && /usr/local/bin/noctispro-startup-notification"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=15
EOF
    
    chown -R "$SYSTEM_USER:$SYSTEM_USER" /home/$SYSTEM_USER/.config/autostart
}

# Create startup notification script
create_startup_notification() {
    log "Creating startup notification script..."
    
    cat > /usr/local/bin/noctispro-startup-notification << 'EOF'
#!/bin/bash

# Wait for services to start
sleep 5

# Check service status
if systemctl is-active --quiet noctispro; then
    STATUS="✅ NoctisPro PACS is running"
    URL="http://localhost"
else
    STATUS="❌ NoctisPro PACS is not running"
    URL=""
fi

# Show notification
if command -v notify-send &> /dev/null; then
    notify-send "NoctisPro PACS" "$STATUS" --icon=noctispro --urgency=normal
fi

# Create desktop notification file
cat > /home/noctispro/Desktop/System-Status.txt << EOL
NoctisPro PACS System Status
===========================
$(date)

$STATUS

Access URLs:
- Main Application: $URL
- Admin Panel: $URL/admin/
- DICOM Viewer: $URL/dicom_viewer/
- Worklist: $URL/worklist/

Management:
- Use desktop applications or terminal commands
- Run 'noctispro-admin status' for detailed status

EOL

chown noctispro:noctispro /home/noctispro/Desktop/System-Status.txt
EOF
    
    chmod +x /usr/local/bin/noctispro-startup-notification
}

# Create system tray integration (if available)
create_system_tray() {
    log "Creating system tray integration..."
    
    # Create system tray script
    cat > /usr/local/bin/noctispro-tray << 'EOF'
#!/bin/bash

# Simple system tray integration for NoctisPro
# This creates a menu in the system panel

create_menu() {
    cat > /tmp/noctispro-menu << 'MENU'
NoctisPro PACS|bash -c "firefox http://localhost"
Admin Panel|bash -c "firefox http://localhost/admin/"
DICOM Viewer|bash -c "firefox http://localhost/dicom_viewer/"
Worklist|bash -c "firefox http://localhost/worklist/"
---
Terminal|gnome-terminal
System Status|noctispro-admin status
Service Logs|noctispro-admin logs
---
Restart Services|noctispro-admin restart
Stop Services|noctispro-admin stop
MENU
}

# Check if system supports tray icons
if command -v yad &> /dev/null; then
    create_menu
    yad --notification --image=noctispro --text="NoctisPro PACS" --menu-file=/tmp/noctispro-menu &
fi
EOF
    
    chmod +x /usr/local/bin/noctispro-tray
    
    # Add to autostart if yad is available
    if command -v yad &> /dev/null; then
        cat > /home/$SYSTEM_USER/.config/autostart/noctispro-tray.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=NoctisPro System Tray
Comment=NoctisPro PACS system tray icon
Exec=/usr/local/bin/noctispro-tray
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=20
EOF
        chown "$SYSTEM_USER:$SYSTEM_USER" /home/$SYSTEM_USER/.config/autostart/noctispro-tray.desktop
    fi
}

# Create MIME type associations
create_mime_types() {
    log "Creating MIME type associations for DICOM files..."
    
    # Create DICOM MIME type
    cat > /usr/share/mime/packages/dicom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/dicom">
    <comment>DICOM medical image</comment>
    <comment xml:lang="en">DICOM medical image</comment>
    <glob pattern="*.dcm"/>
    <glob pattern="*.dicom"/>
    <glob pattern="*.DCM"/>
    <glob pattern="*.DICOM"/>
    <magic priority="50">
      <match type="string" offset="128" value="DICM"/>
    </magic>
  </mime-type>
</mime-info>
EOF
    
    # Update MIME database
    update-mime-database /usr/share/mime
    
    # Associate DICOM files with NoctisPro viewer
    cat > /usr/share/applications/defaults.list << 'EOF'
[Default Applications]
application/dicom=noctispro-viewer.desktop
EOF
}

# Create desktop theme customization
create_desktop_theme() {
    log "Creating desktop theme customization..."
    
    # Create custom wallpaper directory
    mkdir -p /usr/share/backgrounds/noctispro
    
    # Create a simple NoctisPro wallpaper (SVG)
    cat > /usr/share/backgrounds/noctispro/wallpaper.svg << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="1920" height="1080" viewBox="0 0 1920 1080" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#0f172a;stop-opacity:1" />
      <stop offset="50%" style="stop-color:#1e293b;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#334155;stop-opacity:1" />
    </linearGradient>
    <radialGradient id="glow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" style="stop-color:#3b82f6;stop-opacity:0.3" />
      <stop offset="100%" style="stop-color:#3b82f6;stop-opacity:0" />
    </radialGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <ellipse cx="960" cy="540" rx="400" ry="200" fill="url(#glow)"/>
  <circle cx="960" cy="540" r="80" fill="none" stroke="#3b82f6" stroke-width="3" opacity="0.7"/>
  <circle cx="960" cy="540" r="50" fill="none" stroke="#60a5fa" stroke-width="2" opacity="0.8"/>
  <circle cx="960" cy="540" r="20" fill="#3b82f6" opacity="0.9"/>
  <text x="960" y="650" text-anchor="middle" fill="#e2e8f0" font-family="Arial" font-size="36" font-weight="bold">NoctisPro PACS</text>
  <text x="960" y="690" text-anchor="middle" fill="#94a3b8" font-family="Arial" font-size="18">Medical Imaging System</text>
</svg>
EOF
    
    # Set wallpaper for user (GNOME)
    if command -v gsettings &> /dev/null; then
        sudo -u "$SYSTEM_USER" gsettings set org.gnome.desktop.background picture-uri "file:///usr/share/backgrounds/noctispro/wallpaper.svg" || true
        sudo -u "$SYSTEM_USER" gsettings set org.gnome.desktop.background picture-options "scaled" || true
    fi
}

# Create help documentation
create_help_documentation() {
    log "Creating help documentation..."
    
    cat > /home/$SYSTEM_USER/Desktop/NoctisPro-Help.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NoctisPro PACS - Help Guide</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        h1 { color: #1e3a8a; border-bottom: 2px solid #3b82f6; padding-bottom: 10px; }
        h2 { color: #3b82f6; }
        .section { margin: 20px 0; padding: 15px; background: #f8fafc; border-left: 4px solid #3b82f6; }
        .command { background: #1f2937; color: #f9fafb; padding: 10px; border-radius: 4px; font-family: monospace; }
        .url { color: #059669; font-weight: bold; }
        .warning { background: #fef3c7; border-left: 4px solid #f59e0b; padding: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>NoctisPro PACS - User Guide</h1>
        
        <div class="section">
            <h2>🏥 Quick Access</h2>
            <p><strong>Main Application:</strong> <span class="url">http://localhost</span></p>
            <p><strong>Admin Panel:</strong> <span class="url">http://localhost/admin/</span></p>
            <p><strong>DICOM Viewer:</strong> <span class="url">http://localhost/dicom_viewer/</span></p>
            <p><strong>Worklist:</strong> <span class="url">http://localhost/worklist/</span></p>
        </div>
        
        <div class="section">
            <h2>🔐 Login Credentials</h2>
            <p><strong>System User:</strong> noctispro / noctispro123</p>
            <p><strong>Django Admin:</strong> admin / admin123</p>
        </div>
        
        <div class="section">
            <h2>🖥️ Desktop Applications</h2>
            <ul>
                <li><strong>NoctisPro PACS:</strong> Main application launcher</li>
                <li><strong>NoctisPro Admin Panel:</strong> Administrative interface</li>
                <li><strong>DICOM Viewer:</strong> Medical image viewer</li>
                <li><strong>NoctisPro Worklist:</strong> Patient management</li>
                <li><strong>NoctisPro Terminal:</strong> System administration</li>
            </ul>
        </div>
        
        <div class="section">
            <h2>⚡ Management Commands</h2>
            <div class="command">
noctispro-admin start      # Start services
noctispro-admin stop       # Stop services
noctispro-admin restart    # Restart services
noctispro-admin status     # Check status
noctispro-admin logs       # View logs
noctispro-admin url        # Show URLs
            </div>
        </div>
        
        <div class="section">
            <h2>🔒 SSL Commands</h2>
            <div class="command">
noctispro-ssl renew        # Renew SSL certificates
noctispro-ssl status       # Check certificate status
noctispro-ssl test         # Test SSL configuration
            </div>
        </div>
        
        <div class="section">
            <h2>🚀 Features</h2>
            <ul>
                <li><strong>Medical Imaging:</strong> DICOM viewer with support for CT, MR, CR, DX, US, XA</li>
                <li><strong>AI Analysis:</strong> Automated medical image analysis</li>
                <li><strong>Worklist Management:</strong> Patient and study management</li>
                <li><strong>User Management:</strong> Role-based access control</li>
                <li><strong>Reports:</strong> Comprehensive reporting system</li>
                <li><strong>Communication:</strong> Built-in chat system</li>
                <li><strong>Notifications:</strong> Real-time alerts</li>
            </ul>
        </div>
        
        <div class="warning">
            <h2>⚠️ Important Notes</h2>
            <p>This is a medical imaging system. Please ensure compliance with local healthcare regulations and data protection laws.</p>
            <p>Always backup your data before making system changes.</p>
        </div>
        
        <div class="section">
            <h2>🔧 Troubleshooting</h2>
            <p>If you encounter issues:</p>
            <ol>
                <li>Check service status: <code>noctispro-admin status</code></li>
                <li>View logs: <code>noctispro-admin logs</code></li>
                <li>Restart services: <code>noctispro-admin restart</code></li>
                <li>Check system status file on desktop</li>
            </ol>
        </div>
    </div>
</body>
</html>
EOF
    
    chown "$SYSTEM_USER:$SYSTEM_USER" /home/$SYSTEM_USER/Desktop/NoctisPro-Help.html
}

# Main function
main() {
    log "Setting up NoctisPro PACS desktop integration..."
    
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
    
    create_app_icon
    create_desktop_applications
    create_user_shortcuts
    create_autostart
    create_startup_notification
    create_system_tray
    create_mime_types
    create_desktop_theme
    create_help_documentation
    
    # Update desktop database
    update-desktop-database /usr/share/applications
    
    # Install yad for better GUI integration (optional)
    apt install -y yad || warning "Could not install yad for enhanced GUI features"
    
    log "Desktop integration setup completed!"
    log "User will see NoctisPro applications in the applications menu and desktop"
}

# Run main function
main "$@"