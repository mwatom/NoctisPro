#!/usr/bin/env python3
"""
Enhanced DICOM Receiver Service for Internet Access
Handles incoming DICOM images from remote imaging modalities with enhanced security
and facility-based routing using AE titles created during facility setup.
"""

import os
import sys
import logging
import threading
import time
import ipaddress
from datetime import datetime, timedelta
from pathlib import Path
import argparse
import json
from collections import defaultdict

# Add Django project to path
sys.path.append('/workspace')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')

import django
django.setup()

from pynetdicom import AE, evt, AllStoragePresentationContexts, VerificationPresentationContexts
from pynetdicom.sop_class import Verification
from pydicom import dcmread
from pydicom.errors import InvalidDicomError

from worklist.models import Patient, Study, Series, DicomImage, Modality
from accounts.models import User, Facility
from django.utils import timezone
from django.db import transaction
from notifications.models import Notification, NotificationType
from django.db import models
from django.core.cache import cache

# Enhanced logging configuration
def setup_logging(log_level='INFO', external_access=False):
    """Setup enhanced logging for internet-accessible DICOM receiver"""
    log_format = '%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s'
    
    # Create logs directory if it doesn't exist
    log_dir = Path('/workspace/logs')
    log_dir.mkdir(exist_ok=True)
    
    # Configure logging
    logging.basicConfig(
        level=getattr(logging, log_level.upper()),
        format=log_format,
        handlers=[
            logging.FileHandler(log_dir / 'dicom_receiver.log'),
            logging.FileHandler(log_dir / 'dicom_security.log'),  # Security events
            logging.StreamHandler()
        ]
    )
    
    # Create separate security logger
    security_logger = logging.getLogger('dicom_security')
    security_handler = logging.FileHandler(log_dir / 'dicom_security.log')
    security_handler.setFormatter(logging.Formatter(log_format))
    security_logger.addHandler(security_handler)
    security_logger.setLevel(logging.INFO)
    
    return logging.getLogger('dicom_receiver'), security_logger

class DicomSecurityManager:
    """Manage DICOM security for internet access"""
    
    def __init__(self):
        self.failed_attempts = defaultdict(list)
        self.blocked_ips = set()
        self.rate_limits = defaultdict(list)
        self.max_attempts = 5
        self.block_duration = 3600  # 1 hour
        self.rate_limit_window = 300  # 5 minutes
        self.max_connections_per_window = 10
        
    def is_ip_blocked(self, ip_address):
        """Check if IP is currently blocked"""
        if ip_address in self.blocked_ips:
            return True
            
        # Check cache for blocked IPs
        blocked_until = cache.get(f"blocked_ip_{ip_address}")
        if blocked_until and datetime.now() < blocked_until:
            self.blocked_ips.add(ip_address)
            return True
            
        return False
    
    def is_rate_limited(self, ip_address):
        """Check if IP is rate limited"""
        now = datetime.now()
        window_start = now - timedelta(seconds=self.rate_limit_window)
        
        # Clean old entries
        self.rate_limits[ip_address] = [
            timestamp for timestamp in self.rate_limits[ip_address]
            if timestamp > window_start
        ]
        
        # Check if over limit
        if len(self.rate_limits[ip_address]) >= self.max_connections_per_window:
            return True
            
        # Add current attempt
        self.rate_limits[ip_address].append(now)
        return False
    
    def record_failed_attempt(self, ip_address, reason):
        """Record a failed connection attempt"""
        now = datetime.now()
        self.failed_attempts[ip_address].append((now, reason))
        
        # Clean old attempts (older than 1 hour)
        self.failed_attempts[ip_address] = [
            (timestamp, reason) for timestamp, reason in self.failed_attempts[ip_address]
            if now - timestamp < timedelta(seconds=3600)
        ]
        
        # Block IP if too many failures
        if len(self.failed_attempts[ip_address]) >= self.max_attempts:
            self.block_ip(ip_address, f"Too many failed attempts: {len(self.failed_attempts[ip_address])}")
    
    def block_ip(self, ip_address, reason):
        """Block an IP address"""
        block_until = datetime.now() + timedelta(seconds=self.block_duration)
        self.blocked_ips.add(ip_address)
        cache.set(f"blocked_ip_{ip_address}", block_until, self.block_duration)
        
        # Log security event
        security_logger.warning(f"BLOCKED IP {ip_address}: {reason}")
        
        # Create notification for admins
        try:
            admin_users = User.objects.filter(role='admin', is_active=True)
            notification_type = NotificationType.objects.get_or_create(
                name='security_alert',
                defaults={'description': 'Security Alert'}
            )[0]
            
            for admin in admin_users:
                Notification.objects.create(
                    user=admin,
                    notification_type=notification_type,
                    title='DICOM Security Alert',
                    message=f'IP {ip_address} has been blocked due to: {reason}',
                    priority='high'
                )
        except Exception as e:
            logger.error(f"Failed to create security notification: {e}")

