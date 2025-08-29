from django.core.management.base import BaseCommand
from accounts.models import User

class Command(BaseCommand):
    help = 'Verify all existing users so they can log in'

    def handle(self, *args, **options):
        users = User.objects.filter(is_verified=False)
        count = users.count()
        
        if count == 0:
            self.stdout.write(
                self.style.SUCCESS('All users are already verified!')
            )
            return
        
        users.update(is_verified=True)
        
        self.stdout.write(
            self.style.SUCCESS(f'Successfully verified {count} users!')
        )
        
        # Show the verified users
        for user in users:
            self.stdout.write(f'  - {user.username} ({user.get_role_display()})')