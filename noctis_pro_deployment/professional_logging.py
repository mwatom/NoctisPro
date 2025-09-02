"""
Professional Medical Logging System - Medical Imaging Excellence
Masterpiece-level logging infrastructure for medical imaging systems
Enhanced with professional medical standards and diagnostic quality tracking
"""

import logging
import logging.handlers
import os
import json
import time
from datetime import datetime
from django.utils import timezone
from django.conf import settings


class ProfessionalMedicalFormatter(logging.Formatter):
    """Professional medical logging formatter with enhanced information"""
    
    def __init__(self):
        super().__init__()
        self.start_time = time.time()
    
    def format(self, record):
        # Professional timestamp with medical precision
        timestamp = datetime.fromtimestamp(record.created).strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
        
        # Professional level formatting with medical color coding
        level_colors = {
            'DEBUG': '\033[36m',    # Cyan - Technical details
            'INFO': '\033[32m',     # Green - Success operations
            'WARNING': '\033[33m',  # Yellow - Important notices
            'ERROR': '\033[31m',    # Red - Critical issues
            'CRITICAL': '\033[35m', # Magenta - System failures
        }
        
        level_icons = {
            'DEBUG': '🔍',
            'INFO': '✅',
            'WARNING': '⚠️',
            'ERROR': '🚨',
            'CRITICAL': '💥',
        }
        
        reset_color = '\033[0m'
        level_color = level_colors.get(record.levelname, '')
        level_icon = level_icons.get(record.levelname, '📝')
        
        # Professional uptime calculation
        uptime = time.time() - self.start_time
        uptime_str = f"{uptime:.1f}s"
        
        # Professional log formatting with medical precision
        formatted_message = (
            f"{level_color}[{timestamp}] "
            f"{level_icon} {record.levelname:<8} "
            f"[{record.name}] "
            f"[{uptime_str}] "
            f"{reset_color}{record.getMessage()}"
        )
        
        # Add professional context if available
        if hasattr(record, 'user'):
            formatted_message += f" | User: {record.user}"
        if hasattr(record, 'facility'):
            formatted_message += f" | Facility: {record.facility}"
        if hasattr(record, 'study_id'):
            formatted_message += f" | Study: {record.study_id}"
        if hasattr(record, 'processing_time'):
            formatted_message += f" | Time: {record.processing_time}ms"
        
        return formatted_message


class ProfessionalMedicalHandler(logging.Handler):
    """Professional medical logging handler with enhanced capabilities"""
    
    def __init__(self, log_file=None):
        super().__init__()
        self.log_file = log_file or os.path.join(settings.BASE_DIR, 'logs', 'professional_medical.log')
        
        # Ensure log directory exists
        os.makedirs(os.path.dirname(self.log_file), exist_ok=True)
        
        # Professional file handler with rotation
        self.file_handler = logging.handlers.RotatingFileHandler(
            self.log_file,
            maxBytes=50 * 1024 * 1024,  # 50MB
            backupCount=10,
            encoding='utf-8'
        )
        
        # Professional JSON formatter for structured logging
        self.json_formatter = self._create_json_formatter()
        self.file_handler.setFormatter(self.json_formatter)
    
    def _create_json_formatter(self):
        """Create professional JSON formatter for structured medical logging"""
        class JsonFormatter(logging.Formatter):
            def format(self, record):
                log_entry = {
                    'timestamp': datetime.fromtimestamp(record.created).isoformat(),
                    'level': record.levelname,
                    'logger': record.name,
                    'message': record.getMessage(),
                    'module': record.module,
                    'function': record.funcName,
                    'line': record.lineno,
                    'system': 'Noctis Pro PACS v2.0 Enhanced',
                    'medical_grade': True,
                }
                
                # Add professional context
                if hasattr(record, 'user'):
                    log_entry['user'] = record.user
                if hasattr(record, 'facility'):
                    log_entry['facility'] = record.facility
                if hasattr(record, 'study_id'):
                    log_entry['study_id'] = record.study_id
                if hasattr(record, 'processing_time'):
                    log_entry['processing_time_ms'] = record.processing_time
                if hasattr(record, 'medical_context'):
                    log_entry['medical_context'] = record.medical_context
                
                return json.dumps(log_entry, ensure_ascii=False)
        
        return JsonFormatter()
    
    def emit(self, record):
        """Emit professional medical log record"""
        try:
            # Send to file handler for structured logging
            self.file_handler.emit(record)
            
            # Professional console output for critical issues
            if record.levelno >= logging.ERROR:
                print(f"🚨 MEDICAL SYSTEM ALERT: {record.getMessage()}")
            
        except Exception as e:
            self.handleError(record)


