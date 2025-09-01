#!/usr/bin/env python3
"""
System Status Check - Verify all DICOM viewer enhancements are working
"""

import requests
import os
from pathlib import Path

def check_django_server():
    """Check if Django server is running and responding"""
    try:
        response = requests.get('http://localhost:8000/', timeout=5)
        return True, f"Server responding with status {response.status_code}"
    except Exception as e:
        return False, f"Server not responding: {e}"

def check_static_files():
    """Check if static files are being served correctly"""
    static_files = [
        '/static/css/dicom-viewer-buttons.css',
        '/static/css/dicom-viewer-fixes.css',
        '/static/js/hounsfield-ellipse-roi.js',
        '/static/js/movable-annotations.js',
        '/static/js/3d-reconstruction.js',
        '/static/js/ai-auto-learning.js',
        '/static/js/backup-system.js',
        '/static/js/dicom-viewer-mouse-fix.js',
        '/static/js/dicom-print-export-fix.js'
    ]
    
    results = []
    for file_path in static_files:
        try:
            response = requests.head(f'http://localhost:8000{file_path}', timeout=5)
            if response.status_code == 200:
                results.append((True, f"{file_path}: OK ({response.headers.get('content-type', 'unknown type')})"))
            else:
                results.append((False, f"{file_path}: HTTP {response.status_code}"))
        except Exception as e:
            results.append((False, f"{file_path}: Error - {e}"))
    
    return results

def check_api_endpoints():
    """Check if API endpoints are accessible (should redirect to login)"""
    endpoints = [
        '/dicom-viewer/api/hounsfield/',
        '/worklist/api/study/1/delete/',
        '/admin/',
    ]
    
    results = []
    for endpoint in endpoints:
        try:
            response = requests.head(f'http://localhost:8000{endpoint}', timeout=5, allow_redirects=False)
            if response.status_code in [200, 302, 403]:  # OK, Redirect, or Forbidden (expected for auth)
                results.append((True, f"{endpoint}: OK (HTTP {response.status_code})"))
            else:
                results.append((False, f"{endpoint}: HTTP {response.status_code}"))
        except Exception as e:
            results.append((False, f"{endpoint}: Error - {e}"))
    
    return results

def check_file_system():
    """Check if all files exist in the filesystem"""
    files_to_check = [
        '/workspace/static/js/hounsfield-ellipse-roi.js',
        '/workspace/static/js/movable-annotations.js',
        '/workspace/static/js/3d-reconstruction.js',
        '/workspace/static/js/ai-auto-learning.js',
        '/workspace/static/js/backup-system.js',
        '/workspace/static/css/dicom-viewer-fixes.css',
        '/workspace/templates/dicom_viewer/base.html',
        '/workspace/manage.py'
    ]
    
    results = []
    for file_path in files_to_check:
        path = Path(file_path)
        if path.exists():
            size = path.stat().st_size
            results.append((True, f"{file_path}: EXISTS ({size:,} bytes)"))
        else:
            results.append((False, f"{file_path}: MISSING"))
    
    return results

def main():
    print("🔍 DICOM Viewer System Status Check")
    print("=" * 50)
    
    # Check Django server
    print("\n📡 Django Server Status:")
    server_ok, server_msg = check_django_server()
    print(f"{'✅' if server_ok else '❌'} {server_msg}")
    
    # Check static files
    print("\n📁 Static Files Status:")
    static_results = check_static_files()
    for ok, msg in static_results:
        print(f"{'✅' if ok else '❌'} {msg}")
    
    # Check API endpoints
    print("\n🔗 API Endpoints Status:")
    api_results = check_api_endpoints()
    for ok, msg in api_results:
        print(f"{'✅' if ok else '❌'} {msg}")
    
    # Check file system
    print("\n💾 File System Status:")
    fs_results = check_file_system()
    for ok, msg in fs_results:
        print(f"{'✅' if ok else '❌'} {msg}")
    
    # Summary
    total_checks = 1 + len(static_results) + len(api_results) + len(fs_results)
    passed_checks = sum([
        1 if server_ok else 0,
        sum(1 for ok, _ in static_results if ok),
        sum(1 for ok, _ in api_results if ok),
        sum(1 for ok, _ in fs_results if ok)
    ])
    
    print(f"\n📊 SUMMARY:")
    print(f"{'🎉' if passed_checks == total_checks else '⚠️ '} {passed_checks}/{total_checks} checks passed")
    
    if passed_checks == total_checks:
        print("\n🎉 ALL SYSTEMS OPERATIONAL!")
        print("✅ Django server running")
        print("✅ Static files served correctly")
        print("✅ API endpoints accessible")
        print("✅ All enhancement files present")
        print("\n🚀 DICOM Viewer ready for use!")
    else:
        print(f"\n⚠️  {total_checks - passed_checks} issues found")
        print("Please check the failed items above")

if __name__ == '__main__':
    main()