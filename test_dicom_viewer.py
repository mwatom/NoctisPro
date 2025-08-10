#!/usr/bin/env python3
"""
Test script for the improved DICOM viewer.
This script can create synthetic DICOM files for testing if no real DICOM files are available.
"""

import sys
import os
import numpy as np
import pydicom
from pydicom.dataset import Dataset, FileDataset
from pydicom.uid import ExplicitVRLittleEndian, generate_uid
import tempfile
import datetime

def create_synthetic_dicom(filename, width=512, height=512, pattern='gradient'):
    """
    Create a synthetic DICOM file for testing purposes.
    
    Args:
        filename: Output filename
        width: Image width in pixels
        height: Image height in pixels  
        pattern: Type of test pattern ('gradient', 'checkerboard', 'circles', 'noise')
    """
    print(f"Creating synthetic DICOM: {filename}")
    
    # Create the file meta dataset
    file_meta = Dataset()
    file_meta.MediaStorageSOPClassUID = '1.2.840.10008.5.1.4.1.1.2'  # CT Image Storage
    file_meta.MediaStorageSOPInstanceUID = generate_uid()
    file_meta.ImplementationClassUID = generate_uid()
    file_meta.TransferSyntaxUID = ExplicitVRLittleEndian
    
    # Create the main dataset
    ds = FileDataset(filename, {}, file_meta=file_meta, preamble=b"\0" * 128)
    
    # Add required DICOM elements
    ds.PatientName = "Test^Patient"
    ds.PatientID = "TEST001"
    ds.StudyDate = datetime.datetime.now().strftime('%Y%m%d')
    ds.StudyTime = datetime.datetime.now().strftime('%H%M%S')
    ds.StudyInstanceUID = generate_uid()
    ds.SeriesInstanceUID = generate_uid()
    ds.SOPInstanceUID = file_meta.MediaStorageSOPInstanceUID
    ds.SOPClassUID = file_meta.MediaStorageSOPClassUID
    ds.Modality = 'CT'
    ds.SeriesDescription = f'Test Series - {pattern.title()}'
    ds.StudyDescription = 'Synthetic Test Study'
    ds.InstitutionName = 'Test Hospital'
    ds.Manufacturer = 'Test Manufacturer'
    ds.ManufacturerModelName = 'Test Model'
    
    # Image-specific elements
    ds.Rows = height
    ds.Columns = width
    ds.BitsAllocated = 16
    ds.BitsStored = 16
    ds.HighBit = 15
    ds.PixelRepresentation = 1  # signed
    ds.SamplesPerPixel = 1
    ds.PhotometricInterpretation = 'MONOCHROME2'
    ds.PixelSpacing = [0.5, 0.5]  # mm
    ds.SliceThickness = 5.0  # mm
    ds.WindowCenter = 0
    ds.WindowWidth = 400
    ds.RescaleIntercept = -1024
    ds.RescaleSlope = 1
    ds.InstanceNumber = 1
    
    # Create test pattern
    if pattern == 'gradient':
        # Horizontal gradient
        image_data = np.linspace(-1024, 1024, width * height, dtype=np.int16)
        image_data = image_data.reshape(height, width)
    elif pattern == 'checkerboard':
        # Checkerboard pattern
        x, y = np.meshgrid(np.arange(width), np.arange(height))
        image_data = ((x // 32) + (y // 32)) % 2 * 2048 - 1024
        image_data = image_data.astype(np.int16)
    elif pattern == 'circles':
        # Concentric circles
        x, y = np.meshgrid(np.arange(width) - width//2, np.arange(height) - height//2)
        r = np.sqrt(x**2 + y**2)
        image_data = (np.sin(r / 20) * 1024).astype(np.int16)
    elif pattern == 'noise':
        # Random noise
        image_data = np.random.randint(-1024, 1024, (height, width), dtype=np.int16)
    else:
        # Default: simple gradient
        image_data = np.linspace(-1024, 1024, width * height, dtype=np.int16)
        image_data = image_data.reshape(height, width)
    
    # Set pixel data
    ds.PixelData = image_data.tobytes()
    
    # Save the file
    ds.save_as(filename, write_like_original=False)
    print(f"Created: {filename} ({width}x{height}, {pattern})")
    return filename

def create_test_series(output_dir, num_slices=10):
    """
    Create a series of synthetic DICOM files for testing.
    
    Args:
        output_dir: Directory to save files
        num_slices: Number of slices to create
    """
    print(f"Creating test series with {num_slices} slices in {output_dir}")
    
    os.makedirs(output_dir, exist_ok=True)
    files = []
    
    patterns = ['gradient', 'checkerboard', 'circles', 'noise']
    
    for i in range(num_slices):
        pattern = patterns[i % len(patterns)]
        filename = os.path.join(output_dir, f"test_slice_{i+1:03d}.dcm")
        create_synthetic_dicom(filename, pattern=pattern)
        files.append(filename)
    
    print(f"Created {len(files)} test DICOM files")
    return files

def test_viewer_with_synthetic_data():
    """
    Test the DICOM viewer with synthetic data.
    """
    print("Testing DICOM viewer with synthetic data...")
    
    # Create temporary directory for test files
    temp_dir = tempfile.mkdtemp(prefix="dicom_test_")
    print(f"Using temporary directory: {temp_dir}")
    
    try:
        # Create test series
        test_files = create_test_series(temp_dir, num_slices=5)
        
        # Import and run the viewer
        from improved_dicom_viewer import DicomViewer
        from PyQt5.QtWidgets import QApplication
        
        app = QApplication(sys.argv)
        viewer = DicomViewer()
        
        # Load the test files
        viewer.load_dicom_data(test_files)
        
        viewer.show()
        
        print("DICOM viewer started with test data.")
        print("Test files loaded successfully!")
        print(f"Test directory: {temp_dir}")
        print("You can also use 'Load DICOM Directory' to load this test directory.")
        
        return app.exec_()
        
    except Exception as e:
        print(f"Error testing viewer: {e}")
        import traceback
        traceback.print_exc()
        return 1
    finally:
        # Note: We don't clean up temp_dir so user can inspect the files
        pass

def main():
    """Main function to run tests or create sample data."""
    if len(sys.argv) > 1:
        if sys.argv[1] == 'create-samples':
            # Create sample DICOM files
            output_dir = sys.argv[2] if len(sys.argv) > 2 else './sample_dicoms'
            num_slices = int(sys.argv[3]) if len(sys.argv) > 3 else 10
            create_test_series(output_dir, num_slices)
            print(f"Sample DICOM files created in: {output_dir}")
        elif sys.argv[1] == 'test':
            # Test the viewer with synthetic data
            sys.exit(test_viewer_with_synthetic_data())
        else:
            print("Usage:")
            print("  python test_dicom_viewer.py create-samples [output_dir] [num_slices]")
            print("  python test_dicom_viewer.py test")
    else:
        # Default: test the viewer
        sys.exit(test_viewer_with_synthetic_data())

if __name__ == '__main__':
    main()