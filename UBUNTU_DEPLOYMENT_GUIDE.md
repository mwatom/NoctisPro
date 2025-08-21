# NoctisPro Production Deployment Guide for Ubuntu Server 24.04

## PostgreSQL Issues Resolution

This guide addresses common PostgreSQL deployment issues on Ubuntu Server 24.04 and provides solutions.

## Prerequisites

1. **Ubuntu Server 24.04** with sudo access
2. **Internet connection** for downloading Docker and dependencies
3. **At least 4GB RAM** for optimal performance
4. **10GB free disk space** minimum

## Quick Deployment

### Step 1: Make Scripts Executable
```bash
chmod +x start_docker_and_deploy.sh
chmod +x deploy_production.sh
```

### Step 2: Run Deployment
```bash
./start_docker_and_deploy.sh
```

## Manual Deployment Steps

### 1. Install Docker (if not already installed)
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### 2. Start Docker Daemon
```bash
sudo dockerd > /tmp/docker.log 2>&1 &
```

### 3. Verify Docker is Running
```bash
sudo docker info
```

### 4. Create Required Directories
```bash
sudo mkdir -p /opt/noctis/data/{postgres,redis}
sudo mkdir -p /opt/noctis/{media,staticfiles,backups,dicom_storage}
sudo chown -R $USER:$USER /opt/noctis
mkdir -p logs
```

### 5. Configure Environment
The deployment uses `.env.production` file with the following key settings:

```bash
# Database Configuration
POSTGRES_DB=noctis_pro
POSTGRES_USER=noctis_user
POSTGRES_PASSWORD=<secure-password>
POSTGRES_HOST=db
POSTGRES_PORT=5432

# Django Settings
SECRET_KEY=<django-secret-key>
DEBUG=False
```

### 6. Run Production Deployment
```bash
sudo docker compose -f docker-compose.production.yml --env-file .env.production up -d --build
```

## Common PostgreSQL Issues and Solutions

### Issue 1: PostgreSQL Container Fails to Start
**Symptoms:**
- Container exits with code 1
- Error: "database system was not properly shut down"

**Solution:**
```bash
# Stop all containers
sudo docker compose -f docker-compose.production.yml down

# Remove PostgreSQL data (WARNING: This will delete all data)
sudo rm -rf /opt/noctis/data/postgres/*

# Restart deployment
./start_docker_and_deploy.sh
```

### Issue 2: Database Connection Refused
**Symptoms:**
- Django cannot connect to PostgreSQL
- Error: "connection refused"

**Solution:**
```bash
# Check if PostgreSQL container is running
sudo docker ps | grep postgres

# Check PostgreSQL logs
sudo docker compose -f docker-compose.production.yml logs db

# Restart database container
sudo docker compose -f docker-compose.production.yml restart db
```

### Issue 3: Permission Denied Errors
**Symptoms:**
- PostgreSQL fails to write to data directory
- Permission denied errors in logs

**Solution:**
```bash
# Fix directory permissions
sudo chown -R 999:999 /opt/noctis/data/postgres
sudo chmod -R 700 /opt/noctis/data/postgres
```

### Issue 4: Environment Variables Not Loaded
**Symptoms:**
- Default database names/passwords being used
- Authentication failures

**Solution:**
```bash
# Verify environment file exists and has correct values
cat .env.production

# Restart containers with environment file
sudo docker compose -f docker-compose.production.yml --env-file .env.production down
sudo docker compose -f docker-compose.production.yml --env-file .env.production up -d
```

## Verification Steps

### 1. Check All Containers Are Running
```bash
sudo docker ps
```
You should see containers for:
- noctis_db_prod (PostgreSQL)
- noctis_redis_prod (Redis)
- noctis_web_prod (Django Web)
- noctis_celery_prod (Celery Worker)
- noctis_nginx_prod (Nginx)

### 2. Check Database Connection
```bash
sudo docker exec -it noctis_db_prod psql -U noctis_user -d noctis_pro -c "SELECT version();"
```

### 3. Check Web Application
```bash
curl -f http://localhost:8000/health/ || echo "Web app not responding"
```

### 4. Check Logs
```bash
# All services
sudo docker compose -f docker-compose.production.yml logs

# Specific service (e.g., database)
sudo docker compose -f docker-compose.production.yml logs db
```

## Service URLs

- **Web Interface:** http://localhost:8000
- **Admin Panel:** http://localhost:8000/admin/
- **DICOM Receiver:** localhost:11112
- **Database:** localhost:5432 (PostgreSQL)
- **Cache:** localhost:6379 (Redis)

## Backup and Maintenance

### Database Backup
```bash
sudo docker exec noctis_db_prod pg_dump -U noctis_user noctis_pro > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Stop Services
```bash
sudo docker compose -f docker-compose.production.yml down
```

### Update Application
```bash
git pull origin main
sudo docker compose -f docker-compose.production.yml down
sudo docker compose -f docker-compose.production.yml up -d --build
```

## Troubleshooting

### View Real-time Logs
```bash
sudo docker compose -f docker-compose.production.yml logs -f
```

### Access Database Shell
```bash
sudo docker exec -it noctis_db_prod psql -U noctis_user -d noctis_pro
```

### Reset Everything (Nuclear Option)
```bash
sudo docker compose -f docker-compose.production.yml down -v
sudo rm -rf /opt/noctis/data/*
./start_docker_and_deploy.sh
```

## Support

If you encounter issues not covered in this guide:

1. Check the logs: `sudo docker compose -f docker-compose.production.yml logs`
2. Verify all containers are running: `sudo docker ps`
3. Check disk space: `df -h`
4. Check memory usage: `free -h`

## Security Notes

- Change default passwords in `.env.production`
- Configure SSL certificates for production use
- Restrict network access to necessary ports only
- Regular security updates for the host system