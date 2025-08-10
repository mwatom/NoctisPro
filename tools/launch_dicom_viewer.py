#!/usr/bin/env python3
"""
Noctis Pro - Standalone DICOM Viewer Launcher
=============================================

This script launches the standalone DICOM viewer application.
It prefers the C++ Qt desktop viewer when available, falling back to the Python viewer.

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
import subprocess

# Add the project root to the Python path
project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, project_root)


def find_cpp_viewer_binary():
    candidates = [
        os.path.join(project_root, "cpp_viewer", "build", "DicomViewer"),
        os.path.join(project_root, "cpp_viewer", "build", "Release", "DicomViewer"),
        os.path.join(project_root, "cpp_viewer", "build", "Debug", "DicomViewer"),
    ]
    for path in candidates:
        if os.path.exists(path) and os.access(path, os.X_OK):
            return path
    return None


def main():
    parser = argparse.ArgumentParser(
        description='Launch the Noctis Pro Standalone DICOM Viewer',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    parser.add_argument('path', nargs='?', help='Path to DICOM file or directory to open')
    parser.add_argument('--study-id', type=int, help='Database study ID to load (requires database access)')
    parser.add_argument('--debug', action='store_true', help='Enable debug mode')
    parser.add_argument('--standalone', action='store_true', help='Force standalone mode (no database integration)')

    args = parser.parse_args()

    # Prefer C++ viewer if present
    cpp_bin = find_cpp_viewer_binary()
    if cpp_bin:
        env = os.environ.copy()
        # Default Django base URL for the C++ app
        env.setdefault('DICOM_VIEWER_BASE_URL', 'http://localhost:8000/viewer')
        argv = [cpp_bin]
        if args.path:
            argv += [args.path]
        if args.debug:
            print(f"Launching C++ viewer: {' '.join(argv)}")
            print(f"Using base URL: {env['DICOM_VIEWER_BASE_URL']}")
        try:
            subprocess.Popen(argv, env=env)
            return
        except Exception as e:
            print(f"Failed to launch C++ viewer: {e}. Falling back to Python viewer...")

    # Fallback to Python viewer
    try:
        from tools.standalone_viewers.dicom_viewer import main as viewer_main
        if args.debug:
            print("Python viewer fallback engaged")
            print(f"Project root: {project_root}")
            if args.study_id:
                print(f"Loading study ID: {args.study_id}")
            if args.path:
                print(f"Loading DICOM path: {args.path}")
        if args.study_id and not args.standalone:
            viewer_main(study_id=args.study_id)
        elif args.path:
            viewer_main(dicom_path=args.path)
        else:
            viewer_main()
    except ImportError as e:
        print(f"Error importing DICOM viewer: {e}")
        print("Make sure all dependencies are installed:")
        print("pip install -r requirements.txt")
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