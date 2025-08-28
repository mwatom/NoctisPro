#!/bin/bash

echo "🔧 NoctisPro Ngrok Static URL Setup"
echo "=================================="
echo ""

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo "❌ Ngrok is not installed. Please run: ./setup_ngrok.sh"
    exit 1
fi

# Function to update ngrok config
update_ngrok_config() {
    local config_file="$HOME/.config/ngrok/ngrok.yml"
    local subdomain="$1"
    local domain="$2"
    
    if [ ! -f "$config_file" ]; then
        echo "❌ Ngrok config file not found at $config_file"
        return 1
    fi
    
    # Update the configuration file
    if [ ! -z "$domain" ]; then
        # Configure custom domain
        sed -i "s/# *noctispro-domain:/  noctispro-domain:/" "$config_file"
        sed -i "s/# *proto: http/    proto: http/" "$config_file"
        sed -i "s/# *addr: 8000/    addr: 8000/" "$config_file"
        sed -i "s/# *hostname: .*/    hostname: $domain/" "$config_file"
        sed -i "s/# *inspect: true/    inspect: true/" "$config_file"
        echo "✅ Updated ngrok config for custom domain: $domain"
    elif [ ! -z "$subdomain" ]; then
        # Configure static subdomain
        sed -i "s/# *noctispro-static:/  noctispro-static:/" "$config_file"
        sed -i "s/# *proto: http/    proto: http/" "$config_file"
        sed -i "s/# *addr: 8000/    addr: 8000/" "$config_file"
        sed -i "s/# *subdomain: .*/    subdomain: $subdomain/" "$config_file"
        sed -i "s/# *inspect: true/    inspect: true/" "$config_file"
        echo "✅ Updated ngrok config for static subdomain: $subdomain"
    fi
}

# Function to update environment file
update_env_config() {
    local subdomain="$1"
    local domain="$2"
    local env_file="/workspace/.env.ngrok"
    
    # Enable static configuration
    sed -i "s/# *NGROK_USE_STATIC=.*/NGROK_USE_STATIC=true/" "$env_file"
    
    if [ ! -z "$domain" ]; then
        sed -i "s/# *NGROK_DOMAIN=.*/NGROK_DOMAIN=$domain/" "$env_file"
        sed -i "s/# *NGROK_SUBDOMAIN=.*/#NGROK_SUBDOMAIN=$subdomain/" "$env_file"
        echo "✅ Updated environment for custom domain: $domain"
    elif [ ! -z "$subdomain" ]; then
        sed -i "s/# *NGROK_SUBDOMAIN=.*/NGROK_SUBDOMAIN=$subdomain/" "$env_file"
        sed -i "s/# *NGROK_DOMAIN=.*/#NGROK_DOMAIN=$domain/" "$env_file"
        echo "✅ Updated environment for static subdomain: $subdomain"
    fi
}

echo "📋 Static URL Setup Options:"
echo ""
echo "1. 🆓 Static Subdomain (Requires paid ngrok account)"
echo "   Example: noctispro.ngrok.io"
echo ""
echo "2. 🌐 Custom Domain (Requires paid account + domain verification)"
echo "   Example: noctis.yourdomain.com"
echo ""
echo "3. ❌ Disable static URLs (use random URLs)"
echo ""

read -p "Choose option [1/2/3]: " choice

case $choice in
    1)
        echo ""
        echo "🔑 Setting up static subdomain..."
        echo ""
        read -p "Enter your preferred subdomain (e.g., 'noctispro' for noctispro.ngrok.io): " subdomain
        
        if [ -z "$subdomain" ]; then
            echo "❌ Subdomain cannot be empty"
            exit 1
        fi
        
        # Validate subdomain format
        if [[ ! $subdomain =~ ^[a-zA-Z0-9-]+$ ]]; then
            echo "❌ Invalid subdomain format. Use only letters, numbers, and hyphens."
            exit 1
        fi
        
        update_ngrok_config "$subdomain" ""
        update_env_config "$subdomain" ""
        
        echo ""
        echo "✅ Static subdomain configured: https://$subdomain.ngrok.io"
        echo ""
        echo "⚠️  Note: Static subdomains require a paid ngrok account!"
        echo "   Sign up for paid plan at: https://dashboard.ngrok.com/billing"
        ;;
        
    2)
        echo ""
        echo "🌐 Setting up custom domain..."
        echo ""
        read -p "Enter your custom domain (e.g., 'noctis.yourdomain.com'): " domain
        
        if [ -z "$domain" ]; then
            echo "❌ Domain cannot be empty"
            exit 1
        fi
        
        # Basic domain validation
        if [[ ! $domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo "❌ Invalid domain format"
            exit 1
        fi
        
        update_ngrok_config "" "$domain"
        update_env_config "" "$domain"
        
        echo ""
        echo "✅ Custom domain configured: https://$domain"
        echo ""
        echo "⚠️  Note: Custom domains require:"
        echo "   1. Paid ngrok account"
        echo "   2. Domain verification in ngrok dashboard"
        echo "   3. DNS CNAME record pointing to ngrok"
        echo ""
        echo "📋 Setup instructions:"
        echo "   1. Go to: https://dashboard.ngrok.com/domains"
        echo "   2. Add your domain: $domain"
        echo "   3. Follow verification instructions"
        ;;
        
    3)
        echo ""
        echo "❌ Disabling static URLs..."
        sed -i "s/NGROK_USE_STATIC=.*/NGROK_USE_STATIC=false/" "/workspace/.env.ngrok"
        echo "✅ Static URLs disabled. Random URLs will be used."
        ;;
        
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "🚀 Next Steps:"
echo ""
echo "1. Ensure you have configured your ngrok auth token:"
echo "   ngrok config add-authtoken <your-token>"
echo ""
echo "2. Start NoctisPro with ngrok:"
echo "   ./start_with_ngrok.sh"
echo ""
echo "3. For systemd service:"
echo "   sudo systemctl daemon-reload"
echo "   sudo systemctl enable noctispro-ngrok.service"
echo "   sudo systemctl start noctispro-ngrok.service"
echo ""

# Test ngrok configuration
echo "🧪 Testing ngrok configuration..."
if ngrok config check > /dev/null 2>&1; then
    echo "✅ Ngrok configuration is valid"
else
    echo "⚠️  Ngrok configuration has issues. Please check:"
    ngrok config check
fi

echo ""
echo "📖 For more information, see: ./NGROK_STATIC_SETUP.md"
echo ""