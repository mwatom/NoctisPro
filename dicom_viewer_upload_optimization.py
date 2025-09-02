"""
DICOM Viewer Upload Optimization
Enhanced upload functionality with performance improvements for slow networks
"""

import json
import time
import logging
import asyncio
from concurrent.futures import ThreadPoolExecutor
from django.http import JsonResponse, StreamingHttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.decorators import login_required
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from django.utils import timezone
from django.db import transaction
import pydicom
import os
import uuid
from io import BytesIO
import gzip
import threading
from queue import Queue

logger = logging.getLogger(__name__)

# Global upload progress tracking
upload_progress = {}
upload_lock = threading.Lock()

class OptimizedDicomUploader:
    def __init__(self, request, chunk_size=1024*1024):  # 1MB chunks
        self.request = request
        self.chunk_size = chunk_size
        self.upload_id = str(uuid.uuid4())
        self.processed_files = 0
        self.total_files = 0
        self.errors = []
        
    def update_progress(self, current, total, status="processing"):
        """Update upload progress for real-time tracking"""
        with upload_lock:
            upload_progress[self.upload_id] = {
                'current': current,
                'total': total,
                'percentage': int((current / total) * 100) if total > 0 else 0,
                'status': status,
                'errors': self.errors,
                'timestamp': time.time()
            }
    
    def compress_if_needed(self, file_content):
        """Compress large DICOM files for slow networks"""
        if len(file_content) > 5 * 1024 * 1024:  # 5MB threshold
            compressed = gzip.compress(file_content)
            if len(compressed) < len(file_content) * 0.8:  # Only if significant compression
                return compressed, True
        return file_content, False
    
    def process_dicom_file_optimized(self, file_data, filename):
        """Process DICOM file with optimization for slow networks"""
        try:
            # Read DICOM dataset
            ds = pydicom.dcmread(BytesIO(file_data), force=True)
            
            # Extract essential metadata quickly
            metadata = {
                'study_uid': getattr(ds, 'StudyInstanceUID', None),
                'series_uid': getattr(ds, 'SeriesInstanceUID', None),
                'sop_uid': getattr(ds, 'SOPInstanceUID', None),
                'modality': getattr(ds, 'Modality', 'OT'),
                'patient_id': getattr(ds, 'PatientID', 'UNKNOWN'),
                'patient_name': str(getattr(ds, 'PatientName', 'UNKNOWN')),
                'study_date': getattr(ds, 'StudyDate', None),
                'series_description': getattr(ds, 'SeriesDescription', ''),
                'filename': filename
            }
            
            # Validate essential fields
            if not all([metadata['study_uid'], metadata['series_uid'], metadata['sop_uid']]):
                return None, f"Missing essential DICOM UIDs in {filename}"
            
            return metadata, None
            
        except Exception as e:
            return None, f"Error processing {filename}: {str(e)}"
    
    def batch_process_files(self, files, batch_size=5):
        """Process files in batches to optimize memory usage"""
        processed_metadata = []
        
        for i in range(0, len(files), batch_size):
            batch = files[i:i + batch_size]
            batch_results = []
            
            # Process batch with threading
            with ThreadPoolExecutor(max_workers=3) as executor:
                futures = []
                for file in batch:
                    file_data = file.read()
                    file.seek(0)  # Reset for potential reuse
                    future = executor.submit(
                        self.process_dicom_file_optimized, 
                        file_data, 
                        file.name
                    )
                    futures.append(future)
                
                for future in futures:
                    metadata, error = future.result()
                    if metadata:
                        batch_results.append(metadata)
                    elif error:
                        self.errors.append(error)
            
            processed_metadata.extend(batch_results)
            self.update_progress(i + len(batch), len(files), "processing")
            
        return processed_metadata


