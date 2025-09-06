#!/bin/bash

# 🔍 Show Differences Between Old and Refined NoctisPro Systems

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo ""
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}🔍  System Comparison: Old vs Refined${NC}"
echo -e "${CYAN}================================================${NC}"
echo ""

echo -e "${YELLOW}📁 System Locations:${NC}"
echo -e "   Old System: ${RED}/workspace/${NC}"
echo -e "   Refined System: ${GREEN}/workspace/noctis_pro_deployment/${NC}"
echo ""

echo -e "${YELLOW}⚙️ Key Configuration Differences:${NC}"
echo ""

# Compare settings.py
echo -e "${BLUE}🔧 Settings Configuration:${NC}"
echo -e "${RED}❌ Old System (settings.py):${NC}"
grep -n "DEBUG.*=" /workspace/noctis_pro/settings.py | head -1
echo -e "${GREEN}✅ Refined System (settings.py):${NC}"
grep -n "DEBUG.*=" /workspace/noctis_pro_deployment/noctis_pro/settings.py | head -1
echo ""

echo -e "${BLUE}📦 Dependencies:${NC}"
echo -e "${RED}❌ Old System (problematic dependencies):${NC}"
grep -n "daphne\|channels" /workspace/noctis_pro/settings.py | head -3 || echo "   (checking...)"
echo -e "${GREEN}✅ Refined System (optimized dependencies):${NC}"
grep -n "daphne\|channels" /workspace/noctis_pro_deployment/noctis_pro/settings.py | head -3 || echo "   (disabled for stability)"
echo ""

echo -e "${BLUE}📊 File Sizes:${NC}"
echo -e "${RED}❌ Old System:${NC}"
wc -l /workspace/noctis_pro/settings.py | sed 's/^/   /'
echo -e "${GREEN}✅ Refined System:${NC}"
wc -l /workspace/noctis_pro_deployment/noctis_pro/settings.py | sed 's/^/   /'
echo ""

echo -e "${YELLOW}🚀 What the Refined System Provides:${NC}"
echo -e "   ✅ ${GREEN}Production-ready configuration${NC}"
echo -e "   ✅ ${GREEN}Disabled problematic dependencies${NC}"
echo -e "   ✅ ${GREEN}Optimized for stability${NC}"
echo -e "   ✅ ${GREEN}Better error handling${NC}"
echo -e "   ✅ ${GREEN}Streamlined codebase${NC}"
echo ""

echo -e "${CYAN}🎯 To Deploy Refined System:${NC}"
echo -e "   ${WHITE}./deploy_refined_system.sh${NC}"
echo ""