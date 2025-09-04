# Ubuntu Server Security and Storage Management System

A comprehensive security and storage management system for Ubuntu servers that provides:

1. **Automatic Partition Extension** - Monitors disk usage and automatically extends partitions when free space is available
2. **Advanced Log Filtering** - Filters logs to save only valid information and blocks exploit attempts
3. **DICOM Traffic Sanitization** - Sanitizes DICOM traffic, ensuring sterile medical data transmission
4. **Content Sanitization** - Sanitizes reports and chat messages before they reach the server

## 🚀 Quick Start

### Installation

```bash
# Clone or download the system
sudo ./install_security_system.sh

# Start the system
sudo ubuntu-security-system start

# Check status
ubuntu-security-system status
```

## 📋 System Components

### 1. Automatic Partition Extension (`auto_partition_extend.sh`)

**Features:**
- Monitors disk usage in real-time
- Automatically extends LVM partitions when usage exceeds threshold (default: 85%)
- Supports ext2/ext3/ext4, XFS, and Btrfs filesystems
- Systemd integration for continuous monitoring
- Comprehensive logging and error handling

**Configuration:**
- Threshold percentage: 85% (configurable)
- Minimum free space required: 10GB
- Check interval: 30 minutes

**Usage:**
```bash
# Install the service
sudo /workspace/scripts/auto_partition_extend.sh --install

# Manual check
sudo /workspace/scripts/auto_partition_extend.sh --monitor

# Check service status
sudo /workspace/scripts/auto_partition_extend.sh --status
```

### 2. Log Filtering System (`log_filter_system.py`)

**Features:**
- Real-time log monitoring and filtering
- Advanced exploit detection using pattern matching
- SQL injection, XSS, path traversal, and command injection detection
- Behavioral analysis and IP reputation checking
- SQLite database for filtered log storage
- Automatic cleanup of old logs

**Monitored Log Types:**
- Apache/Nginx access logs
- System logs (syslog, auth.log)
- Application logs
- Custom log formats

**Usage:**
```bash
# Process existing logs
python3 /workspace/scripts/log_filter_system.py --process-existing

# Start real-time monitoring
python3 /workspace/scripts/log_filter_system.py --realtime

# Generate security report
python3 /workspace/scripts/log_filter_system.py --report

# Clean up old logs
python3 /workspace/scripts/log_filter_system.py --cleanup
```

### 3. DICOM Traffic Sanitizer (`dicom_traffic_sanitizer.py`)

**Features:**
- DICOM file and network traffic sanitization
- Removes private and dangerous DICOM tags
- Pixel data analysis for embedded malicious content
- Network proxy for real-time DICOM traffic filtering
- Encryption support for sensitive data
- Comprehensive logging and quarantine system

**Sanitization Process:**
- Removes patient identifiers (names, IDs, dates)
- Strips dangerous tags that could contain malicious data
- Analyzes pixel data for embedded executables
- Creates secure hashes of identifiers for tracking
- Adds sanitization metadata to processed files

**Usage:**
```bash
# Sanitize a DICOM file
python3 /workspace/scripts/dicom_traffic_sanitizer.py --sanitize-file /path/to/dicom.dcm

# Start DICOM proxy server
python3 /workspace/scripts/dicom_traffic_sanitizer.py --start-proxy

# Get system status
python3 /workspace/scripts/dicom_traffic_sanitizer.py --status
```

### 4. Reports and Chat Sanitizer (`reports_chat_sanitizer.py`)

**Features:**
- Advanced content analysis using NLP models
- PII detection and redaction
- Malicious content filtering (XSS, SQL injection, etc.)
- Spam and phishing detection
- Toxicity and sentiment analysis
- Rate limiting for chat messages
- Quarantine system for high-risk content

**Content Types Supported:**
- Medical reports (HTML, text, rich text)
- Chat messages and conversations
- User-generated content
- JSON reports and structured data

**Usage:**
```bash
# Sanitize a report file
python3 /workspace/scripts/reports_chat_sanitizer.py --sanitize-report /path/to/report.txt

# Sanitize text content
python3 /workspace/scripts/reports_chat_sanitizer.py --sanitize-text "Your content here" --user-id user123

# Get system statistics
python3 /workspace/scripts/reports_chat_sanitizer.py --stats

# Clean up old data
python3 /workspace/scripts/reports_chat_sanitizer.py --cleanup
```

### 5. Main Orchestrator (`ubuntu_security_orchestrator.py`)

**Features:**
- Centralized management of all security components
- System resource monitoring
- Component health checking
- Automated service management
- Comprehensive logging and alerting
- Web dashboard (optional)

**Monitoring Capabilities:**
- CPU, memory, and disk usage
- Network statistics
- Service health and performance
- Security event tracking
- Automatic alerting for critical issues

**Usage:**
```bash
# Start the orchestrator
sudo python3 /workspace/scripts/ubuntu_security_orchestrator.py --start

# Get system status
python3 /workspace/scripts/ubuntu_security_orchestrator.py --status

# Install as system service
sudo python3 /workspace/scripts/ubuntu_security_orchestrator.py --install

# Run as daemon
sudo python3 /workspace/scripts/ubuntu_security_orchestrator.py --daemon
```

## ⚙️ Configuration

### Main Configuration File: `/etc/ubuntu-security-system/security_orchestrator.conf`

```ini
[monitoring]
monitoring_interval = 300          # 5 minutes
partition_check_interval = 1800    # 30 minutes
log_retention_days = 30

[features]
enable_auto_partition_extension = true
enable_log_filtering = true
enable_dicom_sanitization = true
enable_content_sanitization = true

[security]
log_risk_threshold = 50
dicom_risk_threshold = 50
content_risk_threshold = 40
quarantine_high_risk = true

[dicom]
proxy_port = 11112
target_host = localhost
target_port = 11113
```

