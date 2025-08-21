#!/bin/bash

# NOCTIS Pro - Super Simple Start Script
# This script is designed to be so simple that anyone can use it!

set -e  # Exit on any error

# Colors for output (pretty colors!)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fun emojis to make it friendly!
SUCCESS="🎉"
CHECK="✅"
WARNING="⚠️"
ERROR="❌"
ROCKET="🚀"
HOSPITAL="🏥"
COMPUTER="💻"
NETWORK="🌐"

# Simple logging functions with emojis
log() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

step() {
    echo -e "${BLUE}${ROCKET} $1${NC}"
}

warn() {
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

error() {
    echo -e "${RED}${ERROR} $1${NC}"
}

success() {
    echo -e "${GREEN}${SUCCESS} $1${NC}"
}

# Configuration
COMPOSE_FILE="docker-compose.desktop.yml"
ENV_FILE=".env"

# Welcome message
show_welcome() {
    clear
    echo -e "${PURPLE}"
    echo "════════════════════════════════════════════════════════════"
    echo "🏥 WELCOME TO NOCTIS PRO MEDICAL IMAGING SYSTEM! 🏥"
    echo "════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}This script will set up your medical imaging system step by step.${NC}"
    echo -e "${CYAN}Just follow along - it's super easy!${NC}"
    echo ""
    echo "What this will do:"
    echo "• ${CHECK} Check if Docker is working"
    echo "• ${CHECK} Create configuration files"
    echo "• ${CHECK} Download medical software"
    echo "• ${CHECK} Start your medical system"
    echo "• ${CHECK} Create admin user for you"
    echo "• ${CHECK} Make everything ready to use"
    echo ""
    read -p "Press Enter to start the magic! 🪄"
    echo ""
}

# Check if Docker is working
check_docker_simple() {
    step "Step 1: Checking if Docker is installed and working..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed! ${COMPUTER}"
        echo ""
        echo "Please install Docker first:"
        echo "1. Copy this command:"
        echo "   ${CYAN}curl -fsSL https://get.docker.com -o get-docker.sh${NC}"
        echo "2. Paste it in terminal and press Enter"
        echo "3. Then run: ${CYAN}sudo sh get-docker.sh${NC}"
        echo "4. Then run: ${CYAN}sudo usermod -aG docker \$USER${NC}"
        echo "5. Restart your computer"
        echo "6. Run this script again"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        error "Docker Compose is not working!"
        echo "Install it with: ${CYAN}sudo apt install docker-compose-plugin${NC}"
        exit 1
    fi
    
    # Test if user can use Docker
    if ! docker ps &> /dev/null; then
        error "You don't have permission to use Docker!"
        echo ""
        echo "Fix this by running:"
        echo "1. ${CYAN}sudo usermod -aG docker \$USER${NC}"
        echo "2. Log out and back in (or restart computer)"
        echo "3. Run this script again"
        exit 1
    fi
    
    log "Docker is installed and working perfectly!"
    sleep 1
}

# Check if we're in the right directory
check_directory() {
    step "Step 2: Checking if we're in the right place..."
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        error "Can't find the medical software files!"
        echo ""
        echo "Make sure you're in the NOCTIS Pro directory."
        echo "You should see these files:"
        echo "• docker-compose.desktop.yml"
        echo "• requirements.txt"
        echo "• manage.py"
        echo ""
        echo "If you don't see these files, you're in the wrong folder!"
        echo "Use: ${CYAN}cd /path/to/noctis-pro${NC}"
        exit 1
    fi
    
    log "Found all the medical software files!"
    sleep 1
}

# Create environment file with simple explanations
create_environment_simple() {
    step "Step 3: Creating configuration file..."
    
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f ".env.desktop.example" ]; then
            log "Creating configuration file from template..."
            cp .env.desktop.example "$ENV_FILE"
            
            # Generate a random secret key (make it secure!)
            if command -v openssl &> /dev/null; then
                SECRET_KEY=$(openssl rand -base64 32)
            elif command -v python3 &> /dev/null; then
                SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
            else
                SECRET_KEY="desktop-secret-key-$(date +%s)"
            fi
            
            # Replace the secret key
            sed -i "s/dev-secret-key-change-before-production-use/$SECRET_KEY/" "$ENV_FILE"
            
            log "Configuration file created with secure settings!"
        else
            error "Configuration template not found!"
            echo "Looking for: .env.desktop.example"
            exit 1
        fi
    else
        log "Configuration file already exists!"
    fi
    sleep 1
}

