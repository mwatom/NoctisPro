#!/usr/bin/env python3
"""
Test script for the Enhanced Professional DICOM Viewer
Creates sample DICOM-like data for testing the enhanced UI
"""

import sys
import os
import numpy as np

# Add the current directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from PyQt5.QtWidgets import QApplication, QMessageBox
    from PyQt5.QtCore import Qt
    
    # Import our enhanced viewer
    from python_viewer import DicomViewer
    
    def create_test_dicom_data():
        """Create test DICOM-like data for demonstration"""
        
        class MockDicomData:
            def __init__(self, modality='CT', size=(512, 512)):
                self.Modality = modality
                self.PatientName = "TEST^PATIENT^ENHANCED"
                self.StudyDate = "20250102"
                self.SeriesDescription = f"Enhanced {modality} Test Series"
                self.InstitutionName = "Professional Medical Center"
                self.Rows = size[0]
                self.Columns = size[1]
                self.PixelSpacing = [0.5, 0.5]  # 0.5mm pixel spacing
                self.SliceThickness = 1.0
                self.WindowWidth = 400 if modality == 'CT' else 2000
                self.WindowCenter = 40 if modality == 'CT' else 500
                self.RescaleSlope = 1.0
                self.RescaleIntercept = -1024 if modality == 'CT' else 0
                self.InstanceNumber = 1
                
                # Create realistic test image data
                if modality == 'CT':
                    # Create CT-like data with different tissue densities
                    self.pixel_array = self._create_ct_phantom(size)
                elif modality in ['CR', 'DX']:
                    # Create X-ray-like data
                    self.pixel_array = self._create_xray_phantom(size)
                else:
                    # Generic test pattern
                    self.pixel_array = self._create_test_pattern(size)
            
            def _create_ct_phantom(self, size):
                """Create CT phantom with realistic tissue densities"""
                # Create base phantom
                phantom = np.zeros(size, dtype=np.int16)
                
                # Add different tissue types with realistic HU values
                center_x, center_y = size[1] // 2, size[0] // 2
                
                # Air background (-1000 HU)
                phantom.fill(-1024)  # Raw value before rescale
                
                # Body outline (soft tissue, ~40 HU)
                y, x = np.ogrid[:size[0], :size[1]]
                body_mask = ((x - center_x)**2 + (y - center_y)**2) < (min(size) * 0.4)**2
                phantom[body_mask] = 40
                
                # Bone structures (~300 HU)
                bone_mask = ((x - center_x)**2 + (y - center_y)**2) < (min(size) * 0.1)**2
                phantom[bone_mask] = 300
                
                # Lung areas (-500 HU)
                lung1_mask = ((x - center_x + 80)**2 + (y - center_y)**2) < 60**2
                lung2_mask = ((x - center_x - 80)**2 + (y - center_y)**2) < 60**2
                phantom[lung1_mask] = -500
                phantom[lung2_mask] = -500
                
                # Add some noise for realism
                noise = np.random.normal(0, 20, size).astype(np.int16)
                phantom = phantom + noise
                
                return phantom
            
            def _create_xray_phantom(self, size):
                """Create X-ray phantom with realistic projection data"""
                # Create chest X-ray-like pattern
                phantom = np.zeros(size, dtype=np.uint16)
                
                center_x, center_y = size[1] // 2, size[0] // 2
                
                # Background (air, high intensity in X-ray)
                phantom.fill(3000)
                
                # Body outline (attenuated)
                y, x = np.ogrid[:size[0], :size[1]]
                body_mask = ((x - center_x)**2 + (y - center_y)**2) < (min(size) * 0.45)**2
                phantom[body_mask] = 1500
                
                # Lung fields (less attenuation)
                lung1_mask = ((x - center_x + 100)**2 + (y - center_y + 50)**2) < 80**2
                lung2_mask = ((x - center_x - 100)**2 + (y - center_y + 50)**2) < 80**2
                phantom[lung1_mask] = 2500
                phantom[lung2_mask] = 2500
                
                # Bone structures (high attenuation, low intensity)
                # Ribs
                for i in range(-3, 4):
                    rib_y = center_y + i * 40
                    rib_mask = ((y - rib_y)**2 < 100) & (np.abs(x - center_x) < 150)
                    phantom[rib_mask] = 500
                
                # Spine
                spine_mask = ((x - center_x)**2 < 400) & (np.abs(y - center_y) < 200)
                phantom[spine_mask] = 300
                
                # Heart shadow
                heart_mask = ((x - center_x + 30)**2 + (y - center_y + 80)**2) < 50**2
                phantom[heart_mask] = 1000
                
                # Add realistic noise
                noise = np.random.normal(0, 50, size).astype(np.int16)
                phantom = np.clip(phantom.astype(np.int32) + noise, 0, 4095).astype(np.uint16)
                
                return phantom
            
            def _create_test_pattern(self, size):
                """Create generic test pattern"""
                # Create a test pattern with gradients and shapes
                pattern = np.zeros(size, dtype=np.uint16)
                
                # Create gradient background
                y, x = np.mgrid[:size[0], :size[1]]
                pattern = (x * 4096 // size[1]).astype(np.uint16)
                
                # Add circles of different intensities
                center_x, center_y = size[1] // 2, size[0] // 2
                for i, radius in enumerate([50, 100, 150]):
                    mask = ((x - center_x)**2 + (y - center_y)**2) < radius**2
                    pattern[mask] = 1000 + i * 1000
                
                return pattern
        
        return MockDicomData
    
    def test_enhanced_viewer():
        """Test the enhanced DICOM viewer with sample data"""
        app = QApplication(sys.argv)
        app.setStyle('Fusion')
        
        # Create viewer
        viewer = DicomViewer()
        
        # Create test data
        MockDicom = create_test_dicom_data()
        
        # Create multiple test images
        test_images = [
            MockDicom('CT', (512, 512)),
            MockDicom('CR', (1024, 1024)),
            MockDicom('DX', (2048, 2048)),
        ]
        
        # Update instance numbers
        for i, img in enumerate(test_images):
            img.InstanceNumber = i + 1
        
        # Load test data
        viewer.dicom_files = test_images
        viewer.current_image_index = 0
        
        if hasattr(viewer, 'slice_slider'):
            viewer.slice_slider.setRange(0, len(test_images) - 1)
            viewer.slice_slider.setValue(0)
        
        # Update display
        viewer.update_patient_info()
        viewer.update_display()
        
        # Show viewer
        viewer.show()
        
        # Show welcome message
        QMessageBox.information(
            viewer, 
            "Enhanced DICOM Viewer Test", 
            "Professional DICOM Viewer loaded with test data!\n\n"
            "Features:\n"
            "• Enhanced X-ray image processing\n"
            "• Professional medical imaging presets\n"
            "• Advanced measurement tools\n"
            "• Optimized windowing algorithms\n"
            "• Professional UI with color-coded controls\n\n"
            "Use the tools in the left toolbar and controls in the right panel."
        )
        
        return app.exec_()
    
    if __name__ == '__main__':
        sys.exit(test_enhanced_viewer())
        
except ImportError as e:
    print(f"Error: Missing required packages for enhanced DICOM viewer")
    print(f"Import error: {e}")
    print("\nTo install required packages, run:")
    print("pip install -r requirements_dicom_viewer.txt")
    print("\nOr install system packages:")
    print("sudo apt install python3-pyqt5 python3-numpy python3-matplotlib python3-pil")
    sys.exit(1)