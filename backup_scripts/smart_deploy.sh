#!/bin/bash

# NOCTIS PRO PACS v2.0 - SMART DEPLOYMENT LAUNCHER
# ===============================================
# This script can be run from anywhere and will automatically
# find and deploy your NOCTIS PRO PACS installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Banner
echo -e "${PURPLE}"
cat << "EOF"
🎯 NOCTIS PRO PACS v2.0 - SMART DEPLOYMENT LAUNCHER
===================================================
   🔍 Auto-detecting project location
   🚀 Launching intelligent deployment
EOF
echo -e "${NC}"

# Function to find NOCTIS PRO project directory
find_noctis_project() {
    local current_dir=$(pwd)
    local script_dir=$(dirname "$(realpath "$0")")
    
    # Priority 1: Check current directory
    if [ -f "$current_dir/manage.py" ] && [ -f "$current_dir/deploy_auto_production.sh" ]; then
        echo "$current_dir"
        return 0
    fi
    
    # Priority 2: Check script directory
    if [ -f "$script_dir/manage.py" ] && [ -f "$script_dir/deploy_auto_production.sh" ]; then
        echo "$script_dir"
        return 0
    fi
    
    # Priority 3: Common project locations
    local common_paths=(
        "/workspace"
        "$HOME/workspace"
        "$HOME/NoctisPro"
        "$HOME/noctis_pro"
        "$HOME/Documents/NoctisPro"
        "$HOME/Projects/NoctisPro"
        "$HOME/code/NoctisPro"
        "$HOME/dev/NoctisPro"
        "/opt/noctis_pro"
        "/var/www/noctis_pro"
        "$(pwd)/workspace"
        "$script_dir/../"
    )
    
    for path in "${common_paths[@]}"; do
        if [ -d "$path" ] && [ -f "$path/manage.py" ] && [ -f "$path/deploy_auto_production.sh" ]; then
            echo "$path"
            return 0
        fi
    done
    
    # Priority 4: Search in parent directories (up to 5 levels)
    local search_dir="$current_dir"
    for i in {1..5}; do
        search_dir=$(dirname "$search_dir")
        if [ -f "$search_dir/manage.py" ] && [ -f "$search_dir/deploy_auto_production.sh" ]; then
            echo "$search_dir"
            return 0
        fi
        
        # Stop if we reach root
        if [ "$search_dir" = "/" ]; then
            break
        fi
    done
    
    # Priority 5: Use find command to search filesystem (limited scope)
    info "Searching filesystem for NOCTIS PRO project..."
    local found_path
    
    # Search in home directory first
    if [ -d "$HOME" ]; then
        found_path=$(find "$HOME" -maxdepth 4 -name "manage.py" -type f 2>/dev/null | while read -r manage_py; do
            local dir=$(dirname "$manage_py")
            if [ -f "$dir/deploy_auto_production.sh" ]; then
                echo "$dir"
                break
            fi
        done)
        
        if [ -n "$found_path" ]; then
            echo "$found_path"
            return 0
        fi
    fi
    
    # Search in /opt and /var/www
    for search_root in "/opt" "/var/www"; do
        if [ -d "$search_root" ]; then
            found_path=$(find "$search_root" -maxdepth 3 -name "manage.py" -type f 2>/dev/null | while read -r manage_py; do
                local dir=$(dirname "$manage_py")
                if [ -f "$dir/deploy_auto_production.sh" ]; then
                    echo "$dir"
                    break
                fi
            done)
            
            if [ -n "$found_path" ]; then
                echo "$found_path"
                return 0
            fi
        fi
    done
    
    return 1
}

# Function to check if deployment script exists and is executable
check_deployment_script() {
    local project_dir="$1"
    local deploy_script="$project_dir/deploy_auto_production.sh"
    
    if [ ! -f "$deploy_script" ]; then
        error "Deployment script not found: $deploy_script"
        return 1
    fi
    
    if [ ! -x "$deploy_script" ]; then
        warning "Deployment script is not executable, fixing..."
        chmod +x "$deploy_script"
    fi
    
    return 0
}

# Main execution
main() {
    log "🔍 Searching for NOCTIS PRO PACS project..."
    
    # Find project directory
    PROJECT_DIR=$(find_noctis_project)
    
    if [ -z "$PROJECT_DIR" ]; then
        error "❌ Could not find NOCTIS PRO PACS project directory!"
        echo ""
        echo "Please ensure you have:"
        echo "  1. manage.py file (Django project)"
        echo "  2. deploy_auto_production.sh script"
        echo "  3. Both files in the same directory"
        echo ""
        echo "You can also run this script from your project directory."
        exit 1
    fi
    
    # Resolve absolute path
    PROJECT_DIR=$(realpath "$PROJECT_DIR")
    
    log "✅ Found NOCTIS PRO project at: $PROJECT_DIR"
    
    # Check deployment script
    if ! check_deployment_script "$PROJECT_DIR"; then
        exit 1
    fi
    
    # Navigate to project directory
    log "📁 Navigating to project directory..."
    cd "$PROJECT_DIR" || {
        error "Failed to navigate to project directory: $PROJECT_DIR"
        exit 1
    }
    
    # Display project information
    info "📊 Project Information:"
    echo "   📁 Location: $PROJECT_DIR"
    echo "   🐍 Python: $(python3 --version 2>/dev/null || echo 'Not found')"
    echo "   📦 Django: $(python3 -c 'import django; print(django.get_version())' 2>/dev/null || echo 'Not installed')"
    
    if [ -f "requirements.txt" ]; then
        local req_count=$(wc -l < requirements.txt)
        echo "   📋 Requirements: $req_count packages listed"
    fi
    
    if [ -f "db.sqlite3" ]; then
        local db_size=$(du -h db.sqlite3 | cut -f1)
        echo "   💾 Database: $db_size SQLite database"
    fi
    
    echo ""
    
    # Ask for confirmation
    echo -e "${CYAN}🚀 Ready to deploy NOCTIS PRO PACS v2.0${NC}"
    echo "   This will automatically:"
    echo "   ✓ Install system dependencies"
    echo "   ✓ Set up Python virtual environment"
    echo "   ✓ Install Python packages"
    echo "   ✓ Configure database"
    echo "   ✓ Start production server"
    echo ""
    
    read -p "Continue with deployment? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "🚀 Starting deployment..."
        exec ./deploy_auto_production.sh "$@"
    else
        info "Deployment cancelled by user"
        exit 0
    fi
}

# Handle interruption
trap 'error "Smart deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"