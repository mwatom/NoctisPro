#!/usr/bin/env python3
"""
NoctisPro PACS - Intelligent Dependency Optimizer
Analyzes system capabilities and creates optimized dependency configurations
"""

import os
import sys
import json
import subprocess
import platform
import psutil
import argparse
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class SystemAnalyzer:
    """Analyzes system capabilities and constraints"""
    
    def __init__(self):
        self.system_info = {}
        self.constraints = {}
        self.capabilities = {}
        
    def analyze_system(self) -> Dict:
        """Perform comprehensive system analysis"""
        logger.info("Starting system analysis...")
        
        self.system_info = {
            'os': platform.system().lower(),
            'os_version': platform.version(),
            'architecture': platform.machine(),
            'python_version': platform.python_version(),
            'cpu_count': psutil.cpu_count(logical=True),
            'cpu_count_physical': psutil.cpu_count(logical=False),
            'memory_total_gb': round(psutil.virtual_memory().total / (1024**3), 2),
            'memory_available_gb': round(psutil.virtual_memory().available / (1024**3), 2),
            'disk_total_gb': round(psutil.disk_usage('/').total / (1024**3), 2),
            'disk_free_gb': round(psutil.disk_usage('/').free / (1024**3), 2),
        }
        
        # Detect additional capabilities
        self._detect_capabilities()
        self._analyze_constraints()
        
        logger.info(f"System analysis complete: {self.system_info['os']} {self.system_info['architecture']}")
        logger.info(f"Resources: {self.system_info['memory_total_gb']}GB RAM, {self.system_info['cpu_count']} CPUs")
        
        return {
            'system_info': self.system_info,
            'capabilities': self.capabilities,
            'constraints': self.constraints
        }
    
    def _detect_capabilities(self):
        """Detect system capabilities"""
        self.capabilities = {
            'has_docker': self._check_command('docker'),
            'has_git': self._check_command('git'),
            'has_curl': self._check_command('curl'),
            'has_wget': self._check_command('wget'),
            'has_systemctl': self._check_command('systemctl'),
            'has_nginx': self._check_command('nginx'),
            'has_postgresql': self._check_command('psql'),
            'has_redis': self._check_command('redis-cli'),
            'has_python3': self._check_python_versions(),
            'has_pip': self._check_command('pip') or self._check_command('pip3'),
            'has_venv': self._check_python_module('venv'),
            'has_build_tools': self._check_build_tools(),
            'supports_compilation': self._check_compilation_support(),
            'network_access': self._check_network_access(),
        }
    
    def _analyze_constraints(self):
        """Analyze system constraints"""
        memory_gb = self.system_info['memory_total_gb']
        cpu_count = self.system_info['cpu_count']
        disk_free_gb = self.system_info['disk_free_gb']
        
        self.constraints = {
            'memory_limited': memory_gb < 2,
            'cpu_limited': cpu_count < 2,
            'storage_limited': disk_free_gb < 5,
            'low_memory': memory_gb < 4,
            'low_cpu': cpu_count < 4,
            'very_low_resources': memory_gb < 1 or cpu_count < 1,
            'can_run_docker': memory_gb >= 1 and disk_free_gb >= 2,
            'can_run_full_stack': memory_gb >= 4 and cpu_count >= 2,
            'can_run_ai_features': memory_gb >= 8 and cpu_count >= 4,
            'requires_compilation': not self._check_wheel_availability(),
        }
    
    def _check_command(self, command: str) -> bool:
        """Check if a command is available"""
        try:
            subprocess.run([command, '--version'], 
                         capture_output=True, check=True, timeout=5)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
            return False
    
    def _check_python_versions(self) -> List[str]:
        """Check available Python versions"""
        versions = []
        for version in ['python3.12', 'python3.11', 'python3.10', 'python3.9', 'python3.8', 'python3']:
            if self._check_command(version):
                versions.append(version)
        return versions
    
    def _check_python_module(self, module: str) -> bool:
        """Check if a Python module is available"""
        try:
            subprocess.run([sys.executable, '-c', f'import {module}'], 
                         capture_output=True, check=True, timeout=5)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
            return False
    
    def _check_build_tools(self) -> bool:
        """Check if build tools are available"""
        build_tools = ['gcc', 'g++', 'make', 'pkg-config']
        return any(self._check_command(tool) for tool in build_tools)
    
    def _check_compilation_support(self) -> bool:
        """Check if system supports compilation"""
        return (self.capabilities.get('has_build_tools', False) and 
                self.system_info['disk_free_gb'] > 2)
    
    def _check_wheel_availability(self) -> bool:
        """Check if pre-compiled wheels are likely available"""
        # Most packages have wheels for x86_64 Linux
        return (self.system_info['architecture'] in ['x86_64', 'amd64'] and 
                self.system_info['os'] == 'linux')
    
    def _check_network_access(self) -> bool:
        """Check network connectivity"""
        try:
            subprocess.run(['ping', '-c', '1', '-W', '5', '8.8.8.8'], 
                         capture_output=True, check=True, timeout=10)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
            return False

