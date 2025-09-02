from django.shortcuts import render, get_object_or_404, redirect
from django.contrib.auth.decorators import login_required
from django.http import JsonResponse, HttpResponse, FileResponse
from django.contrib import messages
from django.core.paginator import Paginator
from django.db.models import Q, Count
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
import os
import mimetypes
import json
import logging
from pathlib import Path
import pydicom
from PIL import Image
from io import BytesIO
from dicom_viewer.dicom_utils import safe_dicom_str

logger = logging.getLogger(__name__)

from .models import (
    Study, Patient, Modality, Series, DicomImage, StudyAttachment, 
    AttachmentComment, AttachmentVersion
)
from accounts.models import User, Facility
from notifications.models import Notification, NotificationType
from reports.models import Report

@login_required
def dashboard(request):
	"""Professional dashboard with enhanced functionality"""
	from django.middleware.csrf import get_token
	
	# Get user-specific statistics
	user = request.user
	if user.is_facility_user() and getattr(user, 'facility', None):
		studies = Study.objects.filter(facility=user.facility)
	else:
		studies = Study.objects.all()
	
	# Calculate dashboard statistics
	total_studies = studies.count()
	urgent_studies = studies.filter(priority='urgent').count()
	in_progress_studies = studies.filter(status='in_progress').count()
	completed_studies = studies.filter(status='completed').count()
	
	return render(request, 'worklist/dashboard.html', {
		'user': request.user,
		'csrf_token': get_token(request),
		'total_studies': total_studies,
		'urgent_studies': urgent_studies,
		'in_progress_studies': in_progress_studies,
		'completed_studies': completed_studies,
	})

@login_required
def study_list(request):
	"""List all studies with filtering and pagination"""
	user = request.user
	
	# Base queryset based on user role
	if user.is_facility_user() and getattr(user, 'facility', None):
		studies = Study.objects.filter(facility=user.facility)
	else:
		studies = Study.objects.all()
	
	# Apply filters
	status_filter = request.GET.get('status')
	if status_filter:
		studies = studies.filter(status=status_filter)
	
	priority_filter = request.GET.get('priority')
	if priority_filter:
		studies = studies.filter(priority=priority_filter)
	
	modality_filter = request.GET.get('modality')
	if modality_filter:
		studies = studies.filter(modality__code=modality_filter)
	
	search_query = request.GET.get('search')
	if search_query:
		studies = studies.filter(
			Q(accession_number__icontains=search_query) |
			Q(patient__first_name__icontains=search_query) |
			Q(patient__last_name__icontains=search_query) |
			Q(patient__patient_id__icontains=search_query) |
			Q(study_description__icontains=search_query)
		)
	
	# Sort by study date (most recent first) and prefetch attachments for display
	studies = studies.select_related('patient', 'facility', 'modality', 'radiologist').prefetch_related('attachments').order_by('-study_date')
	
	# Pagination
	paginator = Paginator(studies, 25)
	page_number = request.GET.get('page')
	studies_page = paginator.get_page(page_number)
	
	# Get available modalities for filter
	modalities = Modality.objects.filter(is_active=True)
	
	# Build quick maps for previous reports (by same patient) and attachments per study
	page_studies = list(studies_page.object_list)
	patient_ids = list({s.patient_id for s in page_studies})
	study_ids = [s.id for s in page_studies]
	
	# Previous reports grouped by patient, excluding current study
	all_reports = Report.objects.filter(study__patient_id__in=patient_ids).select_related('study', 'radiologist').order_by('-report_date')
	reports_by_patient = {}
	for rep in all_reports:
		reports_by_patient.setdefault(rep.study.patient_id, []).append(rep)
	previous_reports_map = {}
	for s in page_studies:
		items = [r for r in reports_by_patient.get(s.patient_id, []) if r.study_id != s.id]
		previous_reports_map[s.id] = items[:5]  # cap in template
	
	# Attachments per study (current version only)
	atts = StudyAttachment.objects.filter(study_id__in=study_ids, is_current_version=True).order_by('-upload_date')
	attachments_map = {}
	for a in atts:
		attachments_map.setdefault(a.study_id, []).append(a)
	
	context = {
		'studies': studies_page,
		'modalities': modalities,
		'status_filter': status_filter,
		'priority_filter': priority_filter,
		'modality_filter': modality_filter,
		'search_query': search_query,
		'user': user,
		'previous_reports_map': previous_reports_map,
		'attachments_map': attachments_map,
	}
	
	return render(request, 'worklist/study_list.html', context)

@login_required
def study_detail(request, study_id):
	"""Detailed view of a study"""
	study = get_object_or_404(Study, id=study_id)
	user = request.user
	
	# Check permissions
	if user.is_facility_user() and study.facility != user.facility:
		messages.error(request, 'You do not have permission to view this study.')
		return redirect('worklist:study_list')
	
	# Get series and images
	series_list = study.series_set.all().order_by('series_number')
	
	# Get study attachments
	attachments = study.attachments.filter(is_current_version=True).order_by('-upload_date')
	
	# Get study notes
	notes = study.notes.all().order_by('-created_at')
	
	context = {
		'study': study,
		'series_list': series_list,
		'attachments': attachments,
		'notes': notes,
		'user': user,
	}
	
	return render(request, 'worklist/study_detail.html', context)

