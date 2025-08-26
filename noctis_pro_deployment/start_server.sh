#!/bin/bash

# Activate virtual environment and start Django server
cd /workspace
source venv/bin/activate

echo "Starting Django server..."
echo "Python version: $(python --version)"
echo "Django version: $(python -m django --version)"

# Run migrations first
python manage.py migrate

# Start the server
python manage.py runserver 0.0.0.0:8000