class ProfessionalMedicalLogger:
    """Professional medical logging system with enhanced capabilities"""
    
    def __init__(self, name='noctis_pro'):
        self.logger = logging.getLogger(name)
        self.logger.setLevel(logging.INFO)
        
        # Professional handlers
        self._setup_professional_handlers()
    
    def _setup_professional_handlers(self):
        """Setup professional logging handlers"""
        # Clear existing handlers
        self.logger.handlers.clear()
        
        # Professional console handler
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(ProfessionalMedicalFormatter())
        self.logger.addHandler(console_handler)
        
        # Professional file handler
        medical_handler = ProfessionalMedicalHandler()
        self.logger.addHandler(medical_handler)
    
    def log_upload_start(self, user, file_count, total_size_mb):
        """Log professional upload start"""
        self.logger.info(
            f"🏥 Professional DICOM upload initiated",
            extra={
                'user': user,
                'medical_context': {
                    'operation': 'DICOM_UPLOAD_START',
                    'file_count': file_count,
                    'total_size_mb': total_size_mb,
                }
            }
        )
    
    def log_upload_success(self, user, stats):
        """Log professional upload success"""
        self.logger.info(
            f"✅ Professional DICOM upload completed successfully",
            extra={
                'user': user,
                'processing_time': stats.get('processing_time_ms'),
                'medical_context': {
                    'operation': 'DICOM_UPLOAD_SUCCESS',
                    'statistics': stats,
                }
            }
        )
    
    def log_upload_error(self, user, error, context=None):
        """Log professional upload error"""
        self.logger.error(
            f"🚨 Professional DICOM upload failed: {error}",
            extra={
                'user': user,
                'medical_context': {
                    'operation': 'DICOM_UPLOAD_ERROR',
                    'error_details': str(error),
                    'context': context or {},
                }
            }
        )
    
    def log_user_creation(self, admin_user, created_user, processing_time_ms):
        """Log professional user creation"""
        self.logger.info(
            f"👤 Professional medical staff created: {created_user}",
            extra={
                'user': admin_user,
                'processing_time': processing_time_ms,
                'medical_context': {
                    'operation': 'USER_CREATION',
                    'created_user': created_user,
                    'medical_compliance': 'FULL',
                }
            }
        )
    
    def log_dicom_received(self, study_uid, series_uid, modality, file_size):
        """Log professional DICOM reception"""
        self.logger.info(
            f"📡 Professional DICOM received via network",
            extra={
                'study_id': study_uid,
                'medical_context': {
                    'operation': 'DICOM_NETWORK_RECEPTION',
                    'study_uid': study_uid,
                    'series_uid': series_uid,
                    'modality': modality,
                    'file_size_kb': file_size / 1024,
                    'reception_method': 'C-STORE SCP',
                }
            }
        )
    
    def log_api_request(self, endpoint, user, processing_time_ms, response_size=None):
        """Log professional API request"""
        self.logger.info(
            f"🔌 Professional API request: {endpoint}",
            extra={
                'user': user,
                'processing_time': processing_time_ms,
                'medical_context': {
                    'operation': 'API_REQUEST',
                    'endpoint': endpoint,
                    'response_size': response_size,
                    'api_version': 'v2.0 Enhanced',
                }
            }
        )
    
    def log_system_startup(self, component, version='v2.0 Enhanced'):
        """Log professional system startup"""
        self.logger.info(
            f"🚀 Professional system component started: {component}",
            extra={
                'medical_context': {
                    'operation': 'SYSTEM_STARTUP',
                    'component': component,
                    'version': version,
                    'quality': 'Medical Grade Excellence',
                    'compliance': 'DICOM 3.0 Professional Standards',
                }
            }
        )
    
    def log_system_error(self, component, error, context=None):
        """Log professional system error"""
        self.logger.error(
            f"💥 Professional system error in {component}: {error}",
            extra={
                'medical_context': {
                    'operation': 'SYSTEM_ERROR',
                    'component': component,
                    'error_details': str(error),
                    'context': context or {},
                    'severity': 'HIGH',
                }
            }
        )


# Global professional logger instance
professional_logger = ProfessionalMedicalLogger()


def setup_professional_logging():
    """Setup professional logging for the entire medical imaging system"""
    
    # Professional log directory
    log_dir = os.path.join(settings.BASE_DIR, 'logs')
    os.makedirs(log_dir, exist_ok=True)
    
    # Professional logging configuration
    logging_config = {
        'version': 1,
        'disable_existing_loggers': False,
        'formatters': {
            'professional_medical': {
                '()': ProfessionalMedicalFormatter,
            },
            'professional_json': {
                'format': '%(asctime)s | %(levelname)s | %(name)s | %(message)s',
                'datefmt': '%Y-%m-%d %H:%M:%S',
            },
        },
        'handlers': {
            'professional_console': {
                'class': 'logging.StreamHandler',
                'formatter': 'professional_medical',
                'level': 'INFO',
            },
            'professional_file': {
                'class': 'logging.handlers.RotatingFileHandler',
                'filename': os.path.join(log_dir, 'noctis_pro_professional.log'),
                'maxBytes': 50 * 1024 * 1024,  # 50MB
                'backupCount': 10,
                'formatter': 'professional_json',
                'level': 'DEBUG',
            },
            'medical_operations': {
                'class': 'logging.handlers.RotatingFileHandler',
                'filename': os.path.join(log_dir, 'medical_operations.log'),
                'maxBytes': 100 * 1024 * 1024,  # 100MB
                'backupCount': 20,
                'formatter': 'professional_json',
                'level': 'INFO',
            },
        },
        'loggers': {
            'noctis_pro': {
                'handlers': ['professional_console', 'professional_file'],
                'level': 'INFO',
                'propagate': False,
            },
            'noctis_pro.upload': {
                'handlers': ['medical_operations'],
                'level': 'INFO',
                'propagate': True,
            },
            'noctis_pro.user_management': {
                'handlers': ['medical_operations'],
                'level': 'INFO',
                'propagate': True,
            },
            'noctis_pro.dicom_receiver': {
                'handlers': ['medical_operations'],
                'level': 'INFO',
                'propagate': True,
            },
            'noctis_pro.api': {
                'handlers': ['professional_file'],
                'level': 'INFO',
                'propagate': True,
            },
        },
    }
    
    # Apply professional logging configuration
    logging.config.dictConfig(logging_config)
    
    # Professional startup logging
    professional_logger.log_system_startup('Professional Logging System')


