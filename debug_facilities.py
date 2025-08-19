#!/usr/bin/env python3

import sqlite3
import sys

def debug_facilities():
    """Debug facility assignment issue by checking database directly"""
    
    try:
        # Connect to the database
        conn = sqlite3.connect('db.sqlite3')
        cursor = conn.cursor()
        
        print("=== Facility Assignment Debug ===\n")
        
        # Check if the facilities table exists
        cursor.execute("""
            SELECT name FROM sqlite_master 
            WHERE type='table' AND name='accounts_facility';
        """)
        table_exists = cursor.fetchone()
        
        if not table_exists:
            print("❌ ERROR: accounts_facility table does not exist!")
            print("This suggests migrations haven't been run.")
            return
        
        print("✅ accounts_facility table exists")
        
        # Get all facilities
        cursor.execute("SELECT id, name, is_active, ae_title FROM accounts_facility")
        all_facilities = cursor.fetchall()
        
        print(f"\n📊 Total facilities in database: {len(all_facilities)}")
        
        if not all_facilities:
            print("❌ No facilities found in database!")
            print("\nTo fix this, you need to:")
            print("1. Access the admin panel")
            print("2. Go to Facility Management")
            print("3. Create at least one facility")
            print("4. Make sure the facility is marked as 'Active'")
            return
        
        # Show all facilities
        print("\n📋 All facilities:")
        for facility in all_facilities:
            status = "🟢 ACTIVE" if facility[2] else "🔴 INACTIVE"
            print(f"  - ID: {facility[0]}, Name: '{facility[1]}', Status: {status}, AE Title: '{facility[3]}'")
        
        # Get active facilities (what should appear in dropdown)
        cursor.execute("SELECT id, name, ae_title FROM accounts_facility WHERE is_active = 1")
        active_facilities = cursor.fetchall()
        
        print(f"\n✅ Active facilities (should appear in user form): {len(active_facilities)}")
        
        if not active_facilities:
            print("❌ No ACTIVE facilities found!")
            print("\nTo fix this:")
            print("1. Go to Admin Panel > Facility Management")
            print("2. Edit existing facilities and make sure 'Active' is checked")
            print("3. Or create new facilities with 'Active' checked")
            return
        
        for facility in active_facilities:
            print(f"  - ID: {facility[0]}, Name: '{facility[1]}', AE Title: '{facility[2]}'")
        
        # Check if there are any users assigned to facilities
        cursor.execute("""
            SELECT u.id, u.username, u.role, f.name as facility_name
            FROM accounts_user u
            LEFT JOIN accounts_facility f ON u.facility_id = f.id
            WHERE u.facility_id IS NOT NULL
        """)
        users_with_facilities = cursor.fetchall()
        
        print(f"\n👥 Users with facility assignments: {len(users_with_facilities)}")
        for user in users_with_facilities:
            print(f"  - User: {user[1]} ({user[2]}) → Facility: {user[3]}")
        
        # Create a test facility if none exist
        if not active_facilities:
            print("\n🔧 Creating a test facility...")
            cursor.execute("""
                INSERT INTO accounts_facility (name, address, phone, email, license_number, ae_title, is_active, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))
            """, (
                'Test Medical Center',
                '123 Healthcare Ave, Medical City, MC 12345',
                '+1-555-123-4567',
                'admin@testmedical.com',
                'LIC123456',
                'TESTMC',
                1
            ))
            conn.commit()
            print("✅ Test facility created successfully!")
            
            # Verify it was created
            cursor.execute("SELECT id, name FROM accounts_facility WHERE name = 'Test Medical Center'")
            new_facility = cursor.fetchone()
            if new_facility:
                print(f"   New facility ID: {new_facility[0]}, Name: {new_facility[1]}")
        
        print(f"\n🎯 Summary:")
        print(f"  - Total facilities: {len(all_facilities)}")
        print(f"  - Active facilities: {len(active_facilities)}")
        print(f"  - Users with facilities: {len(users_with_facilities)}")
        
        if active_facilities:
            print(f"\n✅ Facility assignment should work now!")
            print(f"   Active facilities are available for user assignment.")
        else:
            print(f"\n❌ Facility assignment will not work!")
            print(f"   No active facilities available.")
        
    except sqlite3.Error as e:
        print(f"❌ Database error: {e}")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
    finally:
        if conn:
            conn.close()

if __name__ == '__main__':
    debug_facilities()