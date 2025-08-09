# Noctis Pro Installation Guide

## Prerequisites

- Python 3.9 or higher
- Redis server (for Celery and Django Channels)
- Virtual environment (recommended)

## Installation Steps

### 1. Create and activate virtual environment
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install dependencies

For production:
```bash
pip install -r requirements.txt
```

For development (includes testing and debugging tools):
```bash
pip install -r requirements-dev.txt
```

### 3. Set up Redis
Make sure Redis is installed and running on your system:
```bash
# Ubuntu/Debian
sudo apt-get install redis-server

# macOS
brew install redis

# Start Redis
redis-server
```

### 4. Database setup
```bash
python manage.py migrate
python manage.py createsuperuser
```

### 5. Collect static files (for production)
```bash
python manage.py collectstatic
```

### 6. Run the development server
```bash
# Start Django development server
python manage.py runserver

# In another terminal, start Celery worker (if using background tasks)
celery -A noctis_pro worker --loglevel=info
```

## Environment Variables

Consider creating a `.env` file for environment-specific settings:
```
DEBUG=True
SECRET_KEY=your-secret-key
REDIS_URL=redis://localhost:6379
```

## Notes

- This is a Django-based DICOM medical imaging viewer application
- The application uses WebSockets for real-time features (chat and notifications)
- Make sure Redis is running before starting the application
- For production deployment, consider using gunicorn and nginx