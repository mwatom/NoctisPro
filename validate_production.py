#!/usr/bin/env python3
"""
Production Validation Script for NoctisPro
This script validates all functionality, UI consistency, and production readiness.
"""

import os
import sys
import django
from pathlib import Path
import importlib
import subprocess
import json

# Setup Django environment
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings_production')

try:
    django.setup()
except Exception as e:
    print(f"❌ Django setup failed: {e}")
    sys.exit(1)

from django.core.management import call_command
from django.test.utils import get_runner
from django.conf import settings
from django.urls import reverse
from django.contrib.auth import get_user_model
from accounts.models import Facility
from worklist.models import Study, Patient
from django.db import connection

class ProductionValidator:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.success = []
        
    def log_error(self, message):
        self.errors.append(message)
        print(f"❌ {message}")
        
    def log_warning(self, message):
        self.warnings.append(message)
        print(f"⚠️  {message}")
        
    def log_success(self, message):
        self.success.append(message)
        print(f"✅ {message}")
        
    def validate_database_models(self):
        """Validate all database models and relationships"""
        print("\n🔍 Validating Database Models...")
        
        try:
            # Check database connection
            connection.ensure_connection()
            self.log_success("Database connection established")
            
            # Check if migrations are applied
            from django.db.migrations.executor import MigrationExecutor
            executor = MigrationExecutor(connection)
            if executor.migration_plan(executor.loader.graph.leaf_nodes()):
                self.log_error("Unapplied migrations detected")
            else:
                self.log_success("All migrations applied")
                
            # Test model creation
            User = get_user_model()
            
            # Check if essential models exist
            models_to_check = [
                (User, "User model"),
                (Facility, "Facility model"),
                (Patient, "Patient model"),
                (Study, "Study model"),
            ]
            
            for model, name in models_to_check:
                try:
                    model.objects.count()
                    self.log_success(f"{name} accessible")
                except Exception as e:
                    self.log_error(f"{name} error: {e}")
                    
        except Exception as e:
            self.log_error(f"Database validation failed: {e}")
            
    def validate_url_patterns(self):
        """Validate all URL patterns are accessible"""
        print("\n🔍 Validating URL Patterns...")
        
        from django.urls import get_resolver
        from django.urls.exceptions import NoReverseMatch
        
        # Core URL patterns to test
        url_patterns = [
            'accounts:login',
            'accounts:logout',
            'worklist:dashboard',
            'worklist:study_list',
            'worklist:upload_study',
            'reports:report_list',
            'admin_panel:dashboard',
            'chat:chat_rooms',
            'notifications:notification_list',
            'dicom_viewer:index',
        ]
        
        for pattern in url_patterns:
            try:
                url = reverse(pattern)
                self.log_success(f"URL pattern '{pattern}' -> {url}")
            except NoReverseMatch as e:
                self.log_error(f"URL pattern '{pattern}' failed: {e}")
            except Exception as e:
                self.log_warning(f"URL pattern '{pattern}' warning: {e}")
                
    def validate_templates(self):
        """Validate template structure and consistency"""
        print("\n🔍 Validating Templates...")
        
        template_dirs = settings.TEMPLATES[0]['DIRS']
        if not template_dirs:
            self.log_error("No template directories configured")
            return
            
        template_dir = Path(template_dirs[0])
        if not template_dir.exists():
            self.log_error(f"Template directory doesn't exist: {template_dir}")
            return
            
        # Check essential templates
        essential_templates = [
            'base.html',
            'accounts/login.html',
            'worklist/dashboard.html',
            'worklist/study_list.html',
            'dicom_viewer/viewer.html',
        ]
        
        for template in essential_templates:
            template_path = template_dir / template
            if template_path.exists():
                self.log_success(f"Template exists: {template}")
                
                # Basic template validation
                try:
                    content = template_path.read_text()
                    if 'btn-medical' in content or 'btn-control' in content or 'btn-viewer' in content:
                        self.log_success(f"Template uses consistent button classes: {template}")
                    else:
                        self.log_warning(f"Template may not use consistent button classes: {template}")
                        
                    # Check for common template issues
                    if '{{' in content and '}}' in content:
                        self.log_success(f"Template has Django template tags: {template}")
                        
                except Exception as e:
                    self.log_warning(f"Could not validate template content: {template} - {e}")
            else:
                self.log_error(f"Template missing: {template}")
                
    def validate_static_files(self):
        """Validate static files configuration"""
        print("\n🔍 Validating Static Files...")
        
        # Check static files settings
        if hasattr(settings, 'STATIC_URL') and settings.STATIC_URL:
            self.log_success(f"STATIC_URL configured: {settings.STATIC_URL}")
        else:
            self.log_error("STATIC_URL not configured")
            
        if hasattr(settings, 'STATIC_ROOT') and settings.STATIC_ROOT:
            self.log_success(f"STATIC_ROOT configured: {settings.STATIC_ROOT}")
        else:
            self.log_warning("STATIC_ROOT not configured")
            
        # Check if static directory exists
        static_dir = Path('static')
        if static_dir.exists():
            self.log_success("Static directory exists")
        else:
            self.log_warning("Static directory doesn't exist")
            
    def validate_apps_configuration(self):
        """Validate Django apps configuration"""
        print("\n🔍 Validating Apps Configuration...")
        
        required_apps = [
            'django.contrib.admin',
            'django.contrib.auth',
            'django.contrib.contenttypes',
            'django.contrib.sessions',
            'django.contrib.messages',
            'django.contrib.staticfiles',
            'rest_framework',
            'corsheaders',
            'channels',
            'accounts',
            'worklist',
            'dicom_viewer',
            'reports',
            'notifications',
            'chat',
            'ai_analysis',
            'admin_panel',
        ]
        
        for app in required_apps:
            if app in settings.INSTALLED_APPS:
                self.log_success(f"App installed: {app}")
                
                # Try to import the app
                try:
                    if '.' not in app:  # Custom apps
                        importlib.import_module(app)
                        self.log_success(f"App importable: {app}")
                except ImportError as e:
                    self.log_error(f"App import failed: {app} - {e}")
            else:
                self.log_error(f"App not installed: {app}")
                
    def validate_middleware(self):
        """Validate middleware configuration"""
        print("\n🔍 Validating Middleware...")
        
        required_middleware = [
            'django.middleware.security.SecurityMiddleware',
            'whitenoise.middleware.WhiteNoiseMiddleware',
            'django.contrib.sessions.middleware.SessionMiddleware',
            'corsheaders.middleware.CorsMiddleware',
            'django.middleware.common.CommonMiddleware',
            'django.middleware.csrf.CsrfViewMiddleware',
            'django.contrib.auth.middleware.AuthenticationMiddleware',
            'django.contrib.messages.middleware.MessageMiddleware',
            'django.middleware.clickjacking.XFrameOptionsMiddleware',
        ]
        
        for middleware in required_middleware:
            if middleware in settings.MIDDLEWARE:
                self.log_success(f"Middleware configured: {middleware}")
            else:
                self.log_error(f"Middleware missing: {middleware}")
                
    def validate_security_settings(self):
        """Validate security settings for production"""
        print("\n🔍 Validating Security Settings...")
        
        # Check DEBUG setting
        if not settings.DEBUG:
            self.log_success("DEBUG is False (production ready)")
        else:
            self.log_error("DEBUG is True (not production ready)")
            
        # Check SECRET_KEY
        if hasattr(settings, 'SECRET_KEY') and settings.SECRET_KEY:
            if settings.SECRET_KEY.startswith('django-insecure-'):
                self.log_error("Using insecure SECRET_KEY")
            else:
                self.log_success("SECRET_KEY configured")
        else:
            self.log_error("SECRET_KEY not configured")
            
        # Check ALLOWED_HOSTS
        if settings.ALLOWED_HOSTS and settings.ALLOWED_HOSTS != ['*']:
            self.log_success(f"ALLOWED_HOSTS configured: {settings.ALLOWED_HOSTS}")
        else:
            self.log_warning("ALLOWED_HOSTS allows all hosts (consider restricting)")
            
        # Check security middleware
        security_settings = [
            ('SECURE_BROWSER_XSS_FILTER', True),
            ('SECURE_CONTENT_TYPE_NOSNIFF', True),
            ('X_FRAME_OPTIONS', 'DENY'),
        ]
        
        for setting, expected in security_settings:
            if hasattr(settings, setting):
                value = getattr(settings, setting)
                if value == expected:
                    self.log_success(f"{setting} properly configured")
                else:
                    self.log_warning(f"{setting} set to {value}, expected {expected}")
            else:
                self.log_warning(f"{setting} not configured")
                
    def validate_database_settings(self):
        """Validate database configuration"""
        print("\n🔍 Validating Database Settings...")
        
        db_config = settings.DATABASES.get('default', {})
        engine = db_config.get('ENGINE', '')
        
        if 'postgresql' in engine:
            self.log_success("Using PostgreSQL database (production ready)")
            
            # Check required database settings
            required_keys = ['NAME', 'USER', 'PASSWORD', 'HOST', 'PORT']
            for key in required_keys:
                if db_config.get(key):
                    self.log_success(f"Database {key} configured")
                else:
                    self.log_error(f"Database {key} not configured")
        elif 'sqlite' in engine:
            self.log_warning("Using SQLite database (not recommended for production)")
        else:
            self.log_error(f"Unknown database engine: {engine}")
            
    def validate_cache_settings(self):
        """Validate cache configuration"""
        print("\n🔍 Validating Cache Settings...")
        
        if hasattr(settings, 'CACHES') and 'default' in settings.CACHES:
            cache_backend = settings.CACHES['default'].get('BACKEND', '')
            if 'redis' in cache_backend.lower():
                self.log_success("Redis cache configured")
            else:
                self.log_warning(f"Cache backend: {cache_backend}")
        else:
            self.log_warning("No cache configuration found")
            
    def validate_channels_settings(self):
        """Validate WebSocket/Channels configuration"""
        print("\n🔍 Validating Channels Settings...")
        
        if hasattr(settings, 'CHANNEL_LAYERS'):
            backend = settings.CHANNEL_LAYERS.get('default', {}).get('BACKEND', '')
            if 'redis' in backend.lower():
                self.log_success("Redis channels backend configured")
            else:
                self.log_warning(f"Channels backend: {backend}")
        else:
            self.log_warning("No channels configuration found")
            
        if hasattr(settings, 'ASGI_APPLICATION'):
            self.log_success(f"ASGI application configured: {settings.ASGI_APPLICATION}")
        else:
            self.log_error("ASGI application not configured")
            
    def check_button_consistency(self):
        """Check for consistent button classes across templates"""
        print("\n🔍 Checking Button Consistency...")
        
        template_dir = Path('templates')
        if not template_dir.exists():
            self.log_error("Templates directory not found")
            return
            
        button_classes = ['btn-medical', 'btn-control', 'btn-viewer', 'btn-upload']
        inconsistent_files = []
        
        for template_file in template_dir.rglob('*.html'):
            try:
                content = template_file.read_text()
                
                # Check if file uses buttons but not consistent classes
                if 'button' in content.lower() or 'btn' in content:
                    has_consistent_classes = any(btn_class in content for btn_class in button_classes)
                    if not has_consistent_classes and '<button' in content:
                        inconsistent_files.append(str(template_file))
                        
            except Exception as e:
                self.log_warning(f"Could not check button consistency in {template_file}: {e}")
                
        if inconsistent_files:
            self.log_warning(f"Templates with potentially inconsistent buttons: {len(inconsistent_files)}")
            for file in inconsistent_files[:5]:  # Show first 5
                self.log_warning(f"  - {file}")
        else:
            self.log_success("Button classes appear consistent across templates")
            
    def run_all_validations(self):
        """Run all validation checks"""
        print("🚀 Starting Production Validation for NoctisPro...")
        print("=" * 60)
        
        validations = [
            self.validate_database_models,
            self.validate_url_patterns,
            self.validate_templates,
            self.validate_static_files,
            self.validate_apps_configuration,
            self.validate_middleware,
            self.validate_security_settings,
            self.validate_database_settings,
            self.validate_cache_settings,
            self.validate_channels_settings,
            self.check_button_consistency,
        ]
        
        for validation in validations:
            try:
                validation()
            except Exception as e:
                self.log_error(f"Validation failed: {validation.__name__} - {e}")
                
        # Summary
        print("\n" + "=" * 60)
        print("📊 VALIDATION SUMMARY")
        print("=" * 60)
        print(f"✅ Success: {len(self.success)}")
        print(f"⚠️  Warnings: {len(self.warnings)}")
        print(f"❌ Errors: {len(self.errors)}")
        
        if self.errors:
            print(f"\n❌ CRITICAL ISSUES ({len(self.errors)}):")
            for error in self.errors:
                print(f"  - {error}")
                
        if self.warnings:
            print(f"\n⚠️  WARNINGS ({len(self.warnings)}):")
            for warning in self.warnings[:10]:  # Show first 10
                print(f"  - {warning}")
            if len(self.warnings) > 10:
                print(f"  ... and {len(self.warnings) - 10} more warnings")
                
        # Overall status
        if not self.errors:
            if not self.warnings:
                print("\n🎉 PRODUCTION READY! All validations passed.")
                return True
            else:
                print(f"\n✅ MOSTLY READY! {len(self.warnings)} warnings to review.")
                return True
        else:
            print(f"\n❌ NOT PRODUCTION READY! {len(self.errors)} critical issues to fix.")
            return False

if __name__ == '__main__':
    validator = ProductionValidator()
    is_ready = validator.run_all_validations()
    sys.exit(0 if is_ready else 1)