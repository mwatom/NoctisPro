# Ubuntu Docker Setup Guide - Desktop to Server Transfer

This guide will help you set up the NOCTIS Pro system on Ubuntu Desktop using Docker, with easy transfer capabilities to Ubuntu Server.

## Overview

Your system is a Django-based medical imaging platform with:
- **Web Application**: Django with PostgreSQL database
- **Background Tasks**: Celery with Redis
- **DICOM Processing**: Medical image processing services
- **File Storage**: Media and static files
- **Production Ready**: Nginx, SSL, monitoring capabilities

## Quick Start

### 1. Ubuntu Desktop Setup

```bash
# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
sudo apt install docker-compose-plugin

# Log out and back in to apply group changes
```

### 2. Clone and Setup

```bash
git clone <your-repo-url> noctis-pro
cd noctis-pro

# Copy environment template
cp .env.desktop.example .env

# Edit environment variables
nano .env
```

### 3. Start Development Environment

```bash
# Start all services
docker compose -f docker-compose.desktop.yml up -d

# Check status
docker compose -f docker-compose.desktop.yml ps

# View logs
docker compose -f docker-compose.desktop.yml logs -f
```

### 4. Access Your Application

- **Web Interface**: http://localhost:8000
- **Admin Panel**: http://localhost:8000/admin
- **DICOM Receiver**: Port 11112
- **Database**: localhost:5432 (for external tools)

## Desktop vs Server Differences

| Component | Desktop | Server |
|-----------|---------|---------|
| **Ports** | All exposed for development | Only necessary ports exposed |
| **SSL** | Optional | Required with Let's Encrypt |
| **Nginx** | Optional | Required reverse proxy |
| **Monitoring** | Optional | Prometheus + Grafana |
| **Backups** | Manual | Automated daily |
| **Security** | Development settings | Production hardened |
| **Performance** | Debug mode | Optimized for production |

## Transfer to Server Process

### 1. Data Export (Desktop)
```bash
./scripts/export-for-server.sh
```

### 2. Server Setup
```bash
./scripts/setup-ubuntu-server.sh
```

### 3. Data Import (Server)
```bash
./scripts/import-from-desktop.sh
```

### 4. Production Deployment
```bash
docker compose -f docker-compose.production.yml up -d
```

## Directory Structure

```
noctis-pro/
├── docker-compose.desktop.yml      # Desktop development
├── docker-compose.production.yml   # Server production
├── .env.desktop.example            # Desktop environment template
├── .env.server.example             # Server environment template
├── scripts/
│   ├── export-for-server.sh        # Export data for transfer
│   ├── setup-ubuntu-server.sh      # Server initial setup
│   ├── import-from-desktop.sh      # Import data on server
│   └── backup-system.sh            # Backup automation
├── deployment/
│   ├── nginx/                      # Nginx configurations
│   ├── ssl/                        # SSL certificate scripts
│   └── monitoring/                 # Prometheus/Grafana configs
└── data/                           # Persistent data (created at runtime)
    ├── postgres/                   # Database files
    ├── redis/                      # Redis data
    ├── media/                      # Uploaded files
    ├── static/                     # Static web files
    └── backups/                    # System backups
```

## Key Features

### Development (Desktop)
- **Hot Reload**: Code changes reflected immediately
- **Debug Mode**: Detailed error messages
- **Direct Access**: All ports exposed for debugging
- **SQLite Option**: Lighter database for testing

### Production (Server)
- **Security**: Hardened containers and network
- **Performance**: Optimized for production workloads
- **Monitoring**: Health checks and metrics
- **Backups**: Automated data protection
- **SSL/TLS**: Secure HTTPS connections

## Common Commands

```bash
# Desktop Development
docker compose -f docker-compose.desktop.yml up -d    # Start
docker compose -f docker-compose.desktop.yml down     # Stop
docker compose -f docker-compose.desktop.yml logs -f  # View logs
docker compose -f docker-compose.desktop.yml exec web bash  # Shell access

# Server Production
docker compose -f docker-compose.production.yml up -d    # Start
docker compose -f docker-compose.production.yml down     # Stop
docker compose -f docker-compose.production.yml logs -f  # View logs

# Data Management
./scripts/backup-system.sh                            # Create backup
./scripts/restore-system.sh backup-20240101.tar.gz    # Restore backup
./scripts/export-for-server.sh                        # Export for transfer
```

## Troubleshooting

### Common Issues

1. **Port Conflicts**: Change ports in docker-compose files
2. **Permission Issues**: Ensure Docker group membership
3. **Database Connection**: Check PostgreSQL container status
4. **File Permissions**: Use `sudo chown -R $USER:$USER data/`

### Health Checks

```bash
# Check all services
docker compose ps

# Check specific service logs
docker compose logs web
docker compose logs db
docker compose logs redis

# Database connection test
docker compose exec db psql -U noctis_user -d noctis_pro -c "SELECT 1;"

# Redis connection test
docker compose exec redis redis-cli ping
```

## Next Steps

1. **Desktop Setup**: Follow the Quick Start section
2. **Development**: Start coding with hot reload enabled
3. **Testing**: Use the development environment for testing
4. **Server Transfer**: When ready, use the transfer scripts
5. **Production**: Deploy to Ubuntu Server with production config

## Support

- Check logs: `docker compose logs -f`
- Shell access: `docker compose exec web bash`
- Database access: `docker compose exec db psql -U noctis_user -d noctis_pro`
- Redis CLI: `docker compose exec redis redis-cli`

---

This setup ensures minimal changes when transferring from desktop to server while maintaining development flexibility and production security.