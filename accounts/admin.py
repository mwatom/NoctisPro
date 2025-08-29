from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User, Facility, UserSession

@admin.register(Facility)
class FacilityAdmin(admin.ModelAdmin):
    list_display = ('name', 'license_number', 'is_active', 'created_at')
    list_filter = ('is_active', 'created_at')
    search_fields = ('name', 'license_number', 'email')
    ordering = ('name',)

@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = ('username', 'email', 'first_name', 'last_name', 'role', 'facility', 'is_verified', 'is_active')
    list_filter = ('role', 'is_verified', 'is_active', 'facility', 'created_at')
    search_fields = ('username', 'email', 'first_name', 'last_name')
    ordering = ('username',)
    
    fieldsets = UserAdmin.fieldsets + (
        ('Noctis Pro Settings', {
            'fields': ('role', 'facility', 'phone', 'license_number', 'specialization', 'is_verified', 'last_login_ip')
        }),
    )
    
    add_fieldsets = UserAdmin.add_fieldsets + (
        ('Noctis Pro Settings', {
            'fields': ('role', 'facility', 'phone', 'license_number', 'specialization', 'is_verified')
        }),
    )
    
    def save_model(self, request, obj, form, change):
        # Auto-verify new users created through admin
        if not change:  # This is a new user
            obj.is_verified = True
        super().save_model(request, obj, form, change)

@admin.register(UserSession)
class UserSessionAdmin(admin.ModelAdmin):
    list_display = ('user', 'ip_address', 'login_time', 'logout_time', 'is_active')
    list_filter = ('is_active', 'login_time', 'logout_time')
    search_fields = ('user__username', 'ip_address')
    readonly_fields = ('user', 'session_key', 'ip_address', 'user_agent', 'login_time')
    ordering = ('-login_time',)
