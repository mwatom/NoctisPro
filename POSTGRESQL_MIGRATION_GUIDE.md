# NoctisPro PACS - PostgreSQL Migration Guide

## Overview
This system has been migrated from SQLite to PostgreSQL for production deployment. PostgreSQL provides better performance, scalability, and reliability for medical imaging applications.

## What Was Changed

### 1. Database Configuration
- **Environment Variables**: Updated `.env` file to use PostgreSQL by default
- **Settings**: Django settings already supported PostgreSQL via environment variables
- **Backup**: Original SQLite database backed up as `db.sqlite3.backup.YYYYMMDD_HHMMSS`

### 2. Deployment Scripts Updated
- **deploy_master.sh**: Added PostgreSQL backup/restore functionality
- **deploy_intelligent.sh**: Integrated PostgreSQL setup in native deployment
- **Docker**: Already configured for PostgreSQL (no changes needed)

### 3. New Setup Scripts
- **setup_postgresql.sh**: Basic PostgreSQL setup
- **setup_production_postgresql.sh**: Complete production environment setup

## Current Configuration

### Database Settings (from .env)
```bash
DB_ENGINE=django.db.backends.postgresql
DB_NAME=noctis_pro
DB_USER=noctis_user
DB_PASSWORD=QGO5IebYph3b1V2InOhv4OBLytpWCvOXoGevBs8M-cY
DB_HOST=localhost
DB_PORT=5432
```

### Requirements
All requirements files already include `psycopg2-binary` for PostgreSQL support:
- requirements.txt
- requirements.minimal.txt
- requirements.optimized.txt

## Deployment Options

### Option 1: Complete Production Setup (Recommended)
```bash
sudo bash setup_production_postgresql.sh
```
This will:
- Install PostgreSQL, Redis, Nginx
- Configure PostgreSQL for production
- Set up Python environment
- Install all requirements
- Run Django migrations
- Create admin user
- Configure basic Nginx proxy

### Option 2: PostgreSQL Only
```bash
bash setup_postgresql.sh
```
This will only set up PostgreSQL database.

### Option 3: Docker Deployment
```bash
bash deploy_master.sh
```
The master deployment script will automatically handle PostgreSQL in Docker.

### Option 4: Native Deployment
```bash
bash deploy_intelligent.sh
```
This will set up PostgreSQL and deploy natively.

## Requirements Installation Issues

### Current Status
- ✅ PostgreSQL driver (psycopg2-binary) included in all requirements files
- ❌ System package manager restrictions prevent direct pip installation
- ✅ Virtual environment approach works for development
- ✅ Docker approach bypasses system restrictions

### Solutions for Requirements Issues

1. **Use Virtual Environment** (Development):
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

2. **Use Docker** (Recommended for Production):
   ```bash
   docker-compose up -d
   ```

3. **System Package Installation**:
   ```bash
   sudo apt-get install python3-psycopg2 python3-django python3-redis
   ```

4. **Use Production Setup Script** (Handles everything):
   ```bash
   sudo bash setup_production_postgresql.sh
   ```

## Database Migration Steps

### If you have existing data in SQLite:

1. **Export SQLite data**:
   ```bash
   python manage.py dumpdata > data_backup.json
   ```

2. **Set up PostgreSQL**:
   ```bash
   sudo bash setup_production_postgresql.sh
   ```

3. **Import data to PostgreSQL**:
   ```bash
   source venv_optimized/bin/activate
   python manage.py loaddata data_backup.json
   ```

### For fresh installation:
Just run the production setup script - it handles everything.

## Verification

### Test PostgreSQL Connection:
```bash
PGPASSWORD=QGO5IebYph3b1V2InOhv4OBLytpWCvOXoGevBs8M-cY psql -h localhost -U noctis_user -d noctis_pro -c "SELECT version();"
```

### Test Django with PostgreSQL:
```bash
source venv_optimized/bin/activate
python manage.py check
python manage.py showmigrations
```

### Test Web Application:
```bash
python manage.py runserver 0.0.0.0:8000
```
Then visit http://localhost:8000

## Cleaned Up Files

The following files were removed during cleanup:
- `db.sqlite3` (backed up first)
- `backup_scripts/` directory
- `backup_docs/` directory  
- `backup_logs/` directory
- `backup_misc/` directory
- All `*.log` files
- `deploy_ngrok.sh.bak`
- `docker-compose.yml.bak`
- Various duplicate deployment documentation files

## Security Notes

- Database password is randomly generated and stored in `.env`
- Admin password is configurable via environment variables
- PostgreSQL is configured with proper user permissions
- Production configuration includes security optimizations

## Performance Optimizations

PostgreSQL is configured with:
- `shared_buffers = 256MB`
- `effective_cache_size = 1GB` 
- `maintenance_work_mem = 64MB`
- Connection pooling enabled
- Optimized for medical imaging workloads

## Troubleshooting

### PostgreSQL Connection Issues:
1. Check if PostgreSQL is running: `sudo systemctl status postgresql`
2. Check connection: `sudo -u postgres psql -l`
3. Verify user exists: `sudo -u postgres psql -c "\du"`

### Django Migration Issues:
1. Reset migrations: `python manage.py migrate --fake-initial`
2. Check database connection: `python manage.py dbshell`
3. Verify settings: `python manage.py check`

### Requirements Installation Issues:
1. Use virtual environment: `python3 -m venv venv && source venv/bin/activate`
2. Install system packages: `sudo apt-get install python3-psycopg2`
3. Use Docker: `docker-compose up -d`

## Next Steps

1. Run the production setup script
2. Test the application thoroughly
3. Set up automated backups for PostgreSQL
4. Configure SSL certificates for production
5. Set up monitoring and logging

For immediate deployment, run:
```bash
sudo bash setup_production_postgresql.sh
```