class DependencyOptimizer:
    """Optimizes dependencies based on system analysis"""
    
    def __init__(self, system_analysis: Dict):
        self.system_info = system_analysis['system_info']
        self.capabilities = system_analysis['capabilities']
        self.constraints = system_analysis['constraints']
        
        # Define dependency categories
        self.dependency_categories = {
            'core': {
                'description': 'Essential dependencies required for basic functionality',
                'packages': [
                    'Django>=4.2,<5.0',
                    'Pillow',
                    'django-widget-tweaks',
                    'python-dotenv',
                    'gunicorn',
                    'whitenoise',
                    'djangorestframework',
                    'django-cors-headers',
                ]
            },
            'database': {
                'description': 'Database connectivity',
                'packages': [
                    'psycopg2-binary',
                    'dj-database-url',
                ]
            },
            'caching': {
                'description': 'Caching and session storage',
                'packages': [
                    'redis',
                    'django-redis',
                ]
            },
            'dicom_basic': {
                'description': 'Basic DICOM processing',
                'packages': [
                    'pydicom',
                    'pynetdicom',
                ]
            },
            'dicom_advanced': {
                'description': 'Advanced DICOM processing (high memory)',
                'packages': [
                    'SimpleITK',
                    'pylibjpeg',
                    'pylibjpeg-libjpeg',
                    'pylibjpeg-openjpeg',
                    'gdcm',
                    'highdicom',
                ]
            },
            'background_tasks': {
                'description': 'Background task processing',
                'packages': [
                    'celery',
                    'channels',
                    'channels-redis',
                    'daphne',
                ]
            },
            'image_processing': {
                'description': 'Image processing and manipulation',
                'packages': [
                    'opencv-python',
                    'scikit-image',
                    'matplotlib',
                ]
            },
            'ai_ml': {
                'description': 'AI and machine learning features',
                'packages': [
                    'numpy',
                    'scipy',
                    'pandas',
                    'torch',
                    'torchvision',
                    'scikit-learn',
                    'transformers',
                ]
            },
            'document_processing': {
                'description': 'Document and report processing',
                'packages': [
                    'PyMuPDF',
                    'python-docx',
                    'openpyxl',
                    'reportlab',
                ]
            },
            'utilities': {
                'description': 'Utility packages',
                'packages': [
                    'requests',
                    'urllib3',
                    'python-magic',
                    'qrcode',
                    'cryptography',
                    'PyJWT',
                ]
            },
            'development': {
                'description': 'Development and debugging tools',
                'packages': [
                    'django-extensions',
                ]
            },
            'printing': {
                'description': 'Printing support (Linux only)',
                'packages': [
                    'pycups',
                    'python-escpos',
                ]
            }
        }
    
    def generate_optimized_requirements(self) -> Tuple[List[str], Dict]:
        """Generate optimized requirements based on system analysis"""
        logger.info("Generating optimized requirements...")
        
        selected_categories = self._select_categories()
        requirements = self._build_requirements_list(selected_categories)
        optimization_report = self._generate_report(selected_categories)
        
        return requirements, optimization_report
    
    def _select_categories(self) -> List[str]:
        """Select appropriate dependency categories based on system constraints"""
        selected = ['core', 'database', 'dicom_basic', 'utilities']
        
        # Add caching if Redis is available or can be installed
        if not self.constraints['very_low_resources']:
            selected.append('caching')
        
        # Add background tasks for systems with sufficient resources
        if (not self.constraints['memory_limited'] and 
            not self.constraints['cpu_limited']):
            selected.append('background_tasks')
        
        # Add advanced DICOM processing for systems with good resources
        if (self.system_info['memory_total_gb'] >= 4 and 
            not self.constraints['storage_limited']):
            selected.append('dicom_advanced')
        
        # Add image processing for systems that can handle it
        if (self.system_info['memory_total_gb'] >= 2 and 
            self.capabilities['supports_compilation']):
            selected.append('image_processing')
        
        # Add AI/ML features only for high-resource systems
        if self.constraints['can_run_ai_features']:
            selected.append('ai_ml')
        
        # Add document processing for most systems
        if not self.constraints['very_low_resources']:
            selected.append('document_processing')
        
        # Add development tools for non-production environments
        if not self._is_production_environment():
            selected.append('development')
        
        # Add printing support for Linux systems with build tools
        if (self.system_info['os'] == 'linux' and 
            self.capabilities['has_build_tools']):
            selected.append('printing')
        
        return selected
    
    def _build_requirements_list(self, selected_categories: List[str]) -> List[str]:
        """Build the final requirements list"""
        requirements = []
        
        for category in selected_categories:
            if category in self.dependency_categories:
                category_info = self.dependency_categories[category]
                requirements.append(f"# {category_info['description']}")
                requirements.extend(category_info['packages'])
                requirements.append("")  # Empty line for readability
        
        # Add architecture-specific optimizations
        requirements.extend(self._get_architecture_optimizations())
        
        # Add OS-specific packages
        requirements.extend(self._get_os_specific_packages())
        
        return requirements
    
    def _get_architecture_optimizations(self) -> List[str]:
        """Get architecture-specific optimizations"""
        optimizations = ["# Architecture-specific optimizations"]
        
        if self.system_info['architecture'] in ['aarch64', 'arm64']:
            optimizations.extend([
                "# ARM architecture optimizations",
                "# Some packages may need compilation from source",
                "# Consider using --no-binary flag for problematic packages",
            ])
        elif self.system_info['architecture'] in ['x86_64', 'amd64']:
            optimizations.extend([
                "# x86_64 architecture - most packages have pre-built wheels",
                "# Prefer binary packages when available",
            ])
        
        optimizations.append("")
        return optimizations
    
    def _get_os_specific_packages(self) -> List[str]:
        """Get OS-specific package recommendations"""
        packages = ["# OS-specific recommendations"]
        
        if self.system_info['os'] == 'linux':
            packages.extend([
                "# Linux-specific packages",
                "# Most packages should work without issues",
            ])
        elif self.system_info['os'] == 'darwin':
            packages.extend([
                "# macOS-specific considerations",
                "# Some packages may require Xcode command line tools",
            ])
        elif self.system_info['os'] == 'windows':
            packages.extend([
                "# Windows-specific considerations",
                "# Some packages may require Visual Studio Build Tools",
            ])
        
        packages.append("")
        return packages
    
    def _generate_report(self, selected_categories: List[str]) -> Dict:
        """Generate optimization report"""
        total_categories = len(self.dependency_categories)
        selected_count = len(selected_categories)
        
        excluded_categories = [cat for cat in self.dependency_categories.keys() 
                             if cat not in selected_categories]
        
        report = {
            'system_summary': {
                'os': f"{self.system_info['os']} {self.system_info['architecture']}",
                'memory_gb': self.system_info['memory_total_gb'],
                'cpu_count': self.system_info['cpu_count'],
                'disk_free_gb': self.system_info['disk_free_gb'],
            },
            'optimization_summary': {
                'total_categories': total_categories,
                'selected_categories': selected_count,
                'optimization_ratio': f"{(selected_count/total_categories)*100:.1f}%",
            },
            'selected_categories': selected_categories,
            'excluded_categories': excluded_categories,
            'constraints_applied': [k for k, v in self.constraints.items() if v],
            'recommendations': self._generate_recommendations(),
        }
        
        return report
    
    def _generate_recommendations(self) -> List[str]:
        """Generate system-specific recommendations"""
        recommendations = []
        
        if self.constraints['memory_limited']:
            recommendations.append("Consider adding more RAM for better performance")
        
        if self.constraints['cpu_limited']:
            recommendations.append("System may benefit from additional CPU cores")
        
        if self.constraints['storage_limited']:
            recommendations.append("Free up disk space before installation")
        
        if not self.capabilities['has_docker']:
            recommendations.append("Consider installing Docker for easier deployment")
        
        if not self.capabilities['has_build_tools']:
            recommendations.append("Install build tools for packages that require compilation")
        
        if not self.capabilities['network_access']:
            recommendations.append("Ensure internet connectivity for package downloads")
        
        if self.constraints['requires_compilation']:
            recommendations.append("Some packages may need to be compiled from source")
        
        return recommendations
    
    def _is_production_environment(self) -> bool:
        """Detect if this is a production environment"""
        # Simple heuristics to detect production
        return (
            os.environ.get('DJANGO_ENV') == 'production' or
            os.environ.get('DEBUG', '').lower() in ['false', '0'] or
            '/opt/' in os.getcwd() or
            'production' in os.getcwd().lower()
        )

