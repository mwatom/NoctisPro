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
from pathlib import Path
import pydicom
from PIL import Image
from io import BytesIO

from .models import (
    Study, Patient, Modality, Series, DicomImage, StudyAttachment, 
    AttachmentComment, AttachmentVersion
)
from accounts.models import User

@login_required
def dashboard(request):
    """Main dashboard view for the worklist - now shows patients"""
    user = request.user
    from datetime import date
    from django.db.models import Max, Count
    
    # Get patients with study counts and additional data
    if user.is_facility_user():
        patients_queryset = Patient.objects.filter(study__facility=user.facility).distinct()
    else:
        patients_queryset = Patient.objects.all()
    
    # Apply filters from request
    search = request.GET.get('search', '')
    gender = request.GET.get('gender', '')
    
    if search:
        patients_queryset = patients_queryset.filter(
            Q(first_name__icontains=search) |
            Q(last_name__icontains=search) |
            Q(patient_id__icontains=search) |
            Q(medical_record_number__icontains=search)
        )
    
    if gender:
        patients_queryset = patients_queryset.filter(gender=gender)
    
    # Annotate with study count and last study date
    patients = patients_queryset.annotate(
        study_count=Count('study'),
        last_study_date=Max('study__study_date')
    ).order_by('-last_study_date', 'last_name', 'first_name')
    
    # Add age calculation for each patient
    for patient in patients:
        if patient.date_of_birth:
            today = date.today()
            patient.age = today.year - patient.date_of_birth.year - (
                (today.month, today.day) < (patient.date_of_birth.month, patient.date_of_birth.day)
            )
        else:
            patient.age = 'Unknown'
    
    # Get unread notifications count
    try:
        unread_notifications_count = user.notifications.filter(is_read=False).count()
    except AttributeError:
        # Handle case where notifications app is not enabled or relationship doesn't exist
        unread_notifications_count = 0
    
    context = {
        'user': user,
        'patients': patients,
        'unread_notifications_count': unread_notifications_count,
    }
    
    return render(request, 'worklist/dashboard.html', context)

@login_required
def study_list(request):
    """List all studies with filtering and pagination"""
    user = request.user
    
    # Base queryset based on user role
    if user.is_facility_user():
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
    
    # Sort by study date (most recent first)
    studies = studies.select_related('patient', 'facility', 'modality', 'radiologist').order_by('-study_date')
    
    # Pagination
    paginator = Paginator(studies, 25)
    page_number = request.GET.get('page')
    studies_page = paginator.get_page(page_number)
    
    # Get available modalities for filter
    modalities = Modality.objects.filter(is_active=True)
    
    context = {
        'studies': studies_page,
        'modalities': modalities,
        'status_filter': status_filter,
        'priority_filter': priority_filter,
        'modality_filter': modality_filter,
        'search_query': search_query,
        'user': user,
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
def upload_study(request):
    """Upload new studies"""
    if request.method == 'POST':
        try:
            uploaded_files = request.FILES.getlist('dicom_files')
            
            if not uploaded_files:
                return JsonResponse({'success': False, 'error': 'No files uploaded'})
            
            # This would process DICOM files
            # For now, we'll simulate processing
            total_files = len(uploaded_files)
            processed_files = 0
            
            for file in uploaded_files:
                # Validate file type
                if not (file.name.lower().endswith('.dcm') or file.name.lower().endswith('.dicom')):
                    continue
                
                # This would save the file and create Study/Series/Image records
                processed_files += 1
            
            if processed_files == 0:
                return JsonResponse({'success': False, 'error': 'No valid DICOM files found'})
            
            return JsonResponse({
                'success': True, 
                'message': f'Successfully uploaded {processed_files} DICOM files',
                'processed_files': processed_files,
                'total_files': total_files
            })
            
        except Exception as e:
            return JsonResponse({'success': False, 'error': str(e)})
    
    return render(request, 'worklist/upload.html')

@login_required
def modern_worklist(request):
    """Modern worklist UI using the new dashboard layout"""
    return render(request, 'worklist/modern_worklist.html')

@login_required
def api_studies(request):
    """API endpoint for studies data"""
    user = request.user
    
    if user.is_facility_user():
        studies = Study.objects.filter(facility=user.facility)
    else:
        studies = Study.objects.all()
    
    studies_data = []
    for study in studies.order_by('-study_date')[:50]:
        studies_data.append({
            'id': study.id,
            'accession_number': study.accession_number,
            'patient_name': study.patient.full_name,
            'patient_id': study.patient.patient_id,
            'modality': study.modality.code,
            'status': study.status,
            'priority': study.priority,
            'study_date': study.study_date.isoformat(),
            'study_time': study.study_date.isoformat(),
            'facility': study.facility.name,
        })
    
    return JsonResponse({'success': True, 'studies': studies_data})

@login_required
@csrf_exempt
def upload_attachment(request, study_id):
    """Upload attachment to study"""
    study = get_object_or_404(Study, id=study_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
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
                
                # Link to previous study if specified
                if attach_previous_study_id:
                    try:
                        previous_study = Study.objects.get(id=attach_previous_study_id)
                        attachment.attached_study = previous_study
                        attachment.study_date = previous_study.study_date
                        attachment.modality = previous_study.modality.code
                        attachment.save()
                    except Study.DoesNotExist:
                        pass
                
                # Process file for metadata extraction
                process_attachment_metadata(attachment)
                
                # Generate thumbnail if possible
                generate_attachment_thumbnail(attachment)
                
                uploaded_attachments.append({
                    'id': attachment.id,
                    'name': attachment.name,
                    'type': attachment.file_type,
                    'size': attachment.file_size,
                    'url': attachment.file.url
                })
            
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
        'attachment_types': StudyAttachment.ATTACHMENT_TYPES,
    }
    
    return render(request, 'worklist/upload_attachment.html', context)

@login_required
def view_attachment(request, attachment_id):
    """View or download attachment"""
    attachment = get_object_or_404(StudyAttachment, id=attachment_id)
    user = request.user
    
    # Check permissions
    if user.is_facility_user() and attachment.study.facility != user.facility:
        messages.error(request, 'Permission denied')
        return redirect('worklist:study_list')
    
    # Check role-based permissions
    if not attachment.is_public and attachment.allowed_roles:
        user_role = user.role
        if user_role not in attachment.allowed_roles:
            messages.error(request, 'You do not have permission to view this attachment')
            return redirect('worklist:study_detail', study_id=attachment.study.id)
    
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
    
    # Check permissions
    if user.is_facility_user() and attachment.study.facility != user.facility:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    # Only allow deletion by uploader or admin
    if attachment.uploaded_by != user and not user.is_admin():
        return JsonResponse({'error': 'You can only delete your own attachments'}, status=403)
    
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
    if user.is_facility_user():
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
    if user.is_facility_user() and study.facility != user.facility:
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
