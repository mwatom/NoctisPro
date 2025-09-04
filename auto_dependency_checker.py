#!/usr/bin/env python3
"""
Enhanced Auto-Dependency Checker for NOCTIS PRO PACS v2.0
==========================================================
This script automatically detects missing dependencies and provides
installation suggestions for different operating systems.
"""

import sys
import subprocess
import importlib
import platform
import os
from pathlib import Path

class Colors:
    """ANSI color codes for terminal output"""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    WHITE = '\033[1;37m'
    BOLD = '\033[1m'
    NC = '\033[0m'  # No Color

def print_banner():
    """Print application banner"""
    print(f"{Colors.PURPLE}")
    print("🔍 NOCTIS PRO PACS v2.0 - AUTO DEPENDENCY CHECKER")
    print("=" * 52)
    print(f"{Colors.NC}")

def get_system_info():
    """Get system information"""
    return {
        'os': platform.system(),
        'os_release': platform.release(),
        'architecture': platform.machine(),
        'python_version': platform.python_version(),
        'platform': platform.platform()
    }

def detect_package_manager():
    """Detect the system package manager"""
    managers = {
        'apt-get': 'apt',
        'yum': 'yum', 
        'dnf': 'dnf',
        'pacman': 'pacman',
        'apk': 'apk',
        'brew': 'brew',
        'port': 'macports'
    }
    
    for cmd, manager in managers.items():
        if subprocess.run(['which', cmd], capture_output=True).returncode == 0:
            return manager
    
    return 'unknown'

def check_python_dependency(module_name, description="", import_as=None):
    """Check if a Python module can be imported"""
    try:
        if import_as:
            importlib.import_module(import_as)
        else:
            importlib.import_module(module_name)
        print(f"{Colors.GREEN}✅ {module_name}{Colors.NC} - {description}")
        return True
    except ImportError as e:
        print(f"{Colors.RED}❌ {module_name}{Colors.NC} - MISSING: {description}")
        print(f"   Error: {e}")
        return False
    except Exception as e:
        print(f"{Colors.YELLOW}⚠️  {module_name}{Colors.NC} - WARNING: {e}")
        return False

def check_system_dependency(command, description=""):
    """Check if a system command is available"""
    try:
        result = subprocess.run(['which', command], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"{Colors.GREEN}✅ {command}{Colors.NC} - {description} (found at {result.stdout.strip()})")
            return True
        else:
            print(f"{Colors.RED}❌ {command}{Colors.NC} - MISSING: {description}")
            return False
    except Exception as e:
        print(f"{Colors.RED}❌ {command}{Colors.NC} - ERROR: {e}")
        return False

def get_installation_commands(pkg_manager):
    """Get installation commands for different package managers"""
    commands = {
        'apt': {
            'system_update': 'sudo apt-get update',
            'python_dev': 'sudo apt-get install -y python3 python3-pip python3-venv python3-dev',
            'build_tools': 'sudo apt-get install -y build-essential cmake pkg-config',
            'image_libs': 'sudo apt-get install -y libjpeg-dev libpng-dev zlib1g-dev libfreetype6-dev liblcms2-dev libwebp-dev',
            'database': 'sudo apt-get install -y libpq-dev postgresql-client',
            'redis': 'sudo apt-get install -y redis-server',
            'cups': 'sudo apt-get install -y libcups2-dev cups cups-client',
            'dicom': 'sudo apt-get install -y libgdcm-dev gdcm-tools libopenjp2-7-dev',
            'opencv': 'sudo apt-get install -y libopencv-dev python3-opencv'
        },
        'yum': {
            'system_update': 'sudo yum update -y',
            'python_dev': 'sudo yum install -y python3 python3-pip python3-devel',
            'build_tools': 'sudo yum install -y gcc gcc-c++ make cmake pkgconfig',
            'image_libs': 'sudo yum install -y libjpeg-turbo-devel libpng-devel zlib-devel freetype-devel lcms2-devel libwebp-devel',
            'database': 'sudo yum install -y postgresql-devel postgresql',
            'redis': 'sudo yum install -y redis',
            'cups': 'sudo yum install -y cups-devel cups',
            'dicom': 'sudo yum install -y gdcm-devel openjpeg2-devel',
            'opencv': 'sudo yum install -y opencv-devel'
        },
        'dnf': {
            'system_update': 'sudo dnf update -y',
            'python_dev': 'sudo dnf install -y python3 python3-pip python3-devel',
            'build_tools': 'sudo dnf install -y gcc gcc-c++ make cmake pkgconfig',
            'image_libs': 'sudo dnf install -y libjpeg-turbo-devel libpng-devel zlib-devel freetype-devel lcms2-devel libwebp-devel',
            'database': 'sudo dnf install -y postgresql-devel postgresql',
            'redis': 'sudo dnf install -y redis',
            'cups': 'sudo dnf install -y cups-devel cups',
            'dicom': 'sudo dnf install -y gdcm-devel openjpeg2-devel',
            'opencv': 'sudo dnf install -y opencv-devel'
        },
        'brew': {
            'system_update': 'brew update',
            'python_dev': 'brew install python',
            'build_tools': 'brew install cmake pkg-config',
            'image_libs': 'brew install jpeg libpng zlib freetype little-cms2 webp',
            'database': 'brew install postgresql',
            'redis': 'brew install redis',
            'cups': 'brew install cups',
            'dicom': 'brew install gdcm openjpeg',
            'opencv': 'brew install opencv'
        }
    }
    
    return commands.get(pkg_manager, {})

