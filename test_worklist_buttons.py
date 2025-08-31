#!/usr/bin/env python3
"""
Test script to verify all worklist buttons and endpoints work properly
This script will test each button's endpoint to identify 500 errors
"""

import requests
import json
import sys
import os

# Test configuration
BASE_URL = "http://localhost:8000"
ENDPOINTS_TO_TEST = [
    # Worklist API endpoints
    {
        'name': 'Studies API',
        'url': '/worklist/api/studies/',
        'method': 'GET',
        'auth_required': True
    },
    {
        'name': 'Refresh Worklist API',
        'url': '/worklist/api/refresh-worklist/',
        'method': 'GET',
        'auth_required': True
    },
    {
        'name': 'Upload Stats API',
        'url': '/worklist/api/upload-stats/',
        'method': 'GET',
        'auth_required': True
    },
    # Main views
    {
        'name': 'Dashboard',
        'url': '/worklist/',
        'method': 'GET',
        'auth_required': True
    },
    {
        'name': 'Study List',
        'url': '/worklist/studies/',
        'method': 'GET',
        'auth_required': True
    },
    {
        'name': 'Upload Study',
        'url': '/worklist/upload/',
        'method': 'GET',
        'auth_required': True
    },
    # DICOM Viewer
    {
        'name': 'DICOM Viewer',
        'url': '/dicom-viewer/',
        'method': 'GET',
        'auth_required': True
    },
    # Admin Panel (if admin)
    {
        'name': 'Admin Panel Dashboard',
        'url': '/admin-panel/',
        'method': 'GET',
        'auth_required': True
    },
    # Notifications
    {
        'name': 'Notifications',
        'url': '/notifications/',
        'method': 'GET',
        'auth_required': True
    },
    # Chat
    {
        'name': 'Chat Rooms',
        'url': '/chat/',
        'method': 'GET',
        'auth_required': True
    }
]

def test_endpoint(endpoint_info, session=None):
    """Test a single endpoint"""
    url = BASE_URL + endpoint_info['url']
    method = endpoint_info['method']
    name = endpoint_info['name']
    
    try:
        if method == 'GET':
            response = session.get(url) if session else requests.get(url)
        elif method == 'POST':
            response = session.post(url) if session else requests.post(url)
        else:
            return {'name': name, 'status': 'SKIP', 'message': f'Unsupported method: {method}'}
        
        status_code = response.status_code
        
        if status_code == 200:
            return {'name': name, 'status': 'OK', 'code': status_code}
        elif status_code == 302:
            return {'name': name, 'status': 'REDIRECT', 'code': status_code, 'location': response.headers.get('Location', 'Unknown')}
        elif status_code == 403:
            return {'name': name, 'status': 'FORBIDDEN', 'code': status_code, 'message': 'Permission denied'}
        elif status_code == 404:
            return {'name': name, 'status': 'NOT_FOUND', 'code': status_code}
        elif status_code == 500:
            return {'name': name, 'status': 'ERROR_500', 'code': status_code, 'message': 'Internal Server Error'}
        else:
            return {'name': name, 'status': 'OTHER', 'code': status_code}
            
    except requests.exceptions.ConnectionError:
        return {'name': name, 'status': 'CONNECTION_ERROR', 'message': 'Could not connect to server'}
    except Exception as e:
        return {'name': name, 'status': 'EXCEPTION', 'message': str(e)}

def main():
    """Run all tests"""
    print("🔍 Testing Worklist Button Endpoints")
    print("=" * 50)
    
    # Test without authentication first
    print("\n📋 Testing endpoints without authentication:")
    results = []
    
    for endpoint in ENDPOINTS_TO_TEST:
        result = test_endpoint(endpoint)
        results.append(result)
        
        status_emoji = {
            'OK': '✅',
            'REDIRECT': '🔄',
            'FORBIDDEN': '🚫',
            'NOT_FOUND': '❌',
            'ERROR_500': '💥',
            'CONNECTION_ERROR': '🔌',
            'EXCEPTION': '⚠️',
            'OTHER': '❓',
            'SKIP': '⏭️'
        }.get(result['status'], '❓')
        
        print(f"{status_emoji} {result['name']}: {result['status']} ({result.get('code', 'N/A')})")
        if 'message' in result:
            print(f"   └─ {result['message']}")
        if 'location' in result:
            print(f"   └─ Redirects to: {result['location']}")
    
    # Summary
    print("\n📊 Summary:")
    status_counts = {}
    for result in results:
        status = result['status']
        status_counts[status] = status_counts.get(status, 0) + 1
    
    for status, count in status_counts.items():
        print(f"   {status}: {count}")
    
    # Check for critical issues
    error_500_count = status_counts.get('ERROR_500', 0)
    connection_errors = status_counts.get('CONNECTION_ERROR', 0)
    
    if error_500_count > 0:
        print(f"\n🚨 CRITICAL: {error_500_count} endpoints returning 500 errors!")
        return 1
    elif connection_errors > 0:
        print(f"\n⚠️  WARNING: {connection_errors} endpoints have connection issues (server may not be running)")
        return 2
    else:
        print("\n✅ No critical 500 errors detected!")
        return 0

if __name__ == "__main__":
    sys.exit(main())