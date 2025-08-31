#!/usr/bin/env python3
"""
Verification script for NoctisPro fixes
Checks code-level implementations without requiring Django runtime
"""

import os
import re
from pathlib import Path

class CodeVerifier:
    def __init__(self):
        self.checks_passed = []
        self.checks_failed = []
        
    def check_file_exists(self, filepath, description):
        """Check if a file exists"""
        if os.path.exists(filepath):
            self.checks_passed.append(f"✓ {description}: File exists at {filepath}")
            return True
        else:
            self.checks_failed.append(f"✗ {description}: File not found at {filepath}")
            return False
    
    def check_pattern_in_file(self, filepath, pattern, description, case_sensitive=False):
        """Check if a pattern exists in a file"""
        if not os.path.exists(filepath):
            self.checks_failed.append(f"✗ {description}: File not found at {filepath}")
            return False
        
        try:
            with open(filepath, 'r') as f:
                content = f.read()
                
            flags = 0 if case_sensitive else re.IGNORECASE
            if re.search(pattern, content, flags):
                self.checks_passed.append(f"✓ {description}: Pattern found in {filepath}")
                return True
            else:
                self.checks_failed.append(f"✗ {description}: Pattern not found in {filepath}")
                return False
        except Exception as e:
            self.checks_failed.append(f"✗ {description}: Error reading file - {str(e)}")
            return False
    
    def check_middleware_enabled(self, middleware_class):
        """Check if middleware is enabled in settings"""
        settings_file = "noctis_pro/settings.py"
        pattern = rf"^\s*'noctis_pro\.middleware\.{middleware_class}',"
        
        if self.check_pattern_in_file(settings_file, pattern, f"{middleware_class} enabled"):
            return True
        
        # Check if it's commented out
        commented_pattern = rf"^\s*#\s*'noctis_pro\.middleware\.{middleware_class}',"
        if self.check_pattern_in_file(settings_file, commented_pattern, f"{middleware_class} (commented)"):
            self.checks_failed.append(f"✗ {middleware_class} is commented out")
            return False
        
        return False
    
    def print_summary(self):
        """Print verification summary"""
        print("\n" + "="*60)
        print("VERIFICATION SUMMARY")
        print("="*60)
        
        total = len(self.checks_passed) + len(self.checks_failed)
        print(f"Total checks: {total}")
        print(f"\033[92mPassed: {len(self.checks_passed)}\033[0m")
        print(f"\033[91mFailed: {len(self.checks_failed)}\033[0m")
        
        print("\nPassed checks:")
        for check in self.checks_passed:
            print(f"  {check}")
        
        if self.checks_failed:
            print("\nFailed checks:")
            for check in self.checks_failed:
                print(f"  {check}")
        
        return len(self.checks_failed) == 0

