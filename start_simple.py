#!/usr/bin/env python3
"""
Simple Django server startup script with minimal dependencies
"""
import os
import sys
import subprocess

def install_dependencies():
    """Install only essential dependencies"""
    essential_deps = [
        'django',
        'djangorestframework', 
        'django-cors-headers',
        'pillow',
        'pydicom',
        'numpy',
        'scipy'
    ]
    
    print("Installing essential dependencies...")
    for dep in essential_deps:
        print(f"  - Installing {dep}...")
        subprocess.run([sys.executable, '-m', 'pip', 'install', '--break-system-packages', '-q', dep], 
                      capture_output=True)
    print("✅ Dependencies installed")

def start_server():
    """Start Django development server"""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
    
    print("\n🚀 Starting Django server on port 8000...")
    print("=" * 60)
    print("Access the application at:")
    print("  - http://localhost:8000")
    print("  - http://localhost:8000/login/")
    print("\nTest credentials:")
    print("  Admin: admin / admin123")
    print("  Admin: test_admin / TestPass123!")
    print("  Radiologist: test_radiologist / TestPass123!")
    print("  Facility: test_facility / TestPass123!")
    print("=" * 60)
    
    # Start the server from this script's directory if /workspace doesn't exist
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = '/workspace' if os.path.isdir('/workspace') else script_dir
    os.system(f'cd {project_dir} && python3 manage.py runserver 0.0.0.0:8000')

if __name__ == '__main__':
    try:
        install_dependencies()
        start_server()
    except KeyboardInterrupt:
        print("\n\n✅ Server stopped")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()