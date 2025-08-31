#!/usr/bin/env python3
"""
Clean PostgreSQL Setup for Professional Noctis Pro PACS
Removes all test data and sets up production-ready database
"""

import os
import sys
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from accounts.models import User, Facility
from worklist.models import Study, Patient, Modality, Series, DicomImage
from django.db import transaction

def clean_database():
    """Remove all test data and keep only production data"""
    print("🧹 CLEANING DATABASE - REMOVING TEST DATA")
    print("=" * 50)
    
    with transaction.atomic():
        # Remove test users (keep only admin)
        test_users = User.objects.exclude(username='admin')
        deleted_users = test_users.count()
        test_users.delete()
        print(f"✅ Removed {deleted_users} test users")
        
        # Remove test facilities
        test_facilities = Facility.objects.exclude(name__icontains='Noctis Pro')
        deleted_facilities = test_facilities.count()
        test_facilities.delete()
        print(f"✅ Removed {deleted_facilities} test facilities")
        
        # Remove test patients
        test_patients = Patient.objects.filter(patient_id__startswith='TEST')
        deleted_patients = test_patients.count()
        test_patients.delete()
        print(f"✅ Removed {deleted_patients} test patients")
        
        print("✅ Database cleaned successfully")

def setup_production_data():
    """Set up production-ready data"""
    print("\n🏥 SETTING UP PRODUCTION DATA")
    print("=" * 50)
    
    with transaction.atomic():
        # Create professional facility
        facility, created = Facility.objects.get_or_create(
            name='Noctis Pro Medical Center',
            defaults={
                'address': '123 Medical Drive, Healthcare City',
                'phone': '+1-555-MEDICAL',
                'email': 'admin@noctispro.medical',
                'license_number': 'NOCTIS-MAIN-001',
                'ae_title': 'NOCTISPRO',
                'is_active': True
            }
        )
        
        if created:
            print("✅ Created professional facility")
        else:
            print("ℹ️  Professional facility already exists")
        
        # Set up admin user with proper credentials
        admin_user, created = User.objects.get_or_create(
            username='admin',
            defaults={
                'email': 'admin@noctispro.medical',
                'first_name': 'System',
                'last_name': 'Administrator',
                'role': 'admin',
                'facility': facility,
                'is_verified': True,
                'is_staff': True,
                'is_superuser': True
            }
        )
        
        # Set password
        admin_user.set_password('NoctisPro2024!')
        admin_user.email = 'admin@noctispro.medical'
        admin_user.first_name = 'System'
        admin_user.last_name = 'Administrator'
        admin_user.role = 'admin'
        admin_user.facility = facility
        admin_user.is_verified = True
        admin_user.is_staff = True
        admin_user.is_superuser = True
        admin_user.save()
        
        if created:
            print("✅ Created admin user")
        else:
            print("✅ Updated admin user credentials")
        
        # Set up standard modalities
        standard_modalities = [
            ('CT', 'Computed Tomography'),
            ('MR', 'Magnetic Resonance Imaging'),
            ('MRI', 'Magnetic Resonance Imaging'),
            ('PT', 'Positron Emission Tomography'),
            ('PET', 'Positron Emission Tomography'),
            ('NM', 'Nuclear Medicine'),
            ('SPECT', 'Single Photon Emission CT'),
            ('XR', 'X-Ray'),
            ('DX', 'Digital X-Ray'),
            ('CR', 'Computed Radiography'),
            ('US', 'Ultrasound'),
            ('MG', 'Mammography'),
            ('RF', 'Radiofluoroscopy'),
            ('XA', 'X-Ray Angiography'),
        ]
        
        for code, name in standard_modalities:
            modality, created = Modality.objects.get_or_create(
                code=code,
                defaults={'name': name, 'is_active': True}
            )
            if created:
                print(f"✅ Created modality: {code} - {name}")
        
        print(f"✅ Configured {len(standard_modalities)} standard modalities")

def display_final_status():
    """Display final database status"""
    print("\n🏥 FINAL PRODUCTION DATABASE STATUS")
    print("=" * 50)
    print(f"Users: {User.objects.count()}")
    print(f"Facilities: {Facility.objects.count()}")
    print(f"Studies: {Study.objects.count()}")
    print(f"Patients: {Patient.objects.count()}")
    print(f"Modalities: {Modality.objects.count()}")
    
    print("\n👤 PRODUCTION USER ACCOUNTS:")
    for user in User.objects.all():
        print(f"   {user.username} ({user.role}) - {'✅ Verified' if user.is_verified else '❌ Not verified'}")
    
    print("\n🏥 PRODUCTION FACILITIES:")
    for facility in Facility.objects.all():
        print(f"   {facility.name} - {'✅ Active' if facility.is_active else '❌ Inactive'}")
    
    print("\n🔐 ADMIN LOGIN CREDENTIALS:")
    print("   Username: admin")
    print("   Password: NoctisPro2024!")
    print("   Email: admin@noctispro.medical")
    
    print("\n✅ PRODUCTION DATABASE READY")

if __name__ == "__main__":
    try:
        clean_database()
        setup_production_data()
        display_final_status()
        
        print("\n🎉 PROFESSIONAL NOCTIS PRO PACS DATABASE SETUP COMPLETE!")
        print("🏥 System is ready for medical imaging operations")
        
    except Exception as e:
        print(f"\n❌ Error during setup: {e}")
        sys.exit(1)