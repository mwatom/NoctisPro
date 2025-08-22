#!/bin/bash

echo "════════════════════════════════════════════════════════════"
echo "🏥 NOCTIS PRO MEDICAL IMAGING SYSTEM - DEVELOPMENT DEPLOYMENT 🏥"
echo "════════════════════════════════════════════════════════════"
echo ""

# Exit on any error
set -e

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create Python virtual environment
setup_python_environment() {
    echo "🐍 Setting up Python virtual environment..."
    
    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install Python dependencies
    echo "📦 Installing Python dependencies..."
    pip install -r requirements.txt
    
    echo "✅ Python environment setup complete!"
}

# Function to create directory structure
create_directories() {
    echo "📁 Creating directory structure..."
    
    # Create application directories
    mkdir -p ./data/{media,staticfiles,logs,dicom_storage,backups}
    mkdir -p ./logs
    
    # Set permissions
    chmod -R 755 ./data
    chmod -R 755 ./logs
    
    echo "✅ Directory structure created!"
}

# Function to create environment configuration for development
create_environment_config() {
    echo "⚙️  Creating environment configuration..."
    
    # Generate secret key
    SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
    
    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}' | tr -d '[:space:]')
    
    # Create development environment file
    cat > .env.development << EOF
# Django Configuration
SECRET_KEY=${SECRET_KEY}
DEBUG=True
DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Database (SQLite for development)
DATABASE_URL=sqlite:///$(pwd)/db.sqlite3

# Server Configuration
ALLOWED_HOSTS=*
DOMAIN_NAME=

# Media and Static Files
MEDIA_ROOT=$(pwd)/data/media
STATIC_ROOT=$(pwd)/data/staticfiles

# DICOM Configuration
DICOM_STORAGE_PATH=$(pwd)/data/dicom_storage
DICOM_PORT=11112

# Logging
LOG_LEVEL=DEBUG
LOG_FILE=$(pwd)/logs/noctis.log

# Security (development settings)
SECURE_SSL_REDIRECT=False
SECURE_HSTS_SECONDS=0
EOF

    echo "✅ Environment configuration created!"
    echo "📝 Configuration saved to .env.development"
}

# Function to run Django setup
setup_django() {
    echo "🚀 Setting up Django application..."
    
    source venv/bin/activate
    
    # Load environment variables
    set -a
    source .env.development
    set +a
    
    # Run migrations
    echo "🔄 Running database migrations..."
    python manage.py migrate
    
    # Collect static files
    echo "📦 Collecting static files..."
    python manage.py collectstatic --noinput
    
    # Create superuser automatically
    echo "👤 Creating superuser..."
    python create_superuser.py
    
    echo "✅ Django setup complete!"
}

# Function to create startup script
create_startup_script() {
    echo "📝 Creating startup script..."
    
    cat > start_noctis_dev.sh << 'EOF'
#!/bin/bash

echo "🚀 Starting Noctis Pro Medical Imaging System (Development Mode)..."

# Change to application directory
cd "$(dirname "$0")"

# Load environment variables
set -a
source .env.development
set +a

# Activate virtual environment
source venv/bin/activate

# Start Django development server
echo "🌐 Starting Django development server..."
echo ""
echo "✅ Noctis Pro is now running in development mode!"
echo ""
echo "🌐 Access Information:"
echo "====================="
echo "Web Interface: http://localhost:8000"
echo "Admin Interface: http://localhost:8000/admin"
echo ""
echo "👤 Admin Login:"
echo "==============="
echo "Username: admin"
echo "Password: admin123"
echo ""
echo "📝 Press Ctrl+C to stop the server"
echo ""

python manage.py runserver 0.0.0.0:8000
EOF

    chmod +x start_noctis_dev.sh
    
    # Create DICOM receiver script
    cat > start_dicom_receiver.sh << 'EOF'
#!/bin/bash

echo "📡 Starting DICOM Receiver..."

# Change to application directory
cd "$(dirname "$0")"

# Load environment variables
set -a
source .env.development
set +a

# Activate virtual environment
source venv/bin/activate

# Start DICOM receiver
python dicom_receiver.py
EOF

    chmod +x start_dicom_receiver.sh
    
    echo "✅ Startup scripts created!"
}

# Main deployment function
main() {
    echo "Starting Noctis Pro development deployment without Docker..."
    echo ""
    
    # Check if we have the required dependencies
    if ! command_exists python3; then
        echo "❌ Python3 is required. Please install it first."
        exit 1
    fi
    
    if ! command_exists pip3; then
        echo "❌ pip3 is required. Please install it first."
        exit 1
    fi
    
    # Create directories and environment
    create_directories
    setup_python_environment
    create_environment_config
    setup_django
    
    # Create startup scripts
    create_startup_script
    
    echo ""
    echo "🎉 Development deployment completed successfully!"
    echo ""
    echo "🚀 To start the web server, run: ./start_noctis_dev.sh"
    echo "📡 To start DICOM receiver (in another terminal), run: ./start_dicom_receiver.sh"
    echo ""
    echo "Your Noctis Pro Medical Imaging System is ready for development!"
    echo ""
    echo "📋 Quick Start:"
    echo "==============="
    echo "1. Run: ./start_noctis_dev.sh"
    echo "2. Open: http://localhost:8000"
    echo "3. Login with: admin / admin123"
    echo ""
}

# Run main function
main "$@"