@csrf_exempt
@login_required
def upload_dicom_optimized(request):
    """
    Optimized DICOM upload with performance improvements for slow networks
    """
    if request.method != 'POST':
        return JsonResponse({'error': 'Method not allowed'}, status=405)
    
    try:
        uploader = OptimizedDicomUploader(request)
        
        # Get uploaded files
        uploaded_files = request.FILES.getlist('dicom_files')
        if not uploaded_files:
            return JsonResponse({'error': 'No files uploaded'}, status=400)
        
        uploader.total_files = len(uploaded_files)
        uploader.update_progress(0, uploader.total_files, "starting")
        
        # Process files in batches for better performance
        logger.info(f"Processing {len(uploaded_files)} DICOM files for user {request.user.username}")
        
        processed_metadata = uploader.batch_process_files(uploaded_files)
        
        if not processed_metadata:
            return JsonResponse({
                'error': 'No valid DICOM files found',
                'details': uploader.errors
            }, status=400)
        
        # Group by study for efficient database operations
        studies_data = {}
        for metadata in processed_metadata:
            study_uid = metadata['study_uid']
            if study_uid not in studies_data:
                studies_data[study_uid] = {
                    'metadata': metadata,
                    'series': {}
                }
            
            series_uid = metadata['series_uid']
            if series_uid not in studies_data[study_uid]['series']:
                studies_data[study_uid]['series'][series_uid] = []
            
            studies_data[study_uid]['series'][series_uid].append(metadata)
        
        # Create database entries efficiently
        created_studies = []
        with transaction.atomic():
            for study_uid, study_data in studies_data.items():
                try:
                    study = create_study_from_metadata(study_data['metadata'], request.user)
                    
                    for series_uid, series_files in study_data['series'].items():
                        series = create_series_from_metadata(series_files[0], study)
                        
                        # Create DICOM images
                        for file_metadata in series_files:
                            create_dicom_image_from_metadata(file_metadata, series, uploaded_files)
                    
                    created_studies.append(study)
                    uploader.processed_files += len(study_data['series'])
                    
                except Exception as e:
                    logger.error(f"Error creating study {study_uid}: {e}")
                    uploader.errors.append(f"Failed to create study: {str(e)}")
        
        uploader.update_progress(uploader.total_files, uploader.total_files, "completed")
        
        # Return success response with study information
        response_data = {
            'success': True,
            'upload_id': uploader.upload_id,
            'processed_files': len(processed_metadata),
            'created_studies': len(created_studies),
            'errors': uploader.errors
        }
        
        # Include first study ID for immediate viewing
        if created_studies:
            response_data['study_id'] = created_studies[0].id
            response_data['study_accession'] = created_studies[0].accession_number
        
        logger.info(f"Upload completed: {len(processed_metadata)} files, {len(created_studies)} studies")
        return JsonResponse(response_data)
        
    except Exception as e:
        logger.error(f"Upload failed: {e}")
        return JsonResponse({
            'error': f'Upload failed: {str(e)}',
            'upload_id': getattr(uploader, 'upload_id', None)
        }, status=500)


@login_required
def api_upload_progress(request, upload_id):
    """Get real-time upload progress"""
    with upload_lock:
        progress = upload_progress.get(upload_id, {
            'current': 0,
            'total': 0,
            'percentage': 0,
            'status': 'not_found',
            'errors': []
        })
    
    return JsonResponse(progress)


def create_study_from_metadata(metadata, user):
    """Create study from DICOM metadata"""
    from worklist.models import Study, Patient, Modality, Facility
    from datetime import datetime
    
    # Create or get patient
    patient_id = metadata['patient_id']
    patient_name_parts = metadata['patient_name'].replace('^', ' ').split(' ', 1)
    first_name = patient_name_parts[0] if patient_name_parts else 'Unknown'
    last_name = patient_name_parts[1] if len(patient_name_parts) > 1 else ''
    
    patient, _ = Patient.objects.get_or_create(
        patient_id=patient_id,
        defaults={
            'first_name': first_name,
            'last_name': last_name,
            'date_of_birth': timezone.now().date(),
            'gender': 'O'
        }
    )
    
    # Create or get modality
    modality, _ = Modality.objects.get_or_create(
        code=metadata['modality'],
        defaults={'name': metadata['modality']}
    )
    
    # Get facility
    facility = getattr(user, 'facility', None) or Facility.objects.filter(is_active=True).first()
    if not facility:
        facility = Facility.objects.create(
            name='Default Facility',
            address='N/A',
            phone='N/A',
            email='default@example.com',
            license_number=f'DEFAULT-{int(timezone.now().timestamp())}',
            is_active=True
        )
    
    # Parse study date
    study_date = timezone.now()
    if metadata['study_date']:
        try:
            study_date = timezone.make_aware(
                datetime.strptime(metadata['study_date'], '%Y%m%d')
            )
        except:
            pass
    
    # Create study
    accession_number = f"USB_{int(timezone.now().timestamp())}"
    study = Study.objects.create(
        study_instance_uid=metadata['study_uid'],
        accession_number=accession_number,
        patient=patient,
        facility=facility,
        modality=modality,
        study_description=f"USB Upload - {metadata['modality']}",
        study_date=study_date,
        referring_physician='USB Upload',
        uploaded_by=user,
        status='completed'
    )
    
    return study


def create_series_from_metadata(metadata, study):
    """Create series from DICOM metadata"""
    from worklist.models import Series
    
    series = Series.objects.create(
        series_instance_uid=metadata['series_uid'],
        study=study,
        series_number=1,
        series_description=metadata['series_description'] or 'USB Upload Series',
        modality=metadata['modality']
    )
    
    return series


