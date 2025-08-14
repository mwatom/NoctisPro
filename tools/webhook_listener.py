#!/usr/bin/env python3
import hmac
import hashlib
import json
import os
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler

HOST = os.environ.get("WEBHOOK_HOST", "127.0.0.1")
PORT = int(os.environ.get("WEBHOOK_PORT", "9000"))
SECRET = os.environ.get("GITHUB_WEBHOOK_SECRET", "")
BRANCH = os.environ.get("DEPLOY_BRANCH", "refs/heads/main")
APP_DIR = os.environ.get("APP_DIR", "/workspace")
ENV_FILE = os.environ.get("ENV_FILE", "/etc/noctis/noctis.env")

class Handler(BaseHTTPRequestHandler):
    def _verify_signature(self, body: bytes) -> bool:
        if not SECRET:
            # If no secret configured, accept (not recommended for public exposure)
            return True
        sig = self.headers.get("X-Hub-Signature-256", "")
        if not sig.startswith("sha256="):
            return False
        digest = hmac.new(SECRET.encode(), body, hashlib.sha256).hexdigest()
        return hmac.compare_digest(sig.split("=", 1)[1], digest)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        payload = self.rfile.read(length)
        if not self._verify_signature(payload):
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"invalid signature")
            return
        try:
            event = self.headers.get("X-GitHub-Event", "")
            data = json.loads(payload.decode("utf-8"))
        except Exception:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"bad payload")
            return
        # Only act on push to specific branch
        if event == "push" and data.get("ref") == BRANCH:
            self.send_response(202)
            self.end_headers()
            self.wfile.write(b"deploy queued")
            # Run deploy in background
            subprocess.Popen([
                "/usr/bin/bash", "-lc",
                f'DEPLOY_BRANCH="{BRANCH.split("/", 2)[-1]}" ENV_FILE="{ENV_FILE}" bash "{APP_DIR}/ops/deploy_from_git.sh" >> /var/log/noctis-deploy.log 2>&1'
            ])
        else:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"ignored")

if __name__ == "__main__":
    server = HTTPServer((HOST, PORT), Handler)
    print(f"Webhook listener on {HOST}:{PORT}, branch={BRANCH}")
    server.serve_forever()