@login_required
@csrf_exempt
def upload_study(request):
	"""Upload new studies with enhanced folder support for CT/MRI modalities"""
	if request.method == 'POST':
		try:
			# Admin/radiologist options
			override_facility_id = (request.POST.get('facility_id', '') or '').strip()
			assign_to_me = (request.POST.get('assign_to_me', '0') == '1')
			
			uploaded_files = request.FILES.getlist('dicom_files')
			
			if not uploaded_files:
				return JsonResponse({'success': False, 'error': 'No files uploaded'})
			
			# Enhanced grouping with better series detection for CT/MRI
			studies_map = {}
			invalid_files = 0
			processed_files = 0
			total_files = len(uploaded_files)
			
			# Process files with enhanced DICOM metadata extraction
			for in_file in uploaded_files:
				try:
					# Read dataset without saving to disk first
					ds = pydicom.dcmread(in_file, force=True)
					
					# Enhanced metadata extraction for CT/MRI
					study_uid = getattr(ds, 'StudyInstanceUID', None)
					series_uid = getattr(ds, 'SeriesInstanceUID', None)
					sop_uid = getattr(ds, 'SOPInstanceUID', None)
					modality = getattr(ds, 'Modality', 'OT')
					
					if not (study_uid and series_uid and sop_uid):
						invalid_files += 1
						continue
					
					# Enhanced series grouping for CT/MRI with multiple series
					series_key = f"{series_uid}_{modality}"
					studies_map.setdefault(study_uid, {}).setdefault(series_key, []).append((ds, in_file))
					
				except Exception as e:
					invalid_files += 1
					continue
			
			if not studies_map:
				return JsonResponse({'success': False, 'error': 'No valid DICOM files found'})
			
			created_studies = []
			total_series_processed = 0
			
			for study_uid, series_map in studies_map.items():
				# Extract representative dataset
				first_series_key = next(iter(series_map))
				rep_ds = series_map[first_series_key][0][0]
				
				# Enhanced patient info extraction
				patient_id = getattr(rep_ds, 'PatientID', 'UNKNOWN')
				patient_name = str(getattr(rep_ds, 'PatientName', 'UNKNOWN')).replace('^', ' ')
				name_parts = patient_name.split(' ', 1)
				first_name = name_parts[0] if name_parts else 'Unknown'
				last_name = name_parts[1] if len(name_parts) > 1 else ''
				birth_date = getattr(rep_ds, 'PatientBirthDate', None)
				from datetime import datetime
				if birth_date:
					try:
						dob = datetime.strptime(birth_date, '%Y%m%d').date()
					except Exception:
						dob = timezone.now().date()
				else:
					dob = timezone.now().date()
				gender = getattr(rep_ds, 'PatientSex', 'O')
				if gender not in ['M','F','O']:
					gender = 'O'
				
				patient, _ = Patient.objects.get_or_create(
					patient_id=patient_id,
					defaults={'first_name': first_name, 'last_name': last_name, 'date_of_birth': dob, 'gender': gender}
				)
				
				# Enhanced modality and study fields
				modality_code = getattr(rep_ds, 'Modality', 'OT')
				modality, _ = Modality.objects.get_or_create(code=modality_code, defaults={'name': modality_code})
				study_description = getattr(rep_ds, 'StudyDescription', 'DICOM Study')
				referring_physician = str(getattr(rep_ds, 'ReferringPhysicianName', 'UNKNOWN')).replace('^', ' ')
				accession_number = getattr(rep_ds, 'AccessionNumber', f"ACC_{int(timezone.now().timestamp())}")
				# Ensure accession_number not empty
				if not accession_number:
					accession_number = f"ACC_{int(timezone.now().timestamp())}"
				# Collision-safe: if accession_number already exists, append suffix
				if Study.objects.filter(accession_number=accession_number).exists():
					suffix = 1
					base_acc = str(accession_number)
					while Study.objects.filter(accession_number=f"{base_acc}-{suffix}").exists():
						suffix += 1
					accession_number = f"{base_acc}-{suffix}"
				study_date = getattr(rep_ds, 'StudyDate', None)
				study_time = getattr(rep_ds, 'StudyTime', '000000')
				if study_date:
					try:
						sdt = datetime.strptime(f"{study_date}{study_time[:6]}", '%Y%m%d%H%M%S')
						sdt = timezone.make_aware(sdt)
					except Exception:
						sdt = timezone.now()
				else:
					sdt = timezone.now()
				
				# Facility attribution with admin/radiologist override
				facility = None
				if (hasattr(request.user, 'is_admin') and request.user.is_admin()) or (hasattr(request.user, 'is_radiologist') and request.user.is_radiologist()):
					if override_facility_id:
						facility = Facility.objects.filter(id=override_facility_id, is_active=True).first()
				if not facility and getattr(request.user, 'facility', None):
					facility = request.user.facility
				if not facility:
					facility = Facility.objects.filter(is_active=True).first()
				if not facility:
					# Allow admin to upload without preconfigured facility by creating a default one
					if hasattr(request.user, 'is_admin') and request.user.is_admin():
						facility = Facility.objects.create(
							name='Default Facility',
							address='N/A',
							phone='N/A',
							email='default@example.com',
							license_number=f'DEFAULT-{int(timezone.now().timestamp())}',
							ae_title='',
							is_active=True
						)
					else:
						return JsonResponse({'success': False, 'error': 'No active facility configured'})
				
				# Optional: assign uploaded study to current radiologist's worklist
				assigned_radiologist = None
				if assign_to_me and hasattr(request.user, 'is_radiologist') and request.user.is_radiologist():
					assigned_radiologist = request.user
				
				study, created = Study.objects.get_or_create(
					study_instance_uid=study_uid,
					defaults={
						'accession_number': accession_number,
						'patient': patient,
						'facility': facility,
						'modality': modality,
						'study_description': study_description,
						'study_date': sdt,
						'referring_physician': referring_physician,
						'status': 'scheduled',
						'priority': request.POST.get('priority', 'normal'),
						'clinical_info': request.POST.get('clinical_info', ''),
						'uploaded_by': request.user,
						'radiologist': assigned_radiologist,
					}
				)
				
				# Enhanced series creation with better CT/MRI support
				for series_key, items in series_map.items():
					# Parse series key to get series_uid and modality
					series_uid = series_key.split('_')[0]
					
					# Representative dataset for series
					ds0 = items[0][0]
					series_number = getattr(ds0, 'SeriesNumber', 1) or 1
					series_desc = getattr(ds0, 'SeriesDescription', f'Series {series_number}')
					slice_thickness = getattr(ds0, 'SliceThickness', None)
					pixel_spacing = safe_dicom_str(getattr(ds0, 'PixelSpacing', ''))
					image_orientation = safe_dicom_str(getattr(ds0, 'ImageOrientationPatient', ''))
					
					# Enhanced series metadata for CT/MRI
					body_part = getattr(ds0, 'BodyPartExamined', '')
					protocol_name = getattr(ds0, 'ProtocolName', '')
					contrast_bolus_agent = getattr(ds0, 'ContrastBolusAgent', '')
					
					series, _ = Series.objects.get_or_create(
						series_instance_uid=series_uid,
						defaults={
							'study': study,
							'series_number': int(series_number),
							'series_description': series_desc,
							'modality': modality_code,
							'body_part': body_part,
							'slice_thickness': slice_thickness if slice_thickness is not None else None,
							'pixel_spacing': pixel_spacing,
							'image_orientation': image_orientation,
						}
					)
					# If study existed, update clinical info/priority once
					if not created:
						updated = False
						new_priority = request.POST.get('priority')
						new_clin = request.POST.get('clinical_info')
						if new_priority and study.priority != new_priority:
							study.priority = new_priority
							updated = True
						if new_clin is not None and new_clin != '' and study.clinical_info != new_clin:
							study.clinical_info = new_clin
							updated = True
						if updated:
							study.save(update_fields=['priority','clinical_info'])
					
					# Enhanced image processing with better error handling
					for ds, fobj in items:
						try:
							sop_uid = getattr(ds, 'SOPInstanceUID')
							instance_number = getattr(ds, 'InstanceNumber', 1) or 1
							
							# Enhanced file path structure for better organization
							rel_path = f"dicom/images/{study_uid}/{series_uid}/{sop_uid}.dcm"
							
							# Ensure we read from start
							fobj.seek(0)
							saved_path = default_storage.save(rel_path, ContentFile(fobj.read()))
							
							# Enhanced image metadata
							image_position = str(getattr(ds, 'ImagePositionPatient', ''))
							slice_location = getattr(ds, 'SliceLocation', None)
							window_center = getattr(ds, 'WindowCenter', None)
							window_width = getattr(ds, 'WindowWidth', None)
							
							DicomImage.objects.get_or_create(
								sop_instance_uid=sop_uid,
								defaults={
									'series': series,
									'instance_number': int(instance_number),
									'image_position': image_position,
									'slice_location': slice_location,
									'file_path': saved_path,
									'file_size': getattr(fobj, 'size', 0) or 0,
									'processed': False,
								}
							)
							processed_files += 1
						except Exception as e:
							continue
					
					total_series_processed += 1
				
				created_studies.append(study.id)
				
				# Enhanced notifications for new study upload
				try:
					notif_type, _ = NotificationType.objects.get_or_create(
						code='new_study', defaults={'name': 'New Study Uploaded', 'description': 'A new study has been uploaded', 'is_system': True}
					)
					recipients = User.objects.filter(Q(role='radiologist') | Q(role='admin') | Q(facility=facility))
					for recipient in recipients:
						Notification.objects.create(
							notification_type=notif_type,
							recipient=recipient,
							sender=request.user,
							title=f"New {modality_code} study for {patient.full_name}",
							message=f"Study {accession_number} uploaded from {facility.name} with {total_series_processed} series",
							priority='normal',
							study=study,
							facility=facility,
							data={'study_id': study.id, 'accession_number': accession_number, 'series_count': total_series_processed}
						)
				except Exception:
					pass
			
			return JsonResponse({
				'success': True,
				'message': f'Successfully uploaded {processed_files} DICOM files across {len(created_studies)} study(ies) with {total_series_processed} series',
				'created_study_ids': created_studies,
				'invalid_files': invalid_files,
				'processed_files': processed_files,
				'total_files': total_files,
				'total_series': total_series_processed,
				'studies_created': len(created_studies),
			})
			
		except Exception as e:
			return JsonResponse({'success': False, 'error': str(e)})
	
	# Provide facilities for admin/radiologist to target uploads
	facilities = Facility.objects.filter(is_active=True).order_by('name') if ((hasattr(request.user, 'is_admin') and request.user.is_admin()) or (hasattr(request.user, 'is_radiologist') and request.user.is_radiologist())) else []
	return render(request, 'worklist/upload.html', {'facilities': facilities})

