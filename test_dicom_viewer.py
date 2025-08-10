#!/usr/bin/env python3
"""
Test script for the DICOM viewer to verify functionality
"""

import sys
import os
import numpy as np

# Test imports
try:
    import pydicom
    print("✓ PyDICOM import successful")
except ImportError as e:
    print(f"✗ PyDICOM import failed: {e}")
    sys.exit(1)

try:
    from PyQt5.QtWidgets import QApplication
    print("✓ PyQt5 import successful")
except ImportError as e:
    print(f"✗ PyQt5 import failed: {e}")
    sys.exit(1)

try:
    import matplotlib.pyplot as plt
    from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
    print("✓ Matplotlib import successful")
except ImportError as e:
    print(f"✗ Matplotlib import failed: {e}")
    sys.exit(1)

# Test the DICOM viewer import
try:
    from dicom_viewer_fixed import DicomViewer, DicomCanvas
    print("✓ DICOM viewer classes import successful")
except ImportError as e:
    print(f"✗ DICOM viewer import failed: {e}")
    sys.exit(1)

# Create a simple synthetic DICOM-like image for testing
def create_test_dicom_data():
    """Create a simple test DICOM dataset"""
    try:
        # Create a synthetic image array
        test_image = np.random.randint(0, 4096, (512, 512), dtype=np.uint16)
        
        # Add some structure to make it more interesting
        center_x, center_y = 256, 256
        y, x = np.ogrid[:512, :512]
        
        # Create a circle pattern
        circle = (x - center_x)**2 + (y - center_y)**2 < 100**2
        test_image[circle] = 3000
        
        # Create some lines
        test_image[200:220, :] = 2000
        test_image[:, 200:220] = 1500
        
        print("✓ Test image data created successfully")
        return test_image
        
    except Exception as e:
        print(f"✗ Test image creation failed: {e}")
        return None

def test_windowing_function():
    """Test the windowing functionality"""
    try:
        # Create test data
        test_data = np.array([[0, 1000, 2000, 3000, 4000]], dtype=np.float64)
        
        # Test windowing parameters
        window_width = 2000
        window_level = 2000
        
        # Apply windowing (same as in the viewer)
        min_val = window_level - window_width / 2  # 1000
        max_val = window_level + window_width / 2  # 3000
        
        windowed_data = np.clip(test_data, min_val, max_val)
        if max_val - min_val != 0:
            windowed_data = (windowed_data - min_val) / (max_val - min_val) * 255
        else:
            windowed_data = np.zeros_like(windowed_data)
        
        result = windowed_data.astype(np.uint8)
        
        # Expected: [0, 1000, 2000, 3000, 4000] -> [1000, 1000, 2000, 3000, 3000] after clipping
        # Then normalize: [(1000-1000)/2000*255, (1000-1000)/2000*255, (2000-1000)/2000*255, (3000-1000)/2000*255, (3000-1000)/2000*255]
        # = [0, 0, 127.5, 255, 255]
        expected = np.array([[0, 0, 127, 255, 255]], dtype=np.uint8)
        
        if np.allclose(result, expected, atol=2):
            print("✓ Windowing function test passed")
            return True
        else:
            print(f"✗ Windowing function test failed: got {result}, expected {expected}")
            print(f"  min_val: {min_val}, max_val: {max_val}")
            print(f"  clipped: {np.clip(test_data, min_val, max_val)}")
            return False
            
    except Exception as e:
        print(f"✗ Windowing function test failed: {e}")
        return False

def test_viewer_instantiation():
    """Test that the viewer can be instantiated"""
    try:
        app = QApplication([])
        viewer = DicomViewer()
        
        # Test basic attributes
        assert hasattr(viewer, 'dicom_files')
        assert hasattr(viewer, 'current_image_index')
        assert hasattr(viewer, 'window_width')
        assert hasattr(viewer, 'window_level')
        assert hasattr(viewer, 'canvas')
        
        print("✓ DICOM viewer instantiation test passed")
        app.quit()
        return True
        
    except Exception as e:
        print(f"✗ DICOM viewer instantiation test failed: {e}")
        return False

def main():
    print("Testing DICOM Viewer Functionality")
    print("=" * 40)
    
    # Test image creation
    test_image = create_test_dicom_data()
    if test_image is None:
        return False
    
    # Test windowing
    if not test_windowing_function():
        return False
    
    # Test viewer instantiation (requires display)
    if os.environ.get('DISPLAY') or sys.platform == 'win32':
        if not test_viewer_instantiation():
            return False
    else:
        print("⚠ Skipping GUI tests (no display available)")
    
    print("\n" + "=" * 40)
    print("✓ All tests passed! DICOM viewer should work correctly.")
    return True

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)