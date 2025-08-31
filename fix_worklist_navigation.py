#!/usr/bin/env python3
"""
Fix worklist navigation and remove unnecessary dialogues
"""

import os
import re
from datetime import datetime
import shutil

def backup_file(filepath):
    """Create a backup of the file before modifying"""
    backup_path = f"{filepath}.backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    shutil.copy2(filepath, backup_path)
    print(f"Backed up: {filepath} -> {backup_path}")
    return backup_path

def fix_worklist_navigation():
    """Fix the back to worklist button to directly navigate without complex logic"""
    template_path = "/workspace/templates/dicom_viewer/base.html"
    
    with open(template_path, 'r') as f:
        content = f.read()
    
    # Replace the returnToWorklist function with a simpler version
    new_return_function = '''      // Simple worklist navigation - direct redirect
      function returnToWorklist(e){
        if (e) e.preventDefault();
        // Check if we came from a specific page
        const referrer = document.referrer;
        if (referrer && referrer.includes('/worklist/')) {
          // Go back to the referring page
          window.location.href = referrer;
        } else {
          // Default to worklist dashboard
          window.location.href = '{% url 'worklist:dashboard' %}';
        }
        return false;
      }'''
    
    # Find and replace the returnToWorklist function
    pattern = r'// Worklist navigation.*?function returnToWorklist\(e\)\{.*?\n      \}'
    content = re.sub(pattern, new_return_function, content, flags=re.DOTALL)
    
    # Also update the button to remove the onclick handler and use a simple link
    content = content.replace(
        '<a id="btnBackWorklist" class="btn" href="{% url \'worklist:dashboard\' %}" onclick="return returnToWorklist(event)">',
        '<a id="btnBackWorklist" class="btn" href="{% url \'worklist:dashboard\' %}">'
    )
    
    with open(template_path, 'w') as f:
        f.write(content)
    
    print("Fixed worklist navigation")

def remove_unnecessary_toasts():
    """Remove or reduce unnecessary toast notifications"""
    template_path = "/workspace/templates/dicom_viewer/base.html"
    
    with open(template_path, 'r') as f:
        content = f.read()
    
    # List of toast messages to remove (keep only critical ones)
    unnecessary_toasts = [
        # Tool selection toasts - users can see which tool is active
        r"showToast\(`\$\{tool\.charAt.*?\}\s+tool selected`.*?\);?",
        r"showToast\('.*?tool selected'.*?\);?",
        
        # View state toasts - visual feedback is enough
        r"showToast\('Image inverted'.*?\);?",
        r"showToast\('View reset.*?'.*?\);?",
        r"showToast\('Fit to window'.*?\);?",
        r"showToast\('Image fitted.*?'.*?\);?",
        r"showToast\('1:1 view'.*?\);?", 
        r"showToast\('Zoom set to 1:1'.*?\);?",
        r"showToast\('Image centered'.*?\);?",
        r"showToast\('Image reloaded'.*?\);?",
        r"showToast\('Crosshair.*?'.*?\);?",
        r"showToast\('Spyglass.*?'.*?\);?",
        r"showToast\(crosshair \?.*?\);?",
        r"showToast\(spyglass\.active \?.*?\);?",
        
        # Cine mode - keep start/stop but remove FPS info
        r"showToast\(`Cine started at.*?\);?",
        
        # Window/level preset toasts
        r"showToast\('Preset saved'.*?\);?",
        r"showToast\('Preset loaded'.*?\);?",
        r"showToast\(`Applied.*?preset`.*?\);?",
        
        # DICOM tags - keep errors only
        r"showToast\('DICOM tags loaded successfully'.*?\);?",
        
        # Image capture - keep success only
        # Keep: showToast('Image captured successfully', 'success');
        
        # Reconstruction start messages - visual feedback is enough
        r"showToast\(`Starting.*?reconstruction`.*?\);?",
    ]
    
    # Remove unnecessary toasts
    for pattern in unnecessary_toasts:
        content = re.sub(pattern, '', content, flags=re.IGNORECASE | re.DOTALL)
    
    # Clean up empty lines created by removals
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)
    
    # Simplify some toasts to be less verbose
    replacements = [
        # Simplify cine messages
        (r"showToast\('Cine mode started'.*?\)", "showToast('Cine started', 'info', 800)"),
        (r"showToast\('Cine mode stopped'.*?\)", "showToast('Cine stopped', 'info', 800)"),
        
        # Shorten success messages
        (r"showToast\('Measurement saved successfully'.*?\)", "showToast('Saved', 'success', 800)"),
        (r"showToast\('Annotation added successfully'.*?\)", "showToast('Added', 'success', 800)"),
    ]
    
    for old, new in replacements:
        content = re.sub(old, new, content, flags=re.IGNORECASE)
    
    with open(template_path, 'w') as f:
        f.write(content)
    
    print("Removed unnecessary toast notifications")

def simplify_confirmations():
    """Simplify or remove unnecessary confirmations"""
    template_path = "/workspace/templates/dicom_viewer/base.html"
    
    with open(template_path, 'r') as f:
        content = f.read()
    
    # Find annotation prompt and make it simpler
    content = re.sub(
        r"const text = prompt\('Enter annotation text:'\);",
        "const text = prompt('Annotation:');",
        content
    )
    
    # Simplify the delete study confirmation
    content = re.sub(
        r"const confirmDelete = confirm\(`Are you sure.*?This action cannot be undone!`\);",
        "const confirmDelete = confirm('Delete this study? This cannot be undone.');",
        content,
        flags=re.DOTALL
    )
    
    with open(template_path, 'w') as f:
        f.write(content)
    
    print("Simplified confirmation dialogs")

def add_direct_navigation_script():
    """Add a script to handle direct navigation from worklist"""
    template_path = "/workspace/templates/dicom_viewer/base.html"
    
    with open(template_path, 'r') as f:
        content = f.read()
    
    # Add script to store referrer in session storage
    navigation_script = '''
    // Store the referrer for back navigation
    (function() {
      const referrer = document.referrer;
      if (referrer && referrer.includes('/worklist/')) {
        sessionStorage.setItem('worklistReferrer', referrer);
      }
      
      // Update back button href dynamically
      const backBtn = document.getElementById('btnBackWorklist');
      if (backBtn) {
        const storedReferrer = sessionStorage.getItem('worklistReferrer');
        if (storedReferrer) {
          backBtn.href = storedReferrer;
        }
      }
    })();
    '''
    
    # Insert after the main script starts
    content = content.replace(
        '(function(){',
        '(function(){\n' + navigation_script
    )
    
    with open(template_path, 'w') as f:
        f.write(content)
    
    print("Added direct navigation script")

def main():
    """Main function to apply all fixes"""
    print("Fixing worklist navigation and removing unnecessary dialogues...")
    print("=" * 60)
    
    # Backup the template
    template_path = "/workspace/templates/dicom_viewer/base.html"
    if os.path.exists(template_path):
        backup_file(template_path)
    
    # Apply fixes
    print("\nApplying fixes...")
    fix_worklist_navigation()
    remove_unnecessary_toasts()
    simplify_confirmations()
    add_direct_navigation_script()
    
    print("\n" + "=" * 60)
    print("Navigation fixes completed successfully!")
    print("\nChanges made:")
    print("1. Fixed back to worklist button to return to original page")
    print("2. Removed unnecessary toast notifications")
    print("3. Simplified confirmation dialogs")
    print("4. Added session storage for navigation history")
    print("\nThe viewer now has cleaner navigation and fewer interruptions!")

if __name__ == "__main__":
    main()