@login_required
def modern_worklist(request):
	"""Legacy route: redirect to main dashboard UI"""
	return redirect('worklist:dashboard')

@login_required
def modern_dashboard(request):
	"""Legacy route: redirect to main dashboard UI"""
	return redirect('worklist:dashboard')

@login_required
def api_studies(request):
	"""API endpoint for studies data"""
	try:
		user = request.user
		
		if user.is_facility_user() and getattr(user, 'facility', None):
			studies = Study.objects.filter(facility=user.facility)
		else:
			studies = Study.objects.all()
		
		studies_data = []
		for study in studies.select_related('patient', 'modality', 'facility', 'uploaded_by').order_by('-study_date')[:100]:  # Increased limit to show more studies
			try:
				# Use real study data with fallback to reasonable defaults
				study_time = study.study_date
				scheduled_time = study.study_date
				
				# If study has upload_date, use it for better tracking
				if hasattr(study, 'upload_date') and study.upload_date:
					upload_date = study.upload_date.isoformat()
				else:
					upload_date = study.study_date.isoformat()
				
				# Get image and series counts safely
				try:
					image_count = study.get_image_count()
					series_count = study.get_series_count()
				except:
					image_count = 0
					series_count = 0
				
				studies_data.append({
					'id': study.id,
					'accession_number': study.accession_number or f'ACC{study.id:06d}',
					'patient_name': study.patient.full_name if study.patient else 'Unknown Patient',
					'patient_id': study.patient.patient_id if study.patient else f'PID{study.id:06d}',
					'modality': study.modality.code if study.modality else 'OT',
					'status': study.status or 'pending',
					'priority': str(study.priority or 'normal'),
					'study_date': study.study_date.isoformat() if study.study_date else timezone.now().isoformat(),
					'study_time': study_time.isoformat() if study_time else timezone.now().isoformat(),
					'scheduled_time': scheduled_time.isoformat() if scheduled_time else timezone.now().isoformat(),
					'upload_date': upload_date,
					'facility': study.facility.name if study.facility else 'Unknown Facility',
					'image_count': image_count,
					'series_count': series_count,
					'study_description': study.study_description or 'No description',
					'clinical_info': str(study.clinical_info or ''),
					'uploaded_by': study.uploaded_by.get_full_name() if study.uploaded_by else 'Unknown',
				})
			except Exception as e:
				# Log the error but continue processing other studies
				logger.warning(f"Error processing study {study.id}: {e}")
				continue
		
		return JsonResponse({
			'success': True, 
			'studies': studies_data,
			'total_count': len(studies_data),
			'message': f'Found {len(studies_data)} studies' if studies_data else 'No studies found'
		})
		
	except Exception as e:
		return JsonResponse({
			'success': False, 
			'error': str(e),
			'studies': [],
			'message': 'Failed to load studies'
		}, status=500)

