#!/usr/bin/env python3
"""
Noctis Pro - Standalone DICOM Viewer Launcher
=============================================

This script launches the standalone DICOM viewer application.
It requires the C++ Qt desktop viewer binary to be built and available.

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

    # Prefer C++ viewer; required going forward
    cpp_bin = find_cpp_viewer_binary()
    if not cpp_bin:
        print("Error: C++ viewer binary not found. Please build it in cpp_viewer/build (see README).")
        sys.exit(1)

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
        print(f"Failed to launch C++ viewer: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()