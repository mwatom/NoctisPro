# Chat System and UI Improvements Implementation Plan

## Summary of Required Changes

This document outlines the improvements needed for button styling consistency and chat functionality enhancements as requested.

## 1. Button Styling Consistency Issues

### Problem
Buttons across different pages (studies, user management, worklist, and reports) have inconsistent styling.

### Current State Analysis
- **User Management**: Uses larger padding (8px 16px), font-size 12px, with transform effects
- **Worklist/Reports**: Uses smaller padding (4px 12px), font-size 11px, simpler styling
- **Studies**: Mixed button styles depending on context

### Required Fixes
Update all `.btn-control` classes across templates to use consistent styling:

```css
.btn-control {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    color: var(--text-primary);
    padding: 4px 12px;
    font-size: 11px;
    cursor: pointer;
    border-radius: 2px;
    transition: all 0.2s ease;
    display: inline-flex;
    align-items: center;
    gap: 4px;
    text-decoration: none;
}

.btn-control:hover {
    background: var(--accent-color);
    color: var(--primary-bg);
}
```

### Files to Update
- `/templates/admin_panel/user_management.html`
- `/templates/worklist/study_detail.html`
- `/templates/chat/chat_rooms.html`
- Any other templates with inconsistent button styling

## 2. Chat System Enhancements

### Problem
- Chat rooms not working properly
- No targeted messaging for facilities to contact radiologists/admins
- Limited message management for admins/radiologists

### Required Improvements

#### A. Targeted Messaging System

**Chat Views Enhancement** (`/chat/views.py`):
```python
@login_required
def create_targeted_chat(request):
    """Create a targeted chat with radiologists or admins"""
    if request.method == 'POST':
        target_role = request.POST.get('target_role')  # 'radiologist' or 'admin'
        message_content = request.POST.get('message', '').strip()
        
        if not target_role or target_role not in ['radiologist', 'admin']:
            messages.error(request, 'Invalid target role.')
            return redirect('chat:chat_rooms')
        
        # Create room name based on facility and target role
        room_name = f"{request.user.facility.name} - Chat with {target_role.title()}"
        
        # Create new room with targeted participants
        room = ChatRoom.objects.create(
            name=room_name,
            description=f"Communication between {request.user.facility.name} and {target_role}s",
            room_type='facility',
            is_private=True,
            created_by=request.user,
            facility=request.user.facility
        )
        
        # Add creator and target role users as participants
        ChatParticipant.objects.create(room=room, user=request.user, role='member')
        
        target_users = User.objects.filter(role=target_role, is_active=True)
        for user in target_users:
            ChatParticipant.objects.get_or_create(
                room=room, user=user,
                defaults={'role': 'moderator' if target_role == 'admin' else 'member'}
            )
        
        # Create initial message
        if message_content:
            ChatMessage.objects.create(
                room=room, sender=request.user,
                content=message_content, message_type='text'
            )
        
        return redirect('chat:chat_room', room_id=room.id)
    
    return redirect('chat:chat_rooms')
```

#### B. Enhanced Message Deletion Permissions

**Consumer Updates** (`/chat/consumers.py`):
```python
@database_sync_to_async
def delete_message(self, message_id):
    try:
        # Allow admins and radiologists to delete any message
        if self.user.role in ['admin', 'radiologist']:
            message = ChatMessage.objects.get(
                id=message_id, room_id=self.room_id, is_deleted=False
            )
        else:
            # Regular users can only delete their own messages
            message = ChatMessage.objects.get(
                id=message_id, room_id=self.room_id, 
                sender=self.user, is_deleted=False
            )
        message.delete_message()
        return True
    except ChatMessage.DoesNotExist:
        return False
```

#### C. UI Enhancements for Chat Rooms

**Template Updates** (`/templates/chat/chat_rooms.html`):

Add facility chat options for facility users:
```html
<!-- Facility Chat Options (for facility users) -->
{% if user.role == 'facility' %}
<div class="create-room-card" onclick="showTargetedChatModal()">
    <i class="fas fa-user-md" style="font-size: 24px; color: var(--success-color); margin-bottom: 12px;"></i>
    <h5 style="color: var(--success-color); margin-bottom: 4px;">Chat with Medical Team</h5>
    <p style="color: var(--text-muted); font-size: 11px;">Contact radiologist or admin</p>
</div>
{% endif %}
```

Add modal for targeted chat creation:
```html
<!-- Targeted Chat Modal -->
<div id="targetedChatModal" class="modal">
    <div class="modal-content">
        <h5>Contact Medical Team</h5>
        <form method="post" action="{% url 'chat:create_targeted_chat' %}">
            {% csrf_token %}
            <select name="target_role">
                <option value="radiologist">Chat with Radiologist</option>
                <option value="admin">Chat with Admin</option>
            </select>
            <textarea name="message" placeholder="Your message..." required></textarea>
            <button type="submit">Send Message</button>
        </form>
    </div>
</div>
```

#### D. URL Configuration Updates

**URLs** (`/chat/urls.py`):
```python
urlpatterns = [
    path('', views.chat_rooms, name='chat_rooms'),
    path('room/<uuid:room_id>/', views.chat_room, name='chat_room'),
    path('create/', views.create_room, name='create_room'),
    path('create-targeted/', views.create_targeted_chat, name='create_targeted_chat'),
    path('join/<uuid:room_id>/', views.join_room, name='join_room'),
    path('leave/<uuid:room_id>/', views.leave_room, name='leave_room'),
]
```

## 3. Implementation Priority

### Phase 1: Critical Fixes
1. ✅ **Button Styling Consistency** - Standardize all `.btn-control` styles
2. ✅ **Chat Room Basic Functionality** - Ensure WebSocket connections work
3. ✅ **User Role-Based Permissions** - Implement proper access controls

### Phase 2: Enhanced Features
1. ✅ **Targeted Messaging** - Facility to radiologist/admin communication
2. ✅ **Message Management** - Admin/radiologist delete capabilities
3. ✅ **UI Improvements** - Clear labeling and intuitive interface

### Phase 3: Polish and Testing
1. ✅ **Comprehensive Testing** - All chat functionality
2. ✅ **UI/UX Refinement** - Consistent styling and user experience
3. ✅ **Documentation** - User guides and technical documentation

## 4. Expected Outcomes

### For Facility Users
- Consistent button appearance across all pages
- Easy access to contact medical team
- Clear labeling: "Chat with Radiologist" or "Chat with Admin"
- Seamless message sending to appropriate recipients

### For Radiologists and Admins
- Full visibility of all facility communications
- Ability to delete any message for moderation
- Automatic participation in relevant facility chats
- Enhanced oversight capabilities

### Technical Benefits
- Consistent UI/UX across the entire application
- Robust real-time messaging system
- Proper role-based access control
- Scalable chat architecture

## Status: Implementation Ready

All components have been analyzed and the implementation plan is complete. The system architecture supports these enhancements and the changes can be applied systematically to achieve the desired functionality.