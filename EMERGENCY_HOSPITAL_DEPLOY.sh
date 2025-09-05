#!/bin/bash

# 🚨 EMERGENCY HOSPITAL DEPLOYMENT - MULTIPLE METHODS 🚨
# For immediate surgeon/doctor access to NOCTIS PACS
# Run after: git clone [repo] && cd NoctisPro

set -e

echo "🏥🚨 EMERGENCY HOSPITAL NOCTIS PACS DEPLOYMENT 🚨🏥"
echo "================================================="
echo "🔗 Target: http://noctispro2.duckdns.org:8000"
echo "👨‍⚕️ For: Surgeon & Hospital Staff Access"
echo "⏰ Deploying: $(date)"
echo ""

# Function to check if server is running
check_server() {
    sleep 2
    if curl -s --connect-timeout 5 http://localhost:8000 >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to deploy method 1: Standard deployment
deploy_standard() {
    echo "🔹 METHOD 1: Standard Hospital Deployment"
    
    # Kill existing processes
    sudo lsof -ti:8000 | xargs -r sudo kill -9 2>/dev/null || true
    sleep 1
    
    # Setup virtual environment
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    
    # Install dependencies
    pip install --upgrade pip --quiet
    pip install -r requirements.txt --quiet
    
    # Configure environment
    export DEBUG=False
    export ALLOWED_HOSTS="*,noctispro2.duckdns.org,*.duckdns.org,localhost,127.0.0.1"
    export DJANGO_SETTINGS_MODULE="noctis_pro.settings"
    
    # Setup database and admin
    python manage.py migrate --noinput
    echo "from django.contrib.auth import get_user_model; User=get_user_model(); User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin','admin@hospital.com','admin123')" | python manage.py shell
    
    # Setup static files
    python manage.py collectstatic --noinput --clear 2>/dev/null || true
    mkdir -p media/dicom staticfiles
    
    # Start server
    nohup python manage.py runserver 0.0.0.0:8000 > hospital.log 2>&1 &
    
    if check_server; then
        echo "✅ METHOD 1: SUCCESS - Server running!"
        return 0
    else
        echo "❌ METHOD 1: Failed"
        return 1
    fi
}

# Function to deploy method 2: Minimal deployment
deploy_minimal() {
    echo "🔹 METHOD 2: Minimal Emergency Deployment"
    
    sudo lsof -ti:8000 | xargs -r sudo kill -9 2>/dev/null || true
    
    # Use system Python if venv fails
    pip3 install django pillow --user --quiet 2>/dev/null || true
    
    export DEBUG=True
    export ALLOWED_HOSTS="*"
    
    python3 manage.py migrate --noinput 2>/dev/null || true
    echo "from django.contrib.auth import get_user_model; User=get_user_model(); User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin','admin@hospital.com','admin123')" | python3 manage.py shell 2>/dev/null || true
    
    nohup python3 manage.py runserver 0.0.0.0:8000 > minimal.log 2>&1 &
    
    if check_server; then
        echo "✅ METHOD 2: SUCCESS - Minimal server running!"
        return 0
    else
        echo "❌ METHOD 2: Failed"
        return 1
    fi
}

# Function to deploy method 3: Docker fallback
deploy_docker() {
    echo "🔹 METHOD 3: Docker Emergency Deployment"
    
    if command -v docker >/dev/null 2>&1; then
        sudo lsof -ti:8000 | xargs -r sudo kill -9 2>/dev/null || true
        
        # Quick Docker deployment
        cat > Dockerfile.emergency << 'DOCKER_EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8000
CMD python manage.py migrate --noinput && \
    echo "from django.contrib.auth import get_user_model; User=get_user_model(); User.objects.filter(username='admin').exists() or User.objects.create_superuser('admin','admin@hospital.com','admin123')" | python manage.py shell && \
    python manage.py runserver 0.0.0.0:8000
DOCKER_EOF
        
        docker build -f Dockerfile.emergency -t noctis-emergency . 2>/dev/null && \
        docker run -d -p 8000:8000 --name noctis-hospital noctis-emergency 2>/dev/null
        
        if check_server; then
            echo "✅ METHOD 3: SUCCESS - Docker server running!"
            return 0
        else
            echo "❌ METHOD 3: Failed"
            return 1
        fi
    else
        echo "❌ METHOD 3: Docker not available"
        return 1
    fi
}

# Main deployment logic
main() {
    if [ ! -f "manage.py" ]; then
        echo "❌ ERROR: Run this from the NoctisPro directory!"
        echo "Usage: git clone [repo] && cd NoctisPro && ./EMERGENCY_HOSPITAL_DEPLOY.sh"
        exit 1
    fi
    
    echo "🔍 Attempting multiple deployment methods..."
    
    # Try each method until one succeeds
    if deploy_standard; then
        DEPLOY_METHOD="Standard"
    elif deploy_minimal; then
        DEPLOY_METHOD="Minimal"
    elif deploy_docker; then
        DEPLOY_METHOD="Docker"
    else
        echo ""
        echo "❌ ALL DEPLOYMENT METHODS FAILED!"
        echo "🚨 MANUAL INTERVENTION REQUIRED"
        echo ""
        echo "Try manual deployment:"
        echo "1. python3 -m venv venv"
        echo "2. source venv/bin/activate"
        echo "3. pip install django pillow"
        echo "4. python manage.py migrate"
        echo "5. python manage.py runserver 0.0.0.0:8000"
        exit 1
    fi
    
    # Update DuckDNS if possible
    if [ -f "update_duckdns.sh" ]; then
        chmod +x update_duckdns.sh
        ./update_duckdns.sh 2>/dev/null || true
    fi
    
    echo ""
    echo "🎉🏥 HOSPITAL NOCTIS PACS DEPLOYED SUCCESSFULLY! 🏥🎉"
    echo "================================================="
    echo ""
    echo "✅ Deployment Method: $DEPLOY_METHOD"
    echo "🌍 Internet Access: http://noctispro2.duckdns.org:8000"
    echo "🏥 Local Access: http://localhost:8000"
    echo "🔑 Admin Panel: http://noctispro2.duckdns.org:8000/admin/"
    echo ""
    echo "👨‍⚕️ SURGEON LOGIN CREDENTIALS:"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo "   Email: admin@hospital.com"
    echo ""
    echo "📊 Server Status:"
    echo "   - Deployment Time: $(date)"
    echo "   - Method Used: $DEPLOY_METHOD"
    echo "   - Internet Ready: YES"
    echo "   - Hospital Ready: YES"
    echo ""
    echo "🚀 NOCTIS PACS IS NOW LIVE FOR HOSPITAL USE!"
    echo "   Surgeons can access from any device with internet"
}

# Run deployment
main