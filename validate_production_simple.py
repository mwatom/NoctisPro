#!/usr/bin/env python3
"""
Simple Production Validation Script for NoctisPro
This script validates the codebase structure without requiring Django to be running.
"""

import os
import re
from pathlib import Path

class SimpleValidator:
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
        
    def check_file_structure(self):
        """Check essential file structure"""
        print("\n🔍 Checking File Structure...")
        
        essential_files = [
            'manage.py',
            'requirements.txt',
            'deploy_noctis_production.sh',
            'setup_secure_access.sh',
            'noctis_pro/settings_production.py',
            'noctis_pro/urls.py',
            'templates/base.html',
            'static/css/noctis-global.css',
        ]
        
        for file_path in essential_files:
            if Path(file_path).exists():
                self.log_success(f"File exists: {file_path}")
            else:
                self.log_error(f"Missing file: {file_path}")
                
    def check_django_apps(self):
        """Check Django app structure"""
        print("\n🔍 Checking Django Apps...")
        
        apps = [
            'accounts',
            'worklist', 
            'dicom_viewer',
            'reports',
            'notifications',
            'chat',
            'ai_analysis',
            'admin_panel',
        ]
        
        for app in apps:
            app_dir = Path(app)
            if app_dir.exists():
                self.log_success(f"App directory exists: {app}")
                
                # Check essential app files
                essential_app_files = [
                    f'{app}/__init__.py',
                    f'{app}/models.py',
                    f'{app}/views.py',
                    f'{app}/urls.py',
                ]
                
                for file_path in essential_app_files:
                    if Path(file_path).exists():
                        self.log_success(f"App file exists: {file_path}")
                    else:
                        self.log_error(f"Missing app file: {file_path}")
            else:
                self.log_error(f"App directory missing: {app}")
                
    def check_templates(self):
        """Check template structure and button consistency"""
        print("\n🔍 Checking Templates...")
        
        template_dir = Path('templates')
        if not template_dir.exists():
            self.log_error("Templates directory missing")
            return
            
        template_files = list(template_dir.rglob('*.html'))
        self.log_success(f"Found {len(template_files)} template files")
        
        # Check for consistent button classes
        consistent_button_files = 0
        inconsistent_files = []
        
        for template_file in template_files:
            try:
                content = template_file.read_text()
                
                # Check for consistent button classes
                has_buttons = '<button' in content or 'btn-' in content
                if has_buttons:
                    consistent_classes = ['btn-medical', 'btn-control', 'btn-viewer', 'btn-upload']
                    has_consistent = any(cls in content for cls in consistent_classes)
                    
                    if has_consistent:
                        consistent_button_files += 1
                    else:
                        inconsistent_files.append(str(template_file))
                        
            except Exception as e:
                self.log_warning(f"Could not check template: {template_file} - {e}")
                
        if inconsistent_files:
            self.log_warning(f"{len(inconsistent_files)} templates may have inconsistent buttons")
        else:
            self.log_success(f"All {consistent_button_files} templates with buttons use consistent classes")
            
    def check_url_patterns(self):
        """Check URL pattern files"""
        print("\n🔍 Checking URL Patterns...")
        
        url_files = [
            'noctis_pro/urls.py',
            'accounts/urls.py',
            'worklist/urls.py',
            'dicom_viewer/urls.py',
            'reports/urls.py',
            'admin_panel/urls.py',
            'chat/urls.py',
            'notifications/urls.py',
        ]
        
        for url_file in url_files:
            if Path(url_file).exists():
                self.log_success(f"URL file exists: {url_file}")
                
                try:
                    content = Path(url_file).read_text()
                    if 'urlpatterns' in content:
                        self.log_success(f"URL patterns defined in: {url_file}")
                    else:
                        self.log_warning(f"No urlpatterns found in: {url_file}")
                        
                except Exception as e:
                    self.log_warning(f"Could not read URL file: {url_file} - {e}")
            else:
                self.log_error(f"URL file missing: {url_file}")
                
    def check_settings_files(self):
        """Check Django settings"""
        print("\n🔍 Checking Settings Files...")
        
        settings_files = [
            'noctis_pro/settings.py',
            'noctis_pro/settings_production.py',
        ]
        
        for settings_file in settings_files:
            if Path(settings_file).exists():
                self.log_success(f"Settings file exists: {settings_file}")
                
                try:
                    content = Path(settings_file).read_text()
                    
                    # Check for production settings
                    if 'production' in settings_file:
                        if 'DEBUG = False' in content:
                            self.log_success("DEBUG is False in production settings")
                        else:
                            self.log_error("DEBUG not set to False in production settings")
                            
                        if 'postgresql' in content.lower():
                            self.log_success("PostgreSQL configured in production settings")
                        else:
                            self.log_warning("PostgreSQL not found in production settings")
                            
                        if 'redis' in content.lower():
                            self.log_success("Redis configured in production settings")
                        else:
                            self.log_warning("Redis not found in production settings")
                            
                except Exception as e:
                    self.log_warning(f"Could not read settings file: {settings_file} - {e}")
            else:
                self.log_error(f"Settings file missing: {settings_file}")
                
    def check_deployment_scripts(self):
        """Check deployment scripts"""
        print("\n🔍 Checking Deployment Scripts...")
        
        deployment_files = [
            'deploy_noctis_production.sh',
            'setup_secure_access.sh',
            'setup_ssl.sh',
        ]
        
        for script in deployment_files:
            script_path = Path(script)
            if script_path.exists():
                self.log_success(f"Deployment script exists: {script}")
                
                # Check if executable
                if os.access(script_path, os.X_OK):
                    self.log_success(f"Script is executable: {script}")
                else:
                    self.log_warning(f"Script not executable: {script}")
                    
                # Check script content
                try:
                    content = script_path.read_text()
                    if script == 'deploy_noctis_production.sh':
                        if 'postgresql' in content.lower():
                            self.log_success("PostgreSQL setup found in deployment script")
                        if 'nginx' in content.lower():
                            self.log_success("Nginx setup found in deployment script")
                        if 'systemctl' in content:
                            self.log_success("Systemd services setup found in deployment script")
                            
                except Exception as e:
                    self.log_warning(f"Could not read script: {script} - {e}")
            else:
                self.log_error(f"Deployment script missing: {script}")
                
    def check_requirements(self):
        """Check requirements.txt"""
        print("\n🔍 Checking Requirements...")
        
        req_file = Path('requirements.txt')
        if req_file.exists():
            self.log_success("requirements.txt exists")
            
            try:
                content = req_file.read_text()
                
                essential_packages = [
                    'Django',
                    'psycopg2-binary',
                    'redis',
                    'gunicorn',
                    'nginx', # This might not be in requirements
                    'channels',
                    'daphne',
                    'celery',
                ]
                
                for package in essential_packages:
                    if package.lower() in content.lower():
                        self.log_success(f"Package found: {package}")
                    else:
                        if package == 'nginx':
                            self.log_warning(f"Package not in requirements (installed via system): {package}")
                        else:
                            self.log_error(f"Package missing from requirements: {package}")
                            
            except Exception as e:
                self.log_warning(f"Could not read requirements.txt: {e}")
        else:
            self.log_error("requirements.txt missing")
            
    def check_static_files(self):
        """Check static files setup"""
        print("\n🔍 Checking Static Files...")
        
        static_dir = Path('static')
        if static_dir.exists():
            self.log_success("Static directory exists")
            
            css_file = static_dir / 'css' / 'noctis-global.css'
            if css_file.exists():
                self.log_success("Global CSS file exists")
                
                try:
                    content = css_file.read_text()
                    if ':root' in content and '--primary-bg' in content:
                        self.log_success("CSS variables defined in global CSS")
                    if 'btn-medical' in content:
                        self.log_success("Consistent button styles defined")
                        
                except Exception as e:
                    self.log_warning(f"Could not read CSS file: {e}")
            else:
                self.log_error("Global CSS file missing")
        else:
            self.log_warning("Static directory missing (will be created during deployment)")
            
    def check_removed_test_files(self):
        """Check that test files have been removed"""
        print("\n🔍 Checking Test Files Removal...")
        
        # Check for test files that should be removed
        test_patterns = [
            'test_*.py',
            '**/tests.py',
            '**/*test*.py',
        ]
        
        found_test_files = []
        for pattern in test_patterns:
            for file_path in Path('.').rglob(pattern):
                if 'validate_production' not in str(file_path):  # Exclude our validation scripts
                    found_test_files.append(str(file_path))
                    
        if found_test_files:
            self.log_warning(f"Found {len(found_test_files)} potential test files:")
            for file_path in found_test_files[:5]:  # Show first 5
                self.log_warning(f"  - {file_path}")
        else:
            self.log_success("No test files found (properly cleaned)")
            
    def run_all_checks(self):
        """Run all validation checks"""
        print("🚀 Starting Simple Production Validation for NoctisPro...")
        print("=" * 70)
        
        checks = [
            self.check_file_structure,
            self.check_django_apps,
            self.check_templates,
            self.check_url_patterns,
            self.check_settings_files,
            self.check_deployment_scripts,
            self.check_requirements,
            self.check_static_files,
            self.check_removed_test_files,
        ]
        
        for check in checks:
            try:
                check()
            except Exception as e:
                self.log_error(f"Check failed: {check.__name__} - {e}")
                
        # Summary
        print("\n" + "=" * 70)
        print("📊 VALIDATION SUMMARY")
        print("=" * 70)
        print(f"✅ Success: {len(self.success)}")
        print(f"⚠️  Warnings: {len(self.warnings)}")
        print(f"❌ Errors: {len(self.errors)}")
        
        if self.errors:
            print(f"\n❌ CRITICAL ISSUES ({len(self.errors)}):")
            for error in self.errors[:10]:  # Show first 10
                print(f"  - {error}")
            if len(self.errors) > 10:
                print(f"  ... and {len(self.errors) - 10} more errors")
                
        if self.warnings:
            print(f"\n⚠️  WARNINGS ({len(self.warnings)}):")
            for warning in self.warnings[:10]:  # Show first 10
                print(f"  - {warning}")
            if len(self.warnings) > 10:
                print(f"  ... and {len(self.warnings) - 10} more warnings")
                
        # Overall status
        if not self.errors:
            if len(self.warnings) <= 5:
                print("\n🎉 PRODUCTION READY! All critical checks passed.")
                print("📋 Ready for deployment with deploy_noctis_production.sh")
                return True
            else:
                print(f"\n✅ MOSTLY READY! {len(self.warnings)} warnings to review.")
                print("📋 Can proceed with deployment, review warnings if needed.")
                return True
        else:
            print(f"\n❌ NOT PRODUCTION READY! {len(self.errors)} critical issues to fix.")
            return False

if __name__ == '__main__':
    validator = SimpleValidator()
    is_ready = validator.run_all_checks()
    exit(0 if is_ready else 1)