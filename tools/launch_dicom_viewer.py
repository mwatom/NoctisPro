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
        # Windows
        os.path.join(project_root, "cpp_viewer", "build", "DicomViewer.exe"),
        os.path.join(project_root, "cpp_viewer", "build", "Release", "DicomViewer.exe"),
        os.path.join(project_root, "cpp_viewer", "build", "Debug", "DicomViewer.exe"),
        # macOS app bundle
        os.path.join(project_root, "cpp_viewer", "build", "DicomViewer.app", "Contents", "MacOS", "DicomViewer"),
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
    env.setdefault('DICOM_VIEWER_BASE_URL', 'http://127.0.0.1:8000/viewer')
    # Help the binary locate shared libraries on Linux
    bin_dir = os.path.dirname(cpp_bin)
    ld_paths = [
        bin_dir,
        '/usr/lib',
        '/usr/local/lib',
        '/usr/lib/x86_64-linux-gnu',
        '/usr/lib64',
        '/usr/lib/qt6',
        '/usr/local/Qt-6/lib',
    ]
    existing = env.get('LD_LIBRARY_PATH', '')
    env['LD_LIBRARY_PATH'] = os.pathsep.join([p for p in (os.pathsep.join(ld_paths) + (os.pathsep + existing if existing else '')).split(os.pathsep) if p])
    # Also prepend to PATH for plugins/platforms
    env['PATH'] = os.pathsep.join([bin_dir, env.get('PATH', '')])
    argv = [cpp_bin]
    if args.path:
        argv += [args.path]
    if args.debug:
        print(f"Launching C++ viewer: {' '.join(argv)}")
        print(f"Using base URL: {env['DICOM_VIEWER_BASE_URL']}")


    try:
        subprocess.Popen(argv, env=env, cwd=os.path.dirname(cpp_bin))
        return
    except Exception as e:
        print(f"Failed to launch C++ viewer: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()