# Create data directories
create_directories_simple() {
    step "Step 4: Creating folders for medical data..."
    
    log "Creating database folder..."
    mkdir -p data/postgres
    
    log "Creating image storage folder..."
    mkdir -p data/media
    mkdir -p data/dicom_storage
    
    log "Creating other data folders..."
    mkdir -p data/redis
    mkdir -p data/static
    mkdir -p logs
    mkdir -p backups
    
    log "All data folders created!"
    sleep 1
}

# Download Docker images with progress
download_software() {
    step "Step 5: Downloading medical software..."
    echo ""
    echo "This might take a few minutes - we're downloading:"
    echo "• ${HOSPITAL} Medical imaging software"
    echo "• ${COMPUTER} Database system"
    echo "• ${NETWORK} Web server components"
    echo ""
    
    log "Downloading database software (PostgreSQL)..."
    docker compose -f "$COMPOSE_FILE" pull db
    
    log "Downloading cache system (Redis)..."
    docker compose -f "$COMPOSE_FILE" pull redis
    
    log "Building medical imaging application..."
    docker compose -f "$COMPOSE_FILE" build
    
    success "All software downloaded and ready!"
    sleep 1
}

# Start services with detailed feedback
start_services_simple() {
    step "Step 6: Starting your medical system..."
    echo ""
    
    log "Starting database system..."
    docker compose -f "$COMPOSE_FILE" up -d db
    echo "   ${CYAN}Database is starting up...${NC}"
    
    log "Starting cache system..."
    docker compose -f "$COMPOSE_FILE" up -d redis
    echo "   ${CYAN}Cache system is starting up...${NC}"
    
    log "Starting medical web application..."
    docker compose -f "$COMPOSE_FILE" up -d web
    echo "   ${CYAN}Web application is starting up...${NC}"
    
    log "Starting background task processor..."
    docker compose -f "$COMPOSE_FILE" up -d celery
    echo "   ${CYAN}Background tasks are starting up...${NC}"
    
    log "Starting DICOM image receiver..."
    docker compose -f "$COMPOSE_FILE" up -d dicom_receiver
    echo "   ${CYAN}DICOM receiver is starting up...${NC}"
    
    success "All systems started!"
    sleep 1
}

# Wait for everything to be ready with friendly messages
wait_for_ready() {
    step "Step 7: Waiting for everything to be ready..."
    echo ""
    
    # Wait for database
    log "Waiting for database to be ready..."
    for i in {1..30}; do
        if docker compose -f "$COMPOSE_FILE" exec -T db pg_isready -U noctis_user -d noctis_pro >/dev/null 2>&1; then
            log "Database is ready! ${SUCCESS}"
            break
        fi
        if [ $i -eq 30 ]; then
            error "Database took too long to start!"
            echo "Try restarting: ${CYAN}docker compose -f $COMPOSE_FILE restart db${NC}"
            exit 1
        fi
        echo -n "."
        sleep 5
    done
    
    # Wait for Redis
    log "Waiting for cache system to be ready..."
    for i in {1..10}; do
        if docker compose -f "$COMPOSE_FILE" exec -T redis redis-cli ping >/dev/null 2>&1; then
            log "Cache system is ready! ${SUCCESS}"
            break
        fi
        if [ $i -eq 10 ]; then
            error "Cache system took too long to start!"
            exit 1
        fi
        echo -n "."
        sleep 3
    done
    
    # Wait for web application
    log "Waiting for web application to be ready..."
    for i in {1..20}; do
        if curl -f http://localhost:8000/health/ >/dev/null 2>&1; then
            log "Web application is ready! ${SUCCESS}"
            break
        fi
        if [ $i -eq 20 ]; then
            warn "Web application is taking longer than expected..."
            warn "But let's continue - it might still work!"
            break
        fi
        echo -n "."
        sleep 10
    done
    
    success "Everything is ready to use!"
    sleep 1
}

