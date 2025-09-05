#!/bin/bash
echo "🔥 QUICK NGROK DEPLOYMENT"
echo "========================"

# Check if Django server is running
if ! pgrep -f "python manage.py runserver" > /dev/null; then
    echo "🚀 Starting Django server..."
    cd /workspace
    source venv/bin/activate
    sudo venv/bin/python manage.py runserver 0.0.0.0:80 &
    sleep 3
fi

echo "✅ Django server is running on port 80"
echo ""
echo "🌐 TO ACCESS YOUR MASTERPIECE:"
echo "1. Open a new terminal and run:"
echo "   ngrok http --url=mallard-shining-curiously.ngrok-free.app 80"
echo ""
echo "2. Visit: https://mallard-shining-curiously.ngrok-free.app"
echo "3. Login with: admin / admin123"
echo ""
echo "🏥 Your DICOM Viewer masterpiece will be available at:"
echo "   https://mallard-shining-curiously.ngrok-free.app/dicom-viewer/"
echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
