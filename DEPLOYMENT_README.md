# NoctisPro PACS - Intelligent Auto-Detection Deployment System

## 🚀 Overview

This intelligent deployment system automatically detects server capabilities and deploys NoctisPro PACS with optimal configuration for any server environment. The system adapts to available resources, operating system, and infrastructure to provide the best possible deployment experience.

## ✨ Key Features

### 🤖 Intelligent Auto-Detection
- **Operating System Detection**: Supports Ubuntu, Debian, RHEL, CentOS, Fedora, and more
- **Architecture Recognition**: Optimizes for x86_64, ARM64, and other architectures  
- **Resource Analysis**: Automatically detects CPU, memory, and storage capabilities
- **Software Detection**: Identifies available tools (Docker, Python, Nginx, etc.)

### 🎯 Adaptive Deployment Modes
- **Docker Full**: Complete containerized deployment with all services
- **Docker Minimal**: Resource-efficient containerized deployment
- **Native Systemd**: Traditional Linux service deployment
- **Native Simple**: Basic deployment for constrained environments

### ⚡ Resource Optimization
- **Memory-Aware**: Adjusts service limits based on available RAM
- **CPU-Optimized**: Calculates optimal worker processes for CPU count
- **Storage-Conscious**: Adapts to available disk space
- **Network-Adaptive**: Handles online/offline deployment scenarios

### 🛡️ Enterprise-Grade Features
- **Comprehensive Testing**: Built-in validation and testing suite
- **Backup & Rollback**: Automatic backup creation with rollback capability
- **Security Hardening**: Security-first configuration generation
- **Health Monitoring**: Continuous monitoring and auto-recovery
- **Performance Tuning**: System-specific performance optimizations

## 📋 System Requirements

### Minimum Requirements
- **Memory**: 1GB RAM (2GB+ recommended)
- **Storage**: 5GB free space (10GB+ recommended)
- **CPU**: 1 core (2+ cores recommended)
- **OS**: Linux-based system with bash support

### Supported Operating Systems
- Ubuntu 18.04+ (recommended: 22.04, 24.04)
- Debian 9+ (recommended: 11, 12)
- RHEL/CentOS 7+ (recommended: 8, 9)
- Rocky Linux 8+
- AlmaLinux 8+
- Fedora 30+

### Supported Architectures
- x86_64/amd64 (fully supported)
- ARM64/aarch64 (supported with limitations)
- Other architectures (basic support)

## 🚀 Quick Start

### One-Command Deployment

```bash
# Download and run the master deployment script
curl -fsSL https://raw.githubusercontent.com/your-repo/NoctisPro/main/deploy_master.sh | bash
```

### Manual Deployment

```bash
# Clone the repository
git clone https://github.com/your-repo/NoctisPro.git
cd NoctisPro

# Run the intelligent deployment
./deploy_master.sh
```

### Test-Only Mode

```bash
# Run validation tests without deployment
./deploy_master.sh --test-only
```

## 📊 Deployment Components

### Core Scripts

| Script | Purpose | Description |
|--------|---------|-------------|
| `deploy_master.sh` | **Master Orchestrator** | Main deployment script that coordinates all components |
| `deploy_intelligent.sh` | **System Detection** | Analyzes system and determines optimal deployment mode |
| `dependency_optimizer.py` | **Dependency Management** | Optimizes Python dependencies based on system capabilities |
| `deployment_configurator.sh` | **Configuration Generator** | Creates optimized configurations for detected environment |
| `test_deployment.sh` | **Validation Suite** | Comprehensive testing and validation framework |

### Generated Configurations

```
deployment_configs/
├── nginx/                 # Nginx reverse proxy configurations
│   └── nginx.optimized.conf
├── systemd/              # Systemd service files
│   ├── noctis-web.service
│   ├── noctis-dicom.service
│   └── noctis-celery.service
├── docker/               # Docker configurations
│   ├── Dockerfile.optimized
│   └── docker-compose.optimized.yml
├── env/                  # Environment templates
│   ├── .env.development
│   ├── .env.production.template
│   └── .env.docker
└── monitoring/           # Monitoring and health checks
    ├── health_check.sh
    ├── noctis-logrotate
    └── prometheus.yml
```

## 🎛️ Deployment Modes

### Docker Full (Recommended for 8GB+ RAM)
- Complete containerized deployment
- All services in containers
- Nginx reverse proxy
- Automatic SSL setup
- Resource limits and monitoring

### Docker Minimal (4GB+ RAM)
- Essential services only
- Optimized for resource efficiency
- Basic monitoring
- Manual SSL configuration

### Native Systemd (2GB+ RAM)
- Traditional Linux service deployment
- Systemd service management
- Direct system integration
- Lower resource overhead

### Native Simple (1GB+ RAM)
- Basic deployment for constrained environments
- Simple process management
- Minimal resource usage
- Manual service management

## 🔧 Advanced Configuration

### Custom Deployment Options

```bash
# Specify deployment mode
./deploy_master.sh --mode docker_full

# Custom resource allocation
./deploy_master.sh --memory 8 --cpu 4

# Enable specific features
./deploy_master.sh --ssl --monitoring --backup
```

### Environment Variables

```bash
# Override system detection
export FORCE_DEPLOYMENT_MODE="docker_minimal"
export OVERRIDE_MEMORY_GB=4
export OVERRIDE_CPU_CORES=2

# Deployment options
export ENABLE_SSL=true
export ENABLE_MONITORING=true
export SKIP_TESTS=false
```

## 🏥 DICOM Configuration