def main():
    """Main dependency checking function"""
    print_banner()
    
    # System information
    sys_info = get_system_info()
    pkg_manager = detect_package_manager()
    
    print(f"{Colors.BLUE}🖥️  SYSTEM INFORMATION:{Colors.NC}")
    print(f"   OS: {sys_info['os']} {sys_info['os_release']}")
    print(f"   Architecture: {sys_info['architecture']}")
    print(f"   Python: {sys_info['python_version']}")
    print(f"   Package Manager: {pkg_manager}")
    print()
    
    # Check system dependencies
    print(f"{Colors.BLUE}🔧 SYSTEM DEPENDENCIES:{Colors.NC}")
    system_deps = [
        ('python3', 'Python 3 interpreter'),
        ('pip3', 'Python package installer'),
        ('git', 'Version control system'),
        ('curl', 'HTTP client'),
        ('wget', 'File downloader'),
        ('cmake', 'Build system generator'),
        ('pkg-config', 'Package configuration tool'),
        ('redis-server', 'Redis server'),
        ('psql', 'PostgreSQL client'),
    ]
    
    system_passed = 0
    for cmd, desc in system_deps:
        if check_system_dependency(cmd, desc):
            system_passed += 1
    
    print()
    
    # Check Python dependencies
    print(f"{Colors.BLUE}🐍 PYTHON DEPENDENCIES:{Colors.NC}")
    python_deps = [
        ('django', 'Django web framework'),
        ('PIL', 'Python Imaging Library', 'PIL'),
        ('pydicom', 'DICOM file processing'),
        ('pynetdicom', 'DICOM networking'),
        ('numpy', 'Numerical computing'),
        ('cv2', 'OpenCV computer vision', 'cv2'),
        ('torch', 'PyTorch deep learning'),
        ('sklearn', 'Scikit-learn machine learning', 'sklearn'),
        ('matplotlib', 'Plotting library'),
        ('redis', 'Redis Python client'),
        ('psycopg2', 'PostgreSQL adapter', 'psycopg2'),
        ('reportlab', 'PDF generation'),
        ('cups', 'CUPS Python bindings', 'cups'),
        ('escpos', 'ESC/POS printer commands', 'escpos'),
        ('cryptography', 'Cryptographic library'),
        ('requests', 'HTTP library'),
        ('celery', 'Distributed task queue'),
        ('channels', 'Django Channels for WebSockets'),
        ('rest_framework', 'Django REST framework', 'rest_framework'),
    ]
    
    python_passed = 0
    missing_python = []
    
    for dep_info in python_deps:
        if len(dep_info) == 3:
            name, desc, import_name = dep_info
        else:
            name, desc = dep_info
            import_name = None
            
        if check_python_dependency(name, desc, import_name):
            python_passed += 1
        else:
            missing_python.append(name)
    
    print()
    
    # Check Django project structure
    print(f"{Colors.BLUE}📁 PROJECT STRUCTURE:{Colors.NC}")
    project_files = [
        ('manage.py', 'Django management script'),
        ('requirements.txt', 'Python dependencies'),
        ('db.sqlite3', 'Database file'),
        ('static/', 'Static files directory'),
        ('media/', 'Media files directory'),
        ('templates/', 'Template files directory'),
    ]
    
    project_passed = 0
    for filename, desc in project_files:
        if os.path.exists(filename):
            print(f"{Colors.GREEN}✅ {filename}{Colors.NC} - {desc}")
            project_passed += 1
        else:
            print(f"{Colors.YELLOW}⚠️  {filename}{Colors.NC} - MISSING: {desc}")
    
    print()
    
    # Results summary
    total_system = len(system_deps)
    total_python = len(python_deps)
    total_project = len(project_files)
    
    print(f"{Colors.WHITE}📊 DEPENDENCY CHECK RESULTS:{Colors.NC}")
    print(f"   System Dependencies: {system_passed}/{total_system}")
    print(f"   Python Dependencies: {python_passed}/{total_python}")
    print(f"   Project Structure: {project_passed}/{total_project}")
    print()
    
    # Installation suggestions
    if system_passed < total_system or python_passed < total_python:
        print(f"{Colors.YELLOW}💡 INSTALLATION SUGGESTIONS:{Colors.NC}")
        
        if pkg_manager != 'unknown':
            install_cmds = get_installation_commands(pkg_manager)
            if install_cmds:
                print(f"   {Colors.CYAN}For {pkg_manager} package manager:{Colors.NC}")
                for category, cmd in install_cmds.items():
                    print(f"   {cmd}")
                print()
        
        if missing_python:
            print(f"   {Colors.CYAN}Install missing Python packages:{Colors.NC}")
            print(f"   pip install {' '.join(missing_python)}")
            print()
            print(f"   {Colors.CYAN}Or install from requirements.txt:{Colors.NC}")
            print("   pip install -r requirements.txt")
            print()
    
    # Overall status
    if system_passed == total_system and python_passed == total_python:
        print(f"{Colors.GREEN}🎉 ALL DEPENDENCIES SATISFIED!{Colors.NC}")
        print("   Your system is ready for NOCTIS PRO PACS deployment.")
        return 0
    else:
        print(f"{Colors.RED}⚠️  SOME DEPENDENCIES ARE MISSING{Colors.NC}")
        print("   Please install the missing dependencies before deployment.")
        return 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print(f"\n{Colors.RED}❌ Dependency check interrupted{Colors.NC}")
        sys.exit(1)
    except Exception as e:
        print(f"\n{Colors.RED}❌ Error during dependency check: {e}{Colors.NC}")
        sys.exit(1)