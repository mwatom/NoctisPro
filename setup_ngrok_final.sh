#!/bin/bash

echo "🌐 Setting up Ngrok for Professional Noctis Pro PACS"
echo "=================================================="

# You need to set your ngrok authtoken first
echo "To complete ngrok setup, run these commands:"
echo ""
echo "1. Get your authtoken from: https://dashboard.ngrok.com/get-started/your-authtoken"
echo "2. Set the authtoken:"
echo "   ./ngrok config add-authtoken YOUR_AUTHTOKEN_HERE"
echo ""
echo "3. Then start ngrok with your static URL:"
echo "   ./ngrok http --url=colt-charmed-lark.ngrok-free.app 8000"
echo ""
echo "The Django server is already running on port 8000"
echo "Once ngrok is connected, your system will be accessible at:"
echo "   https://colt-charmed-lark.ngrok-free.app/"
echo ""
echo "🔐 Login credentials:"
echo "   Admin: admin / NoctisPro2024!"
echo "   Radiologist: radiologist / RadPro2024!"
echo "   Facility: facility / FacPro2024!"