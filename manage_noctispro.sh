#!/bin/bash

# NoctisPro Service Management Script

ACTION="$1"
WORKSPACE_DIR="/workspace"

case "$ACTION" in
    start)
        echo "Starting NoctisPro services..."
        cd "$WORKSPACE_DIR"
        ./noctispro_startup.sh
        ;;
    
    stop)
        echo "Stopping NoctisPro services..."
        
        # Stop Django
        pkill -f "manage.py runserver"
        echo "Django stopped"
        
        # Stop ngrok
        pkill -f "ngrok"
        echo "Ngrok stopped"
        
        echo "All services stopped"
        ;;
    
    restart)
        echo "Restarting NoctisPro services..."
        $0 stop
        sleep 3
        $0 start
        ;;
    
    status)
        echo "NoctisPro Service Status:"
        echo "========================"
        
        # Check Django
        if pgrep -f "manage.py runserver" > /dev/null; then
            echo "✅ Django: Running (PID: $(pgrep -f 'manage.py runserver'))"
        else
            echo "❌ Django: Not running"
        fi
        
        # Check ngrok
        if pgrep -f "ngrok" > /dev/null; then
            echo "✅ Ngrok: Running (PID: $(pgrep -f 'ngrok'))"
            
            # Try to get ngrok URL
            NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data['tunnels']:
        if tunnel['proto'] == 'https':
            print(tunnel['public_url'])
            break
except:
    pass
" 2>/dev/null)
            
            if [ ! -z "$NGROK_URL" ]; then
                echo "🌍 Ngrok URL: $NGROK_URL"
            fi
        else
            echo "❌ Ngrok: Not running"
        fi
        
        # Check PostgreSQL
        if sudo service postgresql status > /dev/null 2>&1; then
            echo "✅ PostgreSQL: Running"
        else
            echo "❌ PostgreSQL: Not running"
        fi
        
        # Check Redis
        if sudo service redis-server status > /dev/null 2>&1; then
            echo "✅ Redis: Running"
        else
            echo "❌ Redis: Not running"
        fi
        
        echo ""
        echo "Local access: http://localhost:8000"
        ;;
    
    install-autostart)
        echo "Installing auto-start on boot..."
        
        # Add to crontab
        (crontab -l 2>/dev/null; echo "@reboot $WORKSPACE_DIR/noctispro_startup.sh") | crontab -
        
        # Also create a startup script in /etc/init.d (if available)
        if [ -d /etc/init.d ]; then
            sudo tee /etc/init.d/noctispro > /dev/null << 'EOF'
#!/bin/bash
### BEGIN INIT INFO
# Provides:          noctispro
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: NoctisPro Django Application
# Description:       Start/stop NoctisPro Django application
### END INIT INFO

WORKSPACE_DIR="/workspace"

case "$1" in
    start)
        cd "$WORKSPACE_DIR"
        ./noctispro_startup.sh
        ;;
    stop)
        cd "$WORKSPACE_DIR"
        ./manage_noctispro.sh stop
        ;;
    restart)
        cd "$WORKSPACE_DIR"
        ./manage_noctispro.sh restart
        ;;
    status)
        cd "$WORKSPACE_DIR"
        ./manage_noctispro.sh status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0
EOF
            
            sudo chmod +x /etc/init.d/noctispro
            
            # Try to add to startup (if update-rc.d is available)
            if command -v update-rc.d > /dev/null; then
                sudo update-rc.d noctispro defaults
            fi
        fi
        
        echo "✅ Auto-start configured!"
        echo "   - Cron job added for @reboot"
        echo "   - Init script created (if supported)"
        echo "   - Services will start automatically on system boot"
        ;;
    
    remove-autostart)
        echo "Removing auto-start configuration..."
        
        # Remove from crontab
        crontab -l 2>/dev/null | grep -v "noctispro_startup.sh" | crontab -
        
        # Remove init script
        if [ -f /etc/init.d/noctispro ]; then
            if command -v update-rc.d > /dev/null; then
                sudo update-rc.d noctispro remove
            fi
            sudo rm /etc/init.d/noctispro
        fi
        
        echo "✅ Auto-start configuration removed"
        ;;
    
    logs)
        echo "Recent NoctisPro logs:"
        echo "====================="
        
        if [ -f "$WORKSPACE_DIR/noctispro_startup.log" ]; then
            echo "Startup logs:"
            tail -20 "$WORKSPACE_DIR/noctispro_startup.log"
        fi
        
        echo ""
        if [ -f "$WORKSPACE_DIR/ngrok.log" ]; then
            echo "Ngrok logs:"
            tail -10 "$WORKSPACE_DIR/ngrok.log"
        fi
        ;;
    
    *)
        echo "NoctisPro Service Management"
        echo "==========================="
        echo "Usage: $0 {start|stop|restart|status|install-autostart|remove-autostart|logs}"
        echo ""
        echo "Commands:"
        echo "  start            - Start all NoctisPro services"
        echo "  stop             - Stop all NoctisPro services"
        echo "  restart          - Restart all NoctisPro services"
        echo "  status           - Show service status and URLs"
        echo "  install-autostart - Configure auto-start on boot"
        echo "  remove-autostart  - Remove auto-start configuration"
        echo "  logs             - Show recent logs"
        echo ""
        exit 1
        ;;
esac