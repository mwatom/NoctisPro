#!/bin/bash

# 🛑 Stop NoctisPro Online Deployment

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/deployment_pids.env"

echo -e "${YELLOW}🛑 Stopping NoctisPro Online Deployment...${NC}"
echo ""

# Use the service manager to stop
print_status "Stopping NoctisPro service..."
/workspace/noctispro_service.sh stop

print_success "✅ Deployment stopped successfully!"
print_status "Your application is now offline."
echo ""
echo -e "${BLUE}ℹ️ To restart later: ${CYAN}./noctispro_service.sh start${NC}"