@login_required
def api_study_detail(request, study_id):
	"""API endpoint to get study detail for permission checking"""
	user = request.user
	study = get_object_or_404(Study, id=study_id)
	
	# Check permissions
	if user.is_facility_user() and getattr(user, 'facility', None) and study.facility != user.facility:
		return JsonResponse({'error': 'Permission denied'}, status=403)
	
	study_data = {
		'id': study.id,
		'accession_number': study.accession_number,
		'patient_name': study.patient.full_name,
		'patient_id': study.patient.patient_id,
		'modality': study.modality.code,
		'status': study.status,
		'priority': str(study.priority or 'normal'),
		'study_date': study.study_date.isoformat(),
		'facility': study.facility.name,
		'image_count': study.get_image_count(),
		'series_count': study.get_series_count(),
		'study_description': study.study_description,
		'clinical_info': str(study.clinical_info or ''),
	}
	
	return JsonResponse({'success': True, 'study': study_data})

@login_required
@csrf_exempt
def upload_attachment(request, study_id):
    """Upload attachment to study"""
    study = get_object_or_404(Study, id=study_id)
    user = request.user
    
    # All authenticated users can upload attachments regardless of facility
    
    if request.method == 'POST':
        try:
            files = request.FILES.getlist('files')
            attachment_type = request.POST.get('type', 'document')
            description = request.POST.get('description', '')
            attach_previous_study_id = request.POST.get('previous_study_id')
            
            if not files:
                return JsonResponse({'error': 'No files provided'}, status=400)
            
            uploaded_attachments = []
            
            for file in files:
                # Validate file size (max 100MB)
                if file.size > 100 * 1024 * 1024:
                    return JsonResponse({'error': f'File {file.name} is too large (max 100MB)'}, status=400)
                
                # Determine file type based on extension
                file_ext = os.path.splitext(file.name)[1].lower()
                mime_type = mimetypes.guess_type(file.name)[0] or 'application/octet-stream'
                
                # Auto-detect attachment type if not specified
                if attachment_type == 'auto':
                    if file_ext == '.dcm':
                        attachment_type = 'dicom_study'
                    elif file_ext == '.pdf':
                        attachment_type = 'pdf_document'
                    elif file_ext in ['.doc', '.docx']:
                        attachment_type = 'word_document'
                    elif file_ext in ['.jpg', '.jpeg', '.png', '.gif']:
                        attachment_type = 'image'
                    else:
                        attachment_type = 'document'
                
                # Create attachment
                attachment = StudyAttachment.objects.create(
                    study=study,
                    file=file,
                    file_type=attachment_type,
                    name=file.name,
                    description=description,
                    file_size=file.size,
                    mime_type=mime_type,
                    uploaded_by=user,
                    is_public=True
                )
                
                # Generate thumbnail
                try:
                    generate_attachment_thumbnail(attachment)
                except Exception:
                    pass
                
                uploaded_attachments.append({
                    'id': attachment.id,
                    'name': attachment.name,
                    'size': attachment.file_size,
                    'type': attachment.file_type,
                })
            
            # Create notifications for new attachments
            try:
                notif_type, _ = NotificationType.objects.get_or_create(
                    code='new_attachment', defaults={'name': 'New Attachment Uploaded', 'description': 'A new attachment has been uploaded', 'is_system': True}
                )
                recipients = User.objects.filter(Q(role='radiologist') | Q(role='admin') | Q(facility=study.facility))
                for recipient in recipients:
                    Notification.objects.create(
                        notification_type=notif_type,
                        recipient=recipient,
                        sender=request.user,
                        title=f"New attachment for {study.patient.full_name}",
                        message=f"{len(uploaded_attachments)} file(s) attached to study {study.accession_number}",
                        priority='normal',
                        study=study,
                        facility=study.facility,
                        data={'study_id': study.id}
                    )
            except Exception:
                pass
            
            return JsonResponse({
                'success': True,
                'message': f'Successfully uploaded {len(uploaded_attachments)} file(s)',
                'attachments': uploaded_attachments
            })
            
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    
    # GET request - show upload form
    # Get previous studies for this patient
    previous_studies = Study.objects.filter(
        patient=study.patient
    ).exclude(id=study.id).order_by('-study_date')[:10]
    
    context = {
        'study': study,
        'previous_studies': previous_studies,
    }
    
    return render(request, 'worklist/upload_attachment.html', context)

