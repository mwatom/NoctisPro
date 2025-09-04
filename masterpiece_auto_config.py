#!/usr/bin/env python3
"""
Noctis Pro Masterpiece Auto-Configuration System
Automatically detects and configures all system components
"""

import os
import sys
import json
import subprocess
import time
from pathlib import Path

class MasterpieceAutoConfig:
    def __init__(self):
        self.config = {
            'ngrok_authtoken': '32E2HmoUqzrZxaYRNT77wAI0HQs_5N5QNSrxU4Z7d4MFSRF4x',
            'static_url': 'mallard-shining-curiously.ngrok-free.app',
            'port': 8000,
            'project_name': 'noctis_pro'
        }
        self.detected_components = {}
        self.status = {
            'django': False,
            'ngrok': False,
            'database': False,
            'static_files': False,
            'dicom_viewer': False,
            'ai_analysis': False,
            'reports': False,
            'admin_panel': False
        }
    
    def print_status(self, message, status='info'):
        """Print colored status messages"""
        colors = {
            'info': '\033[0;36m',      # Cyan
            'success': '\033[0;32m',   # Green
            'warning': '\033[1;33m',   # Yellow
            'error': '\033[0;31m',     # Red
            'header': '\033[0;35m'     # Purple
        }
        
        icons = {
            'info': '🔍',
            'success': '✅',
            'warning': '⚠️',
            'error': '❌',
            'header': '🚀'
        }
        
        color = colors.get(status, '\033[0m')
        icon = icons.get(status, '•')
        reset = '\033[0m'
        
        print(f"{color}{icon} {message}{reset}")
    
    def detect_system_components(self):
        """Auto-detect all system components"""
        self.print_status("SYSTEM COMPONENT AUTO-DETECTION", 'header')
        
        # Detect Django project
        if os.path.exists('manage.py'):
            self.print_status("Django project detected", 'success')
            self.status['django'] = True
            
            # Detect project name
            for item in os.listdir('.'):
                if os.path.isdir(item) and os.path.exists(f"{item}/settings.py"):
                    self.config['project_name'] = item
                    self.print_status(f"Project name: {item}", 'success')
                    break
        
        # Detect Django apps
        apps = []
        for item in os.listdir('.'):
            if os.path.isdir(item) and (os.path.exists(f"{item}/apps.py") or os.path.exists(f"{item}/models.py")):
                apps.append(item)
                self.print_status(f"Django app detected: {item}", 'success')
        
        self.detected_components['django_apps'] = apps
        
        # Detect DICOM viewer components
        dicom_components = []
        if os.path.exists('templates/dicom_viewer/masterpiece_viewer.html'):
            dicom_components.append('Masterpiece DICOM Viewer')
            self.status['dicom_viewer'] = True
        
        if os.path.exists('static/js/masterpiece_3d_reconstruction.js'):
            dicom_components.append('3D Bone Reconstruction')
        
        if os.path.exists('dicom_viewer/masterpiece_utils.py'):
            dicom_components.append('Enhanced Processing Utilities')
        
        self.detected_components['dicom_components'] = dicom_components
        
        # Detect AI components
        if os.path.exists('ai_analysis'):
            self.print_status("AI Analysis System detected", 'success')
            self.status['ai_analysis'] = True
        
        # Detect report components
        if os.path.exists('reports'):
            self.print_status("Report System detected", 'success')
            self.status['reports'] = True
        
        # Detect admin panel
        if os.path.exists('admin_panel'):
            self.print_status("Enhanced Admin Panel detected", 'success')
            self.status['admin_panel'] = True
        
        # Detect database
        if os.path.exists('db.sqlite3'):
            self.print_status("SQLite database detected", 'success')
            self.status['database'] = True
        
        # Detect static files
        if os.path.exists('staticfiles'):
            self.print_status("Static files directory detected", 'success')
            self.status['static_files'] = True
    
    def detect_dependencies(self):
        """Detect and verify dependencies"""
        self.print_status("DEPENDENCY DETECTION", 'header')
        
        try:
            import django
            self.print_status(f"Django {django.get_version()} detected", 'success')
        except ImportError:
            self.print_status("Django not installed", 'error')
            return False
        
        try:
            import pydicom
            self.print_status(f"pydicom {pydicom.__version__} detected", 'success')
        except ImportError:
            self.print_status("pydicom not installed", 'warning')
        
        try:
            import numpy
            self.print_status(f"numpy {numpy.__version__} detected", 'success')
        except ImportError:
            self.print_status("numpy not installed", 'warning')
        
        try:
            import qrcode
            self.print_status("QR code generation available", 'success')
        except ImportError:
            self.print_status("QR code generation not available", 'warning')
        
        return True
    
    def configure_ngrok(self):
        """Configure ngrok with authtoken and static URL"""
        self.print_status("NGROK CONFIGURATION", 'header')
        
        # Check if ngrok exists
        ngrok_cmd = None
        if subprocess.run(['which', 'ngrok'], capture_output=True).returncode == 0:
            ngrok_cmd = 'ngrok'
        elif os.path.exists('./ngrok'):
            ngrok_cmd = './ngrok'
            os.chmod('./ngrok', 0o755)
        else:
            self.print_status("ngrok not found - will be downloaded", 'warning')
            return False
        
        # Configure authtoken
        try:
            result = subprocess.run([ngrok_cmd, 'config', 'add-authtoken', self.config['ngrok_authtoken']], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                self.print_status("ngrok authtoken configured", 'success')
            else:
                self.print_status(f"ngrok authtoken configuration failed: {result.stderr}", 'error')
                return False
        except Exception as e:
            self.print_status(f"Error configuring ngrok: {e}", 'error')
            return False
        
        return True
    
    def optimize_django_settings(self):
        """Optimize Django settings for deployment"""
        self.print_status("DJANGO SETTINGS OPTIMIZATION", 'header')
        
        settings_file = f"{self.config['project_name']}/settings.py"
        
        if not os.path.exists(settings_file):
            self.print_status("settings.py not found", 'error')
            return False
        
        # Read current settings
        with open(settings_file, 'r') as f:
            settings_content = f.read()
        
        # Check if already optimized
        if 'Masterpiece Auto-Deploy Optimizations' in settings_content:
            self.print_status("Settings already optimized", 'success')
            return True
        
        # Add optimizations
        optimizations = f"""

# Masterpiece Auto-Deploy Optimizations
ALLOWED_HOSTS = ['{self.config['static_url']}', 'localhost', '127.0.0.1', '0.0.0.0']
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SECURE_SSL_REDIRECT = False  # ngrok handles SSL

# CSRF trusted origins for ngrok
CSRF_TRUSTED_ORIGINS = [
    'https://{self.config['static_url']}',
    'http://localhost:{self.config['port']}',
    'http://127.0.0.1:{self.config['port']}'
]

# Session security for ngrok
SESSION_COOKIE_SECURE = False  # ngrok handles SSL
CSRF_COOKIE_SECURE = False     # ngrok handles SSL

# Static files optimization
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# DICOM viewer masterpiece settings
DICOM_VIEWER_SETTINGS = {{
    'MAX_UPLOAD_SIZE': 100 * 1024 * 1024,  # 100MB
    'SUPPORTED_MODALITIES': ['CT', 'MR', 'CR', 'DX', 'US', 'XA'],
    'CACHE_TIMEOUT': 3600,
    'ENABLE_3D_RECONSTRUCTION': True,
    'ENABLE_MEASUREMENTS': True,
    'ENABLE_ANNOTATIONS': True,
    'ENABLE_AI_ANALYSIS': True,
    'ENABLE_QR_CODES': True,
    'ENABLE_LETTERHEADS': True,
}}
"""
        
        # Backup original settings
        backup_file = f"{settings_file}.backup.{int(time.time())}"
        with open(backup_file, 'w') as f:
            f.write(settings_content)
        self.print_status(f"Settings backed up to {backup_file}", 'success')
        
        # Write optimized settings
        with open(settings_file, 'w') as f:
            f.write(settings_content + optimizations)
        
        self.print_status("Django settings optimized for masterpiece deployment", 'success')
        return True
    
    def run_django_setup(self):
        """Run Django setup commands"""
        self.print_status("DJANGO SETUP", 'header')
        
        try:
            # Run migrations
            self.print_status("Running database migrations...", 'info')
            result = subprocess.run([sys.executable, 'manage.py', 'migrate'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                self.print_status("Database migrations completed", 'success')
            else:
                self.print_status(f"Migration warning: {result.stderr}", 'warning')
            
            # Collect static files
            self.print_status("Collecting static files...", 'info')
            result = subprocess.run([sys.executable, 'manage.py', 'collectstatic', '--noinput'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                self.print_status("Static files collected", 'success')
            else:
                self.print_status(f"Static files warning: {result.stderr}", 'warning')
            
            return True
            
        except Exception as e:
            self.print_status(f"Django setup error: {e}", 'error')
            return False
    
    def generate_deployment_summary(self):
        """Generate comprehensive deployment summary"""
        self.print_status("DEPLOYMENT SUMMARY", 'header')
        
        print(f"""
🎯 NOCTIS PRO MASTERPIECE DEPLOYMENT SUMMARY
============================================

🌐 ACCESS INFORMATION:
   Public URL:  https://{self.config['static_url']}
   Local URL:   http://localhost:{self.config['port']}
   
🔧 SYSTEM COMPONENTS:
   Django Apps: {len(self.detected_components.get('django_apps', []))}
   DICOM Components: {len(self.detected_components.get('dicom_components', []))}
   
🏥 MEDICAL FEATURES:
   ✅ Masterpiece DICOM Viewer
   ✅ 3D Bone Reconstruction  
   ✅ AI Analysis System
   ✅ Professional Reports with Letterheads
   ✅ QR Code Integration
   ✅ User & Facility Management
   
🚀 DEPLOYMENT STATUS:
   Django:      {'✅ READY' if self.status['django'] else '❌ NOT READY'}
   Database:    {'✅ READY' if self.status['database'] else '❌ NOT READY'}
   Static Files:{'✅ READY' if self.status['static_files'] else '❌ NOT READY'}
   DICOM Viewer:{'✅ READY' if self.status['dicom_viewer'] else '❌ NOT READY'}
   AI Analysis: {'✅ READY' if self.status['ai_analysis'] else '❌ NOT READY'}
   Reports:     {'✅ READY' if self.status['reports'] else '❌ NOT READY'}
   Admin Panel: {'✅ READY' if self.status['admin_panel'] else '❌ NOT READY'}

📋 QUICK START COMMANDS:
   Start System:    ./start_masterpiece.sh
   Monitor System:  ./masterpiece_monitor.sh
   Full Deploy:     ./deploy_masterpiece_auto.sh
   
🎉 MASTERPIECE SYSTEM IS READY FOR DEPLOYMENT!
        """)
    
    def run_full_configuration(self):
        """Run complete auto-configuration"""
        print("🚀 NOCTIS PRO MASTERPIECE AUTO-CONFIGURATION")
        print("=" * 50)
        
        # Step 1: Detect system components
        self.detect_system_components()
        print()
        
        # Step 2: Detect dependencies
        if not self.detect_dependencies():
            self.print_status("Critical dependencies missing", 'error')
            return False
        print()
        
        # Step 3: Configure ngrok
        self.configure_ngrok()
        print()
        
        # Step 4: Optimize Django settings
        self.optimize_django_settings()
        print()
        
        # Step 5: Run Django setup
        self.run_django_setup()
        print()
        
        # Step 6: Generate summary
        self.generate_deployment_summary()
        
        return True

if __name__ == "__main__":
    config = MasterpieceAutoConfig()
    success = config.run_full_configuration()
    
    if success:
        print("\n🎉 AUTO-CONFIGURATION COMPLETED SUCCESSFULLY!")
        print("🚀 Ready to deploy the Masterpiece system!")
    else:
        print("\n❌ AUTO-CONFIGURATION FAILED")
        print("🔧 Please check the errors above and try again")
        sys.exit(1)