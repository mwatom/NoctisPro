from django import template

register = template.Library()

@register.filter
def get_item(dictionary, key):
    """Get item from dictionary by key"""
    if not dictionary:
        return None
    return dictionary.get(key)

@register.filter  
def get_attr(obj, attr_name):
    """Get attribute from object"""
    if not obj:
        return None
    return getattr(obj, attr_name, None)

@register.filter
def dict_get(dictionary, key):
    """Alternative name for get_item"""
    return get_item(dictionary, key)

@register.filter
def getattribute(obj, attr_name):
    """Alternative name for get_attr"""
    return get_attr(obj, attr_name)