@login_required
def view_attachment(request, attachment_id):
    """View or download attachment"""
    attachment = get_object_or_404(StudyAttachment, id=attachment_id)
    user = request.user
    
    # All authenticated users can view attachments
    
    # Increment access count
    attachment.increment_access_count()
    
    # Handle DICOM files
    if attachment.is_dicom_file():
        if attachment.attached_study:
            # Launch desktop viewer for attached study
            return redirect('dicom_viewer:launch_study_in_desktop_viewer', study_id=attachment.attached_study.id)
        else:
            # Launch desktop viewer without study context
            return redirect('dicom_viewer:launch_standalone_viewer')
    
    # Handle viewable files (PDF, images)
    if attachment.is_viewable_in_browser():
        action = request.GET.get('action', 'view')
        
        if action == 'download':
            # Force download
            response = FileResponse(
                attachment.file.open('rb'),
                as_attachment=True,
                filename=attachment.name
            )
            return response
        else:
            # View in browser
            response = FileResponse(
                attachment.file.open('rb'),
                content_type=attachment.mime_type
            )
            return response
    
    # For non-viewable files, force download
    response = FileResponse(
        attachment.file.open('rb'),
        as_attachment=True,
        filename=attachment.name
    )
    return response

@login_required
@csrf_exempt
def attachment_comments(request, attachment_id):
    """Handle attachment comments"""
    attachment = get_object_or_404(StudyAttachment, id=attachment_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and attachment.study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            comment_text = data.get('comment', '').strip()
            
            if not comment_text:
                return JsonResponse({'error': 'Comment cannot be empty'}, status=400)
            
            comment = AttachmentComment.objects.create(
                attachment=attachment,
                user=user,
                comment=comment_text
            )
            
            return JsonResponse({
                'success': True,
                'comment': {
                    'id': comment.id,
                    'comment': comment.comment,
                    'user': comment.user.get_full_name() or comment.user.username,
                    'created_at': comment.created_at.isoformat()
                }
            })
            
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    
    # GET request - return comments
    comments = attachment.comments.select_related('user').order_by('-created_at')
    comments_data = []
    
    for comment in comments:
        comments_data.append({
            'id': comment.id,
            'comment': comment.comment,
            'user': comment.user.get_full_name() or comment.user.username,
            'created_at': comment.created_at.isoformat()
        })
    
    return JsonResponse({'comments': comments_data})

@login_required
@csrf_exempt
def delete_attachment(request, attachment_id):
    """Delete attachment"""
    attachment = get_object_or_404(StudyAttachment, id=attachment_id)
    user = request.user
    
    # All authenticated users can delete attachments
    
    if request.method == 'POST':
        try:
            study_id = attachment.study.id
            attachment_name = attachment.name
            
            # Delete file from storage
            if attachment.file:
                attachment.file.delete()
            
            # Delete thumbnail if exists
            if attachment.thumbnail:
                attachment.thumbnail.delete()
            
            # Delete attachment record
            attachment.delete()
            
            messages.success(request, f'Attachment "{attachment_name}" deleted successfully')
            
            return JsonResponse({
                'success': True,
                'message': f'Attachment "{attachment_name}" deleted successfully'
            })
            
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=500)
    
    return JsonResponse({'error': 'Method not allowed'}, status=405)

