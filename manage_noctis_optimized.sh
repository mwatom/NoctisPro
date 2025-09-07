#!/bin/bash

# NoctisPro Optimized Management Script

DEPLOYMENT_MODE="native_simple"
PROJECT_DIR="/workspace"

case "$1" in
    start)
        echo "Starting NoctisPro services..."
        if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
            cd "${PROJECT_DIR}"
            docker-compose -f docker-compose.optimized.yml up -d
        else
            sudo systemctl start noctis-web-optimized noctis-dicom-optimized
            [[ -f /etc/systemd/system/noctis-celery-optimized.service ]] && sudo systemctl start noctis-celery-optimized
        fi
        ;;
    stop)
        echo "Stopping NoctisPro services..."
        if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
            cd "${PROJECT_DIR}"
            docker-compose -f docker-compose.optimized.yml down
        else
            sudo systemctl stop noctis-web-optimized noctis-dicom-optimized noctis-celery-optimized
        fi
        ;;
    restart)
        echo "Restarting NoctisPro services..."
        $0 stop
        sleep 5
        $0 start
        ;;
    status)
        echo "NoctisPro Service Status:"
        if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
            cd "${PROJECT_DIR}"
            docker-compose -f docker-compose.optimized.yml ps
        else
            sudo systemctl status noctis-web-optimized noctis-dicom-optimized noctis-celery-optimized
        fi
        ;;
    logs)
        echo "NoctisPro Logs:"
        if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
            cd "${PROJECT_DIR}"
            docker-compose -f docker-compose.optimized.yml logs -f
        else
            sudo journalctl -f -u noctis-web-optimized -u noctis-dicom-optimized -u noctis-celery-optimized
        fi
        ;;
    health)
        echo "Performing health checks..."
        # Web service check
        if curl -f -s "http://localhost:8000/" >/dev/null 2>&1; then
            echo "✅ Web service: Healthy"
        else
            echo "❌ Web service: Unhealthy"
        fi
        
        # DICOM port check
        if timeout 5 bash -c "</dev/tcp/localhost/11112" >/dev/null 2>&1; then
            echo "✅ DICOM port: Accessible"
        else
            echo "❌ DICOM port: Not accessible"
        fi
        
        # Resource usage
        echo "📊 Memory usage: $(free | grep '^Mem:' | awk '{print int($3/$2 * 100)}')%"
        echo "📊 Disk usage: $(df "${PROJECT_DIR}" | tail -1 | awk '{print int($3/$2 * 100)}')%"
        
        # DuckDNS status
        if [[ -f "${PROJECT_DIR}/.duckdns_config" ]]; then
            source "${PROJECT_DIR}/.duckdns_config"
            echo "🦆 DuckDNS: ${DUCKDNS_DOMAIN:-Not configured}"
        fi
        ;;
    update)
        echo "Updating NoctisPro..."
        cd "${PROJECT_DIR}"
        git pull origin main
        if [[ "${DEPLOYMENT_MODE}" == "docker_"* ]]; then
            docker-compose -f docker-compose.optimized.yml down
            docker-compose -f docker-compose.optimized.yml up -d --build
        else
            source venv_optimized/bin/activate
            pip install -r requirements.optimized.txt
            python manage.py migrate --noinput
            python manage.py collectstatic --noinput
            $0 restart
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|health|update}"
        echo ""
        echo "Commands:"
        echo "  start   - Start all NoctisPro services"
        echo "  stop    - Stop all NoctisPro services"
        echo "  restart - Restart all NoctisPro services"
        echo "  status  - Show service status"
        echo "  logs    - Show service logs"
        echo "  health  - Perform health checks"
        echo "  update  - Update and restart services"
        exit 1
        ;;
esac
