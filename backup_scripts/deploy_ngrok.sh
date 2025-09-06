#!/bin/bash

# 🚀 Noctis Pro PACS - Ngrok Deployment Script
# This script sets up and deploys Noctis Pro PACS with ngrok tunneling

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for user input
wait_for_user() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read
}

print_success "🚀 Starting Noctis Pro PACS Ngrok Deployment"
echo "================================================="

# Check prerequisites
print_status "Checking prerequisites..."

if ! command_exists python3; then
    print_error "Python 3 is not installed. Please install Python 3.9+ and try again."
    exit 1
fi

if ! command_exists pip; then
    print_error "pip is not installed. Please install pip and try again."
    exit 1
fi

if ! command_exists ngrok; then
    print_warning "ngrok is not installed. Installing ngrok..."
    
    # Install ngrok based on OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
        echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
        sudo apt update && sudo apt install ngrok
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OS
        if command_exists brew; then
            brew install ngrok/ngrok/ngrok
        else
            print_error "Please install Homebrew or manually install ngrok from https://ngrok.com/download"
            exit 1
        fi
    else
        print_error "Unsupported OS. Please manually install ngrok from https://ngrok.com/download"
        exit 1
    fi
fi

print_success "Prerequisites checked"

# Check if ngrok is configured
print_status "Checking ngrok configuration..."
if ! ngrok config check > /dev/null 2>&1; then
    print_warning "Ngrok is not configured with an authtoken."
    echo "Please get your authtoken from https://dashboard.ngrok.com/get-started/your-authtoken"
    echo -n "Enter your ngrok authtoken: "
    read NGROK_AUTHTOKEN
    
    if [ -z "$NGROK_AUTHTOKEN" ]; then
        print_error "Authtoken cannot be empty"
        exit 1
    fi
    
    ngrok config add-authtoken "$NGROK_AUTHTOKEN"
    print_success "Ngrok configured with authtoken"
fi

# Install Python dependencies
print_status "Installing Python dependencies..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
    print_success "Dependencies installed"
else
    print_warning "requirements.txt not found. Please ensure all dependencies are installed."
fi

# Database setup
print_status "Setting up database..."
if [ ! -f "db.sqlite3" ]; then
    python manage.py makemigrations
    python manage.py migrate
    print_success "Database created and migrated"
    
    print_status "Creating superuser account..."
    echo "Please create an admin user for the system:"
    python manage.py createsuperuser
else
    print_status "Database already exists, running migrations..."
    python manage.py migrate
    print_success "Database migrations completed"
fi

# Collect static files
print_status "Collecting static files..."
python manage.py collectstatic --noinput
print_success "Static files collected"

# Create logs directory
mkdir -p logs
print_success "Logs directory created"

# Environment configuration
print_status "Configuring environment..."

# Check if .env exists
if [ ! -f ".env" ]; then
    print_status "Creating .env file..."
    
    # Generate secret key
    SECRET_KEY=$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
    
    cat > .env << EOL
# Noctis Pro PACS Environment Configuration
DEBUG=False
SECRET_KEY=$SECRET_KEY

# Ngrok configuration (will be updated automatically)
NGROK_URL=
ALLOWED_HOSTS=*,localhost,127.0.0.1

# Database
DB_ENGINE=django.db.backends.sqlite3
DB_NAME=db.sqlite3

# Security (adjusted for ngrok)
SECURE_SSL_REDIRECT=False
SESSION_COOKIE_SECURE=False
CSRF_COOKIE_SECURE=False

# File uploads
FILE_UPLOAD_MAX_MEMORY_SIZE=3221225472
DATA_UPLOAD_MAX_MEMORY_SIZE=3221225472

# Media files
SERVE_MEDIA_FILES=True
EOL
    print_success ".env file created"
else
    print_status ".env file already exists"
fi

# Start Django server in background
print_status "Starting Django server..."
python manage.py runserver 0.0.0.0:8000 > logs/django.log 2>&1 &
DJANGO_PID=$!
print_success "Django server started (PID: $DJANGO_PID)"

# Wait for Django to start
sleep 3

# Start ngrok tunnel
print_status "Starting ngrok tunnel..."
ngrok http 8000 --log=stdout > logs/ngrok.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to start
sleep 5

