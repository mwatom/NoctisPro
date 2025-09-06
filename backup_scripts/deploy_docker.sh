#!/bin/bash
echo "🐳 DOCKER DEPLOYMENT"
echo "==================="
echo ""
echo "📋 PREREQUISITES:"
echo "   • Docker and Docker Compose installed"
echo "   • 4GB+ RAM recommended"
echo "   • 20GB+ storage space"
echo ""

# Create production Dockerfile
cat > Dockerfile.production << 'DOCKER_EOF'
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DJANGO_SETTINGS_MODULE=noctis_pro.settings

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    libpq-dev \
    libgdal-dev \
    gdal-bin \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install gunicorn psycopg2-binary

# Copy application code
COPY . .

# Collect static files
RUN python manage.py collectstatic --noinput

# Create non-root user
RUN adduser --disabled-password --gecos '' appuser
RUN chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Run gunicorn
CMD ["gunicorn", "noctis_pro.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
DOCKER_EOF

# Create docker-compose for production
cat > docker-compose.production.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: noctispro
      POSTGRES_USER: noctispro
      POSTGRES_PASSWORD: your_secure_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U noctispro"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - redis_data:/data

  web:
    build:
      context: .
      dockerfile: Dockerfile.production
    environment:
      - DEBUG=False
      - DATABASE_URL=postgresql://noctispro:your_secure_password@db:5432/noctispro
      - REDIS_URL=redis://redis:6379/0
      - ALLOWED_HOSTS=your-domain.com,www.your-domain.com
    volumes:
      - static_volume:/app/staticfiles
      - media_volume:/app/media
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health/"]
      interval: 30s
      timeout: 10s
      retries: 3

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - static_volume:/app/staticfiles
      - media_volume:/app/media
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - web
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
  static_volume:
  media_volume:
COMPOSE_EOF

echo ""
echo "🚀 DEPLOYMENT COMMANDS:"
echo "----------------------"
echo "# Build and start services"
echo "docker-compose -f docker-compose.production.yml up -d --build"
echo ""
echo "# Run migrations"
echo "docker-compose -f docker-compose.production.yml exec web python manage.py migrate"
echo ""
echo "# Create superuser"
echo "docker-compose -f docker-compose.production.yml exec web python manage.py createsuperuser"
echo ""
echo "# View logs"
echo "docker-compose -f docker-compose.production.yml logs -f"
echo ""
echo "✅ Docker deployment files created!"
