#!/usr/bin/env python3

"""
DICOM Traffic Sanitization System
Sanitizes DICOM traffic, reports, and chats before reaching the server
Ensures sterile DICOM traffic and removes potentially harmful content
"""

import os
import re
import json
import logging
import hashlib
import asyncio
import aiofiles
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Set, Optional, Tuple, Any
from dataclasses import dataclass, asdict
import sqlite3
import threading
from collections import defaultdict
import pydicom
from pydicom.errors import InvalidDicomError
import socket
import struct
import binascii
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import base64

@dataclass
class DicomSanitizationResult:
    original_size: int
    sanitized_size: int
    removed_tags: List[str]
    risk_score: int
    is_safe: bool
    warnings: List[str]
    patient_id_hash: Optional[str] = None
    study_uid_hash: Optional[str] = None

@dataclass
class TrafficLog:
    timestamp: datetime
    source_ip: str
    destination_ip: str
    port: int
    protocol: str
    data_size: int
    is_dicom: bool
    sanitization_result: Optional[DicomSanitizationResult] = None
    blocked: bool = False
    reason: Optional[str] = None

class DicomSanitizer:
    """Advanced DICOM sanitization with privacy protection"""
    
    def __init__(self, encryption_key: Optional[bytes] = None):
        # DICOM tags that should be removed for privacy
        self.private_tags = {
            0x00100010,  # Patient Name
            0x00100020,  # Patient ID
            0x00100030,  # Patient Birth Date
            0x00100040,  # Patient Sex
            0x00101010,  # Patient Age
            0x00101020,  # Patient Size
            0x00101030,  # Patient Weight
            0x00101040,  # Patient Address
            0x00101060,  # Patient Mother Birth Name
            0x00101090,  # Medical Record Locator
            0x00102160,  # Ethnic Group
            0x00102180,  # Occupation
            0x001021B0,  # Additional Patient History
            0x00104000,  # Patient Comments
            0x00080090,  # Referring Physician Name
            0x00081048,  # Physician(s) of Record
            0x00081050,  # Performing Physician Name
            0x00081060,  # Name of Physician(s) Reading Study
            0x00081070,  # Operators' Name
            0x00180010,  # Contrast/Bolus Agent
            0x00401001,  # Requested Procedure ID
            0x00321032,  # Requesting Physician
            0x00321060,  # Requested Procedure Description
        }
        
        # Potentially dangerous tags that could contain malicious data
        self.dangerous_tags = {
            0x7FE00010,  # Pixel Data (check for embedded content)
            0x00420011,  # Encapsulated Document
            0x00420012,  # MIME Type of Encapsulated Document
            0x00880130,  # Storage Media File-set ID
            0x00880140,  # Storage Media File-set UID
            0x04000500,  # MAC Parameters Sequence
            0x04000550,  # Modified Attributes Sequence
        }
        
        # Setup encryption for sensitive data hashing
        if encryption_key:
            self.cipher = Fernet(encryption_key)
        else:
            self.cipher = None
        
        # Malicious pattern detection
        self.malicious_patterns = [
            rb'<script[^>]*>.*?</script>',
            rb'javascript:',
            rb'vbscript:',
            rb'onload\s*=',
            rb'onerror\s*=',
            rb'eval\s*\(',
            rb'exec\s*\(',
            rb'system\s*\(',
            rb'cmd\s*\.',
            rb'powershell',
            rb'bash\s*-c',
            rb'/bin/sh',
            rb'nc\s+-l',
            rb'netcat',
            rb'wget\s+http',
            rb'curl\s+http',
        ]
        
        self.compiled_patterns = [re.compile(pattern, re.IGNORECASE) for pattern in self.malicious_patterns]
    
    def sanitize_dicom_file(self, file_path: str, output_path: Optional[str] = None) -> DicomSanitizationResult:
        """Sanitize a DICOM file"""
        try:
            # Read DICOM file
            ds = pydicom.dcmread(file_path, force=True)
            original_size = os.path.getsize(file_path)
            
            removed_tags = []
            warnings = []
            risk_score = 0
            
            # Hash patient identifiers before removal
            patient_id_hash = self._hash_identifier(str(ds.get('PatientID', '')))
            study_uid_hash = self._hash_identifier(str(ds.get('StudyInstanceUID', '')))
            
            # Remove private tags
            for tag in list(ds.keys()):
                tag_int = int(tag)
                
                if tag_int in self.private_tags:
                    removed_tags.append(f"0x{tag_int:08X}")
                    del ds[tag]
                elif tag_int in self.dangerous_tags:
                    # Check dangerous tags for malicious content
                    if self._check_tag_for_malicious_content(ds[tag]):
                        removed_tags.append(f"0x{tag_int:08X}")
                        warnings.append(f"Removed potentially malicious tag: 0x{tag_int:08X}")
                        risk_score += 30
                        del ds[tag]
                elif tag.group & 0xFF00 == 0x7F00:  # Private tags
                    removed_tags.append(f"0x{tag_int:08X}")
                    del ds[tag]
            
            # Check pixel data for embedded content
            if 'PixelData' in ds:
                pixel_risk = self._analyze_pixel_data(ds.PixelData)
                risk_score += pixel_risk
                if pixel_risk > 50:
                    warnings.append("Suspicious patterns found in pixel data")
            
            # Add sanitization metadata
            ds.add_new(0x00120010, 'LO', 'SANITIZED')
            ds.add_new(0x00120020, 'DT', datetime.now().strftime('%Y%m%d%H%M%S'))
            
            # Save sanitized file
            if output_path:
                ds.save_as(output_path)
                sanitized_size = os.path.getsize(output_path)
            else:
                # Overwrite original
                ds.save_as(file_path)
                sanitized_size = os.path.getsize(file_path)
            
            is_safe = risk_score < 50
            
            return DicomSanitizationResult(
                original_size=original_size,
                sanitized_size=sanitized_size,
                removed_tags=removed_tags,
                risk_score=risk_score,
                is_safe=is_safe,
                warnings=warnings,
                patient_id_hash=patient_id_hash,
                study_uid_hash=study_uid_hash
            )
            
        except InvalidDicomError:
            raise ValueError("Invalid DICOM file")
        except Exception as e:
            raise RuntimeError(f"Error sanitizing DICOM file: {e}")
    
    def sanitize_dicom_data(self, data: bytes) -> Tuple[bytes, DicomSanitizationResult]:
        """Sanitize DICOM data in memory"""
        try:
            import io
            from pydicom.filebase import DicomBytesIO
            
            # Create a file-like object from bytes
            file_like = DicomBytesIO(data)
            ds = pydicom.dcmread(file_like, force=True)
            
            original_size = len(data)
            removed_tags = []
            warnings = []
            risk_score = 0
            
            # Hash identifiers
            patient_id_hash = self._hash_identifier(str(ds.get('PatientID', '')))
            study_uid_hash = self._hash_identifier(str(ds.get('StudyInstanceUID', '')))
            
            # Sanitize similar to file method
            for tag in list(ds.keys()):
                tag_int = int(tag)
                
                if tag_int in self.private_tags:
                    removed_tags.append(f"0x{tag_int:08X}")
                    del ds[tag]
                elif tag_int in self.dangerous_tags:
                    if self._check_tag_for_malicious_content(ds[tag]):
                        removed_tags.append(f"0x{tag_int:08X}")
                        warnings.append(f"Removed potentially malicious tag: 0x{tag_int:08X}")
                        risk_score += 30
                        del ds[tag]
                elif tag.group & 0xFF00 == 0x7F00:
                    removed_tags.append(f"0x{tag_int:08X}")
                    del ds[tag]
            
            # Check pixel data
            if 'PixelData' in ds:
                pixel_risk = self._analyze_pixel_data(ds.PixelData)
                risk_score += pixel_risk
                if pixel_risk > 50:
                    warnings.append("Suspicious patterns found in pixel data")
            
            # Add sanitization metadata
            ds.add_new(0x00120010, 'LO', 'SANITIZED')
            ds.add_new(0x00120020, 'DT', datetime.now().strftime('%Y%m%d%H%M%S'))
            
            # Convert back to bytes
            output_buffer = io.BytesIO()
            ds.save_as(output_buffer)
            sanitized_data = output_buffer.getvalue()
            sanitized_size = len(sanitized_data)
            
            is_safe = risk_score < 50
            
            result = DicomSanitizationResult(
                original_size=original_size,
                sanitized_size=sanitized_size,
                removed_tags=removed_tags,
                risk_score=risk_score,
                is_safe=is_safe,
                warnings=warnings,
                patient_id_hash=patient_id_hash,
                study_uid_hash=study_uid_hash
            )
            
            return sanitized_data, result
            
        except Exception as e:
            raise RuntimeError(f"Error sanitizing DICOM data: {e}")
    
    def _hash_identifier(self, identifier: str) -> str:
        """Create a secure hash of an identifier"""
        if not identifier:
            return ""
        
        # Use SHA-256 for hashing
        hash_obj = hashlib.sha256()
        hash_obj.update(identifier.encode('utf-8'))
        return hash_obj.hexdigest()[:16]  # First 16 chars
    
    def _check_tag_for_malicious_content(self, tag_value) -> bool:
        """Check if a DICOM tag contains malicious content"""
        try:
            # Convert tag value to bytes for pattern matching
            if hasattr(tag_value, 'value'):
                data = str(tag_value.value).encode('utf-8', errors='ignore')
            else:
                data = str(tag_value).encode('utf-8', errors='ignore')
            
            # Check for malicious patterns
            for pattern in self.compiled_patterns:
                if pattern.search(data):
                    return True
            
            return False
            
        except Exception:
            return False
    
    def _analyze_pixel_data(self, pixel_data) -> int:
        """Analyze pixel data for suspicious content"""
        risk_score = 0
        
        try:
            # Convert to bytes if necessary
            if hasattr(pixel_data, 'tobytes'):
                data = pixel_data.tobytes()
            else:
                data = bytes(pixel_data)
            
            # Check for embedded executable signatures
            exe_signatures = [
                b'MZ',  # DOS/Windows executable
                b'\x7fELF',  # Linux executable
                b'\xfe\xed\xfa',  # Mach-O (macOS)
                b'PK\x03\x04',  # ZIP file
                b'\x1f\x8b\x08',  # GZIP
                b'Rar!',  # RAR archive
            ]
            
            for signature in exe_signatures:
                if signature in data:
                    risk_score += 40
            
            # Check for script patterns in pixel data
            for pattern in self.compiled_patterns:
                if pattern.search(data):
                    risk_score += 20
            
            # Check for unusual entropy (could indicate encrypted/compressed data)
            entropy = self._calculate_entropy(data[:1024])  # Check first 1KB
            if entropy > 7.5:  # High entropy might indicate encrypted data
                risk_score += 10
            
        except Exception:
            risk_score += 5  # Small penalty for processing errors
        
        return min(risk_score, 100)
    
    def _calculate_entropy(self, data: bytes) -> float:
        """Calculate Shannon entropy of data"""
        if not data:
            return 0
        
        # Count byte frequencies
        frequencies = defaultdict(int)
        for byte in data:
            frequencies[byte] += 1
        
        # Calculate entropy
        entropy = 0
        length = len(data)
        for count in frequencies.values():
            if count > 0:
                probability = count / length
                entropy -= probability * (probability.bit_length() - 1)
        
        return entropy