class DockerOptimizer:
    """Optimizes Docker configurations based on system analysis"""
    
    def __init__(self, system_analysis: Dict):
        self.system_info = system_analysis['system_info']
        self.capabilities = system_analysis['capabilities']
        self.constraints = system_analysis['constraints']
    
    def generate_optimized_compose(self) -> str:
        """Generate optimized Docker Compose configuration"""
        logger.info("Generating optimized Docker Compose configuration...")
        
        memory_gb = self.system_info['memory_total_gb']
        cpu_count = self.system_info['cpu_count']
        
        # Calculate resource allocations
        db_memory = max(256, min(1024, int(memory_gb * 0.2 * 1024)))  # 20% of total, min 256MB, max 1GB
        web_memory = max(512, min(2048, int(memory_gb * 0.4 * 1024)))  # 40% of total
        redis_memory = max(128, min(512, int(memory_gb * 0.1 * 1024)))  # 10% of total
        
        worker_count = max(1, min(8, cpu_count))
        
        compose_config = f"""version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: noctis_db_optimized
    environment:
      POSTGRES_DB: noctis_pro
      POSTGRES_USER: noctis_user
      POSTGRES_PASSWORD: ${{POSTGRES_PASSWORD:-noctis_secure_password}}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: {db_memory}M
        reservations:
          memory: {db_memory//2}M
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U noctis_user -d noctis_pro"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: noctis_redis_optimized
    command: redis-server --appendonly yes --maxmemory {redis_memory}mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: {redis_memory}M
        reservations:
          memory: {redis_memory//2}M

  web:
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    container_name: noctis_web_optimized
    environment:
      - DEBUG=False
      - SECRET_KEY=${{SECRET_KEY}}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - POSTGRES_DB=noctis_pro
      - POSTGRES_USER=noctis_user
      - POSTGRES_PASSWORD=${{POSTGRES_PASSWORD:-noctis_secure_password}}
      - POSTGRES_HOST=db
      - REDIS_URL=redis://redis:6379/0
    volumes:
      - .:/app
      - media_files:/app/media
      - static_files:/app/staticfiles
    ports:
      - "8000:8000"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    restart: unless-stopped
    command: >
      sh -c "python manage.py migrate --noinput &&
             python manage.py collectstatic --noinput &&
             gunicorn noctis_pro.wsgi:application --bind 0.0.0.0:8000 --workers {worker_count} --timeout 120 --max-requests 1000 --max-requests-jitter 100"
    deploy:
      resources:
        limits:
          memory: {web_memory}M
        reservations:
          memory: {web_memory//2}M

  dicom_receiver:
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    container_name: noctis_dicom_optimized
    environment:
      - DEBUG=False
      - SECRET_KEY=${{SECRET_KEY}}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - POSTGRES_HOST=db
      - REDIS_URL=redis://redis:6379/0
    volumes:
      - .:/app
      - media_files:/app/media
    ports:
      - "11112:11112"
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    restart: unless-stopped
    command: python dicom_receiver.py --port 11112 --aet NOCTIS_SCP
    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
"""

        # Add Celery service for systems with sufficient resources
        if not self.constraints['memory_limited'] and not self.constraints['cpu_limited']:
            celery_memory = max(256, min(1024, int(memory_gb * 0.2 * 1024)))
            compose_config += f"""
  celery:
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    container_name: noctis_celery_optimized
    environment:
      - DEBUG=False
      - SECRET_KEY=${{SECRET_KEY}}
      - DJANGO_SETTINGS_MODULE=noctis_pro.settings
      - POSTGRES_HOST=db
      - REDIS_URL=redis://redis:6379/0
    volumes:
      - .:/app
      - media_files:/app/media
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    restart: unless-stopped
    command: celery -A noctis_pro worker --loglevel=info --concurrency={max(1, cpu_count//2)}
    deploy:
      resources:
        limits:
          memory: {celery_memory}M
        reservations:
          memory: {celery_memory//2}M
"""

        # Add volumes
        compose_config += """
volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  media_files:
    driver: local
  static_files:
    driver: local
"""

        return compose_config

