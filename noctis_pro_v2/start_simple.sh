#!/bin/bash

# 🚀 NoctisPro V2 - Simple Start Script
# For container environments or manual deployment

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🏥 Starting NoctisPro V2...${NC}"

# Go to project directory
cd /workspace/noctis_pro_v2

# Activate virtual environment
source venv/bin/activate

# Run migrations if needed
echo -e "${YELLOW}📋 Checking database...${NC}"
python manage.py migrate --noinput

# Collect static files
echo -e "${YELLOW}📁 Collecting static files...${NC}"
python manage.py collectstatic --noinput

# Create admin user if needed
echo -e "${YELLOW}👤 Setting up admin user...${NC}"
python manage.py shell -c "
from apps.accounts.models import User
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@noctispro.com', 'admin123')
    print('Admin user created: admin / admin123')
else:
    print('Admin user already exists')
"

# Create sample data
echo -e "${YELLOW}📊 Setting up sample data...${NC}"
python manage.py shell -c "
from apps.worklist.models import Patient, Study, Modality
from datetime import date, time

# Create modalities
modalities = ['CT', 'MR', 'XR', 'US', 'DX']
for mod in modalities:
    Modality.objects.get_or_create(code=mod, defaults={'name': f'{mod} Imaging'})

# Create sample data if needed
if not Patient.objects.exists():
    patient = Patient.objects.create(
        patient_id='P001',
        patient_name='John Doe',
        date_of_birth=date(1980, 1, 1),
        sex='M'
    )
    
    # Add more sample patients
    patient2 = Patient.objects.create(
        patient_id='P002',
        patient_name='Jane Smith',
        date_of_birth=date(1975, 5, 15),
        sex='F'
    )
    
    patient3 = Patient.objects.create(
        patient_id='P003',
        patient_name='Robert Johnson',
        date_of_birth=date(1965, 12, 3),
        sex='M'
    )
    
    # Create studies
    ct_modality = Modality.objects.get(code='CT')
    mr_modality = Modality.objects.get(code='MR')
    xr_modality = Modality.objects.get(code='XR')
    
    Study.objects.create(
        study_instance_uid='1.2.3.4.5.6.7.8.9.1',
        patient=patient,
        study_date=date.today(),
        study_time=time(10, 30),
        study_description='CT Chest without contrast',
        accession_number='ACC001',
        referring_physician='Dr. Smith',
        modality=ct_modality,
        status='completed'
    )
    
    Study.objects.create(
        study_instance_uid='1.2.3.4.5.6.7.8.9.2',
        patient=patient2,
        study_date=date.today(),
        study_time=time(14, 15),
        study_description='MRI Brain with contrast',
        accession_number='ACC002',
        referring_physician='Dr. Johnson',
        modality=mr_modality,
        status='in_progress'
    )
    
    Study.objects.create(
        study_instance_uid='1.2.3.4.5.6.7.8.9.3',
        patient=patient3,
        study_date=date.today(),
        study_time=time(16, 45),
        study_description='X-Ray Chest PA and Lateral',
        accession_number='ACC003',
        referring_physician='Dr. Brown',
        modality=xr_modality,
        status='urgent'
    )
    
    print('Sample data created with 3 patients and 3 studies')
else:
    print('Sample data already exists')
"

echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo -e "${BLUE}🚀 Starting Django server...${NC}"
echo -e "${YELLOW}📱 Access URLs:${NC}"
echo -e "  🏠 Local:  http://localhost:8000"
echo -e "  🌐 Public: https://colt-charmed-lark.ngrok-free.app"
echo -e "${YELLOW}👤 Login:${NC}"
echo -e "  Username: admin"
echo -e "  Password: admin123"
echo ""
echo -e "${GREEN}🏥 NoctisPro V2 is starting...${NC}"

# Start Django server
python manage.py runserver 0.0.0.0:8000