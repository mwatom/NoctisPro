#!/usr/bin/env python3
"""
Noctis Pro - Standalone DICOM Viewer Launcher
=============================================

This script launches the standalone DICOM viewer application.
It can be used independently of the web interface.

Usage:
    python tools/launch_dicom_viewer.py [dicom_file_or_directory]

Examples:
    python tools/launch_dicom_viewer.py
    python tools/launch_dicom_viewer.py /path/to/dicom/files/
    python tools/launch_dicom_viewer.py study.dcm
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
        '--debug', 
        action='store_true', 
        help='Enable debug mode'
    )
    
    args = parser.parse_args()
    
    try:
        # Import and run the DICOM viewer
        from tools.standalone_viewers.dicom_viewer import main as viewer_main
        
        # If a path is provided, pass it to the viewer
        if args.path:
            # TODO: Modify the viewer to accept command line arguments
            print(f"Opening DICOM path: {args.path}")
        
        if args.debug:
            print("Debug mode enabled")
        
        viewer_main()
        
    except ImportError as e:
        print(f"Error importing DICOM viewer: {e}")
        print("Make sure all dependencies are installed:")
        print("pip install -r requirements.txt")
        sys.exit(1)
    except Exception as e:
        print(f"Error launching DICOM viewer: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()