def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='NoctisPro Dependency Optimizer')
    parser.add_argument('--output-dir', default='.', help='Output directory for generated files')
    parser.add_argument('--format', choices=['requirements', 'docker', 'both'], default='both',
                       help='Output format')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        # Analyze system
        analyzer = SystemAnalyzer()
        system_analysis = analyzer.analyze_system()
        
        output_dir = Path(args.output_dir)
        output_dir.mkdir(exist_ok=True)
        
        if args.format in ['requirements', 'both']:
            # Generate optimized requirements
            optimizer = DependencyOptimizer(system_analysis)
            requirements, report = optimizer.generate_optimized_requirements()
            
            # Write requirements file
            req_file = output_dir / 'requirements.optimized.txt'
            with open(req_file, 'w') as f:
                f.write('\n'.join(requirements))
            
            # Write optimization report
            report_file = output_dir / 'optimization_report.json'
            with open(report_file, 'w') as f:
                json.dump(report, f, indent=2)
            
            logger.info(f"Requirements written to: {req_file}")
            logger.info(f"Optimization report written to: {report_file}")
            
            # Print summary
            print(f"\n🔍 System Analysis Complete")
            print(f"OS: {system_analysis['system_info']['os']} {system_analysis['system_info']['architecture']}")
            print(f"Resources: {system_analysis['system_info']['memory_total_gb']}GB RAM, {system_analysis['system_info']['cpu_count']} CPUs")
            print(f"Selected {len(report['selected_categories'])}/{len(optimizer.dependency_categories)} dependency categories")
            
            if report['recommendations']:
                print(f"\n💡 Recommendations:")
                for rec in report['recommendations']:
                    print(f"  • {rec}")
        
        if args.format in ['docker', 'both']:
            # Generate optimized Docker Compose
            docker_optimizer = DockerOptimizer(system_analysis)
            compose_config = docker_optimizer.generate_optimized_compose()
            
            # Write Docker Compose file
            compose_file = output_dir / 'docker-compose.optimized.yml'
            with open(compose_file, 'w') as f:
                f.write(compose_config)
            
            logger.info(f"Optimized Docker Compose written to: {compose_file}")
    
    except Exception as e:
        logger.error(f"Error during optimization: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()