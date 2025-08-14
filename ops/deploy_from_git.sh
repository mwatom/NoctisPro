#!/usr/bin/env bash
set -Eeuo pipefail

log() { echo "[$(date '+%F %T')] $*"; }

# Configurable via env or /etc/noctis/noctis.env
ENV_FILE=${ENV_FILE:-/etc/noctis/noctis.env}
DEPLOY_BRANCH=${DEPLOY_BRANCH:-main}
SUDO=${SUDO:-sudo}

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

APP_DIR=${APP_DIR:-/opt/noctis}
VENV_DIR=${VENV_DIR:-"$APP_DIR/venv"}

# Ensure git is available
if ! command -v git >/dev/null 2>&1; then
  $SUDO apt-get update -y
  $SUDO apt-get install -y git
fi

# If APP_DIR is not a git repo, try to clone it using REPO_URL
if [ ! -d "$APP_DIR/.git" ]; then
  REPO_URL=${REPO_URL:-https://github.com/mwatom/NoctisPro}
  log "APP_DIR ($APP_DIR) is not a git repository. Bootstrapping from $REPO_URL"
  if [ -d "$APP_DIR" ] && [ -n "$(ls -A "$APP_DIR" 2>/dev/null || true)" ]; then
    echo "APP_DIR ($APP_DIR) exists and is not empty; cannot clone into it. Aborting." >&2
    exit 1
  fi
  $SUDO mkdir -p "$APP_DIR"
  $SUDO rm -rf "$APP_DIR"
  $SUDO git clone "$REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"

PREV_COMMIT=$(git rev-parse HEAD || echo "unknown")
log "Fetching latest code from origin/$DEPLOY_BRANCH"
git fetch --all --prune
# Ensure branch exists locally tracking origin
if git show-ref --verify --quiet "refs/heads/$DEPLOY_BRANCH"; then
  git checkout "$DEPLOY_BRANCH"
fi
git reset --hard "origin/$DEPLOY_BRANCH"
git submodule update --init --recursive
NEW_COMMIT=$(git rev-parse HEAD)

if [ "$PREV_COMMIT" = "$NEW_COMMIT" ]; then
  log "No new commits on $DEPLOY_BRANCH ($NEW_COMMIT). Skipping deploy."
  exit 0
fi

log "Upgrading Python dependencies"
"$VENV_DIR/bin/pip" install --upgrade pip wheel setuptools
"$VENV_DIR/bin/pip" install -r requirements.txt

# Apply migrations while web is still running to minimize downtime.
log "Applying database migrations"
"$VENV_DIR/bin/python" manage.py migrate --noinput

log "Collecting static files"
"$VENV_DIR/bin/python" manage.py collectstatic --noinput || true

log "Restarting services"
$SUDO systemctl restart noctis-celery.service || true
$SUDO systemctl restart noctis-dicom.service || true
$SUDO systemctl restart noctis-web.service

# Verify web restarted and is active
if $SUDO systemctl is-active --quiet noctis-web.service; then
  log "Web service is active"
else
  echo "Web service failed to start. Rolling back to previous commit $PREV_COMMIT" >&2
  git reset --hard "$PREV_COMMIT" || true
  "$VENV_DIR/bin/python" manage.py migrate --noinput || true
  $SUDO systemctl restart noctis-web.service || true
  exit 1
fi

log "Deploy completed successfully at commit $NEW_COMMIT"