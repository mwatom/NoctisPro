"""
Noctis Pro - Standalone Viewers Module
=====================================

This module provides standalone desktop viewers for DICOM and other medical imaging formats.
The viewers can be used independently or integrated with the web-based Noctis Pro system.

Main Components:
- DicomViewer: Advanced DICOM viewer with measurement and annotation tools
- Study integration: Database-connected viewing for Noctis Pro studies
- Standalone mode: File-based viewing without database dependency

Usage:
    from tools.standalone_viewers import DicomViewer
    
    # Create viewer instance
    viewer = DicomViewer()
    
    # Or with study ID (requires Django integration)
    viewer = DicomViewer(study_id=123)
    
    # Or with DICOM path
    viewer = DicomViewer(dicom_path="/path/to/dicom/files")
"""

from .dicom_viewer import DicomViewer, main

__all__ = ['DicomViewer', 'main']
__version__ = '3.0.0'
__author__ = 'Noctis Pro Development Team'