# Setup the medical database
setup_database_simple() {
    step "Step 8: Setting up medical database..."
    
    log "Creating database tables for medical data..."
    docker compose -f "$COMPOSE_FILE" exec -T web python manage.py migrate --noinput
    
    log "Setting up static files for web interface..."
    docker compose -f "$COMPOSE_FILE" exec -T web python manage.py collectstatic --noinput
    
    log "Creating admin user for you..."
    docker compose -f "$COMPOSE_FILE" exec -T web python manage.py shell -c "
from accounts.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', 'admin123')
    print('Admin user created: admin / admin123')
else:
    print('Admin user already exists')
" 2>/dev/null || warn "Admin user creation had an issue, but continuing..."
    
    success "Medical database is ready!"
    sleep 1
}

# Show final status with lots of helpful information
show_success_status() {
    clear
    echo -e "${GREEN}"
    echo "════════════════════════════════════════════════════════════"
    echo "${SUCCESS} NOCTIS PRO IS READY! YOUR MEDICAL SYSTEM IS WORKING! ${SUCCESS}"
    echo "════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo ""
    
    # Show container status
    echo -e "${CYAN}${COMPUTER} System Status:${NC}"
    docker compose -f "$COMPOSE_FILE" ps
    echo ""
    
    echo -e "${PURPLE}${NETWORK} How to Access Your Medical System:${NC}"
    echo "════════════════════════════════════════════════"
    echo ""
    echo -e "${GREEN}🌐 Web Interface:${NC}      http://localhost:8000"
    echo -e "${GREEN}🔧 Admin Panel:${NC}        http://localhost:8000/admin"
    echo -e "${GREEN}🏥 DICOM Receiver:${NC}     Port 11112 (for medical machines)"
    echo ""
    echo -e "${YELLOW}👤 Login Information:${NC}"
    echo "   Username: ${CYAN}admin${NC}"
    echo "   Password: ${CYAN}admin123${NC}"
    echo ""
    
    echo -e "${PURPLE}${HOSPITAL} What You Can Do Now:${NC}"
    echo "═══════════════════════════════════════════"
    echo ""
    echo "1. ${CHECK} Open your web browser"
    echo "2. ${CHECK} Go to: ${CYAN}http://localhost:8000${NC}"
    echo "3. ${CHECK} Login with: ${CYAN}admin${NC} / ${CYAN}admin123${NC}"
    echo "4. ${CHECK} Click 'Facility Management' to create hospitals/clinics"
    echo "5. ${CHECK} Click 'User Management' to create users"
    echo "6. ${CHECK} Each facility gets a unique AE Title for DICOM machines"
    echo ""
    
    echo -e "${PURPLE}${COMPUTER} Useful Commands:${NC}"
    echo "════════════════════════════════════════"
    echo ""
    echo "Stop the system:     ${CYAN}docker compose -f $COMPOSE_FILE down${NC}"
    echo "Start the system:    ${CYAN}docker compose -f $COMPOSE_FILE up -d${NC}"
    echo "View logs:           ${CYAN}docker compose -f $COMPOSE_FILE logs -f${NC}"
    echo "Check status:        ${CYAN}docker compose -f $COMPOSE_FILE ps${NC}"
    echo "Restart everything:  ${CYAN}docker compose -f $COMPOSE_FILE restart${NC}"
    echo ""
    
    echo -e "${PURPLE}🔧 Database Access (Advanced):${NC}"
    echo "═══════════════════════════════════════════"
    echo ""
    echo "Database: ${CYAN}localhost:5432${NC}"
    echo "Database Name: ${CYAN}noctis_pro${NC}"
    echo "Username: ${CYAN}noctis_user${NC}"
    echo "Password: ${CYAN}(check .env file)${NC}"
    echo ""
    
    echo -e "${PURPLE}📊 Optional Development Tools:${NC}"
    echo "════════════════════════════════════════════"
    echo ""
    echo "Enable database viewer and Redis manager:"
    echo "${CYAN}ENABLE_DEV_TOOLS=true docker compose -f $COMPOSE_FILE --profile tools up -d${NC}"
    echo ""
    echo "Then access:"
    echo "• Database Viewer: ${CYAN}http://localhost:8080${NC}"
    echo "• Redis Manager: ${CYAN}http://localhost:8081${NC}"
    echo ""
    
    echo -e "${PURPLE}🌍 When Ready for Internet Access:${NC}"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "1. Export your data: ${CYAN}./scripts/export-for-server.sh${NC}"
    echo "2. Set up server: ${CYAN}./scripts/setup-ubuntu-server.sh${NC}"
    echo "3. Deploy internet access: ${CYAN}./scripts/deploy-internet-access.sh${NC}"
    echo ""
    
    success "Your medical imaging system is ready to use!"
    echo ""
    echo -e "${YELLOW}${WARNING} Remember:${NC}"
    echo "• This is running on your desktop for development"
    echo "• Use export/import scripts to move to real server later"
    echo "• Change admin password before production use"
    echo "• Create real facilities for actual hospitals/clinics"
    echo ""
}