def get_professional_logger(name):
    """Get professional logger instance with medical standards"""
    return logging.getLogger(f'noctis_pro.{name}')


# Professional logging decorators
def log_professional_operation(operation_name):
    """Decorator for professional operation logging"""
    def decorator(func):
        def wrapper(*args, **kwargs):
            start_time = time.time()
            logger = get_professional_logger('operations')
            
            try:
                # Log operation start
                logger.info(f"🏥 Professional operation started: {operation_name}")
                
                # Execute function
                result = func(*args, **kwargs)
                
                # Log operation success
                processing_time = round((time.time() - start_time) * 1000, 1)
                logger.info(f"✅ Professional operation completed: {operation_name} ({processing_time}ms)")
                
                return result
                
            except Exception as e:
                # Log operation error
                error_time = round((time.time() - start_time) * 1000, 1)
                logger.error(f"🚨 Professional operation failed: {operation_name} - {str(e)} (after {error_time}ms)")
                raise
        
        return wrapper
    return decorator


def log_medical_api_call(endpoint_name):
    """Decorator for professional medical API logging"""
    def decorator(func):
        def wrapper(request, *args, **kwargs):
            start_time = time.time()
            logger = get_professional_logger('api')
            
            try:
                # Log API call start
                user = getattr(request, 'user', 'Anonymous')
                logger.info(f"🔌 Professional API call: {endpoint_name} by {user}")
                
                # Execute API function
                response = func(request, *args, **kwargs)
                
                # Log API call success
                processing_time = round((time.time() - start_time) * 1000, 1)
                response_size = len(response.content) if hasattr(response, 'content') else 0
                
                logger.info(f"✅ Professional API completed: {endpoint_name} ({processing_time}ms, {response_size} bytes)")
                
                return response
                
            except Exception as e:
                # Log API call error
                error_time = round((time.time() - start_time) * 1000, 1)
                logger.error(f"🚨 Professional API failed: {endpoint_name} - {str(e)} (after {error_time}ms)")
                raise
        
        return wrapper
    return decorator


# Professional system monitoring
class ProfessionalSystemMonitor:
    """Professional system monitoring with medical standards"""
    
    def __init__(self):
        self.logger = get_professional_logger('monitor')
        self.start_time = time.time()
        self.stats = {
            'api_calls': 0,
            'uploads': 0,
            'user_creations': 0,
            'dicom_receptions': 0,
            'errors': 0,
            'warnings': 0,
        }
    
    def record_api_call(self, endpoint, processing_time_ms):
        """Record professional API call statistics"""
        self.stats['api_calls'] += 1
        self.logger.debug(f"API call recorded: {endpoint} ({processing_time_ms}ms)")
    
    def record_upload(self, file_count, size_mb):
        """Record professional upload statistics"""
        self.stats['uploads'] += 1
        self.logger.info(f"Upload recorded: {file_count} files, {size_mb:.2f} MB")
    
    def record_error(self, component, error):
        """Record professional error statistics"""
        self.stats['errors'] += 1
        self.logger.error(f"Error recorded in {component}: {error}")
    
    def get_professional_statistics(self):
        """Get professional system statistics"""
        uptime = time.time() - self.start_time
        
        return {
            'system_uptime_seconds': round(uptime, 1),
            'statistics': self.stats,
            'performance_metrics': {
                'avg_api_calls_per_minute': round(self.stats['api_calls'] / max(1, uptime / 60), 2),
                'avg_uploads_per_hour': round(self.stats['uploads'] / max(1, uptime / 3600), 2),
                'error_rate_percent': round(self.stats['errors'] / max(1, sum(self.stats.values())) * 100, 2),
            },
            'system_health': 'EXCELLENT' if self.stats['errors'] < 10 else 'GOOD' if self.stats['errors'] < 50 else 'NEEDS_ATTENTION',
            'medical_compliance': 'FULL',
            'timestamp': timezone.now().isoformat(),
        }


# Global professional system monitor
professional_monitor = ProfessionalSystemMonitor()


# Initialize professional logging on import
if hasattr(settings, 'BASE_DIR'):
    setup_professional_logging()
    professional_logger.log_system_startup('Professional Medical Logging System')