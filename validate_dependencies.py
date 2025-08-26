#!/usr/bin/env python3
"""
Validation script to check if printing-related dependencies are working
after the Docker build fix.
"""

import sys
import importlib

def check_dependency(module_name, description=""):
    """Check if a module can be imported successfully."""
    try:
        importlib.import_module(module_name)
        print(f"✅ {module_name} - OK {description}")
        return True
    except ImportError as e:
        print(f"❌ {module_name} - FAILED: {e}")
        return False
    except Exception as e:
        print(f"⚠️  {module_name} - WARNING: {e}")
        return False

def main():
    """Main validation function."""
    print("Validating Docker build dependencies...")
    print("=" * 50)
    
    dependencies = [
        ("django", "- Core Django framework"),
        ("PIL", "- Python Imaging Library (Pillow)"),
        ("pydicom", "- DICOM file processing"),
        ("pynetdicom", "- DICOM networking"),
        ("reportlab", "- PDF generation for printing"),
        ("cups", "- Python CUPS bindings (pycups)"),
        ("escpos", "- ESC/POS printer commands"),
        ("numpy", "- Numerical computing"),
        ("torch", "- PyTorch AI framework"),
        ("cv2", "- OpenCV computer vision"),
        ("matplotlib", "- Plotting library"),
    ]
    
    passed = 0
    total = len(dependencies)
    
    for module, desc in dependencies:
        if check_dependency(module, desc):
            passed += 1
    
    print("=" * 50)
    print(f"Results: {passed}/{total} dependencies validated successfully")
    
    if passed == total:
        print("🎉 All dependencies are working correctly!")
        print("The Docker build fix was successful.")
        return 0
    else:
        print("⚠️  Some dependencies failed to import.")
        print("This may be expected if running outside the Docker container.")
        return 1

if __name__ == "__main__":
    sys.exit(main())