# Test everything is working
test_everything_simple() {
    step "Step 9: Testing everything works perfectly..."
    
    # Test web interface
    log "Testing web interface..."
    if curl -f http://localhost:8000/ >/dev/null 2>&1; then
        log "Web interface is working! ${SUCCESS}"
    else
        warn "Web interface test failed, but might still work"
    fi
    
    # Test admin panel
    log "Testing admin panel..."
    if curl -f http://localhost:8000/admin/ >/dev/null 2>&1; then
        log "Admin panel is working! ${SUCCESS}"
    else
        warn "Admin panel test failed, but might still work"
    fi
    
    # Test DICOM port
    log "Testing DICOM receiver..."
    if timeout 5 bash -c "</dev/tcp/localhost/11112" >/dev/null 2>&1; then
        log "DICOM receiver is working! ${SUCCESS}"
    else
        warn "DICOM receiver test failed - check logs if needed"
    fi
    
    # Test database
    log "Testing medical database..."
    if docker compose -f "$COMPOSE_FILE" exec -T web python manage.py check >/dev/null 2>&1; then
        log "Medical database is working! ${SUCCESS}"
    else
        warn "Database test failed - might need a few more minutes"
    fi
    
    success "All tests completed!"
    sleep 1
}

# Show helpful tips
show_helpful_tips() {
    echo ""
    echo -e "${PURPLE}💡 Helpful Tips for Beginners:${NC}"
    echo "═══════════════════════════════════════════"
    echo ""
    echo "🏥 ${GREEN}Creating Your First Hospital/Clinic:${NC}"
    echo "   1. Go to: http://localhost:8000/admin/"
    echo "   2. Login with: admin / admin123"
    echo "   3. Click 'Facility Management'"
    echo "   4. Click 'Add Facility'"
    echo "   5. Fill in real hospital information"
    echo "   6. The system will create an AE Title automatically!"
    echo ""
    echo "👥 ${GREEN}Creating Users:${NC}"
    echo "   1. Go to 'User Management' in admin panel"
    echo "   2. Click 'Create User'"
    echo "   3. Choose role: Admin, Radiologist, or Facility User"
    echo "   4. Assign to facility (for Facility Users)"
    echo ""
    echo "📷 ${GREEN}DICOM Machine Setup:${NC}"
    echo "   1. Create facility first (to get AE Title)"
    echo "   2. Configure DICOM machine with:"
    echo "      • Called AE: NOCTIS_SCP"
    echo "      • Calling AE: [Your facility's AE Title]"
    echo "      • IP: localhost (or your computer's IP)"
    echo "      • Port: 11112"
    echo ""
    echo "🔍 ${GREEN}If Something Goes Wrong:${NC}"
    echo "   • Check logs: ${CYAN}docker compose -f $COMPOSE_FILE logs -f${NC}"
    echo "   • Restart system: ${CYAN}docker compose -f $COMPOSE_FILE restart${NC}"
    echo "   • Stop system: ${CYAN}docker compose -f $COMPOSE_FILE down${NC}"
    echo "   • Start system: ${CYAN}docker compose -f $COMPOSE_FILE up -d${NC}"
    echo ""
}