@login_required
@csrf_exempt
def api_search_studies(request):
    """API endpoint to search for studies to attach"""
    user = request.user
    query = request.GET.get('q', '').strip()
    patient_id = request.GET.get('patient_id')
    
    if len(query) < 2:
        return JsonResponse({'studies': []})
    
    # Base queryset based on user role
    if user.is_facility_user() and getattr(user, 'facility', None):
        studies = Study.objects.filter(facility=user.facility)
    else:
        studies = Study.objects.all()
    
    # Filter by patient if specified
    if patient_id:
        studies = studies.filter(patient__patient_id=patient_id)
    
    # Search query
    studies = studies.filter(
        Q(accession_number__icontains=query) |
        Q(patient__first_name__icontains=query) |
        Q(patient__last_name__icontains=query) |
        Q(study_description__icontains=query)
    ).select_related('patient', 'modality').order_by('-study_date')[:20]
    
    studies_data = []
    for study in studies:
        studies_data.append({
            'id': study.id,
            'accession_number': study.accession_number,
            'patient_name': study.patient.full_name,
            'patient_id': study.patient.patient_id,
            'study_date': study.study_date.strftime('%Y-%m-%d'),
            'modality': study.modality.code,
            'description': study.study_description
        })
    
    return JsonResponse({'studies': studies_data})

