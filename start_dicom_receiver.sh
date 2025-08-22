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
