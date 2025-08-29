#!/bin/bash

# NoctisPro Production Startup Script

echo "🚀 Starting NoctisPro with PostgreSQL..."

# Set PostgreSQL environment variables
export POSTGRES_DB=noctis_pro
export POSTGRES_USER=noctis_user
export POSTGRES_PASSWORD=noctis123
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export DEBUG=false
export SECRET_KEY=django-insecure-production-key-$(date +%s)

# Activate virtual environment
source venv/bin/activate

# Start PostgreSQL if not running
sudo service postgresql start

# Run migrations
echo "🔄 Running migrations..."
python manage.py migrate

# Collect static files
echo "📦 Collecting static files..."
python manage.py collectstatic --noinput

# Create/update admin user
echo "👤 Setting up admin user..."
echo "
from django.contrib.auth import get_user_model
User = get_user_model()
admin, created = User.objects.get_or_create(username='admin')
admin.set_password('admin123')
admin.is_staff = True
admin.is_superuser = True
admin.save()
print('✅ Admin user ready: admin/admin123')
" | python manage.py shell

# Start the server
echo "🌐 Starting Django server on http://localhost:8000"
echo "👤 Admin login: http://localhost:8000/admin/ (admin/admin123)"
echo "🏥 Main app: http://localhost:8000/worklist/"

python manage.py runserver 0.0.0.0:8000