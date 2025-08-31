#!/usr/bin/env python3
"""
Quick system initialization script
"""
import os
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from accounts.models import User, Facility
from worklist.models import Study, Patient, Modality, Series, DicomImage
from django.contrib.auth.hashers import make_password
from django.utils import timezone

print("🔧 Initializing Noctis Pro PACS System")

# Create facility
facility, created = Facility.objects.get_or_create(
    name='Test Hospital',
    defaults={
        'ae_title': 'TESTHSP',
        'address': '123 Test St',
        'phone': '555-0123',
        'contact_person': 'Test Admin'
    }
)
print(f"✅ Facility: {facility.name}")

# Create admin user
admin_user, created = User.objects.get_or_create(
    username='admin',
    defaults={
        'email': 'admin@test.com',
        'password': make_password('admin123'),
        'role': 'admin',
        'first_name': 'Admin',
        'last_name': 'User',
        'is_staff': True,
        'is_superuser': True,
        'facility': facility
    }
)
print(f"✅ Admin user: admin / admin123")

# Create modalities
modalities = [
    ('CT', 'Computed Tomography'),
    ('MRI', 'Magnetic Resonance Imaging'), 
    ('XR', 'X-Ray'),
    ('US', 'Ultrasound'),
    ('NM', 'Nuclear Medicine')
]

for code, name in modalities:
    modality, created = Modality.objects.get_or_create(
        code=code,
        defaults={'name': name, 'is_active': True}
    )
    print(f"✅ Modality: {modality.code}")

# Create sample patient and study for testing
patient, created = Patient.objects.get_or_create(
    patient_id='TEST001',
    defaults={
        'first_name': 'John',
        'last_name': 'Doe',
        'date_of_birth': '1980-01-01',
        'gender': 'M'
    }
)

ct_modality = Modality.objects.get(code='CT')
study, created = Study.objects.get_or_create(
    accession_number='ACC001',
    defaults={
        'patient': patient,
        'modality': ct_modality,
        'facility': facility,
        'study_date': timezone.now().date(),
        'study_description': 'Test CT Scan',
        'status': 'scheduled',
        'priority': 'normal',
        'uploaded_by': admin_user,
        'clinical_info': 'Sample study for testing system functionality'
    }
)
print(f"✅ Sample study: {study.accession_number}")

# Create a sample series and image for testing
series, created = Series.objects.get_or_create(
    study=study,
    series_number=1,
    defaults={
        'series_description': 'Test Series',
        'modality': 'CT',
        'slice_thickness': 1.0,
        'pixel_spacing': [1.0, 1.0]
    }
)

print(f"✅ Sample series: {series.series_number}")

print("\n🎉 System initialization complete!")
print("📋 Login credentials:")
print("   Username: admin")
print("   Password: admin123")
print("\n🌐 Access the system at: http://localhost:8000")