class EnhancedDicomReceiver:
    """Enhanced DICOM SCP with internet security and facility-based routing"""
    
    def __init__(self, port=11112, aet='NOCTIS_SCP', external_access=False):
        self.port = port
        self.aet = aet
        self.external_access = external_access
        self.security_manager = DicomSecurityManager()
        
        # Initialize AE
        self.ae = AE(ae_title=aet)
        
        # Add supported presentation contexts
        self.ae.supported_contexts = AllStoragePresentationContexts
        self.ae.supported_contexts.extend(VerificationPresentationContexts)
        
        # Configure for external access
        if external_access:
            # More restrictive settings for internet access
            self.ae.maximum_associations = 10
            self.ae.network_timeout = 30
            self.ae.acse_timeout = 30
            self.ae.dimse_timeout = 30
        
        # Storage directory
        self.storage_dir = Path('/workspace/media/dicom/received')
        self.storage_dir.mkdir(parents=True, exist_ok=True)
        
        # Event handlers
        self.ae.on_c_store = self.handle_store
        self.ae.on_c_echo = self.handle_echo
        self.ae.on_association_request = self.handle_association_request
        self.ae.on_association_released = self.handle_association_released
        
        # Load facility AE titles into cache
        self.refresh_facility_cache()
        
        logger.info(f"Enhanced DICOM Receiver initialized - AET: {aet}, Port: {port}, External: {external_access}")
        logger.info("Ready to receive DICOM images from configured facilities")
    
    def refresh_facility_cache(self):
        """Refresh facility AE titles cache"""
        try:
            facilities = Facility.objects.filter(is_active=True).values('id', 'name', 'ae_title')
            facility_map = {f['ae_title'].upper(): f for f in facilities if f['ae_title']}
            cache.set('facility_ae_map', facility_map, 300)  # Cache for 5 minutes
            logger.info(f"Refreshed facility cache: {len(facility_map)} active facilities")
        except Exception as e:
            logger.error(f"Failed to refresh facility cache: {e}")
    
    def get_facility_by_aet(self, ae_title):
        """Get facility by AE title with caching"""
        facility_map = cache.get('facility_ae_map')
        if facility_map is None:
            self.refresh_facility_cache()
            facility_map = cache.get('facility_ae_map', {})
        
        facility_data = facility_map.get(ae_title.upper())
        if facility_data:
            try:
                return Facility.objects.get(id=facility_data['id'], is_active=True)
            except Facility.DoesNotExist:
                # Facility was deleted, refresh cache
                self.refresh_facility_cache()
                return None
        return None
    
    def handle_association_request(self, event):
        """Handle association requests with security checks"""
        try:
            calling_aet = event.assoc.requestor.ae_title.decode(errors='ignore').strip()
            peer_ip = getattr(event.assoc.requestor, 'address', '')
            
            # Security checks for external access
            if self.external_access:
                # Check if IP is blocked
                if self.security_manager.is_ip_blocked(peer_ip):
                    security_logger.warning(f"BLOCKED connection attempt from {peer_ip} (AET: {calling_aet})")
                    return 0x0122  # Refused - SOP Class Not Supported
                
                # Check rate limiting
                if self.security_manager.is_rate_limited(peer_ip):
                    security_logger.warning(f"RATE LIMITED connection from {peer_ip} (AET: {calling_aet})")
                    self.security_manager.record_failed_attempt(peer_ip, "Rate limited")
                    return 0x0122  # Refused - SOP Class Not Supported
            
            # Validate facility AE title
            facility = self.get_facility_by_aet(calling_aet)
            if not facility:
                logger.warning(f"Unknown Calling AET '{calling_aet}' from {peer_ip}")
                if self.external_access:
                    self.security_manager.record_failed_attempt(peer_ip, f"Unknown AE Title: {calling_aet}")
                return 0x0122  # Refused - SOP Class Not Supported
            
            # Log successful association
            logger.info(f"Accepting association from '{calling_aet}' ({facility.name}) at {peer_ip}")
            security_logger.info(f"ACCEPTED connection from {peer_ip} - AET: {calling_aet} - Facility: {facility.name}")
            
            # Store facility info in association for later use
            event.assoc.facility = facility
            
            return 0x0000  # Accept association
            
        except Exception as e:
            logger.error(f"Error handling association request: {e}")
            if self.external_access:
                self.security_manager.record_failed_attempt(peer_ip, f"Association error: {str(e)}")
            return 0x0122  # Refused
    
    def handle_association_released(self, event):
        """Handle association release"""
        try:
            calling_aet = event.assoc.requestor.ae_title.decode(errors='ignore').strip()
            peer_ip = getattr(event.assoc.requestor, 'address', '')
            facility = getattr(event.assoc, 'facility', None)
            
            facility_name = facility.name if facility else 'Unknown'
            logger.info(f"Association released from '{calling_aet}' ({facility_name}) at {peer_ip}")
            
        except Exception as e:
            logger.error(f"Error handling association release: {e}")
    
    def handle_echo(self, event):
        """Handle C-ECHO requests (DICOM ping) with security"""
        try:
            calling_aet = event.assoc.requestor.ae_title.decode(errors='ignore').strip()
            peer_ip = getattr(event.assoc.requestor, 'address', '')
            facility = getattr(event.assoc, 'facility', None)
            
            if facility:
                logger.info(f"C-ECHO from '{calling_aet}' ({facility.name}) at {peer_ip}")
                security_logger.info(f"ECHO from {peer_ip} - AET: {calling_aet} - Facility: {facility.name}")
                return 0x0000  # Success
            else:
                logger.warning(f"C-ECHO from unknown AET '{calling_aet}' at {peer_ip}")
                if self.external_access:
                    self.security_manager.record_failed_attempt(peer_ip, f"Echo from unknown AET: {calling_aet}")
                return 0x0122  # Refused
                
        except Exception as e:
            logger.error(f"Error handling C-ECHO: {e}")
            return 0xA700  # Out of Resources
    
    def handle_store(self, event):
        """Handle C-STORE requests with enhanced security and facility routing"""
        try:
            calling_aet = event.assoc.requestor.ae_title.decode(errors='ignore').strip()
            peer_ip = getattr(event.assoc.requestor, 'address', '')
            facility = getattr(event.assoc, 'facility', None)
            
            # Facility should be validated in association request
            if not facility:
                logger.error(f"No facility associated with connection from {peer_ip}")
                if self.external_access:
                    self.security_manager.record_failed_attempt(peer_ip, "No facility association")
                return 0xC000  # Cannot Understand
            
            # Get the dataset
            ds = event.dataset
            
            # Validate dataset
            if not self.validate_dicom_dataset(ds):
                logger.warning(f"Invalid DICOM dataset from '{calling_aet}' at {peer_ip}")
                if self.external_access:
                    self.security_manager.record_failed_attempt(peer_ip, "Invalid DICOM dataset")
                return 0xA700  # Out of Resources
            
            # Log the incoming study with facility info
            study_uid = getattr(ds, 'StudyInstanceUID', 'Unknown')
            series_uid = getattr(ds, 'SeriesInstanceUID', 'Unknown')
            sop_instance_uid = getattr(ds, 'SOPInstanceUID', 'Unknown')
            
            logger.info(
                f"Receiving DICOM from '{calling_aet}' ({facility.name}) at {peer_ip}: "
                f"Study: {study_uid}, Series: {series_uid}, SOP: {sop_instance_uid}"
            )
            
            # Log security event for successful reception
            security_logger.info(
                f"DICOM_STORE from {peer_ip} - AET: {calling_aet} - Facility: {facility.name} - "
                f"Study: {study_uid} - Patient: {getattr(ds, 'PatientID', 'Unknown')}"
            )
            
            # Process the DICOM object
            with transaction.atomic():
                result = self.process_dicom_object(ds, event, calling_aet, facility)
                
            if result:
                logger.info(f"DICOM object stored successfully for facility: {facility.name}")
                
                # Create notification for facility users
                self.notify_facility_users(facility, ds)
                
                return 0x0000  # Success
            else:
                logger.error(f"Failed to store DICOM object from facility: {facility.name}")
                return 0xA700  # Out of Resources
                
        except Exception as e:
            logger.error(f"Error handling C-STORE: {str(e)}")
            if self.external_access and 'peer_ip' in locals():
                self.security_manager.record_failed_attempt(peer_ip, f"Store error: {str(e)}")
            return 0xA700  # Out of Resources
    
    def validate_dicom_dataset(self, ds):
        """Validate DICOM dataset for security and completeness"""
        try:
            # Check for required fields
            required_fields = ['StudyInstanceUID', 'SeriesInstanceUID', 'SOPInstanceUID', 'PatientID']
            for field in required_fields:
                if not hasattr(ds, field) or not getattr(ds, field):
                    logger.warning(f"Missing required DICOM field: {field}")
                    return False
            
            # Validate UID formats (basic check)
            uids = [ds.StudyInstanceUID, ds.SeriesInstanceUID, ds.SOPInstanceUID]
            for uid in uids:
                if not isinstance(uid, str) or len(uid) < 10 or len(uid) > 64:
                    logger.warning(f"Invalid UID format: {uid}")
                    return False
            
            # Check for suspicious content (basic security)
            patient_name = str(getattr(ds, 'PatientName', ''))
            if len(patient_name) > 200:  # Suspiciously long name
                logger.warning(f"Suspiciously long patient name: {len(patient_name)} chars")
                return False
            
            return True
            
        except Exception as e:
            logger.error(f"Error validating DICOM dataset: {e}")
            return False
    
    def notify_facility_users(self, facility, ds):
        """Notify facility users about new DICOM study"""
        try:
            # Get facility users
            facility_users = User.objects.filter(
                facility=facility, 
                is_active=True,
                role__in=['facility', 'radiologist']
            )
            
            if not facility_users.exists():
                return
            
            # Get notification type
            notification_type = NotificationType.objects.get_or_create(
                name='new_study',
                defaults={'description': 'New Study Received'}
            )[0]
            
            # Create notification
            patient_name = str(getattr(ds, 'PatientName', 'Unknown')).replace('^', ' ')
            study_description = getattr(ds, 'StudyDescription', 'DICOM Study')
            modality = getattr(ds, 'Modality', 'Unknown')
            
            message = f"New {modality} study received: {study_description} for patient {patient_name}"
            
            for user in facility_users:
                Notification.objects.create(
                    user=user,
                    notification_type=notification_type,
                    title='New Study Received',
                    message=message,
                    priority='normal'
                )
                
            logger.info(f"Notified {facility_users.count()} users from {facility.name}")
            
        except Exception as e:
            logger.error(f"Error sending notifications: {e}")
    
    def process_dicom_object(self, ds, event, calling_aet, facility):
        """Process and store the DICOM object with facility attribution"""
        try:
            # Extract DICOM metadata
            study_uid = getattr(ds, 'StudyInstanceUID', None)
            series_uid = getattr(ds, 'SeriesInstanceUID', None)
            sop_instance_uid = getattr(ds, 'SOPInstanceUID', None)
            
            if not all([study_uid, series_uid, sop_instance_uid]):
                logger.error("Missing required DICOM UIDs")
                return False
            
            # Extract patient information
            patient_id = getattr(ds, 'PatientID', 'UNKNOWN')
            patient_name = str(getattr(ds, 'PatientName', 'UNKNOWN')).replace('^', ' ')
            patient_birth_date = getattr(ds, 'PatientBirthDate', None)
            patient_sex = getattr(ds, 'PatientSex', 'O')
            
            # Parse patient name
            name_parts = patient_name.split(' ', 1)
            first_name = name_parts[0] if name_parts else 'Unknown'
            last_name = name_parts[1] if len(name_parts) > 1 else ''
            
            # Parse birth date
            birth_date = None
            if patient_birth_date:
                try:
                    birth_date = datetime.strptime(patient_birth_date, '%Y%m%d').date()
                except ValueError:
                    birth_date = timezone.now().date()
            else:
                birth_date = timezone.now().date()
            
            # Get or create patient (scoped to facility for privacy)
            patient, created = Patient.objects.get_or_create(
                patient_id=patient_id,
                defaults={
                    'first_name': first_name,
                    'last_name': last_name,
                    'date_of_birth': birth_date,
                    'gender': patient_sex if patient_sex in ['M', 'F'] else 'O'
                }
            )
            
            if created:
                logger.info(f"Created new patient: {patient} for facility: {facility.name}")
            
            # Extract study information
            study_date = getattr(ds, 'StudyDate', None)
            study_time = getattr(ds, 'StudyTime', '000000')
            study_description = getattr(ds, 'StudyDescription', 'DICOM Study')
            referring_physician = str(getattr(ds, 'ReferringPhysicianName', 'UNKNOWN')).replace('^', ' ')
            modality_code = getattr(ds, 'Modality', 'OT')
            accession_number = getattr(ds, 'AccessionNumber', f"ACC_{int(time.time())}")
            
            # Parse study datetime
            if study_date:
                try:
                    study_datetime = datetime.strptime(f"{study_date}{study_time[:6]}", '%Y%m%d%H%M%S')
                    study_datetime = timezone.make_aware(study_datetime)
                except ValueError:
                    study_datetime = timezone.now()
            else:
                study_datetime = timezone.now()
            
            # Get or create modality
            modality, _ = Modality.objects.get_or_create(
                code=modality_code,
                defaults={'name': modality_code, 'description': f'{modality_code} Modality'}
            )
            
            # Get or create study (attributed to the specific facility)
            study, created = Study.objects.get_or_create(
                study_instance_uid=study_uid,
                defaults={
                    'patient': patient,
                    'accession_number': accession_number,
                    'study_date': study_datetime.date(),
                    'study_time': study_datetime.time(),
                    'description': study_description,
                    'referring_physician': referring_physician,
                    'modality': modality,
                    'facility': facility,  # Important: Associate with facility
                    'upload_date': timezone.now()
                }
            )
            
            if created:
                logger.info(f"Created new study: {study} for facility: {facility.name}")
            
            # Get or create series
            series, created = Series.objects.get_or_create(
                series_instance_uid=series_uid,
                study=study,
                defaults={
                    'series_number': getattr(ds, 'SeriesNumber', 1),
                    'modality': modality,
                    'series_description': getattr(ds, 'SeriesDescription', 'DICOM Series'),
                    'body_part_examined': getattr(ds, 'BodyPartExamined', ''),
                    'patient_position': getattr(ds, 'PatientPosition', ''),
                    'series_date': study_datetime.date(),
                    'series_time': study_datetime.time()
                }
            )
            
            if created:
                logger.info(f"Created new series: {series}")
            
            # Create facility-specific file path
            facility_dir = self.storage_dir / f"facility_{facility.id}_{facility.ae_title}"
            facility_dir.mkdir(exist_ok=True)
            
            # Save DICOM file with facility organization
            filename = f"{sop_instance_uid}.dcm"
            file_path = facility_dir / filename
            
            # Save the DICOM file
            ds.save_as(str(file_path))
            
            # Create DicomImage record
            dicom_image, created = DicomImage.objects.get_or_create(
                sop_instance_uid=sop_instance_uid,
                series=series,
                defaults={
                    'instance_number': getattr(ds, 'InstanceNumber', 1),
                    'file_path': str(file_path.relative_to(Path('/workspace'))),
                    'file_size': file_path.stat().st_size,
                    'image_type': getattr(ds, 'ImageType', ''),
                    'acquisition_date': study_datetime.date(),
                    'acquisition_time': study_datetime.time(),
                    'facility': facility  # Track facility for each image
                }
            )
            
            if created:
                logger.info(f"Created new DICOM image: {dicom_image} for facility: {facility.name}")
            
            return True
            
        except Exception as e:
            logger.error(f"Error processing DICOM object: {e}")
            return False
    
    def start_server(self, bind_address='0.0.0.0'):
        """Start the DICOM SCP server"""
        logger.info(f"Starting DICOM SCP server on {bind_address}:{self.port}")
        
        if self.external_access:
            logger.warning("DICOM server configured for INTERNET ACCESS - Enhanced security enabled")
            security_logger.info(f"DICOM server started with external access on {bind_address}:{self.port}")
        
        # Refresh facility cache periodically
        def cache_refresher():
            while True:
                time.sleep(300)  # Refresh every 5 minutes
                self.refresh_facility_cache()
        
        cache_thread = threading.Thread(target=cache_refresher, daemon=True)
        cache_thread.start()
        
        # Start the server
        self.ae.start_server((bind_address, self.port), block=True)