def create_dicom_image_from_metadata(metadata, series, uploaded_files):
    """Create DICOM image from metadata"""
    from worklist.models import DicomImage
    import shutil
    
    # Find the corresponding uploaded file
    source_file = None
    for file in uploaded_files:
        if file.name == metadata['filename']:
            source_file = file
            break
    
    if not source_file:
        logger.warning(f"Could not find source file for {metadata['filename']}")
        return None
    
    # Save file to media directory
    file_path = f"dicom/images/{series.study.study_instance_uid}/{series.series_instance_uid}/{metadata['sop_uid']}.dcm"
    
    # Ensure directory exists
    full_path = os.path.join(default_storage.location, file_path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    
    # Save file
    with open(full_path, 'wb') as dest:
        source_file.seek(0)
        shutil.copyfileobj(source_file, dest)
    
    # Create database entry
    dicom_image = DicomImage.objects.create(
        sop_instance_uid=metadata['sop_uid'],
        series=series,
        instance_number=1,
        file_path=file_path,
        file_size=source_file.size
    )
    
    return dicom_image


# Enhanced chunked upload for very large files
@csrf_exempt
@login_required
def upload_dicom_chunked(request):
    """Handle chunked uploads for very large DICOM files"""
    if request.method != 'POST':
        return JsonResponse({'error': 'Method not allowed'}, status=405)
    
    chunk_number = int(request.POST.get('chunk_number', 0))
    total_chunks = int(request.POST.get('total_chunks', 1))
    upload_id = request.POST.get('upload_id')
    filename = request.POST.get('filename')
    
    if not upload_id:
        upload_id = str(uuid.uuid4())
    
    try:
        # Handle chunk upload
        chunk_data = request.FILES['chunk']
        
        # Store chunk temporarily
        chunk_dir = os.path.join(default_storage.location, 'temp_uploads', upload_id)
        os.makedirs(chunk_dir, exist_ok=True)
        
        chunk_path = os.path.join(chunk_dir, f'chunk_{chunk_number}')
        with open(chunk_path, 'wb') as f:
            for chunk in chunk_data.chunks():
                f.write(chunk)
        
        # Update progress
        progress = int((chunk_number + 1) / total_chunks * 100)
        with upload_lock:
            upload_progress[upload_id] = {
                'current': chunk_number + 1,
                'total': total_chunks,
                'percentage': progress,
                'status': 'uploading',
                'filename': filename
            }
        
        # If this is the last chunk, reassemble file
        if chunk_number == total_chunks - 1:
            return reassemble_and_process(upload_id, filename, total_chunks, request)
        
        return JsonResponse({
            'success': True,
            'upload_id': upload_id,
            'chunk_number': chunk_number,
            'progress': progress
        })
        
    except Exception as e:
        logger.error(f"Chunked upload error: {e}")
        return JsonResponse({'error': str(e)}, status=500)


def reassemble_and_process(upload_id, filename, total_chunks, request):
    """Reassemble chunks and process the complete file"""
    try:
        chunk_dir = os.path.join(default_storage.location, 'temp_uploads', upload_id)
        
        # Reassemble file
        output_path = os.path.join(chunk_dir, filename)
        with open(output_path, 'wb') as output_file:
            for i in range(total_chunks):
                chunk_path = os.path.join(chunk_dir, f'chunk_{i}')
                with open(chunk_path, 'rb') as chunk_file:
                    output_file.write(chunk_file.read())
                os.remove(chunk_path)  # Clean up chunk
        
        # Process the reassembled file
        with open(output_path, 'rb') as f:
            # Create a file-like object for processing
            from django.core.files.uploadedfile import SimpleUploadedFile
            uploaded_file = SimpleUploadedFile(filename, f.read())
            
            # Use the regular upload processing
            uploader = OptimizedDicomUploader(request)
            processed_metadata = uploader.batch_process_files([uploaded_file])
            
            if processed_metadata:
                # Create database entries
                study = create_study_from_metadata(processed_metadata[0], request.user)
                series = create_series_from_metadata(processed_metadata[0], study)
                create_dicom_image_from_metadata(processed_metadata[0], series, [uploaded_file])
                
                # Clean up
                os.remove(output_path)
                os.rmdir(chunk_dir)
                
                return JsonResponse({
                    'success': True,
                    'upload_id': upload_id,
                    'study_id': study.id,
                    'message': 'File uploaded and processed successfully'
                })
            else:
                return JsonResponse({'error': 'Failed to process DICOM file'}, status=400)
                
    except Exception as e:
        logger.error(f"File reassembly error: {e}")
        return JsonResponse({'error': f'File processing failed: {str(e)}'}, status=500)