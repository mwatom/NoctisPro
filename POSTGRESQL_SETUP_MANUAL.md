# PostgreSQL Setup for NoctisPro (Manual Instructions)

If you don't have sudo access or prefer manual setup, follow these steps:

## Option 1: Use No-Sudo Script
```bash
./setup_postgresql_no_sudo.sh
```

## Option 2: Manual Setup

### Step 1: Check PostgreSQL Status
```bash
# Check if PostgreSQL is running
pg_isready -h localhost -p 5432

# If not running and you have access, try:
sudo systemctl start postgresql
# or
sudo service postgresql start
```

### Step 2: Create Environment File
Create `.env.production` with your PostgreSQL credentials:

```bash
cat > .env.production << EOF
# PostgreSQL Database Configuration
POSTGRES_DB=noctis_pro
POSTGRES_USER=your_pg_username
POSTGRES_PASSWORD=your_pg_password
POSTGRES_HOST=localhost
POSTGRES_PORT=5432

# Django Settings
DJANGO_SETTINGS_MODULE=noctis_pro.settings
SECRET_KEY=your-secret-key-here
DEBUG=False
ALLOWED_HOSTS=*,localhost,127.0.0.1

# Application Settings
STATIC_ROOT=/workspace/staticfiles
MEDIA_ROOT=/workspace/media
SERVE_MEDIA_FILES=True
BUILD_TARGET=production
ENVIRONMENT=production
HEALTH_CHECK_ENABLED=True
TIME_ZONE=UTC
USE_TZ=True
DICOM_STORAGE_PATH=/workspace/media/dicom
EOF
```

### Step 3: Setup Virtual Environment
```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### Step 4: Run Migrations
```bash
source venv/bin/activate
source .env.production
python manage.py migrate
```

### Step 5: Start Application
```bash
source venv/bin/activate
source .env.production
python manage.py runserver
```

## Option 3: Cloud PostgreSQL Services

If you don't have local PostgreSQL access, use a cloud service:

### Railway.app (Free Tier)
1. Go to [railway.app](https://railway.app)
2. Create account and new project
3. Add PostgreSQL database
4. Get connection details and use in `.env.production`

### Supabase (Free Tier)
1. Go to [supabase.com](https://supabase.com)
2. Create new project
3. Go to Settings → Database
4. Get connection string and configure `.env.production`

### Example with Cloud Database:
```bash
# For cloud database, update .env.production:
POSTGRES_DB=your_cloud_db_name
POSTGRES_USER=your_cloud_user
POSTGRES_PASSWORD=your_cloud_password
POSTGRES_HOST=your_cloud_host
POSTGRES_PORT=5432
```

## Troubleshooting

### Connection Issues
```bash
# Test PostgreSQL connection
psql -h localhost -U postgres -d postgres

# Test with specific user
psql -h localhost -U noctis_user -d noctis_pro
```

### Permission Issues
If you get permission errors, your PostgreSQL user might need database creation permissions:
```sql
-- Connect as superuser and run:
ALTER USER noctis_user CREATEDB;
GRANT ALL PRIVILEGES ON DATABASE noctis_pro TO noctis_user;
```

### Django Migration Issues
```bash
# Reset migrations if needed
source venv/bin/activate
source .env.production
python manage.py migrate --fake-initial
```

## Verification

After setup, verify everything works:

```bash
source venv/bin/activate
source .env.production

# Test database connection
python manage.py dbshell

# Check migrations
python manage.py showmigrations

# Create superuser
python manage.py createsuperuser

# Start server
python manage.py runserver
```

Your NoctisPro application is now configured to use **PostgreSQL exclusively**!