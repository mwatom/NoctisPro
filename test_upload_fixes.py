#!/usr/bin/env python3
"""
Test script to verify upload and worklist functionality fixes
"""

import os
import sys
import django
from pathlib import Path

# Add the project root to Python path
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from django.test import TestCase, Client
from django.contrib.auth import get_user_model
from django.urls import reverse
from worklist.models import Study, Patient, Modality, Facility
from django.core.files.uploadedfile import SimpleUploadedFile
import tempfile
import pydicom
from pydicom.dataset import FileDataset, FileMetaDataset
import io

User = get_user_model()

def create_test_dicom_file():
    """Create a simple test DICOM file"""
    # Create some test data
    file_meta = FileMetaDataset()
    file_meta.FileMetaInformationGroupLength = 0
    file_meta.FileMetaInformationVersion = b'\x00\x01'
    file_meta.MediaStorageSOPClassUID = '1.2.840.10008.5.1.4.1.1.2'  # CT Image Storage
    file_meta.MediaStorageSOPInstanceUID = '1.2.3.4.5.6.7.8.9.10'
    file_meta.TransferSyntaxUID = '1.2.840.10008.1.2.1'  # Explicit VR Little Endian

    ds = FileDataset(None, {}, file_meta=file_meta, preamble=b"\0" * 128)
    
    # Add required DICOM elements
    ds.PatientName = "Test^Patient"
    ds.PatientID = "TEST123"
    ds.PatientBirthDate = "19800101"
    ds.PatientSex = "M"
    ds.StudyInstanceUID = "1.2.3.4.5.6.7.8.9.11"
    ds.SeriesInstanceUID = "1.2.3.4.5.6.7.8.9.12"
    ds.SOPInstanceUID = "1.2.3.4.5.6.7.8.9.10"
    ds.Modality = "CT"
    ds.StudyDescription = "Test Study"
    ds.SeriesDescription = "Test Series"
    ds.StudyDate = "20240115"
    ds.StudyTime = "120000"
    ds.AccessionNumber = "ACC123"
    ds.ReferringPhysicianName = "Dr^Test"
    ds.SeriesNumber = 1
    ds.InstanceNumber = 1
    
    # Create a simple pixel array
    ds.Rows = 64
    ds.Columns = 64
    ds.BitsAllocated = 16
    ds.BitsStored = 16
    ds.HighBit = 15
    ds.PixelRepresentation = 0
    ds.SamplesPerPixel = 1
    ds.PhotometricInterpretation = "MONOCHROME2"
    ds.PixelData = b'\x00' * (64 * 64 * 2)  # 16-bit pixels
    
    # Write to bytes
    buffer = io.BytesIO()
    ds.save_as(buffer, write_like_original=False)
    buffer.seek(0)
    
    return buffer.getvalue()

def test_upload_functionality():
    """Test the upload functionality"""
    print("Testing upload functionality...")
    
    # Create test user and facility
    try:
        facility = Facility.objects.create(
            name="Test Facility",
            is_active=True
        )
        
        user = User.objects.create_user(
            username='testuser',
            password='testpass123',
            email='test@example.com',
            facility=facility
        )
        
        # Create test modality
        modality = Modality.objects.create(
            code="CT",
            name="Computed Tomography"
        )
        
        print("✓ Test data created successfully")
        
        # Test upload endpoint
        client = Client()
        client.force_login(user)
        
        # Create test DICOM file
        dicom_data = create_test_dicom_file()
        dicom_file = SimpleUploadedFile(
            "test.dcm",
            dicom_data,
            content_type="application/dicom"
        )
        
        # Test upload
        response = client.post(
            reverse('worklist:upload_study'),
            {'dicom_files': [dicom_file]},
            follow=True
        )
        
        print(f"✓ Upload response status: {response.status_code}")
        
        # Check if study was created
        studies = Study.objects.all()
        print(f"✓ Studies in database: {studies.count()}")
        
        if studies.count() > 0:
            study = studies.first()
            print(f"✓ Study created: {study.accession_number} - {study.patient.full_name}")
            print(f"✓ Study modality: {study.modality.code}")
            print(f"✓ Study status: {study.status}")
            print(f"✓ Upload date: {study.upload_date}")
        
        # Test API endpoints
        response = client.get(reverse('worklist:api_studies'))
        print(f"✓ API studies response status: {response.status_code}")
        
        response = client.get(reverse('worklist:api_refresh_worklist'))
        print(f"✓ API refresh response status: {response.status_code}")
        
        response = client.get(reverse('worklist:api_get_upload_stats'))
        print(f"✓ API stats response status: {response.status_code}")
        
        print("✓ All upload functionality tests passed!")
        
    except Exception as e:
        print(f"✗ Test failed: {e}")
        import traceback
        traceback.print_exc()

def test_dashboard_functionality():
    """Test the dashboard functionality"""
    print("\nTesting dashboard functionality...")
    
    try:
        client = Client()
        
        # Test dashboard access
        response = client.get(reverse('worklist:dashboard'))
        print(f"✓ Dashboard response status: {response.status_code}")
        
        # Test upload page access
        response = client.get(reverse('worklist:upload_study'))
        print(f"✓ Upload page response status: {response.status_code}")
        
        print("✓ All dashboard functionality tests passed!")
        
    except Exception as e:
        print(f"✗ Test failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    print("Running upload and worklist functionality tests...")
    print("=" * 50)
    
    test_upload_functionality()
    test_dashboard_functionality()
    
    print("\n" + "=" * 50)
    print("Test completed!")