#!/usr/bin/env python3
"""
Cleanup Test Studies Script

This script helps identify and delete test studies from the NOCTIS Pro system.
It can identify test studies based on various criteria and provides options
to delete them safely.

Usage:
    python cleanup_test_studies.py --list              # List potential test studies
    python cleanup_test_studies.py --delete-confirm    # Delete test studies with confirmation
    python cleanup_test_studies.py --delete-all        # Delete all test studies (use with caution)

"""

import os
import sys
import django
from datetime import datetime
import re

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

from worklist.models import Study, Patient
from django.db import transaction


def identify_test_studies():
    """
    Identify potential test studies based on common patterns:
    - Study descriptions containing 'test', 'demo', 'sample'
    - Patient names containing 'test', 'demo', 'sample'
    - Accession numbers containing 'test', 'demo', 'sample'
    - Patient IDs that look like test data
    """
    test_patterns = [
        'test', 'demo', 'sample', 'example', 'dummy', 'fake',
        'training', 'practice', 'trial', 'experiment'
    ]
    
    potential_test_studies = []
    
    all_studies = Study.objects.select_related('patient').all()
    
    for study in all_studies:
        reasons = []
        
        # Check study description
        if study.study_description:
            for pattern in test_patterns:
                if pattern.lower() in study.study_description.lower():
                    reasons.append(f"Study description contains '{pattern}'")
                    break
        
        # Check accession number
        if study.accession_number:
            for pattern in test_patterns:
                if pattern.lower() in study.accession_number.lower():
                    reasons.append(f"Accession number contains '{pattern}'")
                    break
        
        # Check patient name
        patient_name = f"{study.patient.first_name} {study.patient.last_name}".lower()
        for pattern in test_patterns:
            if pattern.lower() in patient_name:
                reasons.append(f"Patient name contains '{pattern}'")
                break
        
        # Check patient ID
        if study.patient.patient_id:
            for pattern in test_patterns:
                if pattern.lower() in study.patient.patient_id.lower():
                    reasons.append(f"Patient ID contains '{pattern}'")
                    break
        
        # Check for sequential test patient IDs (TEST001, TEST002, etc.)
        if re.match(r'^(TEST|DEMO|SAMPLE)\d+$', study.patient.patient_id, re.IGNORECASE):
            reasons.append("Patient ID follows test pattern (TEST###, DEMO###, etc.)")
        
        # Check for placeholder data
        if study.referring_physician and any(placeholder in study.referring_physician.lower() 
                                           for placeholder in ['test', 'demo', 'dr^test', 'placeholder']):
            reasons.append("Referring physician appears to be test data")
        
        if reasons:
            potential_test_studies.append({
                'study': study,
                'reasons': reasons
            })
    
    return potential_test_studies


def list_test_studies():
    """List all potential test studies"""
    test_studies = identify_test_studies()
    
    if not test_studies:
        print("✅ No potential test studies found in the system.")
        return
    
    print(f"🔍 Found {len(test_studies)} potential test studies:")
    print("=" * 80)
    
    for i, item in enumerate(test_studies, 1):
        study = item['study']
        reasons = item['reasons']
        
        print(f"\n{i}. Study ID: {study.id}")
        print(f"   Accession: {study.accession_number}")
        print(f"   Description: {study.study_description}")
        print(f"   Patient: {study.patient.full_name} (ID: {study.patient.patient_id})")
        print(f"   Modality: {study.modality.code}")
        print(f"   Upload Date: {study.upload_date.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"   Reasons: {', '.join(reasons)}")
        print("-" * 40)


def delete_test_studies(confirm_each=True):
    """Delete test studies with optional confirmation"""
    test_studies = identify_test_studies()
    
    if not test_studies:
        print("✅ No potential test studies found to delete.")
        return
    
    print(f"🗑️  Found {len(test_studies)} potential test studies to delete:")
    
    deleted_count = 0
    skipped_count = 0
    
    for i, item in enumerate(test_studies, 1):
        study = item['study']
        reasons = item['reasons']
        
        print(f"\n{i}/{len(test_studies)} - Study: {study.accession_number}")
        print(f"   Patient: {study.patient.full_name}")
        print(f"   Description: {study.study_description}")
        print(f"   Reasons: {', '.join(reasons)}")
        
        if confirm_each:
            response = input("   Delete this study? (y/n/q to quit): ").lower().strip()
            if response == 'q':
                print("Deletion process cancelled.")
                break
            elif response != 'y':
                print("   Skipped.")
                skipped_count += 1
                continue
        
        try:
            with transaction.atomic():
                study_info = {
                    'id': study.id,
                    'accession': study.accession_number,
                    'patient': study.patient.full_name
                }
                
                # Delete the study (cascades to related objects)
                study.delete()
                
                print(f"   ✅ Deleted study {study_info['accession']}")
                deleted_count += 1
                
        except Exception as e:
            print(f"   ❌ Error deleting study {study.accession_number}: {e}")
    
    print(f"\n📊 Summary:")
    print(f"   Deleted: {deleted_count}")
    print(f"   Skipped: {skipped_count}")
    print(f"   Total processed: {deleted_count + skipped_count}")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == '--list':
        list_test_studies()
    elif command == '--delete-confirm':
        print("🚨 WARNING: This will delete test studies from your database!")
        print("You will be asked to confirm each deletion.")
        response = input("Do you want to continue? (yes/no): ").lower().strip()
        if response == 'yes':
            delete_test_studies(confirm_each=True)
        else:
            print("Operation cancelled.")
    elif command == '--delete-all':
        print("🚨 DANGER: This will delete ALL identified test studies without confirmation!")
        print("This action cannot be undone!")
        response = input("Type 'DELETE ALL TEST STUDIES' to confirm: ").strip()
        if response == 'DELETE ALL TEST STUDIES':
            delete_test_studies(confirm_each=False)
        else:
            print("Operation cancelled.")
    else:
        print("Invalid command. Use --list, --delete-confirm, or --delete-all")
        print(__doc__)
        sys.exit(1)


if __name__ == '__main__':
    main()