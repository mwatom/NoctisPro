# 🏥 NoctisPro Production Deployment

## 🚀 Quick Production Setup

### Single Command Installation:
```bash
sudo ./production_deployment.sh
```

This will:
- ✅ Install all system dependencies (Docker, Python, etc.)
- ✅ Configure static ngrok URL: `colt-charmed-lark.ngrok-free.app`
- ✅ Set up Ubuntu server auto-startup services
- ✅ Deploy with latest package versions
- ✅ Create secure production environment
- ✅ Configure systemd services for auto-restart

## 🌐 Access URLs

- **Local Access**: http://localhost:8000
- **Remote Access**: https://colt-charmed-lark.ngrok-free.app

## 🔧 System Management

### Start/Stop Services:
```bash
sudo ./start_production.sh   # Start all services
sudo ./stop_production.sh    # Stop all services
```

### Systemd Service Management:
```bash
# Service control
sudo systemctl start noctispro-production
sudo systemctl stop noctispro-production
sudo systemctl restart noctispro-production
sudo systemctl status noctispro-production

# Ngrok tunnel control
sudo systemctl start noctispro-ngrok
sudo systemctl stop noctispro-ngrok
sudo systemctl restart noctispro-ngrok
sudo systemctl status noctispro-ngrok

# View logs
sudo journalctl -u noctispro-production -f
sudo journalctl -u noctispro-ngrok -f
```

### Docker Management (if not using systemd):
```bash
cd /opt/noctispro
sudo docker-compose -f docker-compose.production.yml logs -f
sudo docker-compose -f docker-compose.production.yml restart
sudo docker-compose -f docker-compose.production.yml down
sudo docker-compose -f docker-compose.production.yml up -d
```

## 🔐 Security Configuration

### Initial Setup:
1. Run `sudo ./production_deployment.sh`
2. Enter admin email and password when prompted
3. System generates secure credentials automatically

### Post-Installation Security:
- Change default database passwords
- Configure firewall rules
- Set up SSL certificates for custom domains
- Regular security updates

## 📦 Package Management

### Latest Versions:
All packages install the latest stable versions:
- Django (latest)
- PostgreSQL (latest)
- Redis (latest)
- All Python dependencies (latest)

### Updating Packages:
```bash
cd /opt/noctispro
sudo docker-compose -f docker-compose.production.yml build --no-cache
sudo docker-compose -f docker-compose.production.yml up -d
```

## 🔄 Auto-Startup Configuration

### Services Enabled:
- `noctispro-production.service` - Main application
- `noctispro-ngrok.service` - Remote access tunnel

### Startup Sequence:
1. System boots
2. Docker starts
3. NoctisPro services start automatically
4. Ngrok tunnel establishes
5. System is accessible locally and remotely

### Boot Behavior:
- Services start automatically on system boot
- Auto-restart on failure
- Graceful shutdown on system stop
- Logging to systemd journal

## 🏥 Production Features

### Architecture:
- **Django**: Latest version web framework
- **PostgreSQL**: Production database
- **Redis**: Caching and session storage
- **Docker**: Containerized deployment
- **Gunicorn**: Production WSGI server
- **Nginx**: Reverse proxy (optional)

### Performance:
- Database connection pooling
- Redis caching
- Static file optimization
- Image processing optimization
- Background task processing

### Monitoring:
- Health check endpoints
- System resource monitoring
- Service status tracking
- Comprehensive logging

## 🌐 Ngrok Configuration

### Static URL:
- **URL**: `colt-charmed-lark.ngrok-free.app`
- **Protocol**: HTTPS
- **Port**: 80 (mapped from internal 8000)

### Service Configuration:
```bash
# Manual ngrok start (if needed)
ngrok http --url=colt-charmed-lark.ngrok-free.app 80

# Check ngrok status
curl http://localhost:4040/api/tunnels
```

## 📊 Health Monitoring

### Health Check Endpoints:
- `/health/` - Comprehensive health check
- `/health/simple/` - Simple OK response
- `/health/ready/` - Readiness check
- `/health/live/` - Liveness check

### System Health Check:
```bash
cd /opt/noctispro
python3 health_check.py
```

## 🔧 Troubleshooting

### Common Issues:

**Services not starting:**
```bash
sudo systemctl status noctispro-production
sudo journalctl -u noctispro-production -n 50
```

**Ngrok tunnel issues:**
```bash
sudo systemctl restart noctispro-ngrok
sudo journalctl -u noctispro-ngrok -n 50
```

**Database connection issues:**
```bash
cd /opt/noctispro
sudo docker-compose -f docker-compose.production.yml logs db
```

**Port conflicts:**
```bash
sudo netstat -tulpn | grep :8000
sudo netstat -tulpn | grep :80
```

### Emergency Recovery:
```bash
# Complete system reset
sudo ./stop_production.sh
sudo ./production_deployment.sh

# Database reset (WARNING: Data loss)
cd /opt/noctispro
sudo docker-compose -f docker-compose.production.yml down -v
sudo docker-compose -f docker-compose.production.yml up -d
```

## 📈 Performance Tuning

### Database Optimization:
- Connection pooling enabled
- Query optimization
- Index usage monitoring

### Cache Configuration:
- Redis for sessions and application cache
- Static file caching
- Image optimization caching

### Resource Limits:
- Docker container resource limits
- Database connection limits
- File upload size limits

## 🛡️ Backup & Recovery

### Automated Backups:
- Database dumps to `/opt/noctispro/backups/`
- DICOM file versioning
- Configuration backups

### Manual Backup:
```bash
cd /opt/noctispro
sudo docker-compose -f docker-compose.production.yml exec db pg_dump -U noctis_user noctis_pro > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restore:
```bash
cd /opt/noctispro
sudo docker-compose -f docker-compose.production.yml exec -T db psql -U noctis_user noctis_pro < backup_file.sql
```

## 📞 Support

### Log Locations:
- **System logs**: `sudo journalctl -u noctispro-production`
- **Ngrok logs**: `sudo journalctl -u noctispro-ngrok`
- **Application logs**: `/opt/noctispro/logs/`
- **Docker logs**: `sudo docker-compose logs`

### Configuration Files:
- **Environment**: `/opt/noctispro/.env.production`
- **Docker**: `/opt/noctispro/docker-compose.production.yml`
- **Services**: `/etc/systemd/system/noctispro-*.service`

### System Requirements:
- **OS**: Ubuntu Server 20.04+ or 22.04+
- **RAM**: 4GB minimum, 8GB+ recommended
- **Storage**: 20GB minimum, 100GB+ recommended
- **CPU**: 2+ cores recommended
- **Network**: Internet connectivity for ngrok

---

**🎉 Your NoctisPro system is now production-ready with auto-startup and latest packages!**