@login_required
@csrf_exempt
def api_update_study_status(request, study_id):
    """API endpoint to update study status"""
    if request.method != 'POST':
        return JsonResponse({'error': 'Method not allowed'}, status=405)
    
    study = get_object_or_404(Study, id=study_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and getattr(user, 'facility', None) and study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    try:
        data = json.loads(request.body)
        new_status = data.get('status', '').strip()
        
        # Validate status
        valid_statuses = ['scheduled', 'in_progress', 'completed', 'cancelled']
        if new_status not in valid_statuses:
            return JsonResponse({'error': 'Invalid status'}, status=400)
        
        # Update study status
        old_status = study.status
        study.status = new_status
        study.save()
        
        # Log the status change (if you have logging)
        # StudyStatusLog.objects.create(
        #     study=study,
        #     old_status=old_status,
        #     new_status=new_status,
        #     changed_by=user
        # )
        
        return JsonResponse({
            'success': True,
            'message': f'Study status updated from {old_status} to {new_status}',
            'old_status': old_status,
            'new_status': new_status
        })
        
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Invalid JSON data'}, status=400)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def api_delete_study(request, study_id):
    """API endpoint to delete a study (admin only)
    Accepts DELETE and POST (for environments where DELETE is blocked)."""
    if request.method not in ['DELETE', 'POST']:
        return JsonResponse({'error': 'Method not allowed'}, status=405)
    
    # Check if user is admin
    if not request.user.is_admin():
        return JsonResponse({'error': 'Permission denied. Only administrators can delete studies.'}, status=403)
    
    study = get_object_or_404(Study, id=study_id)
    
    try:
        # Store study info for logging
        study_info = {
            'id': study.id,
            'accession_number': study.accession_number,
            'patient_name': study.patient.full_name,
            'deleted_by': request.user.username
        }
        
        # Delete the study (this will cascade to related objects)
        study.delete()
        
        return JsonResponse({
            'success': True,
            'message': f'Study {study_info["accession_number"]} deleted successfully',
            'deleted_study': study_info
        })
        
    except Exception as e:
        return JsonResponse({'error': f'Failed to delete study: {str(e)}'}, status=500)

@login_required
def api_refresh_worklist(request):
    """API endpoint to refresh worklist and get latest studies"""
    user = request.user
    
    # Get recent studies (last 24 hours)
    from datetime import timedelta
    recent_cutoff = timezone.now() - timedelta(hours=24)
    
    if user.is_facility_user() and getattr(user, 'facility', None):
        studies = Study.objects.filter(facility=user.facility, upload_date__gte=recent_cutoff)
    else:
        studies = Study.objects.filter(upload_date__gte=recent_cutoff)
    
    studies_data = []
    for study in studies.order_by('-upload_date')[:20]:  # Last 20 uploaded studies
        studies_data.append({
            'id': study.id,
            'accession_number': study.accession_number,
            'patient_name': study.patient.full_name,
            'patient_id': study.patient.patient_id,
            'modality': study.modality.code,
            'status': study.status,
            'priority': study.priority,
            'study_date': study.study_date.isoformat(),
            'upload_date': study.upload_date.isoformat(),
            'facility': study.facility.name,
            'series_count': study.get_series_count(),
            'image_count': study.get_image_count(),
            'uploaded_by': study.uploaded_by.get_full_name() if study.uploaded_by else 'Unknown',
            'study_description': study.study_description,
        })
    
    return JsonResponse({
        'success': True, 
        'studies': studies_data,
        'total_recent': len(studies_data),
        'refresh_time': timezone.now().isoformat()
    })

@login_required
def api_get_upload_stats(request):
    """API endpoint to get upload statistics"""
    user = request.user
    
    # Get upload statistics for the last 7 days
    from datetime import timedelta
    week_ago = timezone.now() - timedelta(days=7)
    
    if user.is_facility_user() and getattr(user, 'facility', None):
        recent_studies = Study.objects.filter(facility=user.facility, upload_date__gte=week_ago)
    else:
        recent_studies = Study.objects.filter(upload_date__gte=week_ago)
    
    total_studies = recent_studies.count()
    total_series = sum(study.get_series_count() for study in recent_studies)
    total_images = sum(study.get_image_count() for study in recent_studies)
    
    # Group by modality
    modality_stats = {}
    for study in recent_studies:
        modality = study.modality.code
        modality_stats[modality] = modality_stats.get(modality, 0) + 1
    
    return JsonResponse({
        'success': True,
        'stats': {
            'total_studies': total_studies,
            'total_series': total_series,
            'total_images': total_images,
            'modality_breakdown': modality_stats,
            'period': '7 days'
        }
    })

@login_required
@csrf_exempt
def api_reassign_study_facility(request, study_id):
	"""Reassign a study to a facility (admin/radiologist only). Useful for recovering a lost study."""
	if request.method != 'POST':
		return JsonResponse({'error': 'Method not allowed'}, status=405)
	user = request.user
	if not (user.is_admin() or user.is_radiologist()):
		return JsonResponse({'error': 'Permission denied'}, status=403)
	study = get_object_or_404(Study, id=study_id)
	try:
		payload = json.loads(request.body)
		facility_id = str(payload.get('facility_id', '')).strip()
		if not facility_id:
			return JsonResponse({'error': 'facility_id is required'}, status=400)
		target = Facility.objects.filter(id=facility_id, is_active=True).first()
		if not target:
			return JsonResponse({'error': 'Target facility not found or inactive'}, status=404)
		old_fac = study.facility
		study.facility = target
		study.save(update_fields=['facility'])
		return JsonResponse({'success': True, 'message': 'Study reassigned', 'old_facility': old_fac.name, 'new_facility': target.name})
	except json.JSONDecodeError:
		return JsonResponse({'error': 'Invalid JSON data'}, status=400)
	except Exception as e:
		return JsonResponse({'error': str(e)}, status=500)

@login_required
@csrf_exempt
def api_update_clinical_info(request, study_id):
	"""API endpoint to create or update a study's clinical information"""
	if request.method != 'POST':
		return JsonResponse({'error': 'Method not allowed'}, status=405)
	
	study = get_object_or_404(Study, id=study_id)
	user = request.user
	
	# Check permissions
	if user.is_facility_user() and getattr(user, 'facility', None) and study.facility != user.facility:
		return JsonResponse({'error': 'Permission denied'}, status=403)
	
	try:
		new_info = ''
		if request.content_type and request.content_type.startswith('application/json'):
			payload = json.loads(request.body)
			new_info = (payload.get('clinical_info') or '').strip()
		else:
			new_info = (request.POST.get('clinical_info') or '').strip()
		
		old_info = study.clinical_info or ''
		study.clinical_info = new_info
		# Ensure auto_now updates last_updated when using update_fields
		study.save(update_fields=['clinical_info', 'last_updated'])
		
		return JsonResponse({
			'success': True,
			'message': 'Clinical information updated',
			'old_clinical_info': old_info,
			'clinical_info': study.clinical_info,
		})
	except json.JSONDecodeError:
		return JsonResponse({'error': 'Invalid JSON data'}, status=400)
	except Exception as e:
		return JsonResponse({'error': str(e)}, status=500)

def process_attachment_metadata(attachment):
    """Extract metadata from uploaded attachment"""
    try:
        file_path = attachment.file.path
        
        if attachment.file_type == 'dicom_study':
            # Extract DICOM metadata
            try:
                ds = pydicom.dcmread(file_path)
                attachment.study_date = getattr(ds, 'StudyDate', None)
                attachment.modality = getattr(ds, 'Modality', '')
                attachment.save()
            except Exception:
                pass
        
        elif attachment.file_type in ['pdf_document', 'word_document']:
            # Extract document metadata (would require additional libraries)
            # For now, just set basic info
            attachment.creation_date = timezone.now()
            attachment.save()
            
    except Exception:
        # If metadata extraction fails, continue silently
        pass

def generate_attachment_thumbnail(attachment):
    """Generate thumbnail for supported file types"""
    try:
        if attachment.file_type == 'image':
            # Generate thumbnail for images
            image = Image.open(attachment.file.path)
            image.thumbnail((200, 200), Image.Resampling.LANCZOS)
            
            # Save thumbnail
            thumb_io = BytesIO()
            image.save(thumb_io, format='PNG')
            thumb_file = ContentFile(thumb_io.getvalue())
            
            thumb_name = f"thumb_{attachment.id}.png"
            attachment.thumbnail.save(thumb_name, thumb_file, save=True)
            
        elif attachment.file_type == 'dicom_study':
            # Generate thumbnail for DICOM images
            try:
                ds = pydicom.dcmread(attachment.file.path)
                if hasattr(ds, 'pixel_array'):
                    pixel_array = ds.pixel_array
                    
                    # Normalize pixel values
                    pixel_array = ((pixel_array - pixel_array.min()) * 255 / 
                                 (pixel_array.max() - pixel_array.min())).astype('uint8')
                    
                    # Create PIL image and thumbnail
                    image = Image.fromarray(pixel_array, mode='L')
                    image.thumbnail((200, 200), Image.Resampling.LANCZOS)
                    
                    # Save thumbnail
                    thumb_io = BytesIO()
                    image.save(thumb_io, format='PNG')
                    thumb_file = ContentFile(thumb_io.getvalue())
                    
                    thumb_name = f"thumb_{attachment.id}.png"
                    attachment.thumbnail.save(thumb_name, thumb_file, save=True)
            except Exception:
                pass
                
    except Exception:
        # If thumbnail generation fails, continue silently
        pass

@login_required
def api_refresh_worklist(request):
	"""API endpoint for worklist refresh"""
	try:
		user = request.user
		
		if user.is_facility_user() and getattr(user, 'facility', None):
			recent_studies = Study.objects.filter(facility=user.facility, upload_date__gte=timezone.now() - timezone.timedelta(hours=1))
		else:
			recent_studies = Study.objects.filter(upload_date__gte=timezone.now() - timezone.timedelta(hours=1))
		
		return JsonResponse({
			'success': True,
			'total_recent': recent_studies.count(),
			'refresh_time': timezone.now().isoformat()
		})
	except Exception as e:
		return JsonResponse({'success': False, 'error': str(e)})

@login_required
def api_get_upload_stats(request):
	"""API endpoint for upload statistics"""
	try:
		user = request.user
		
		if user.is_facility_user() and getattr(user, 'facility', None):
			studies = Study.objects.filter(facility=user.facility)
		else:
			studies = Study.objects.all()
		
		total_studies = studies.count()
		total_series = sum(study.get_series_count() for study in studies[:100])  # Limit for performance
		total_images = sum(study.get_image_count() for study in studies[:100])  # Limit for performance
		
		return JsonResponse({
			'success': True,
			'stats': {
				'total_studies': total_studies,
				'total_series': total_series,
				'total_images': total_images
			}
		})
	except Exception as e:
		return JsonResponse({'success': False, 'error': str(e)})

@login_required
@csrf_exempt
def api_delete_study(request, study_id):
	"""API endpoint to delete a study (ADMIN ONLY)"""
	if request.method != 'DELETE':
		return JsonResponse({'error': 'Method not allowed'}, status=405)
	
	user = request.user
	
	# STRICT admin-only check
	if not (user.is_authenticated and 
			hasattr(user, 'role') and 
			user.role == 'admin' and 
			user.is_verified and 
			user.is_active):
		return JsonResponse({
			'error': 'UNAUTHORIZED: Only verified administrators can delete studies',
			'code': 'ADMIN_ONLY_DELETE',
			'user_role': getattr(user, 'role', 'unknown')
		}, status=403)
	
	try:
		study = get_object_or_404(Study, id=study_id)
		accession = study.accession_number
		
		# Delete study and all related data
		study.delete()
		
		return JsonResponse({
			'success': True,
			'message': f'Study {accession} deleted successfully'
		})
	except Exception as e:
		logger.error(f"Error deleting study {study_id}: {e}")
		return JsonResponse({'error': str(e)}, status=500)

def generate_attachment_thumbnail(attachment):
	"""Generate thumbnail for supported file types"""
	try:
		if attachment.file_type == 'image':
			# Generate thumbnail for images
			image = Image.open(attachment.file.path)
			image.thumbnail((200, 200), Image.Resampling.LANCZOS)
			
			# Save thumbnail
			thumb_io = BytesIO()
			image.save(thumb_io, format='PNG')
			thumb_file = ContentFile(thumb_io.getvalue())
			
			thumb_name = f"thumb_{attachment.id}.png"
			attachment.thumbnail.save(thumb_name, thumb_file, save=True)
			
		elif attachment.file_type == 'dicom_study':
			# Generate thumbnail for DICOM images
			try:
				ds = pydicom.dcmread(attachment.file.path)
				if hasattr(ds, 'pixel_array'):
					pixel_array = ds.pixel_array
					
					# Normalize pixel values
					pixel_array = ((pixel_array - pixel_array.min()) * 255 / 
								 (pixel_array.max() - pixel_array.min())).astype('uint8')
					
					# Create PIL image
					pil_image = Image.fromarray(pixel_array)
					pil_image.thumbnail((200, 200), Image.Resampling.LANCZOS)
					
					# Save thumbnail
					thumb_io = BytesIO()
					pil_image.save(thumb_io, format='PNG')
					thumb_file = ContentFile(thumb_io.getvalue())
					
					thumb_name = f"dicom_thumb_{attachment.id}.png"
					attachment.thumbnail.save(thumb_name, thumb_file, save=True)
					
			except Exception:
				pass
				
	except Exception:
		# If thumbnail generation fails, continue silently
		pass
