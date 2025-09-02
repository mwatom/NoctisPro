#!/usr/bin/env python3
"""
Test script to verify DICOM image processing pipeline
"""

import os
import sys
import django
import numpy as np
from PIL import Image
import base64
from io import BytesIO

# Add the project to the Python path
sys.path.append('/workspace')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

def test_windowing_algorithm():
    """Test the windowing algorithm with various inputs"""
    print("Testing windowing algorithm...")
    
    # Import the windowing function
    from dicom_viewer.views import _apply_windowing_fast
    
    # Test case 1: Normal gradient
    test_array = np.zeros((256, 256), dtype=np.float32)
    for i in range(256):
        for j in range(256):
            test_array[i, j] = i + j
    
    result = _apply_windowing_fast(test_array, 400, 200, False)
    print(f"Test 1 - Gradient: min={result.min()}, max={result.max()}, mean={result.mean():.1f}")
    
    # Test case 2: High contrast medical image simulation
    test_array2 = np.random.normal(1000, 200, (512, 512)).astype(np.float32)
    # Add some "organs" with different densities
    test_array2[100:150, 100:150] = 2000  # Bone
    test_array2[200:250, 200:250] = -500  # Air
    test_array2[300:350, 300:350] = 50    # Soft tissue
    
    result2 = _apply_windowing_fast(test_array2, 1500, 500, False)
    print(f"Test 2 - Medical simulation: min={result2.min()}, max={result2.max()}, mean={result2.mean():.1f}")
    
    # Test case 3: Edge case - all zeros
    test_array3 = np.zeros((100, 100), dtype=np.float32)
    result3 = _apply_windowing_fast(test_array3, 400, 40, False)
    print(f"Test 3 - All zeros: min={result3.min()}, max={result3.max()}, mean={result3.mean():.1f}")
    
    return True

def test_image_conversion():
    """Test the array to base64 conversion"""
    print("\nTesting image conversion...")
    
    from dicom_viewer.views import _array_to_base64_image
    
    # Create a test pattern
    test_array = np.zeros((256, 256), dtype=np.uint8)
    for i in range(256):
        test_array[i, :] = i  # Gradient
    
    # Add some features
    test_array[120:136, :] = 255  # White line
    test_array[:, 120:136] = 0    # Black line
    
    image_url = _array_to_base64_image(test_array)
    
    if image_url and image_url.startswith('data:image/png;base64,'):
        print("✓ Image conversion successful")
        print(f"  Data URL length: {len(image_url)}")
        print(f"  Data URL start: {image_url[:50]}...")
        return True
    else:
        print("✗ Image conversion failed")
        return False

def create_test_dicom():
    """Create a simple test DICOM file for testing"""
    print("\nCreating test DICOM...")
    
    try:
        import pydicom
        from pydicom.dataset import Dataset, FileDataset
        from pydicom.uid import generate_uid
        
        # Create a simple test image
        test_image = np.zeros((512, 512), dtype=np.uint16)
        
        # Add gradient
        for i in range(512):
            for j in range(512):
                test_image[i, j] = (i + j) % 4096
        
        # Add some medical-style features
        # Center circle
        center_x, center_y = 256, 256
        for i in range(512):
            for j in range(512):
                dist = np.sqrt((i - center_x)**2 + (j - center_y)**2)
                if 80 < dist < 100:
                    test_image[i, j] = 3000
                elif 120 < dist < 140:
                    test_image[i, j] = 1000
        
        # Create DICOM dataset
        ds = Dataset()
        ds.PatientName = "Test^Patient"
        ds.PatientID = "TEST001"
        ds.StudyDate = "20240101"
        ds.StudyTime = "120000"
        ds.Modality = "CT"
        ds.SeriesDescription = "Test Series"
        ds.StudyInstanceUID = generate_uid()
        ds.SeriesInstanceUID = generate_uid()
        ds.SOPInstanceUID = generate_uid()
        ds.SOPClassUID = "1.2.840.10008.5.1.4.1.1.2"  # CT Image Storage
        ds.Rows = 512
        ds.Columns = 512
        ds.BitsAllocated = 16
        ds.BitsStored = 16
        ds.HighBit = 15
        ds.PixelRepresentation = 1
        ds.SamplesPerPixel = 1
        ds.PhotometricInterpretation = "MONOCHROME2"
        ds.RescaleSlope = 1.0
        ds.RescaleIntercept = -1024.0
        ds.WindowWidth = 400
        ds.WindowCenter = 40
        ds.PixelSpacing = [0.5, 0.5]
        ds.SliceThickness = 5.0
        ds.PixelData = test_image.tobytes()
        
        # Save test DICOM
        test_file = '/workspace/test_dicom.dcm'
        ds.save_as(test_file)
        print(f"✓ Test DICOM created: {test_file}")
        return test_file
        
    except Exception as e:
        print(f"✗ Failed to create test DICOM: {e}")
        return None

if __name__ == "__main__":
    print("=== DICOM Image Processing Test ===")
    
    # Test windowing algorithm
    windowing_ok = test_windowing_algorithm()
    
    # Test image conversion
    conversion_ok = test_image_conversion()
    
    # Create test DICOM
    test_dicom_file = create_test_dicom()
    
    print(f"\n=== Test Results ===")
    print(f"Windowing Algorithm: {'✓ PASS' if windowing_ok else '✗ FAIL'}")
    print(f"Image Conversion: {'✓ PASS' if conversion_ok else '✗ FAIL'}")
    print(f"Test DICOM Creation: {'✓ PASS' if test_dicom_file else '✗ FAIL'}")
    
    if windowing_ok and conversion_ok:
        print("\n✓ Image processing pipeline appears to be working correctly!")
        print("If images still appear white, the issue is likely in the frontend display.")
        print("Try the following:")
        print("1. Open browser developer tools (F12)")
        print("2. Go to Console tab")
        print("3. Load a DICOM image")
        print("4. Check for any JavaScript errors")
        print("5. Use Ctrl+Shift+D to debug image display")
    else:
        print("\n✗ Issues found in image processing pipeline")
        
    print(f"\nFor testing, you can:")
    print(f"1. Start the server: python manage.py runserver")
    print(f"2. Go to: http://localhost:8000/dicom-viewer/")
    print(f"3. Click the test tube icon to load a test image")
    print(f"4. Check browser console for debug information")