# Get ngrok URL
print_status "Getting ngrok URL..."
NGROK_URL=""
for i in {1..10}; do
    NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | python -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data['tunnels']:
        if tunnel['proto'] == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
" 2>/dev/null)
    
    if [ ! -z "$NGROK_URL" ]; then
        break
    fi
    print_status "Waiting for ngrok to start... (attempt $i/10)"
    sleep 2
done

if [ -z "$NGROK_URL" ]; then
    print_error "Could not get ngrok URL. Please check ngrok logs."
    kill $DJANGO_PID $NGROK_PID 2>/dev/null
    exit 1
fi

# Update .env with ngrok URL
print_status "Updating environment with ngrok URL..."
sed -i "s|NGROK_URL=.*|NGROK_URL=$NGROK_URL|" .env

# Extract domain from URL
NGROK_DOMAIN=$(echo $NGROK_URL | sed 's|https://||' | sed 's|http://||')
sed -i "s|ALLOWED_HOSTS=.*|ALLOWED_HOSTS=*,$NGROK_DOMAIN,localhost,127.0.0.1|" .env

print_success "Environment updated with ngrok configuration"

# Restart Django to apply new settings
print_status "Restarting Django server with ngrok configuration..."
kill $DJANGO_PID 2>/dev/null || true
sleep 2
python manage.py runserver 0.0.0.0:8000 > logs/django.log 2>&1 &
DJANGO_PID=$!

print_success "Django server restarted (PID: $DJANGO_PID)"

# Display deployment information
echo ""
echo "================================================="
print_success "🎉 Noctis Pro PACS Successfully Deployed!"
echo "================================================="
echo ""
echo -e "${GREEN}🌐 Access URLs:${NC}"
echo -e "   Public URL:  ${BLUE}$NGROK_URL${NC}"
echo -e "   Local URL:   ${BLUE}http://localhost:8000${NC}"
echo -e "   Admin URL:   ${BLUE}$NGROK_URL/admin/${NC}"
echo ""
echo -e "${GREEN}📊 System Information:${NC}"
echo -e "   Django PID:  $DJANGO_PID"
echo -e "   Ngrok PID:   $NGROK_PID"
echo -e "   Log Files:   logs/django.log, logs/ngrok.log"
echo ""
echo -e "${GREEN}👤 User Roles:${NC}"
echo -e "   ${BLUE}Admin:${NC}        Can manage everything"
echo -e "   ${BLUE}Radiologist:${NC}  Can view all studies, write reports, delete"
echo -e "   ${BLUE}Facility:${NC}     Can only access their facility's data"
echo ""
echo -e "${GREEN}🔧 Management Commands:${NC}"
echo -e "   View Django logs:  tail -f logs/django.log"
echo -e "   View ngrok logs:   tail -f logs/ngrok.log"
echo -e "   Stop services:     kill $DJANGO_PID $NGROK_PID"
echo -e "   Restart Django:    python manage.py runserver 0.0.0.0:8000"
echo ""
echo -e "${YELLOW}⚠️  Important Notes:${NC}"
echo -e "   • Keep this terminal open to maintain the tunnel"
echo -e "   • The ngrok URL will change when you restart ngrok"
echo -e "   • For production, consider using a paid ngrok plan"
echo -e "   • Always use strong passwords for admin accounts"
echo ""

# Create stop script
cat > stop_ngrok.sh << 'EOL'
#!/bin/bash
echo "Stopping Noctis Pro PACS services..."
pkill -f "python manage.py runserver"
pkill -f "ngrok http"
echo "Services stopped."
EOL
chmod +x stop_ngrok.sh

print_success "Stop script created: ./stop_ngrok.sh"

# Wait for user to stop
echo -e "${YELLOW}Press Ctrl+C to stop all services${NC}"
trap 'print_status "Stopping services..."; kill $DJANGO_PID $NGROK_PID 2>/dev/null; print_success "Services stopped. Goodbye!"; exit 0' INT

# Keep script running
while true; do
    sleep 10
    # Check if processes are still running
    if ! kill -0 $DJANGO_PID 2>/dev/null; then
        print_error "Django server stopped unexpectedly"
        break
    fi
    if ! kill -0 $NGROK_PID 2>/dev/null; then
        print_error "Ngrok tunnel stopped unexpectedly"
        break
    fi
done

print_error "One or more services stopped. Please check logs and restart."
exit 1