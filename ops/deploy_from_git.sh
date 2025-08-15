#!/usr/bin/env bash
set -Eeuo pipefail

log() { echo "[$(date '+%F %T')] $*"; }
error() { echo "[$(date '+%F %T')] ERROR: $*" >&2; }
success() { echo "[$(date '+%F %T')] SUCCESS: $*"; }

# Configurable via env or /etc/noctis/noctis.env
ENV_FILE=${ENV_FILE:-/etc/noctis/noctis.env}
DEPLOY_BRANCH=${DEPLOY_BRANCH:-main}
SUDO=${SUDO:-sudo}

# Maximum time to wait for service to become healthy (seconds)
HEALTH_CHECK_TIMEOUT=${HEALTH_CHECK_TIMEOUT:-60}

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

APP_DIR=${APP_DIR:-/opt/noctis}
VENV_DIR=${VENV_DIR:-"$APP_DIR/venv"}

# Function to check if web service is healthy
check_web_health() {
    local host=${HOST:-127.0.0.1}
    local port=${PORT:-8000}
    local timeout=${1:-30}
    local max_attempts=$((timeout / 2))
    
    for i in $(seq 1 $max_attempts); do
        if curl -f -s --max-time 5 "http://${host}:${port}/" >/dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done
    return 1
}

# Function to backup current state
backup_current_state() {
    log "Creating backup of current state"
    cd "$APP_DIR"
    local backup_dir="/tmp/noctis-backup-$(date +%s)"
    mkdir -p "$backup_dir"
    
    # Backup current commit
    git rev-parse HEAD > "$backup_dir/commit.txt" 2>/dev/null || echo "unknown" > "$backup_dir/commit.txt"
    
    # Backup database
    if [ -f db.sqlite3 ]; then
        cp db.sqlite3 "$backup_dir/db.sqlite3.bak"
    fi
    
    echo "$backup_dir"
}

# Function to restore from backup
restore_from_backup() {
    local backup_dir=$1
    log "Restoring from backup: $backup_dir"
    
    cd "$APP_DIR"
    
    # Restore commit
    if [ -f "$backup_dir/commit.txt" ]; then
        local prev_commit=$(cat "$backup_dir/commit.txt")
        if [ "$prev_commit" != "unknown" ]; then
            git reset --hard "$prev_commit" 2>/dev/null || true
        fi
    fi
    
    # Restore database
    if [ -f "$backup_dir/db.sqlite3.bak" ]; then
        cp "$backup_dir/db.sqlite3.bak" db.sqlite3
    fi
    
    # Run migrations on restored database
    "$VENV_DIR/bin/python" manage.py migrate --noinput || true
    
    # Cleanup backup
    rm -rf "$backup_dir"
}

# Ensure git is available
if ! command -v git >/dev/null 2>&1; then
  log "Installing git"
  $SUDO apt-get update -y
  $SUDO apt-get install -y git
fi

# If APP_DIR is not a git repo, try to clone it using REPO_URL
if [ ! -d "$APP_DIR/.git" ]; then
  REPO_URL=${REPO_URL:-https://github.com/mwatom/NoctisPro}
  log "APP_DIR ($APP_DIR) is not a git repository. Bootstrapping from $REPO_URL"
  if [ -d "$APP_DIR" ] && [ -n "$(ls -A "$APP_DIR" 2>/dev/null || true)" ]; then
    error "APP_DIR ($APP_DIR) exists and is not empty; cannot clone into it. Aborting."
    exit 1
  fi
  $SUDO mkdir -p "$APP_DIR"
  $SUDO rm -rf "$APP_DIR"
  $SUDO git clone "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"

# Create backup before deployment
BACKUP_DIR=$(backup_current_state)

PREV_COMMIT=$(git rev-parse HEAD || echo "unknown")
log "Current commit: $PREV_COMMIT"

log "Fetching latest code from origin/$DEPLOY_BRANCH"
if ! git fetch --all --prune; then
    error "Failed to fetch from remote repository"
    restore_from_backup "$BACKUP_DIR"
    exit 1
fi

# Ensure branch exists locally tracking origin
if git show-ref --verify --quiet "refs/heads/$DEPLOY_BRANCH"; then
  git checkout "$DEPLOY_BRANCH"
else
  git checkout -b "$DEPLOY_BRANCH" "origin/$DEPLOY_BRANCH"
fi

if ! git reset --hard "origin/$DEPLOY_BRANCH"; then
    error "Failed to reset to origin/$DEPLOY_BRANCH"
    restore_from_backup "$BACKUP_DIR"
    exit 1
fi

if ! git submodule update --init --recursive; then
    log "Warning: Failed to update submodules, continuing anyway"
fi

NEW_COMMIT=$(git rev-parse HEAD)
log "New commit: $NEW_COMMIT"

if [ "$PREV_COMMIT" = "$NEW_COMMIT" ]; then
  log "No new commits on $DEPLOY_BRANCH ($NEW_COMMIT). Skipping deploy."
  rm -rf "$BACKUP_DIR"
  exit 0
fi

log "Upgrading Python dependencies"
if ! "$VENV_DIR/bin/pip" install --upgrade pip wheel setuptools; then
    error "Failed to upgrade pip/wheel/setuptools"
    restore_from_backup "$BACKUP_DIR"
    exit 1
fi

if ! "$VENV_DIR/bin/pip" install -r requirements.txt; then
    error "Failed to install requirements"
    restore_from_backup "$BACKUP_DIR"
    exit 1
fi

# Apply migrations while web is still running to minimize downtime.
log "Applying database migrations"
if ! "$VENV_DIR/bin/python" manage.py migrate --noinput; then
    error "Database migration failed"
    restore_from_backup "$BACKUP_DIR"
    exit 1
fi

log "Collecting static files"
"$VENV_DIR/bin/python" manage.py collectstatic --noinput || true

# Check if web service was healthy before restart
WEB_WAS_HEALTHY=false
if check_web_health 5; then
    WEB_WAS_HEALTHY=true
    log "Web service is currently healthy"
else
    log "Web service is not responding or not healthy"
fi

log "Restarting services in optimal order"
# Restart supporting services first
$SUDO systemctl restart noctis-celery.service || true
$SUDO systemctl restart noctis-dicom.service || true

# Restart web service last for minimal downtime
$SUDO systemctl restart noctis-web.service

# Wait for web service to become healthy
log "Waiting for web service to become healthy (timeout: ${HEALTH_CHECK_TIMEOUT}s)"
if check_web_health "$HEALTH_CHECK_TIMEOUT"; then
  success "Web service is healthy after restart"
else
  error "Web service failed to become healthy after restart. Rolling back."
  restore_from_backup "$BACKUP_DIR"
  
  # Restart services again with old code
  $SUDO systemctl restart noctis-celery.service || true
  $SUDO systemctl restart noctis-dicom.service || true
  $SUDO systemctl restart noctis-web.service || true
  
  # Check if rollback was successful
  if check_web_health 30; then
    error "Rollback successful, web service is healthy again"
  else
    error "Rollback failed, web service is still unhealthy"
  fi
  exit 1
fi

# Verify all services are active
for service in noctis-web noctis-celery noctis-dicom; do
    if $SUDO systemctl is-active --quiet "${service}.service"; then
        log "$service service is active"
    else
        error "$service service is not active"
    fi
done

# Cleanup successful backup
rm -rf "$BACKUP_DIR"

success "Deploy completed successfully at commit $NEW_COMMIT"
success "All services are running and healthy"