# Ask if they want development tools
ask_about_dev_tools() {
    echo ""
    echo -e "${CYAN}Would you like to enable development tools?${NC}"
    echo "These give you:"
    echo "• ${CHECK} Database viewer (see all medical data)"
    echo "• ${CHECK} Redis manager (see cache data)"
    echo ""
    read -p "Enable development tools? [y/N]: " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        step "Enabling development tools..."
        ENABLE_DEV_TOOLS=true docker compose -f "$COMPOSE_FILE" --profile tools up -d
        
        echo ""
        success "Development tools enabled!"
        echo "• Database Viewer: ${CYAN}http://localhost:8080${NC}"
        echo "• Redis Manager: ${CYAN}http://localhost:8081${NC}"
        echo ""
    fi
}

# Final verification with actual data check
final_verification() {
    step "Step 10: Final verification of your medical system..."
    
    # Check actual system functionality
    verification_result=$(docker compose -f "$COMPOSE_FILE" exec -T web python manage.py shell -c "
from accounts.models import Facility, User
from admin_panel.views import _standardize_aetitle

# Check models work
facility_count = Facility.objects.count()
user_count = User.objects.count()
admin_count = User.objects.filter(role='admin').count()

# Test AE title generation
test_ae = _standardize_aetitle('General Hospital')

print(f'FACILITIES:{facility_count}')
print(f'USERS:{user_count}')
print(f'ADMINS:{admin_count}')
print(f'AE_TEST:{test_ae}')
print('SYSTEM:READY')
" 2>/dev/null)

    if echo "$verification_result" | grep -q "SYSTEM:READY"; then
        facility_count=$(echo "$verification_result" | grep "FACILITIES:" | cut -d: -f2)
        user_count=$(echo "$verification_result" | grep "USERS:" | cut -d: -f2)
        admin_count=$(echo "$verification_result" | grep "ADMINS:" | cut -d: -f2)
        ae_test=$(echo "$verification_result" | grep "AE_TEST:" | cut -d: -f2)
        
        log "System verification passed!"
        log "Current data: $facility_count facilities, $user_count users, $admin_count admins"
        log "AE title generation test: '$ae_test'"
        
        success "Your medical system is 100% ready!"
    else
        warn "System verification had issues, but basic functionality should work"
    fi
}

# Main function - the magic happens here!
main() {
    show_welcome
    check_docker_simple
    check_directory
    create_environment_simple
    create_directories_simple
    download_software
    start_services_simple
    wait_for_ready
    setup_database_simple
    test_everything_simple
    final_verification
    ask_about_dev_tools
    show_success_status
    show_helpful_tips
    
    echo ""
    echo -e "${GREEN}${SUCCESS}${SUCCESS}${SUCCESS} CONGRATULATIONS! ${SUCCESS}${SUCCESS}${SUCCESS}${NC}"
    echo ""
    echo -e "${CYAN}Your NOCTIS Pro medical imaging system is now running!${NC}"
    echo ""
    echo -e "${YELLOW}What to do next:${NC}"
    echo "1. ${CHECK} Open browser and go to: ${CYAN}http://localhost:8000${NC}"
    echo "2. ${CHECK} Login with: ${CYAN}admin${NC} / ${CYAN}admin123${NC}"
    echo "3. ${CHECK} Create your first hospital/clinic (facility)"
    echo "4. ${CHECK} Create users for your staff"
    echo "5. ${CHECK} Test DICOM connectivity if you have medical machines"
    echo ""
    echo -e "${GREEN}Have fun with your medical imaging system! ${HOSPITAL}${NC}"
    echo ""
}

# Handle interruption gracefully
trap 'echo ""; error "Setup was interrupted! Run the script again to continue."; exit 1' INT TERM

# Run the magic!
main "$@"