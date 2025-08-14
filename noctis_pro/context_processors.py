from django.conf import settings


def global_settings(request):
    """Expose selected settings to all templates."""
    return {
        'PUBLIC_BASE_URL': getattr(settings, 'PUBLIC_BASE_URL', ''),
    }