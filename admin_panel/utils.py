import json
import os
from pathlib import Path
from django.conf import settings


CAPS_FILE = Path(settings.BASE_DIR) / 'config' / 'admin_capabilities.json'


DEFAULT_CAPS = {
    'manage_users': True,
    'manage_facilities': True,
    'view_logs': True,
    'manage_settings': True,
    'run_backup': True,
    'manage_permissions': True,
}


def _ensure_caps_file() -> None:
    try:
        CAPS_FILE.parent.mkdir(parents=True, exist_ok=True)
        if not CAPS_FILE.exists():
            CAPS_FILE.write_text(json.dumps({"__default__": DEFAULT_CAPS}, indent=2))
    except Exception:
        # Best-effort only
        pass


def load_capabilities() -> dict:
    _ensure_caps_file()
    try:
        with open(CAPS_FILE, 'r') as f:
            data = json.load(f)
            if not isinstance(data, dict):
                return {"__default__": DEFAULT_CAPS}
            return data
    except Exception:
        return {"__default__": DEFAULT_CAPS}


def save_capabilities(data: dict) -> None:
    _ensure_caps_file()
    try:
        with open(CAPS_FILE, 'w') as f:
            json.dump(data, f, indent=2)
    except Exception:
        pass


def get_user_caps(username: str) -> dict:
    data = load_capabilities()
    caps = data.get(username)
    if not isinstance(caps, dict):
        caps = data.get('__default__', DEFAULT_CAPS)
    # Merge with defaults to ensure all keys present
    merged = {**DEFAULT_CAPS, **caps}
    return merged


def set_user_caps(username: str, caps_update: dict) -> None:
    data = load_capabilities()
    user_caps = data.get(username, {})
    # Only accept known keys
    cleaned = {k: bool(caps_update.get(k, user_caps.get(k, DEFAULT_CAPS.get(k)))) for k in DEFAULT_CAPS.keys()}
    data[username] = cleaned
    save_capabilities(data)

