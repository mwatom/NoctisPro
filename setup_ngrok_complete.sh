#!/bin/bash

# 🔧 Complete Ngrok Setup with Authentication
# This script will set up ngrok authentication and connect to your static URL

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

STATIC_URL="mallard-shining-curiously.ngrok-free.app"
LOCAL_PORT=8000
NGROK_BINARY="/workspace/ngrok"

echo -e "${CYAN}🔧 Complete Ngrok Setup for Static URL${NC}"
echo "======================================"
echo ""

# Function to check if ngrok is authenticated
check_auth() {
    if $NGROK_BINARY config check > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to setup authentication
setup_auth() {
    echo -e "${BLUE}Setting up ngrok authentication...${NC}"
    
    # Check for existing auth token in various places
    local auth_token=""
    
    # Check environment variable
    if [ -n "${NGROK_AUTHTOKEN:-}" ]; then
        auth_token="$NGROK_AUTHTOKEN"
        echo -e "${GREEN}Found auth token in environment variable${NC}"
    fi
    
    # Check .env file
    if [ -z "$auth_token" ] && [ -f "/workspace/.env" ]; then
        auth_token=$(grep "^NGROK_AUTHTOKEN=" /workspace/.env 2>/dev/null | cut -d'=' -f2 | tr -d '"' || true)
        if [ -n "$auth_token" ] && [ "$auth_token" != "\${NGROK_AUTHTOKEN:-}" ]; then
            echo -e "${GREEN}Found auth token in .env file${NC}"
        else
            auth_token=""
        fi
    fi
    
    # If no token found, prompt user
    if [ -z "$auth_token" ]; then
        echo -e "${YELLOW}⚠️  Ngrok authentication token required${NC}"
        echo ""
        echo "To get your FREE ngrok auth token:"
        echo -e "1. Visit: ${CYAN}https://dashboard.ngrok.com/signup${NC}"
        echo -e "2. Sign up for a free account"
        echo -e "3. Go to: ${CYAN}https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
        echo -e "4. Copy your auth token"
        echo ""
        
        while [ -z "$auth_token" ]; do
            read -p "Enter your ngrok auth token: " auth_token
            if [ -z "$auth_token" ]; then
                echo -e "${RED}❌ Auth token cannot be empty${NC}"
            fi
        done
    fi
    
    # Configure ngrok with the token
    echo -e "${BLUE}Configuring ngrok with auth token...${NC}"
    if $NGROK_BINARY config add-authtoken "$auth_token"; then
        echo -e "${GREEN}✅ Ngrok authentication configured successfully!${NC}"
        
        # Save token to .env file for future use
        if [ ! -f "/workspace/.env" ]; then
            echo "NGROK_AUTHTOKEN=$auth_token" > /workspace/.env
        else
            if grep -q "NGROK_AUTHTOKEN" /workspace/.env; then
                sed -i "s/NGROK_AUTHTOKEN=.*/NGROK_AUTHTOKEN=$auth_token/" /workspace/.env
            else
                echo "NGROK_AUTHTOKEN=$auth_token" >> /workspace/.env
            fi
        fi
        echo -e "${BLUE}Auth token saved to .env file for future use${NC}"
        
        return 0
    else
        echo -e "${RED}❌ Failed to configure ngrok authentication${NC}"
        return 1
    fi
}

# Function to start the tunnel
start_tunnel() {
    echo -e "${BLUE}Starting ngrok tunnel...${NC}"
    
    # Kill any existing ngrok processes
    pkill ngrok 2>/dev/null || true
    sleep 2
    
    # Check if Django is running
    if curl -s http://localhost:$LOCAL_PORT > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Django server detected on port $LOCAL_PORT${NC}"
    else
        echo -e "${YELLOW}⚠️  Django server not detected on port $LOCAL_PORT${NC}"
        echo "Make sure your Django server is running:"
        echo -e "${CYAN}cd ~/NoctisPro && daphne -b 0.0.0.0 -p 8000 noctis_pro.asgi:application${NC}"
        echo ""
        echo "Continuing anyway..."
    fi
    
    # Start ngrok
    echo -e "${CYAN}Command: $NGROK_BINARY http --url=$STATIC_URL $LOCAL_PORT${NC}"
    nohup $NGROK_BINARY http --url=$STATIC_URL $LOCAL_PORT > /workspace/ngrok_final.log 2>&1 &
    local ngrok_pid=$!
    
    # Wait for startup
    sleep 5
    
    # Check if ngrok is running
    if kill -0 $ngrok_pid 2>/dev/null; then
        echo -e "${GREEN}✅ Ngrok tunnel started successfully!${NC}"
        echo ""
        echo -e "${GREEN}🎉 SUCCESS! Your application is now live at:${NC}"
        echo -e "${CYAN}https://$STATIC_URL${NC}"
        echo ""
        echo -e "${BLUE}📋 Connection Details:${NC}"
        echo "   Public URL: https://$STATIC_URL"
        echo "   Local Port: $LOCAL_PORT"
        echo "   Process ID: $ngrok_pid"
        echo "   Log file: /workspace/ngrok_final.log"
        echo ""
        echo -e "${BLUE}🔗 Quick Links:${NC}"
        echo -e "   Main App: ${CYAN}https://$STATIC_URL${NC}"
        echo -e "   Admin Panel: ${CYAN}https://$STATIC_URL/admin/${NC}"
        echo ""
        
        # Test connection
        echo -e "${BLUE}Testing connection...${NC}"
        sleep 2
        if curl -s -H "ngrok-skip-browser-warning: 1" "https://$STATIC_URL" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ URL is accessible and responding!${NC}"
        else
            echo -e "${YELLOW}⚠️  URL test inconclusive - may still be starting up${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}✅ Setup Complete!${NC}"
        echo -e "${BLUE}To stop ngrok: ${CYAN}kill $ngrok_pid${NC}"
        echo -e "${BLUE}To view logs: ${CYAN}tail -f /workspace/ngrok_final.log${NC}"
        
    else
        echo -e "${RED}❌ Failed to start ngrok tunnel${NC}"
        echo "Error details:"
        cat /workspace/ngrok_final.log
        return 1
    fi
}

# Main execution
main() {
    # Check if already authenticated
    if check_auth; then
        echo -e "${GREEN}✅ Ngrok is already authenticated${NC}"
    else
        echo -e "${YELLOW}⚠️  Ngrok needs authentication${NC}"
        if ! setup_auth; then
            echo -e "${RED}❌ Failed to setup authentication${NC}"
            exit 1
        fi
    fi
    
    # Start the tunnel
    start_tunnel
}

# Run main function
main "$@"