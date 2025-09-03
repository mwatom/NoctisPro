#!/bin/bash

# 🚀 NoctisPro Masterpiece Service Manager
# Simple service management for the medical imaging system

SERVICE_NAME="noctispro-masterpiece"
MASTERPIECE_DIR="/workspace/noctis_pro_deployment"
WORKSPACE_DIR="/workspace"
DJANGO_PORT="8000"
STATIC_URL="colt-charmed-lark.ngrok-free.app"

case "${1:-start}" in
    start)
        echo "🚀 Starting Masterpiece service..."
        
        # Kill existing
        tmux kill-session -t "$SERVICE_NAME" 2>/dev/null || true
        pkill -f "manage.py runserver" 2>/dev/null || true
        sleep 3
        
        # Start Django
        cd "$MASTERPIECE_DIR"
        tmux new-session -d -s "$SERVICE_NAME" -c "$MASTERPIECE_DIR"
        tmux send-keys -t "$SERVICE_NAME" "cd $MASTERPIECE_DIR" C-m
        tmux send-keys -t "$SERVICE_NAME" "export DJANGO_SETTINGS_MODULE=noctis_pro.settings" C-m
        tmux send-keys -t "$SERVICE_NAME" "export SECRET_KEY=masterpiece-service-\$(date +%s)" C-m
        tmux send-keys -t "$SERVICE_NAME" "export DEBUG=False" C-m
        tmux send-keys -t "$SERVICE_NAME" "python3 manage.py runserver 0.0.0.0:$DJANGO_PORT" C-m
        
        sleep 10
        
        # Start ngrok if available (requires auth token)
        if [ -f "$WORKSPACE_DIR/ngrok" ]; then
            echo "ℹ️  Ngrok available but requires authentication"
            echo "   Configure with: ./ngrok authtoken YOUR_TOKEN"
            echo "   Then run: tmux new-window -t $SERVICE_NAME -n ngrok"
            echo "   And: tmux send-keys -t $SERVICE_NAME:ngrok './ngrok http $DJANGO_PORT' C-m"
        fi
        
        echo "✅ Service started"
        echo "🌐 Local: http://localhost:$DJANGO_PORT"
        echo "🔧 Admin: http://localhost:$DJANGO_PORT/admin/ (admin/admin123)"
        ;;
    stop)
        echo "🛑 Stopping Masterpiece service..."
        tmux kill-session -t "$SERVICE_NAME" 2>/dev/null || true
        pkill -f "manage.py runserver" 2>/dev/null || true
        pkill -f "ngrok.*http" 2>/dev/null || true
        rm -f "$WORKSPACE_DIR/${SERVICE_NAME}.pid"
        echo "✅ Service stopped"
        ;;
    restart)
        $0 stop
        sleep 3
        $0 start
        ;;
    status)
        echo "📊 Masterpiece Service Status:"
        if tmux has-session -t "$SERVICE_NAME" 2>/dev/null; then
            echo "✅ Service: Running"
            if curl -s http://localhost:$DJANGO_PORT > /dev/null 2>&1; then
                echo "✅ Django: Responding"
                echo "🌐 Local: http://localhost:$DJANGO_PORT"
                echo "🔧 Admin: http://localhost:$DJANGO_PORT/admin/"
            else
                echo "⚠️  Django: Not responding"
            fi
            if pgrep -f "ngrok.*http" > /dev/null; then
                echo "✅ Ngrok: Active"
                echo "🌐 External: https://$STATIC_URL"
            else
                echo "⚠️  Ngrok: Not active (requires auth token)"
            fi
        else
            echo "❌ Service: Not running"
        fi
        ;;
    logs)
        echo "📋 Django logs:"
        tmux capture-pane -t "$SERVICE_NAME:0" -p 2>/dev/null || echo "No Django session found"
        if tmux list-windows -t "$SERVICE_NAME" 2>/dev/null | grep -q ngrok; then
            echo ""
            echo "📋 Ngrok logs:"
            tmux capture-pane -t "$SERVICE_NAME:ngrok" -p 2>/dev/null || echo "No ngrok session found"
        fi
        ;;
    *)
        echo "🚀 NoctisPro Masterpiece Service Manager"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  start    - Start the service"
        echo "  stop     - Stop the service"
        echo "  restart  - Restart the service"
        echo "  status   - Show service status"
        echo "  logs     - Show service logs"
        echo ""
        echo "🏥 Complete medical imaging platform with:"
        echo "   • DICOM Worklist Management"
        echo "   • Advanced DICOM Viewer"
        echo "   • Medical Reports"
        echo "   • AI Analysis"
        echo "   • Real-time Chat"
        echo "   • Notifications"
        echo "   • Admin Panel"
        echo ""
        exit 1
        ;;
esac