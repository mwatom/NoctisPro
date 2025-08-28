#!/bin/bash

SERVICE_NAME="noctispro"
INIT_SCRIPT="/etc/init.d/$SERVICE_NAME"

case "$1" in
    start)
        echo "Starting NoctisPro service..."
        sudo "$INIT_SCRIPT" start
        ;;
    stop)
        echo "Stopping NoctisPro service..."
        sudo "$INIT_SCRIPT" stop
        ;;
    restart)
        echo "Restarting NoctisPro service..."
        sudo "$INIT_SCRIPT" restart
        ;;
    status)
        sudo "$INIT_SCRIPT" status
        ;;
    enable)
        echo "Service auto-start is already enabled via runlevel links"
        ;;
    disable)
        echo "Disabling auto-start..."
        # Remove runlevel links
        for runlevel in 0 1 2 3 4 5 6; do
            sudo rm -f "/etc/rc${runlevel}.d/"*"noctispro"
        done
        echo "Auto-start disabled"
        ;;
    logs)
        echo "Showing recent logs..."
        tail -f /var/log/noctispro.log
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|enable|disable|logs}"
        echo ""
        echo "Commands:"
        echo "  start    - Start the NoctisPro service"
        echo "  stop     - Stop the NoctisPro service"
        echo "  restart  - Restart the NoctisPro service"
        echo "  status   - Show service status"
        echo "  enable   - Enable auto-start (already enabled)"
        echo "  disable  - Disable auto-start"
        echo "  logs     - Show service logs"
        exit 1
        ;;
esac
