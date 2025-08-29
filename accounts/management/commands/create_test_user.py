from django.core.management.base import BaseCommand
from accounts.models import User, Facility
from django.contrib.auth.hashers import make_password

class Command(BaseCommand):
    help = 'Create a test user for system testing'

    def add_arguments(self, parser):
        parser.add_argument('--username', type=str, default='testuser', help='Username for the test user')
        parser.add_argument('--password', type=str, default='testpass123', help='Password for the test user')
        parser.add_argument('--role', type=str, default='radiologist', choices=['admin', 'radiologist', 'facility'], help='Role for the test user')

    def handle(self, *args, **options):
        username = options['username']
        password = options['password']
        role = options['role']
        
        # Check if user already exists
        if User.objects.filter(username=username).exists():
            self.stdout.write(
                self.style.WARNING(f'User {username} already exists!')
            )
            return
        
        # Get or create a facility
        facility, created = Facility.objects.get_or_create(
            name='Test Facility',
            defaults={
                'address': '123 Test Street',
                'phone': '555-1234',
                'email': 'test@facility.com',
                'license_number': 'TEST-LICENSE-001',
                'is_active': True
            }
        )
        
        if created:
            self.stdout.write(f'Created facility: {facility.name}')
        
        # Create the test user
        user = User.objects.create(
            username=username,
            email=f'{username}@test.com',
            first_name='Test',
            last_name='User',
            password=make_password(password),
            role=role,
            facility=facility,
            is_verified=True,
            is_active=True,
            is_staff=True,
            is_superuser=(role == 'admin')
        )
        
        self.stdout.write(
            self.style.SUCCESS(f'Successfully created test user: {username}')
        )
        self.stdout.write(f'  - Role: {user.get_role_display()}')
        self.stdout.write(f'  - Facility: {facility.name}')
        self.stdout.write(f'  - Password: {password}')
        self.stdout.write(f'  - Verified: {user.is_verified}')
        self.stdout.write(f'  - Active: {user.is_active}')