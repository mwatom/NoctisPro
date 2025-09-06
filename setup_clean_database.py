#!/usr/bin/env python3
"""
🏥 Noctis Pro PACS - Clean Database Setup Script
This script sets up a fresh database with all necessary data for production use.
"""

import os
import sys
import django
from pathlib import Path

# Add the project directory to Python path
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from django.core.management import execute_from_command_line, call_command
from django.contrib.auth import get_user_model
from django.db import transaction
from accounts.models import Facility
from worklist.models import Modality
from reports.models import ReportTemplate
from ai_analysis.models import AIModel

User = get_user_model()

def print_header(message):
    print(f"\n{'='*60}")
    print(f"🏥 {message}")
    print(f"{'='*60}")

def print_step(message):
    print(f"📋 {message}")

def print_success(message):
    print(f"✅ {message}")

def print_warning(message):
    print(f"⚠️  {message}")

def print_error(message):
    print(f"❌ {message}")

@transaction.atomic
def setup_clean_database():
    """Setup clean database with all necessary data"""
    
    print_header("NOCTIS PRO PACS - CLEAN DATABASE SETUP")
    
    # Step 1: Clean migrations and create fresh ones
    print_step("Cleaning existing migrations...")
    
    # Remove migration files (keep __init__.py)
    migration_dirs = [
        'accounts/migrations',
        'worklist/migrations', 
        'reports/migrations',
        'admin_panel/migrations',
        'chat/migrations',
        'notifications/migrations',
        'ai_analysis/migrations',
        'dicom_viewer/migrations'
    ]
    
    for migration_dir in migration_dirs:
        migration_path = BASE_DIR / migration_dir
        if migration_path.exists():
            for file in migration_path.glob('*.py'):
                if file.name != '__init__.py':
                    file.unlink()
                    print(f"   Removed: {file}")
    
    print_success("Migration files cleaned")
    
    # Step 2: Create fresh migrations
    print_step("Creating fresh migrations...")
    
    apps_to_migrate = [
        'accounts',
        'worklist', 
        'reports',
        'admin_panel',
        'chat',
        'notifications',
        'ai_analysis',
        'dicom_viewer'
    ]
    
    for app in apps_to_migrate:
        try:
            call_command('makemigrations', app, verbosity=0)
            print(f"   ✅ Created migrations for {app}")
        except Exception as e:
            print(f"   ⚠️  Warning for {app}: {e}")
    
    print_success("Fresh migrations created")
    
    # Step 3: Apply migrations
    print_step("Applying database migrations...")
    call_command('migrate', verbosity=0)
    print_success("Database migrations applied")
    
    # Step 4: Create superuser admin/admin
    print_step("Creating superuser account (admin/admin)...")
    
    if User.objects.filter(username='admin').exists():
        print_warning("Admin user already exists, skipping creation")
    else:
        admin_user = User.objects.create_superuser(
            username='admin',
            email='admin@noctispro.local',
            password='admin',
            first_name='System',
            last_name='Administrator',
            role='admin'
        )
        print_success("Superuser 'admin' created with password 'admin'")
    
    # Step 5: Create sample facilities
    print_step("Setting up sample facilities...")
    
    facilities_data = [
        {
            'name': 'Main Hospital',
            'address': '123 Medical Center Dr, Healthcare City, HC 12345',
            'phone': '+1-555-HOSPITAL',
            'email': 'radiology@mainhospital.com',
            'license_number': 'MH-RAD-2024-001',
            'ae_title': 'MAIN_HOSP'
        },
        {
            'name': 'Imaging Center North',
            'address': '456 Diagnostic Ave, Medical District, MD 67890',
            'phone': '+1-555-IMAGING',
            'email': 'info@imagingnorth.com', 
            'license_number': 'ICN-RAD-2024-002',
            'ae_title': 'IMG_NORTH'
        },
        {
            'name': 'Emergency Radiology Unit',
            'address': '789 Emergency Blvd, Trauma Center, TC 13579',
            'phone': '+1-555-EMERGENCY',
            'email': 'emergency@traumacenter.com',
            'license_number': 'ERU-RAD-2024-003', 
            'ae_title': 'EMERG_RAD'
        }
    ]
    
    for facility_data in facilities_data:
        facility, created = Facility.objects.get_or_create(
            name=facility_data['name'],
            defaults=facility_data
        )
        if created:
            print(f"   ✅ Created facility: {facility.name}")
        else:
            print(f"   ⚠️  Facility already exists: {facility.name}")
    
    # Step 6: Create modalities
    print_step("Setting up DICOM modalities...")
    
    modalities_data = [
        {'code': 'CT', 'name': 'Computed Tomography'},
        {'code': 'MR', 'name': 'Magnetic Resonance Imaging'},
        {'code': 'CR', 'name': 'Computed Radiography'},
        {'code': 'DR', 'name': 'Digital Radiography'},
        {'code': 'US', 'name': 'Ultrasound'},
        {'code': 'NM', 'name': 'Nuclear Medicine'},
        {'code': 'PT', 'name': 'Positron Emission Tomography'},
        {'code': 'MG', 'name': 'Mammography'},
        {'code': 'DX', 'name': 'Digital X-Ray'},
        {'code': 'RF', 'name': 'Radiofluoroscopy'},
        {'code': 'XA', 'name': 'X-Ray Angiography'},
        {'code': 'ES', 'name': 'Endoscopy'},
        {'code': 'OT', 'name': 'Other'}
    ]
    
    for modality_data in modalities_data:
        modality, created = Modality.objects.get_or_create(
            code=modality_data['code'],
            defaults={
                'name': modality_data['name'],
                'is_active': True
            }
        )
        if created:
            print(f"   ✅ Created modality: {modality.code} - {modality.name}")
    
    # Step 7: Setup report templates
    print_step("Setting up report templates...")
    call_command('setup_report_templates', verbosity=0)
    print_success("Report templates configured")
    
    # Step 8: Create sample users
    print_step("Creating sample users...")
    
    # Create a radiologist
    if not User.objects.filter(username='radiologist').exists():
        radiologist = User.objects.create_user(
            username='radiologist',
            email='radiologist@noctispro.local',
            password='radiologist',
            first_name='Dr. Sarah',
            last_name='Johnson',
            role='radiologist',
            specialization='Diagnostic Radiology',
            license_number='RAD-2024-001'
        )
        print_success("Created radiologist user: radiologist/radiologist")
    
    # Create a facility user
    main_facility = Facility.objects.first()
    if not User.objects.filter(username='facility').exists():
        facility_user = User.objects.create_user(
            username='facility',
            email='facility@noctispro.local', 
            password='facility',
            first_name='John',
            last_name='Smith',
            role='facility',
            facility=main_facility
        )
        print_success("Created facility user: facility/facility")
    
    # Step 9: Setup AI models (basic configuration)
    print_step("Setting up AI analysis models...")
    
    ai_models_data = [
        {
            'name': 'Chest X-Ray Classifier',
            'version': '1.0',
            'model_type': 'classification',
            'modality': 'CR',
            'body_part': 'CHEST',
            'description': 'AI model for chest X-ray pathology detection',
            'model_file_path': '/models/chest_xray_classifier.pkl',
            'is_active': True,
            'is_trained': True
        },
        {
            'name': 'CT Brain Segmentation',
            'version': '1.0', 
            'model_type': 'segmentation',
            'modality': 'CT',
            'body_part': 'BRAIN',
            'description': 'AI model for brain tissue segmentation',
            'model_file_path': '/models/brain_segmentation.pkl',
            'is_active': True,
            'is_trained': True
        },
        {
            'name': 'Auto Report Generator',
            'version': '1.0',
            'model_type': 'report_generation', 
            'modality': 'CT',
            'body_part': '',
            'description': 'AI model for automated report generation',
            'model_file_path': '/models/report_generator.pkl',
            'is_active': True,
            'is_trained': True
        }
    ]
    
    for ai_model_data in ai_models_data:
        ai_model, created = AIModel.objects.get_or_create(
            name=ai_model_data['name'],
            version=ai_model_data['version'],
            defaults=ai_model_data
        )
        if created:
            print(f"   ✅ Created AI model: {ai_model.name}")
    
    # Step 10: Collect static files
    print_step("Collecting static files...")
    call_command('collectstatic', '--noinput', verbosity=0)
    print_success("Static files collected")
    
    print_header("DATABASE SETUP COMPLETED SUCCESSFULLY!")
    
    print("\n🎉 NOCTIS PRO PACS is ready for production!")
    print("\n📊 Database Summary:")
    print(f"   • Users: {User.objects.count()}")
    print(f"   • Facilities: {Facility.objects.count()}")
    print(f"   • Modalities: {Modality.objects.count()}")
    print(f"   • Report Templates: {ReportTemplate.objects.count()}")
    print(f"   • AI Models: {AIModel.objects.count()}")
    
    print("\n👤 Login Credentials:")
    print("   • Administrator: admin / admin")
    print("   • Radiologist: radiologist / radiologist") 
    print("   • Facility User: facility / facility")
    
    print("\n🚀 Next Steps:")
    print("   1. Start the Django server")
    print("   2. Access the system via web browser")
    print("   3. Upload DICOM studies for testing")
    print("   4. Test reporting workflow")
    print("   5. Verify measurements and annotations")
    print("   6. Test 3D reconstructions")
    
    print(f"\n{'='*60}")

if __name__ == '__main__':
    try:
        setup_clean_database()
    except Exception as e:
        print_error(f"Database setup failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)