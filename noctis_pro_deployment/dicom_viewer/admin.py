from django.contrib import admin
from .models import HangingProtocol, WindowLevelPreset

@admin.register(HangingProtocol)
class HangingProtocolAdmin(admin.ModelAdmin):
	list_display = ('name', 'modality', 'body_part', 'layout', 'is_default')
	list_filter = ('modality', 'body_part', 'is_default')
	search_fields = ('name', 'modality', 'body_part')

@admin.register(WindowLevelPreset)
class WindowLevelPresetAdmin(admin.ModelAdmin):
	list_display = ('user', 'name', 'modality', 'body_part', 'window_width', 'window_level', 'inverted')
	list_filter = ('modality', 'body_part', 'inverted')
	search_fields = ('name', 'user__username')