def verify_all_fixes():
    """Verify all the fixes implemented"""
    verifier = CodeVerifier()
    
    print("="*60)
    print("NOCTISPRO FIXES VERIFICATION")
    print("="*60)
    
    # 1. Check upload functionality
    print("\n1. Checking Upload Functionality...")
    verifier.check_pattern_in_file(
        "worklist/views.py",
        r"def upload_study\(request\):",
        "Upload study function exists"
    )
    verifier.check_pattern_in_file(
        "templates/worklist/upload.html",
        r"dicom_files",
        "Upload template has file input"
    )
    verifier.check_pattern_in_file(
        "worklist/urls.py",
        r"path\('upload/',.*upload_study.*\)",
        "Upload URL configured"
    )
    
    # 2. Check admin delete functionality
    print("\n2. Checking Admin Delete Study...")
    verifier.check_pattern_in_file(
        "worklist/views.py",
        r"def api_delete_study\(request, study_id\):",
        "Delete study API function exists"
    )
    verifier.check_pattern_in_file(
        "worklist/urls.py",
        r"path\('api/study/<int:study_id>/delete/',.*api_delete_study",
        "Delete study URL configured"
    )
    verifier.check_pattern_in_file(
        "templates/worklist/dashboard.html",
        r"deleteStudy\(",
        "Delete button JavaScript function"
    )
    
    # 3. Check load local DICOM functionality
    print("\n3. Checking Load Local DICOM...")
    verifier.check_pattern_in_file(
        "dicom_viewer/views.py",
        r"def upload_dicom\(request\):",
        "Upload DICOM function exists"
    )
    verifier.check_pattern_in_file(
        "dicom_viewer/urls.py",
        r"path\('upload/',.*upload_dicom",
        "Upload DICOM URL configured"
    )
    verifier.check_pattern_in_file(
        "templates/dicom_viewer/base.html",
        r"btnLoadLocal",
        "Load Local button in template"
    )
    verifier.check_pattern_in_file(
        "templates/dicom_viewer/base.html",
        r'id="localDicom".*type="file"',
        "File input for local DICOM"
    )
    
    # 4. Check 3D dropdown functionality
    print("\n4. Checking 3D Dropdown...")
    verifier.check_pattern_in_file(
        "templates/dicom_viewer/base.html",
        r'id="btn3D"',
        "3D button exists"
    )
    verifier.check_pattern_in_file(
        "templates/dicom_viewer/base.html",
        r'id="menu3D"',
        "3D dropdown menu exists"
    )
    verifier.check_pattern_in_file(
        "templates/dicom_viewer/base.html",
        r'data-recon="mpr"',
        "MPR option in dropdown"
    )
    verifier.check_pattern_in_file(
        "templates/dicom_viewer/base.html",
        r'data-recon="mip"',
        "MIP option in dropdown"
    )
    verifier.check_pattern_in_file(
        "templates/dicom_viewer/base.html",
        r'data-recon="bone"',
        "Bone option in dropdown"
    )
    verifier.check_pattern_in_file(
        "templates/dicom_viewer/base.html",
        r"generateReconstruction\(",
        "Generate reconstruction function"
    )
    
    # 5. Check user/facility management
    print("\n5. Checking User/Facility Management...")
    verifier.check_pattern_in_file(
        "admin_panel/views.py",
        r"def user_create\(request\):",
        "User creation view exists"
    )
    verifier.check_pattern_in_file(
        "admin_panel/views.py",
        r"def facility_create\(request\):",
        "Facility creation view exists"
    )
    verifier.check_pattern_in_file(
        "admin_panel/urls.py",
        r"path\('users/create/'",
        "User creation URL configured"
    )
    verifier.check_pattern_in_file(
        "admin_panel/urls.py",
        r"path\('facilities/create/'",
        "Facility creation URL configured"
    )
    
    # 6. Check login functionality
    print("\n6. Checking Login Functionality...")
    verifier.check_pattern_in_file(
        "accounts/views.py",
        r"def login_view\(request\):",
        "Login view exists"
    )
    verifier.check_pattern_in_file(
        "accounts/urls.py",
        r"path\('login/'",
        "Login URL configured"
    )
    verifier.check_pattern_in_file(
        "accounts/models.py",
        r"class User\(",
        "User model exists"
    )
    verifier.check_pattern_in_file(
        "accounts/models.py",
        r"def is_admin\(self\):",
        "is_admin method exists"
    )
    
    # 7. Check session timeout (10 minutes)
    print("\n7. Checking Session Timeout...")
    verifier.check_middleware_enabled("SessionTimeoutMiddleware")
    verifier.check_pattern_in_file(
        "noctis_pro/settings.py",
        r"SESSION_COOKIE_AGE.*=.*600|SESSION_COOKIE_AGE.*=.*\*\s*60.*'10'",
        "Session timeout set to 10 minutes"
    )
    verifier.check_pattern_in_file(
        "noctis_pro/middleware.py",
        r"class SessionTimeoutMiddleware",
        "SessionTimeoutMiddleware class exists"
    )
    
    # 8. Check critical imports
    print("\n8. Checking Critical Imports...")
    verifier.check_pattern_in_file(
        "worklist/views.py",
        r"import pydicom",
        "pydicom imported in worklist views"
    )
    verifier.check_pattern_in_file(
        "dicom_viewer/views.py",
        r"import pydicom",
        "pydicom imported in DICOM viewer views"
    )
    
    # Print summary
    success = verifier.print_summary()
    
    print("\n" + "="*60)
    if success:
        print("\033[92mALL CRITICAL FIXES VERIFIED!\033[0m")
        print("\nThe following features should now be working:")
        print("  1. Upload button (no more 500 error)")
        print("  2. Admin delete study button in worklist")
        print("  3. Load local DICOM in viewer")
        print("  4. 3D dropdown with MPR/MIP/Bone options")
        print("  5. Add user and facilities functionality")
        print("  6. User login system")
        print("  7. Auto-logout after 10 minutes of inactivity")
    else:
        print("\033[91mSOME VERIFICATIONS FAILED\033[0m")
        print("Please review the failed checks above.")
    print("="*60)
    
    return success

if __name__ == "__main__":
    import sys
    success = verify_all_fixes()
    sys.exit(0 if success else 1)