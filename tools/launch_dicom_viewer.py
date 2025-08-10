#!/usr/bin/env python3
"""
Noctis Pro - Standalone DICOM Viewer Launcher
=============================================

This script launches the standalone DICOM viewer application.
It can be used independently of the web interface.

Usage:
    python tools/launch_dicom_viewer.py [options] [dicom_file_or_directory]

Examples:
    python tools/launch_dicom_viewer.py
    python tools/launch_dicom_viewer.py /path/to/dicom/files/
    python tools/launch_dicom_viewer.py study.dcm
    python tools/launch_dicom_viewer.py --study-id 123
    python tools/launch_dicom_viewer.py --debug
"""

import sys
import os
import argparse

# Add the project root to the Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, project_root)

def main():
    parser = argparse.ArgumentParser(
        description='Launch the Noctis Pro Standalone DICOM Viewer',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument(
        'path', 
        nargs='?', 
        help='Path to DICOM file or directory to open'
    )
    parser.add_argument(
        '--study-id', 
        type=int,
        help='Database study ID to load (requires database access)'
    )
    parser.add_argument(
        '--debug', 
        action='store_true', 
        help='Enable debug mode'
    )
    parser.add_argument(
        '--standalone',
        action='store_true',
        help='Force standalone mode (no database integration)'
    )
    
    args = parser.parse_args()
    
    try:
        # Import and run the DICOM viewer
        from tools.standalone_viewers.dicom_viewer import main as viewer_main
        
        if args.debug:
            print("Debug mode enabled")
            print(f"Project root: {project_root}")
            if args.study_id:
                print(f"Loading study ID: {args.study_id}")
            if args.path:
                print(f"Loading DICOM path: {args.path}")
        
        # Launch viewer with appropriate parameters
        if args.study_id and not args.standalone:
            if args.debug:
                print("Launching with database study integration")
            viewer_main(study_id=args.study_id)
        elif args.path:
            if args.debug:
                print(f"Launching with DICOM path: {args.path}")
            viewer_main(dicom_path=args.path)
        else:
            if args.debug:
                print("Launching in standard mode")
            viewer_main()
        
    except ImportError as e:
        print(f"Error importing DICOM viewer: {e}")
        print("Make sure all dependencies are installed:")
        print("pip install -r requirements.txt")
        
        # Try to provide more specific error information
        try:
            import PyQt5
            print("✓ PyQt5 is available")
        except ImportError:
            print("✗ PyQt5 is not installed - install with: pip install PyQt5")
            
        try:
            import pydicom
            print("✓ pydicom is available")
        except ImportError:
            print("✗ pydicom is not installed - install with: pip install pydicom")
            
        try:
            import matplotlib
            print("✓ matplotlib is available")
        except ImportError:
            print("✗ matplotlib is not installed - install with: pip install matplotlib")
            
        sys.exit(1)
    except Exception as e:
        print(f"Error launching DICOM viewer: {e}")
        if args.debug:
            import traceback
            traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()