### Automatic Setup
- DICOM receiver automatically configured on port 11112
- AE Title: `NOCTIS_SCP`
- Facility-based routing
- Security validation

### Manual DICOM Machine Configuration
```
Called AE Title:   NOCTIS_SCP
Calling AE Title:  [Your facility's AE Title]
Hostname:          your-server-ip-or-domain
Port:              11112
Protocol:          DICOM TCP/IP
```

## 🛡️ Security Features

### Automatic Security Hardening
- **Service Isolation**: Non-root user execution
- **Resource Limits**: Memory and CPU constraints
- **Network Security**: Firewall configuration
- **SSL/TLS**: Automatic certificate management
- **Access Control**: Role-based permissions

### Security Configurations
- Nginx security headers
- Systemd security settings
- Docker security constraints
- Environment variable protection
- Audit logging

## 📊 Monitoring & Management

### Health Monitoring
```bash
# Check system health
./manage_noctis.sh health

# View service status
./manage_noctis.sh status

# Monitor logs
./manage_noctis.sh logs
```

### Automated Monitoring
- Health checks every 15 minutes
- Automatic service restart on failure
- Resource usage monitoring
- Log rotation and archival

### Management Commands
```bash
# Service management
./manage_noctis.sh start|stop|restart|status

# Health and monitoring
./manage_noctis.sh health|logs

# Updates and maintenance
./manage_noctis.sh update
```

## 🔄 Backup & Recovery

### Automatic Backup
- Database backup before deployment
- Configuration backup
- Environment file backup
- Complete rollback capability

### Manual Backup
```bash
# Create backup
./manage_noctis.sh backup

# Restore from backup
./manage_noctis.sh restore backup_20241218_143022
```

### Disaster Recovery
```bash
# Emergency rollback
./deploy_master.sh --rollback

# System restoration
./manage_noctis.sh restore --full
```

## 🧪 Testing & Validation

### Comprehensive Test Suite
- System detection validation
- Configuration generation tests
- Security compliance checks
- Performance benchmarks
- Integration testing

### Running Tests
```bash
# Full test suite
./test_deployment.sh

# Specific test categories
./test_deployment.sh --category security
./test_deployment.sh --category performance
```

### Test Coverage
- ✅ System detection accuracy
- ✅ Configuration validity
- ✅ Security compliance
- ✅ Performance optimization
- ✅ Integration functionality

## 📈 Performance Optimization

### Automatic Optimizations
- **Worker Processes**: CPU-based calculation
- **Memory Limits**: RAM-aware allocation
- **Connection Pooling**: Database optimization
- **Caching Strategy**: Redis configuration
- **Static File Serving**: Nginx optimization

### Resource Allocation Examples

| System Resources | Deployment Mode | Web Workers | Memory Allocation |
|------------------|-----------------|-------------|-------------------|
| 1GB RAM, 1 CPU   | Native Simple   | 1           | 512MB web        |
| 2GB RAM, 2 CPU   | Native Systemd  | 2           | 1GB web          |
| 4GB RAM, 4 CPU   | Docker Minimal  | 4           | 1.5GB web        |
| 8GB RAM, 8 CPU   | Docker Full     | 8           | 2GB web + services |

## 🚨 Troubleshooting

### Common Issues

#### Deployment Fails
```bash
# Check logs
tail -f /tmp/noctis_master_deploy_*.log

# Run diagnostics
./deploy_master.sh --test-only

# Force specific mode
FORCE_DEPLOYMENT_MODE=native_simple ./deploy_master.sh
```

#### Services Not Starting
```bash
# Check service status
./manage_noctis.sh status

# View detailed logs
./manage_noctis.sh logs

# Restart services
./manage_noctis.sh restart
```

#### DICOM Connection Issues
```bash
# Test DICOM port
telnet localhost 11112

# Check DICOM logs
docker-compose logs dicom_receiver
# or
journalctl -u noctis-dicom
```

### System-Specific Issues

#### Low Memory Systems
- Use `native_simple` mode
- Disable background services
- Increase swap space

#### ARM Architecture
- Expect longer build times
- Some packages may need compilation
- Use minimal deployment mode

#### Network Issues
- Check firewall settings
- Verify port availability
- Test connectivity

## 🔗 Access Information

After successful deployment:

- **Web Interface**: http://localhost:8000
- **Admin Panel**: http://localhost:8000/admin/
- **DICOM Port**: localhost:11112
- **Default Login**: admin / admin123

### Production Access
- Configure domain name in environment
- Set up SSL certificates
- Configure firewall rules
- Update DNS records

## 📚 Additional Resources

### Documentation
- [Installation Guide](docs/INSTALLATION.md)
- [Configuration Reference](docs/CONFIGURATION.md)
- [API Documentation](docs/API.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)

### Support
- [GitHub Issues](https://github.com/your-repo/NoctisPro/issues)
- [Discussion Forum](https://github.com/your-repo/NoctisPro/discussions)
- [Wiki](https://github.com/your-repo/NoctisPro/wiki)

## 🤝 Contributing

We welcome contributions! Please see:
- [Contributing Guidelines](CONTRIBUTING.md)
- [Development Setup](docs/DEVELOPMENT.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with Django and modern web technologies
- DICOM processing powered by pydicom and pynetdicom
- Container orchestration with Docker
- System service management with systemd
- Reverse proxy and load balancing with Nginx

---

**NoctisPro PACS** - Intelligent healthcare imaging solution that adapts to your infrastructure.

*For technical support or questions, please open an issue on GitHub or consult the documentation.*