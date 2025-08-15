#!/usr/bin/env bash
set -euo pipefail

# GitHub Integration Setup Helper
# This script helps configure GitHub Actions and Webhooks for auto-deployment

log() { echo "[$(date '+%F %T')] $*"; }
success() { echo -e "\e[32m✓\e[0m $*"; }
warning() { echo -e "\e[33m⚠\e[0m $*"; }
error() { echo -e "\e[31m✗\e[0m $*" >&2; }

# Load configuration
ENV_FILE=${ENV_FILE:-/etc/noctis/noctis.env}
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

# Get server information
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || hostname -I | awk '{print $1}')
SERVER_DOMAIN=${PUBLIC_URL:-}
WEBHOOK_SECRET=${GITHUB_WEBHOOK_SECRET:-}
SSH_PORT=${SSH_PORT:-22}

echo "=== Noctis Pro GitHub Integration Setup ==="
echo

# Check if environment file exists
if [ ! -f "$ENV_FILE" ]; then
    error "Environment file not found: $ENV_FILE"
    echo "Please run the installation script first:"
    echo "  sudo bash ops/install_services.sh"
    exit 1
fi

echo "Current configuration:"
echo "  Server IP: $SERVER_IP"
echo "  Server Domain: ${SERVER_DOMAIN:-"Not set"}"
echo "  Webhook Port: ${WEBHOOK_PORT:-9000}"
echo "  Webhook Secret: ${WEBHOOK_SECRET:0:8}***"
echo "  SSH Port: $SSH_PORT"
echo

# Check if webhook service is running
if systemctl is-active --quiet noctis-webhook.service; then
    success "Webhook service is running"
else
    warning "Webhook service is not running"
    echo "Start it with: sudo systemctl start noctis-webhook.service"
fi

# Test webhook endpoint
echo "Testing webhook endpoint..."
if curl -s -f "http://localhost:${WEBHOOK_PORT}/health" >/dev/null; then
    success "Webhook endpoint is accessible locally"
else
    error "Webhook endpoint is not accessible"
fi

echo
echo "=== GitHub Actions Setup ==="
echo
echo "To set up GitHub Actions for auto-deployment:"
echo
echo "1. Go to your GitHub repository: https://github.com/YOUR_USERNAME/NoctisPro"
echo "2. Click on 'Settings' → 'Secrets and variables' → 'Actions'"
echo "3. Add the following repository secrets:"
echo
echo "   SSH_HOST = $SERVER_IP"
echo "   SSH_USER = $(whoami)"
echo "   SSH_PORT = $SSH_PORT"
echo "   SSH_KEY  = (paste your private SSH key here)"
echo
echo "4. To get your SSH private key, run:"
echo "   cat ~/.ssh/id_rsa"
echo "   (or the path to your private key)"
echo

# Generate SSH key if it doesn't exist
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "SSH key not found. Generate one with:"
    echo "  ssh-keygen -t rsa -b 4096 -C 'noctis-deployment'"
    echo "  cat ~/.ssh/id_rsa.pub  # Add this to authorized_keys"
    echo
fi

echo "=== GitHub Webhook Setup (Alternative) ==="
echo
echo "If you prefer webhooks instead of GitHub Actions:"
echo
echo "1. Go to your GitHub repository: https://github.com/YOUR_USERNAME/NoctisPro"
echo "2. Click on 'Settings' → 'Webhooks'"
echo "3. Click 'Add webhook' and configure:"
echo
echo "   Payload URL: http://$SERVER_IP:${WEBHOOK_PORT}/"
if [ -n "$SERVER_DOMAIN" ]; then
    echo "   (or use domain: $SERVER_DOMAIN:${WEBHOOK_PORT}/)"
fi
echo "   Content type: application/json"
echo "   Secret: $WEBHOOK_SECRET"
echo "   Events: Just the push event"
echo "   Active: ✓"
echo
echo "4. Make sure port ${WEBHOOK_PORT} is open in your firewall:"
echo "   sudo ufw allow ${WEBHOOK_PORT}/tcp"
echo

# Check firewall status
if command -v ufw >/dev/null 2>&1; then
    echo "Current firewall status:"
    ufw status | grep -E "(Status|${WEBHOOK_PORT})" || echo "Port ${WEBHOOK_PORT} not found in firewall rules"
    echo
fi

echo "=== Testing the Setup ==="
echo
echo "To test the auto-deployment system:"
echo
echo "1. Make a test commit to your repository:"
echo "   git commit --allow-empty -m 'Test auto-deployment'"
echo "   git push origin main"
echo
echo "2. Check deployment logs:"
echo "   tail -f /var/log/noctis-deploy.log"
echo
echo "3. Check webhook logs (if using webhooks):"
echo "   tail -f /var/log/noctis-webhook.log"
echo
echo "4. Verify services are healthy:"
echo "   noctis-check check"
echo

echo "=== Troubleshooting ==="
echo
echo "If deployment doesn't work:"
echo
echo "1. Check GitHub Actions logs (if using Actions)"
echo "2. Check webhook delivery (if using webhooks)"
echo "3. Verify SSH access:"
echo "   ssh $(whoami)@$SERVER_IP -p $SSH_PORT 'echo Connected successfully'"
echo
echo "4. Test manual deployment:"
echo "   sudo bash $APP_DIR/ops/deploy_from_git.sh"
echo
echo "5. Check service status:"
echo "   systemctl status noctis-web noctis-celery noctis-dicom noctis-webhook"
echo

echo "=== Security Recommendations ==="
echo
success "Use SSH keys instead of passwords"
success "Keep webhook secrets secure"
success "Only expose necessary ports"
if [ "${WEBHOOK_PORT}" != "9000" ]; then
    warning "Consider using a non-default webhook port for security"
fi
echo

echo "Setup complete! Your auto-deployment system is ready."
echo "For detailed documentation, see: AUTO_DEPLOYMENT_SETUP.md"