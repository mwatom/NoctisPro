#!/bin/bash

# Noctis Pro PACS - ngrok Authentication Setup
# This script helps set up ngrok authentication for public access

echo "🔐 Setting up ngrok Authentication"
echo "================================="

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_status() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[NOTE]${NC} $1"
}

# Check if ngrok exists
if [[ ! -f "ngrok" ]]; then
    echo "❌ ngrok binary not found!"
    echo "Please download ngrok first from https://ngrok.com/download"
    exit 1
fi

print_info "ngrok binary found ✅"

# Check if already authenticated
if ./ngrok config check 2>/dev/null; then
    print_status "ngrok is already authenticated!"
    
    # Show current configuration
    echo ""
    print_info "Current ngrok configuration:"
    ./ngrok config check
    
    echo ""
    echo "You can proceed with the production deployment:"
    echo -e "${CYAN}./deploy_production_ngrok.sh${NC}"
    exit 0
fi

echo ""
print_warning "ngrok is not authenticated yet."
echo ""
echo "To set up ngrok for public access:"
echo ""
echo "1. 📝 Sign up for a free ngrok account:"
echo -e "   ${CYAN}https://ngrok.com/signup${NC}"
echo ""
echo "2. 🔑 Get your authentication token:"
echo -e "   • Login to ${CYAN}https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
echo -e "   • Copy your authtoken"
echo ""
echo "3. 🔧 Authenticate ngrok (choose one method):"
echo ""
echo -e "   ${GREEN}Method A - Interactive:${NC}"
echo -e "   ${CYAN}./ngrok config add-authtoken YOUR_TOKEN_HERE${NC}"
echo ""
echo -e "   ${GREEN}Method B - Automated:${NC}"
echo "   Enter your authtoken when prompted below"
echo ""

# Prompt for authtoken
read -p "Enter your ngrok authtoken (or press Enter to skip): " AUTHTOKEN

if [[ -n "$AUTHTOKEN" ]]; then
    print_info "Setting up ngrok authentication..."
    
    if ./ngrok config add-authtoken "$AUTHTOKEN"; then
        print_status "ngrok authentication successful!"
        
        # Verify authentication
        if ./ngrok config check 2>/dev/null; then
            print_status "Authentication verified ✅"
            
            echo ""
            echo "🎉 ngrok is now ready for production deployment!"
            echo ""
            echo "Next steps:"
            echo -e "1. Run: ${CYAN}./deploy_production_ngrok.sh${NC}"
            echo "2. Share the public URL with your team"
            echo ""
        else
            print_warning "Authentication may not be working properly"
        fi
    else
        echo "❌ Failed to authenticate ngrok"
        echo "Please check your authtoken and try again"
        exit 1
    fi
else
    echo ""
    print_warning "Skipping authentication setup"
    echo ""
    echo "📋 Manual setup instructions:"
    echo ""
    echo "1. Get your authtoken from: https://dashboard.ngrok.com/get-started/your-authtoken"
    echo -e "2. Run: ${CYAN}./ngrok config add-authtoken YOUR_TOKEN${NC}"
    echo -e "3. Then run: ${CYAN}./deploy_production_ngrok.sh${NC}"
    echo ""
    echo "🆓 Free tier limitations:"
    echo "• 1 online ngrok process"
    echo "• Random URLs (changes on restart)"
    echo "• 40 connections/minute"
    echo ""
    echo "💎 Paid features include:"
    echo "• Custom domains"
    echo "• Reserved domains"
    echo "• Higher connection limits"
    echo "• Password protection"
    echo ""
fi

echo ""
print_info "You can also run the production deployment without authentication"
print_info "It will work with ngrok's free tier limitations"
echo ""
echo -e "To proceed: ${CYAN}./deploy_production_ngrok.sh${NC}"