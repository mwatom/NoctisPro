from django.core.management.base import BaseCommand
from accounts.models import User, Facility


class Command(BaseCommand):
    help = 'Fix admin user by setting proper role and permissions'

    def add_arguments(self, parser):
        parser.add_argument(
            '--username',
            type=str,
            default='admin',
            help='Username of the admin user to fix (default: admin)'
        )
        parser.add_argument(
            '--password',
            type=str,
            default='admin123',
            help='Password for the admin user (default: admin123)'
        )
        parser.add_argument(
            '--email',
            type=str,
            default='admin@noctispro.local',
            help='Email for the admin user (default: admin@noctispro.local)'
        )

    def handle(self, *args, **options):
        username = options['username']
        password = options['password']
        email = options['email']

        # Check if user exists
        try:
            user = User.objects.get(username=username)
            # Update existing user
            user.role = 'admin'
            user.is_staff = True
            user.is_superuser = True
            user.is_active = True
            user.email = email
            user.set_password(password)
            user.save()
            self.stdout.write(
                self.style.SUCCESS(f'Successfully updated admin user: {username}')
            )
        except User.DoesNotExist:
            # Create new admin user
            user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
                role='admin',
                is_staff=True,
                is_superuser=True,
                is_active=True
            )
            self.stdout.write(
                self.style.SUCCESS(f'Successfully created admin user: {username}')
            )

        # Create default facility if none exists
        if not Facility.objects.exists():
            facility = Facility.objects.create(
                name='Default Medical Center',
                address='123 Medical Center Drive',
                phone='(555) 123-4567',
                email='info@medicalcenter.com',
                license_number='MED-001',
                ae_title='NOCTISPRO'
            )
            self.stdout.write(
                self.style.SUCCESS('Created default facility')
            )

        self.stdout.write('Admin user configuration:')
        self.stdout.write(f'  Username: {username}')
        self.stdout.write(f'  Password: {password}')
        self.stdout.write(f'  Email: {email}')
        self.stdout.write(f'  Role: Administrator')
        self.stdout.write(f'  Staff: Yes')
        self.stdout.write(f'  Superuser: Yes')
        self.stdout.write(f'  Active: Yes')
        
        self.stdout.write(
            self.style.WARNING('\n⚠️  Remember to change the password in production!')
        )