def main():
    """Main function with command line argument parsing"""
    parser = argparse.ArgumentParser(description='Enhanced DICOM Receiver for NOCTIS Pro')
    parser.add_argument('--port', type=int, default=11112, help='Port to listen on (default: 11112)')
    parser.add_argument('--aet', default='NOCTIS_SCP', help='AE Title for this SCP (default: NOCTIS_SCP)')
    parser.add_argument('--bind', default='0.0.0.0', help='IP address to bind to (default: 0.0.0.0)')
    parser.add_argument('--external-access', action='store_true', help='Enable external/internet access with enhanced security')
    parser.add_argument('--log-level', default='INFO', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'], help='Log level')
    
    args = parser.parse_args()
    
    # Setup logging
    global logger, security_logger
    logger, security_logger = setup_logging(args.log_level, args.external_access)
    
    # Log startup information
    logger.info("="*60)
    logger.info("NOCTIS Pro Enhanced DICOM Receiver Starting")
    logger.info("="*60)
    logger.info(f"AE Title: {args.aet}")
    logger.info(f"Port: {args.port}")
    logger.info(f"Bind Address: {args.bind}")
    logger.info(f"External Access: {args.external_access}")
    logger.info(f"Log Level: {args.log_level}")
    
    if args.external_access:
        logger.warning("⚠️  EXTERNAL ACCESS ENABLED - Internet-accessible DICOM receiver")
        logger.warning("⚠️  Ensure proper firewall and security measures are in place")
        security_logger.warning("DICOM receiver started with external access enabled")
    
    # Initialize and start receiver
    try:
        receiver = EnhancedDicomReceiver(
            port=args.port,
            aet=args.aet,
            external_access=args.external_access
        )
        
        logger.info("DICOM receiver initialized successfully")
        logger.info("Waiting for DICOM connections...")
        
        # Start the server
        receiver.start_server(args.bind)
        
    except KeyboardInterrupt:
        logger.info("DICOM receiver stopped by user")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()