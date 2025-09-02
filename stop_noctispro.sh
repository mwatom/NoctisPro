#!/bin/bash

# 🛑 NoctisPro Stop Script
# Stops all NoctisPro processes

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🛑 Stopping NoctisPro services...${NC}"

# Stop Django
if pkill -f "manage.py runserver"; then
    echo -e "${GREEN}✅ Django server stopped${NC}"
else
    echo -e "${YELLOW}⚠️  No Django server running${NC}"
fi

# Stop Ngrok
if pkill -f "ngrok"; then
    echo -e "${GREEN}✅ Ngrok tunnel stopped${NC}"
else
    echo -e "${YELLOW}⚠️  No ngrok tunnel running${NC}"
fi

echo -e "${GREEN}🏁 All NoctisPro services stopped${NC}"