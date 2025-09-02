#!/bin/bash

# 🏥 Professional NoctisPro One-Line Deployment Masterpiece
# Medical Imaging Excellence - Complete System Deployment in One Command
# Enhanced with masterpiece-level automation and professional reliability

set -euo pipefail

# Professional color palette
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r CYAN='\033[0;36m'
declare -r WHITE='\033[1;37m'
declare -r NC='\033[0m'

# Professional icons
declare -r ICON_ROCKET="🚀"
declare -r ICON_HOSPITAL="🏥"
declare -r ICON_SUCCESS="✅"

echo
echo -e "${WHITE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${WHITE}║${NC}     ${ICON_ROCKET} ${CYAN}Professional NoctisPro One-Line Deployment${NC} ${ICON_ROCKET}     ${WHITE}║${NC}"
echo -e "${WHITE}║${NC}              ${GREEN}Medical Imaging Excellence Automation${NC}              ${WHITE}║${NC}"
echo -e "${WHITE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Professional deployment execution
echo -e "${CYAN}${ICON_HOSPITAL} Executing Professional Deployment Masterpiece...${NC}"
echo

# Run the professional deployment
if "$SCRIPT_DIR/professional_deployment_masterpiece.sh"; then
    echo
    echo -e "${GREEN}${ICON_SUCCESS} Professional deployment completed successfully!${NC}"
    echo
    
    # Auto-start the system
    echo -e "${CYAN}${ICON_ROCKET} Starting Professional Medical Imaging System...${NC}"
    "$SCRIPT_DIR/professional_startup_masterpiece.sh"
else
    echo -e "${RED}🚨 Professional deployment failed!${NC}"
    echo "Check logs: $SCRIPT_DIR/professional_deployment.log"
    exit 1
fi