class TrafficInterceptor:
    """Intercept and sanitize DICOM network traffic"""
    
    def __init__(self, listen_port: int = 11112, target_host: str = "localhost", target_port: int = 11113):
        self.listen_port = listen_port
        self.target_host = target_host
        self.target_port = target_port
        self.sanitizer = DicomSanitizer()
        self.traffic_logs = []
        self.running = False
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('/var/log/dicom_traffic_sanitizer.log'),
                logging.StreamHandler()
            ]
        )
    
    async def start_proxy(self):
        """Start the DICOM proxy server"""
        self.running = True
        server = await asyncio.start_server(
            self.handle_client,
            '0.0.0.0',
            self.listen_port
        )
        
        logging.info(f"DICOM proxy started on port {self.listen_port}")
        logging.info(f"Forwarding to {self.target_host}:{self.target_port}")
        
        async with server:
            await server.serve_forever()
    
    async def handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        """Handle incoming DICOM connection"""
        client_addr = writer.get_extra_info('peername')
        logging.info(f"New DICOM connection from {client_addr}")
        
        try:
            # Connect to target server
            target_reader, target_writer = await asyncio.open_connection(
                self.target_host, self.target_port
            )
            
            # Start bidirectional data forwarding
            await asyncio.gather(
                self.forward_data(reader, target_writer, client_addr, "client->server"),
                self.forward_data(target_reader, writer, client_addr, "server->client"),
                return_exceptions=True
            )
            
        except Exception as e:
            logging.error(f"Error handling client {client_addr}: {e}")
        finally:
            writer.close()
            await writer.wait_closed()
    
    async def forward_data(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter, 
                          client_addr: Tuple[str, int], direction: str):
        """Forward data between client and server with sanitization"""
        try:
            while self.running:
                data = await reader.read(8192)
                if not data:
                    break
                
                # Log traffic
                traffic_log = TrafficLog(
                    timestamp=datetime.now(),
                    source_ip=client_addr[0],
                    destination_ip=self.target_host,
                    port=self.target_port,
                    protocol="DICOM",
                    data_size=len(data),
                    is_dicom=self.is_dicom_data(data)
                )
                
                # Sanitize DICOM data
                if traffic_log.is_dicom and direction == "client->server":
                    try:
                        sanitized_data, sanitization_result = self.sanitizer.sanitize_dicom_data(data)
                        traffic_log.sanitization_result = sanitization_result
                        
                        if not sanitization_result.is_safe:
                            traffic_log.blocked = True
                            traffic_log.reason = f"High risk score: {sanitization_result.risk_score}"
                            logging.warning(f"Blocked DICOM data from {client_addr}: {traffic_log.reason}")
                            continue
                        
                        data = sanitized_data
                        logging.info(f"Sanitized DICOM data from {client_addr}: "
                                   f"removed {len(sanitization_result.removed_tags)} tags")
                        
                    except Exception as e:
                        traffic_log.blocked = True
                        traffic_log.reason = f"Sanitization error: {e}"
                        logging.error(f"Error sanitizing DICOM data from {client_addr}: {e}")
                        continue
                
                # Forward sanitized data
                writer.write(data)
                await writer.drain()
                
                self.traffic_logs.append(traffic_log)
                
        except Exception as e:
            logging.error(f"Error in data forwarding ({direction}): {e}")
    
    def is_dicom_data(self, data: bytes) -> bool:
        """Check if data appears to be DICOM format"""
        try:
            # DICOM files start with a 128-byte preamble followed by "DICM"
            if len(data) > 132 and data[128:132] == b'DICM':
                return True
            
            # Check for DICOM network protocol patterns
            # DICOM network messages have specific structure
            if len(data) >= 6:
                # Check for DICOM network PDU types
                pdu_types = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]
                if data[0] in pdu_types:
                    return True
            
            return False
            
        except Exception:
            return False
    
    def stop(self):
        """Stop the proxy server"""
        self.running = False
        logging.info("DICOM proxy stopping...")
    
    def get_traffic_summary(self, hours: int = 24) -> Dict:
        """Get traffic summary for the last N hours"""
        since = datetime.now() - timedelta(hours=hours)
        recent_logs = [log for log in self.traffic_logs if log.timestamp > since]
        
        dicom_logs = [log for log in recent_logs if log.is_dicom]
        blocked_logs = [log for log in recent_logs if log.blocked]
        
        return {
            'period_hours': hours,
            'total_connections': len(recent_logs),
            'dicom_connections': len(dicom_logs),
            'blocked_connections': len(blocked_logs),
            'total_data_mb': sum(log.data_size for log in recent_logs) / (1024 * 1024),
            'sanitized_data_mb': sum(
                log.sanitization_result.sanitized_size if log.sanitization_result else 0
                for log in dicom_logs
            ) / (1024 * 1024)
        }

