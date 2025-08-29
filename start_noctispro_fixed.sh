#!/bin/bash

echo "🚀 Starting NoctisPro with SQLite Database..."

# Set environment variables for SQLite
export USE_SQLITE=true
export DEBUG=true
export SECRET_KEY=django-insecure-7x!8k@m$z9h#4p&x3w2v6t@n5q8r7y#3e$6u9i%m&o^2d1f0g
export ALLOWED_HOSTS=*
export DATABASE_PATH=/workspace/db.sqlite3
export USE_DUMMY_CACHE=true
export DISABLE_REDIS=true
export SESSION_TIMEOUT_MINUTES=30
export SESSION_WARNING_MINUTES=5

# Activate virtual environment
source /workspace/venv/bin/activate

# Change to project directory
cd /workspace

echo "🔄 Running database migrations..."
python manage.py migrate

echo "👤 Creating admin user..."
python manage.py shell << EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
    print("✅ Admin user created: admin/admin123")
else:
    print("✅ Admin user already exists: admin/admin123")
EOF

echo "📦 Collecting static files..."
python manage.py collectstatic --noinput

echo "🚀 Starting NoctisPro server..."
python manage.py runserver 0.0.0.0:8000
