#!/usr/bin/env python3
"""
GitHub Webhook Server for Noctis Pro Docker Auto-Update
Listens for GitHub push events and automatically updates the running system.
"""

import os
import sys
import json
import hmac
import hashlib
import subprocess
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class GitHubWebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/webhook':
            self.send_response(404)
            self.end_headers()
            return

        # Get content length
        content_length = int(self.headers.get('Content-Length', 0))
        
        # Read the payload
        payload = self.rfile.read(content_length)
        
        # Verify signature if webhook secret is set
        webhook_secret = os.environ.get('WEBHOOK_SECRET')
        if webhook_secret:
            signature = self.headers.get('X-Hub-Signature-256')
            if not self.verify_signature(payload, signature, webhook_secret):
                logger.warning("Invalid webhook signature")
                self.send_response(401)
                self.end_headers()
                return

        try:
            # Parse JSON payload
            data = json.loads(payload.decode('utf-8'))
            
            # Check if this is a push event to main/master branch
            if data.get('ref') in ['refs/heads/main', 'refs/heads/master']:
                logger.info(f"Received push to {data.get('ref')}")
                
                # Trigger update
                success = self.update_system()
                
                if success:
                    self.send_response(200)
                    response = {'status': 'success', 'message': 'System updated successfully'}
                else:
                    self.send_response(500)
                    response = {'status': 'error', 'message': 'Update failed'}
                
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(response).encode('utf-8'))
            else:
                logger.info(f"Ignoring push to {data.get('ref')}")
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'status': 'ignored'}).encode('utf-8'))
                
        except Exception as e:
            logger.error(f"Error processing webhook: {e}")
            self.send_response(500)
            self.end_headers()

    def verify_signature(self, payload, signature, secret):
        """Verify GitHub webhook signature"""
        if not signature:
            return False
            
        expected_signature = 'sha256=' + hmac.new(
            secret.encode('utf-8'),
            payload,
            hashlib.sha256
        ).hexdigest()
        
        return hmac.compare_digest(signature, expected_signature)

    def update_system(self):
        """Update the system from GitHub and restart containers"""
        try:
            logger.info("Starting system update...")
            
            # Change to app directory
            os.chdir('/app')
            
            # Pull latest changes from GitHub
            logger.info("Pulling latest changes from GitHub...")
            result = subprocess.run(['git', 'pull'], capture_output=True, text=True)
            if result.returncode != 0:
                logger.error(f"Git pull failed: {result.stderr}")
                return False
            
            logger.info(f"Git pull output: {result.stdout}")
            
            # Update Python dependencies if requirements changed
            if self.file_changed('requirements.txt', result.stdout):
                logger.info("Updating Python dependencies...")
                subprocess.run(['pip', 'install', '-r', 'requirements.txt'], check=True)
            
            # Run migrations if models changed
            if self.code_changed(result.stdout):
                logger.info("Running database migrations...")
                subprocess.run(['python', 'manage.py', 'migrate'], check=True)
            
            # Collect static files if static files changed
            if self.static_changed(result.stdout):
                logger.info("Collecting static files...")
                subprocess.run(['python', 'manage.py', 'collectstatic', '--noinput'], check=True)
            
            # Restart containers using Docker Compose
            logger.info("Restarting Docker containers...")
            subprocess.run(['docker', 'compose', 'restart', 'web', 'celery', 'dicom_receiver'], check=True)
            
            logger.info("✅ System update completed successfully!")
            return True
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Command failed: {e}")
            return False
        except Exception as e:
            logger.error(f"Update failed: {e}")
            return False

    def file_changed(self, filename, git_output):
        """Check if a specific file was changed"""
        return filename in git_output

    def code_changed(self, git_output):
        """Check if Python code was changed"""
        code_patterns = ['.py', 'models.py', 'migrations/']
        return any(pattern in git_output for pattern in code_patterns)

    def static_changed(self, git_output):
        """Check if static files were changed"""
        static_patterns = ['static/', 'templates/', '.css', '.js', '.html']
        return any(pattern in git_output for pattern in static_patterns)

    def log_message(self, format, *args):
        """Override to use our logger"""
        logger.info(format % args)

def main():
    port = int(os.environ.get('WEBHOOK_PORT', 9000))
    
    logger.info(f"🔄 Starting GitHub Webhook Server on port {port}")
    logger.info(f"📡 Webhook URL: http://localhost:{port}/webhook")
    logger.info(f"🔐 Webhook secret: {'Set' if os.environ.get('WEBHOOK_SECRET') else 'Not set'}")
    
    server = HTTPServer(('0.0.0.0', port), GitHubWebhookHandler)
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down webhook server...")
        server.shutdown()

if __name__ == '__main__':
    main()