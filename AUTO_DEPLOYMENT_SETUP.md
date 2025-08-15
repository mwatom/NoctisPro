# Noctis Pro Auto-Deployment System

This document explains the complete auto-deployment system for Noctis Pro that ensures the Ubuntu server automatically updates when changes are committed to the GitHub repository.

## Overview

The auto-deployment system consists of several components working together:

1. **GitHub Actions Workflow** - Triggers deployments via SSH
2. **Webhook Listener** - Listens for GitHub push events and triggers deployments
3. **Deployment Script** - Handles the actual update process with rollback capability
4. **Systemd Services** - Ensures all components start automatically on boot
5. **Health Monitoring** - Verifies system health and automatically restarts failed services

## Components

### 1. GitHub Actions Workflow (`.github/workflows/deploy.yml`)

Automatically triggers when code is pushed to the `main` branch. It connects to your server via SSH and runs the deployment script.

**Required GitHub Secrets:**
- `SSH_HOST` - Your server's IP address or domain
- `SSH_USER` - SSH username (typically `root` or `ubuntu`)
- `SSH_KEY` - Private SSH key for authentication
- `SSH_PORT` - SSH port (optional, defaults to 22)

### 2. Webhook Listener (`tools/webhook_listener.py`)

A Python service that listens for GitHub webhook events and triggers local deployments. Features:
- Signature verification for security
- Rate limiting to prevent spam deployments
- Real-time logging of deployment progress
- Health check endpoint at `/health`

### 3. Deployment Script (`ops/deploy_from_git.sh`)

A robust deployment script that:
- Creates backups before deployment
- Handles failures with automatic rollback
- Performs health checks to ensure successful deployment
- Updates dependencies and runs migrations
- Restarts services in optimal order for minimal downtime

### 4. Systemd Services

All services are configured to start automatically on boot:
- `noctis-web.service` - Main Django web application
- `noctis-celery.service` - Background task processor
- `noctis-dicom.service` - DICOM receiver
- `noctis-webhook.service` - GitHub webhook listener
- `noctis-startup-check.service` - Post-boot health verification

### 5. Health Monitoring (`ops/startup_check.sh`)

A comprehensive monitoring script that:
- Checks if all services are running
- Verifies web service responds to HTTP requests
- Tests webhook endpoint functionality
- Ensures DICOM port is listening
- Automatically restarts failed services

## Setup Instructions

### 1. Initial Server Setup

Run the installation script to set up all services:

```bash
sudo bash ops/install_services.sh [YOUR_DOMAIN] [DUCKDNS_SUBDOMAIN] [DUCKDNS_TOKEN]
```

This will:
- Install all required dependencies
- Configure systemd services
- Set up nginx with SSL
- Enable auto-start on boot
- Install monitoring scripts

### 2. GitHub Repository Setup

#### Option A: GitHub Actions (Recommended)

1. Add the following secrets to your GitHub repository:
   - `SSH_HOST`: Your server's IP or domain
   - `SSH_USER`: SSH username
   - `SSH_KEY`: Your SSH private key
   - `SSH_PORT`: SSH port (optional)

2. The workflow will automatically trigger on pushes to `main` branch.

#### Option B: GitHub Webhooks

1. In your GitHub repository, go to Settings → Webhooks
2. Add a new webhook:
   - **Payload URL**: `http://YOUR_SERVER:9000/`
   - **Content type**: `application/json`
   - **Secret**: Use the value from `/etc/noctis/noctis.env` (`GITHUB_WEBHOOK_SECRET`)
   - **Events**: Just the push event

3. Ensure your server's port 9000 is accessible from the internet.

### 3. Verify Setup

Check if all services are running:

```bash
sudo /usr/local/bin/noctis-check status
```

Run a full health check:

```bash
sudo /usr/local/bin/noctis-check check
```

## Configuration Files

### Environment Configuration (`/etc/noctis/noctis.env`)

Contains all environment variables used by the services:

```bash
APP_DIR=/opt/noctis
VENV_DIR=/opt/noctis/venv
REPO_URL=https://github.com/mwatom/NoctisPro
HOST=127.0.0.1
PORT=8000
WEBHOOK_PORT=9000
DICOM_PORT=11112
GITHUB_WEBHOOK_SECRET=your_secret_here
```

### Service Configuration

All systemd service files are in `ops/` directory:
- `noctis-web.service` - Web application
- `noctis-celery.service` - Background tasks
- `noctis-dicom.service` - DICOM receiver
- `webhook.service` - Webhook listener

## Monitoring and Logs

### Log Files

- `/var/log/noctis-deploy.log` - Deployment activities
- `/var/log/noctis-webhook.log` - Webhook events
- `/var/log/noctis-startup.log` - Boot-time health checks

### Check Service Status

```bash
# Check all services
systemctl status noctis-web noctis-celery noctis-dicom noctis-webhook

# Check specific service logs
journalctl -u noctis-web.service -f

# Run health check
noctis-check check
```

### Webhook Health Check

```bash
curl http://localhost:9000/health
```

## Troubleshooting

### Services Don't Start on Boot

1. Check if services are enabled:
   ```bash
   systemctl is-enabled noctis-web.service
   ```

2. Enable if not enabled:
   ```bash
   sudo systemctl enable noctis-web.service
   ```

3. Check service logs:
   ```bash
   journalctl -u noctis-web.service
   ```

### Deployment Fails

1. Check deployment logs:
   ```bash
   tail -f /var/log/noctis-deploy.log
   ```

2. Manually run deployment:
   ```bash
   sudo bash /opt/noctis/ops/deploy_from_git.sh
   ```

3. Check if git repository is accessible:
   ```bash
   cd /opt/noctis
   git fetch origin
   ```

### Webhook Not Triggering

1. Check webhook service:
   ```bash
   systemctl status noctis-webhook.service
   ```

2. Test webhook endpoint:
   ```bash
   curl http://localhost:9000/health
   ```

3. Check webhook logs:
   ```bash
   tail -f /var/log/noctis-webhook.log
   ```

4. Verify GitHub webhook configuration and secret

### Web Service Not Responding

1. Check web service status:
   ```bash
   systemctl status noctis-web.service
   ```

2. Check if port is listening:
   ```bash
   netstat -tlnp | grep :8000
   ```

3. Check nginx configuration:
   ```bash
   nginx -t
   systemctl status nginx
   ```

## Auto-Recovery Features

The system includes several auto-recovery mechanisms:

1. **Service Restart**: All services automatically restart on failure
2. **Health Monitoring**: Post-boot verification ensures services are healthy
3. **Deployment Rollback**: Failed deployments automatically rollback to previous version
4. **Rate Limiting**: Prevents excessive deployment attempts
5. **Dependency Management**: Services start in correct order with proper dependencies

## Security Considerations

1. **Webhook Secret**: Always use a strong webhook secret
2. **SSH Keys**: Use key-based authentication, disable password auth
3. **Firewall**: Only expose necessary ports (80, 443, 22, optionally 9000)
4. **SSL/TLS**: Use HTTPS for production deployments
5. **User Permissions**: Run services with appropriate user permissions

## Performance Optimization

1. **Zero-Downtime Deployment**: Services restart in optimal order
2. **Backup Strategy**: Quick rollback capability if issues occur
3. **Health Checks**: Verify service health before considering deployment successful
4. **Resource Monitoring**: Monitor CPU, memory, and disk usage

This auto-deployment system ensures your Noctis Pro server stays up-to-date automatically while maintaining high availability and reliability.