class ReportChatSanitizer:
    """Sanitize reports and chat messages"""
    
    def __init__(self):
        # Patterns for sensitive information
        self.pii_patterns = [
            (r'\b\d{3}-\d{2}-\d{4}\b', 'SSN'),  # Social Security Numbers
            (r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b', 'CREDIT_CARD'),  # Credit cards
            (r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', 'EMAIL'),  # Email addresses
            (r'\b\d{3}[\s.-]?\d{3}[\s.-]?\d{4}\b', 'PHONE'),  # Phone numbers
            (r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', 'IP_ADDRESS'),  # IP addresses
        ]
        
        # Malicious patterns
        self.malicious_patterns = [
            (r'<script[^>]*>.*?</script>', 'XSS_SCRIPT'),
            (r'javascript\s*:', 'JAVASCRIPT_PROTOCOL'),
            (r'on\w+\s*=', 'EVENT_HANDLER'),
            (r'(eval|exec|system|shell_exec)\s*\(', 'CODE_INJECTION'),
            (r'(union\s+select|select\s+.*\s+from)', 'SQL_INJECTION'),
            (r'(\.\./|\.\.\\)', 'PATH_TRAVERSAL'),
        ]
        
        self.compiled_pii = [(re.compile(pattern, re.IGNORECASE), label) for pattern, label in self.pii_patterns]
        self.compiled_malicious = [(re.compile(pattern, re.IGNORECASE), label) for pattern, label in self.malicious_patterns]
    
    def sanitize_text(self, text: str, preserve_structure: bool = True) -> Dict[str, Any]:
        """Sanitize text content"""
        original_text = text
        sanitized_text = text
        removed_items = []
        risk_score = 0
        
        # Remove PII
        for pattern, label in self.compiled_pii:
            matches = pattern.findall(sanitized_text)
            if matches:
                if preserve_structure:
                    # Replace with placeholder
                    sanitized_text = pattern.sub(f'[{label}_REDACTED]', sanitized_text)
                else:
                    # Remove completely
                    sanitized_text = pattern.sub('', sanitized_text)
                
                removed_items.extend([(match, label) for match in matches])
                risk_score += len(matches) * 10
        
        # Remove malicious content
        for pattern, label in self.compiled_malicious:
            matches = pattern.findall(sanitized_text)
            if matches:
                sanitized_text = pattern.sub('[MALICIOUS_CONTENT_REMOVED]', sanitized_text)
                removed_items.extend([(match, label) for match in matches])
                risk_score += len(matches) * 30
        
        # Additional sanitization
        sanitized_text = self._additional_sanitization(sanitized_text)
        
        return {
            'original_length': len(original_text),
            'sanitized_length': len(sanitized_text),
            'sanitized_text': sanitized_text,
            'removed_items': removed_items,
            'risk_score': min(risk_score, 100),
            'is_safe': risk_score < 50
        }
    
    def _additional_sanitization(self, text: str) -> str:
        """Additional sanitization steps"""
        # Remove excessive whitespace
        text = re.sub(r'\s+', ' ', text)
        
        # Remove null bytes and control characters
        text = re.sub(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '', text)
        
        # Normalize line endings
        text = text.replace('\r\n', '\n').replace('\r', '\n')
        
        return text.strip()
    
    def sanitize_json_report(self, json_data: Dict) -> Dict[str, Any]:
        """Sanitize JSON report data"""
        sanitized_data = {}
        total_risk_score = 0
        all_removed_items = []
        
        def sanitize_recursive(obj, path=""):
            nonlocal total_risk_score, all_removed_items
            
            if isinstance(obj, dict):
                sanitized_obj = {}
                for key, value in obj.items():
                    new_path = f"{path}.{key}" if path else key
                    sanitized_obj[key] = sanitize_recursive(value, new_path)
                return sanitized_obj
            
            elif isinstance(obj, list):
                return [sanitize_recursive(item, f"{path}[{i}]") for i, item in enumerate(obj)]
            
            elif isinstance(obj, str):
                result = self.sanitize_text(obj)
                total_risk_score += result['risk_score']
                all_removed_items.extend([(item, label, path) for item, label in result['removed_items']])
                return result['sanitized_text']
            
            else:
                return obj
        
        sanitized_data = sanitize_recursive(json_data)
        
        return {
            'sanitized_data': sanitized_data,
            'total_risk_score': min(total_risk_score, 100),
            'removed_items': all_removed_items,
            'is_safe': total_risk_score < 50
        }

class DicomTrafficSanitizationSystem:
    """Main system orchestrator"""
    
    def __init__(self, config_path: str = "/etc/dicom_sanitizer_config.json"):
        self.config = self._load_config(config_path)
        self.traffic_interceptor = TrafficInterceptor(
            listen_port=self.config.get('proxy_port', 11112),
            target_host=self.config.get('target_host', 'localhost'),
            target_port=self.config.get('target_port', 11113)
        )
        self.report_sanitizer = ReportChatSanitizer()
        self.db_path = self.config.get('database_path', '/var/log/dicom_sanitizer.db')
        self._init_database()
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('/var/log/dicom_sanitization_system.log'),
                logging.StreamHandler()
            ]
        )
    
    def _load_config(self, config_path: str) -> Dict:
        """Load configuration"""
        default_config = {
            "proxy_port": 11112,
            "target_host": "localhost",
            "target_port": 11113,
            "database_path": "/var/log/dicom_sanitizer.db",
            "enable_proxy": True,
            "log_retention_days": 30,
            "max_file_size_mb": 100
        }
        
        try:
            with open(config_path, 'r') as f:
                config = json.load(f)
                default_config.update(config)
                return default_config
        except FileNotFoundError:
            logging.info(f"Config file {config_path} not found, using defaults")
            return default_config
        except json.JSONDecodeError as e:
            logging.error(f"Error parsing config file: {e}")
            return default_config
    
    def _init_database(self):
        """Initialize SQLite database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS sanitization_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                operation_type TEXT NOT NULL,
                source_info TEXT,
                original_size INTEGER,
                sanitized_size INTEGER,
                risk_score INTEGER,
                removed_items TEXT,
                is_safe BOOLEAN,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        conn.commit()
        conn.close()
    
    async def start_system(self):
        """Start the complete sanitization system"""
        logging.info("Starting DICOM Traffic Sanitization System")
        
        tasks = []
        
        # Start DICOM proxy if enabled
        if self.config.get('enable_proxy', True):
            tasks.append(asyncio.create_task(self.traffic_interceptor.start_proxy()))
        
        # Start periodic cleanup
        tasks.append(asyncio.create_task(self._periodic_cleanup()))
        
        try:
            await asyncio.gather(*tasks)
        except KeyboardInterrupt:
            logging.info("Shutting down system...")
            self.traffic_interceptor.stop()
    
    async def _periodic_cleanup(self):
        """Periodic cleanup of old logs"""
        while True:
            try:
                await asyncio.sleep(3600)  # Run every hour
                self._cleanup_old_logs()
            except Exception as e:
                logging.error(f"Error in periodic cleanup: {e}")
    
    def _cleanup_old_logs(self):
        """Clean up old log entries"""
        retention_days = self.config.get('log_retention_days', 30)
        cutoff_date = (datetime.now() - timedelta(days=retention_days)).isoformat()
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("DELETE FROM sanitization_logs WHERE timestamp < ?", (cutoff_date,))
        deleted_count = cursor.rowcount
        
        conn.commit()
        conn.close()
        
        logging.info(f"Cleaned up {deleted_count} old log entries")
    
    def sanitize_file(self, file_path: str, output_path: Optional[str] = None) -> Dict:
        """Sanitize a single file"""
        try:
            if file_path.lower().endswith('.dcm') or self._is_dicom_file(file_path):
                # DICOM file
                sanitizer = DicomSanitizer()
                result = sanitizer.sanitize_dicom_file(file_path, output_path)
                
                # Log to database
                self._log_sanitization('dicom_file', file_path, result.__dict__)
                
                return {
                    'type': 'dicom',
                    'result': asdict(result)
                }
            
            else:
                # Regular file - treat as text/report
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                
                result = self.report_sanitizer.sanitize_text(content)
                
                if output_path:
                    with open(output_path, 'w', encoding='utf-8') as f:
                        f.write(result['sanitized_text'])
                
                # Log to database
                self._log_sanitization('text_file', file_path, result)
                
                return {
                    'type': 'text',
                    'result': result
                }
                
        except Exception as e:
            logging.error(f"Error sanitizing file {file_path}: {e}")
            return {
                'type': 'error',
                'error': str(e)
            }
    
    def _is_dicom_file(self, file_path: str) -> bool:
        """Check if file is a DICOM file"""
        try:
            with open(file_path, 'rb') as f:
                # Read first 132 bytes
                header = f.read(132)
                if len(header) >= 132 and header[128:132] == b'DICM':
                    return True
            return False
        except Exception:
            return False
    
    def _log_sanitization(self, operation_type: str, source_info: str, result_data: Dict):
        """Log sanitization operation to database"""
        try:
            conn = sqlite3.connect(self.db_path)
            cursor = conn.cursor()
            
            cursor.execute("""
                INSERT INTO sanitization_logs 
                (timestamp, operation_type, source_info, original_size, sanitized_size, 
                 risk_score, removed_items, is_safe)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                datetime.now().isoformat(),
                operation_type,
                source_info,
                result_data.get('original_size', result_data.get('original_length', 0)),
                result_data.get('sanitized_size', result_data.get('sanitized_length', 0)),
                result_data.get('risk_score', 0),
                json.dumps(result_data.get('removed_items', [])),
                result_data.get('is_safe', True)
            ))
            
            conn.commit()
            conn.close()
            
        except Exception as e:
            logging.error(f"Error logging sanitization: {e}")
    
    def get_system_status(self) -> Dict:
        """Get system status and statistics"""
        traffic_summary = self.traffic_interceptor.get_traffic_summary()
        
        # Get database statistics
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT operation_type, COUNT(*), AVG(risk_score), SUM(CASE WHEN is_safe = 0 THEN 1 ELSE 0 END)
            FROM sanitization_logs 
            WHERE timestamp > datetime('now', '-24 hours')
            GROUP BY operation_type
        """)
        
        db_stats = cursor.fetchall()
        conn.close()
        
        return {
            'timestamp': datetime.now().isoformat(),
            'traffic_summary': traffic_summary,
            'sanitization_stats': [
                {
                    'type': row[0],
                    'count': row[1],
                    'avg_risk_score': round(row[2] or 0, 2),
                    'unsafe_count': row[3]
                }
                for row in db_stats
            ],
            'system_config': self.config
        }

async def main():
    """Main function"""
    import argparse
    
    parser = argparse.ArgumentParser(description='DICOM Traffic Sanitization System')
    parser.add_argument('--config', default='/etc/dicom_sanitizer_config.json', help='Configuration file')
    parser.add_argument('--start-proxy', action='store_true', help='Start DICOM proxy server')
    parser.add_argument('--sanitize-file', help='Sanitize a single file')
    parser.add_argument('--output-file', help='Output file path for sanitization')
    parser.add_argument('--status', action='store_true', help='Show system status')
    
    args = parser.parse_args()
    
    system = DicomTrafficSanitizationSystem(args.config)
    
    try:
        if args.sanitize_file:
            result = system.sanitize_file(args.sanitize_file, args.output_file)
            print(json.dumps(result, indent=2))
        
        elif args.status:
            status = system.get_system_status()
            print(json.dumps(status, indent=2))
        
        elif args.start_proxy:
            await system.start_system()
        
        else:
            print("No action specified. Use --help for usage information.")
    
    except Exception as e:
        logging.error(f"Error in main: {e}")
        raise

if __name__ == "__main__":
    asyncio.run(main())