### Component-Specific Configuration

Each component can be configured with individual JSON configuration files:
- `/etc/log_filter_config.json`
- `/etc/dicom_sanitizer_config.json`
- `/etc/content_sanitizer_config.json`

## 🔧 System Requirements

### Minimum Requirements
- Ubuntu 18.04 LTS or newer
- Python 3.8+
- 2GB RAM
- 10GB free disk space
- Root privileges

### Recommended Requirements
- Ubuntu 20.04 LTS or newer
- Python 3.9+
- 4GB RAM
- 50GB free disk space
- SSD storage for better performance

### Dependencies
- LVM2 (for partition extension)
- SQLite3
- Python packages (see requirements_security.txt)

## 🚦 Service Management

### Using the Control Script

```bash
# Start all services
sudo ubuntu-security-system start

# Stop all services
sudo ubuntu-security-system stop

# Restart all services
sudo ubuntu-security-system restart

# Check service status
ubuntu-security-system status

# View recent logs
ubuntu-security-system logs

# Install additional dependencies
sudo ubuntu-security-system install-deps
```

### Using systemctl directly

```bash
# Main orchestrator
sudo systemctl start ubuntu-security-orchestrator
sudo systemctl status ubuntu-security-orchestrator
sudo systemctl enable ubuntu-security-orchestrator

# Partition extension timer
sudo systemctl start ubuntu-partition-extend.timer
sudo systemctl status ubuntu-partition-extend.timer
```

## 📊 Monitoring and Logging

### Log Locations
- Main system logs: `/var/log/ubuntu-security-system/`
- Component logs: `/var/log/*_sanitizer.log`
- System databases: `/var/log/*.db`

### Monitoring Dashboard

The system provides a comprehensive status overview:

```bash
# Get detailed system status
python3 /workspace/scripts/ubuntu_security_orchestrator.py --status
```

This returns JSON data with:
- System resource usage
- Component health status
- Security event summaries
- Performance metrics

## 🔐 Security Features

### Exploit Detection
- SQL injection patterns
- XSS attempts
- Path traversal attacks
- Command injection
- Brute force attempts
- Malicious user agents

### Content Sanitization
- PII removal (SSN, credit cards, emails, phone numbers)
- Medical identifier protection
- Malicious code detection
- Spam and phishing filtering
- Toxicity analysis

### DICOM Security
- Private tag removal
- Dangerous content filtering
- Pixel data analysis
- Secure identifier hashing
- Traffic interception and filtering

## 🚨 Alerting and Notifications

### Alert Types
- Disk space warnings
- Security exploits detected
- Service failures
- High resource usage
- Partition extensions performed

### Notification Methods
- System logs
- Email alerts (configurable)
- Webhook notifications (configurable)
- Syslog integration

## 🔧 Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   ```bash
   # Ensure scripts are executable
   sudo chmod +x /opt/ubuntu-security-system/scripts/*
   
   # Check service user permissions
   sudo chown -R root:root /opt/ubuntu-security-system
   ```

2. **Python Module Import Errors**
   ```bash
   # Reinstall dependencies
   sudo ubuntu-security-system install-deps
   
   # Check virtual environment
   source /opt/ubuntu-security-system/bin/activate
   pip list
   ```

3. **Service Won't Start**
   ```bash
   # Check service status
   sudo systemctl status ubuntu-security-orchestrator
   
   # View detailed logs
   sudo journalctl -u ubuntu-security-orchestrator -f
   ```

4. **Partition Extension Not Working**
   ```bash
   # Check LVM tools
   sudo lvdisplay
   sudo vgdisplay
   
   # Test manually
   sudo /opt/ubuntu-security-system/scripts/auto_partition_extend.sh --monitor
   ```

### Log Analysis

```bash
# View system logs
tail -f /var/log/ubuntu-security-system/*.log

# Check database content
sqlite3 /var/log/security_orchestrator.db "SELECT * FROM system_status ORDER BY timestamp DESC LIMIT 10;"

# Monitor real-time events
journalctl -u ubuntu-security-orchestrator -f
```

## 🔄 Updates and Maintenance

### Regular Maintenance
1. **Weekly**: Review security logs and alerts
2. **Monthly**: Check system resource usage and performance
3. **Quarterly**: Update dependencies and security patterns
4. **Annually**: Review and update configuration

### Update Process
```bash
# Update system packages
sudo apt update && sudo apt upgrade

# Update Python dependencies
sudo ubuntu-security-system install-deps

# Restart services
sudo ubuntu-security-system restart
```

## 📈 Performance Optimization

### For High-Volume Environments
1. **Database Optimization**: Use PostgreSQL instead of SQLite for better performance
2. **Distributed Processing**: Run components on separate servers
3. **Caching**: Implement Redis for frequently accessed data
4. **Load Balancing**: Use multiple DICOM proxy instances

### Resource Tuning
```bash
# Adjust monitoring intervals for less frequent checks
# Edit /etc/ubuntu-security-system/security_orchestrator.conf
monitoring_interval = 600  # 10 minutes instead of 5

# Reduce log retention for space savings
log_retention_days = 14    # 2 weeks instead of 30 days
```

## 🤝 Contributing

To contribute to this system:
1. Test changes in a development environment
2. Follow Python PEP 8 style guidelines
3. Add comprehensive logging
4. Update documentation
5. Test with various Ubuntu versions

## 📄 License

This system is provided as-is for educational and security purposes. Use at your own risk and ensure compliance with your organization's security policies.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review system logs for error messages
3. Test individual components separately
4. Ensure all dependencies are properly installed

---

**Note**: This system requires root privileges and makes significant changes to system configuration. Always test in a non-production environment first.