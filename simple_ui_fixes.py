#!/usr/bin/env python3
"""
Simple UI Fixes Script
Fixes common button and window issues using simple string replacements
"""

import os
import re
from pathlib import Path

class SimpleUIFixer:
    def __init__(self):
        self.workspace_root = Path("/workspace")
        self.templates_dir = self.workspace_root / "templates"
        self.fixes_count = 0
        
    def fix_button_types_simple(self):
        """Fix button type attributes using simple replacements"""
        print("Fixing button type attributes...")
        
        template_files = list(self.templates_dir.rglob("*.html"))
        
        for template_file in template_files:
            try:
                with open(template_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                original_content = content
                
                # Simple replacements for common button patterns
                replacements = [
                    # Basic buttons without type
                    ('<button class=', '<button type="button" class='),
                    ('<button id=', '<button type="button" id='),
                    ('<button data-', '<button type="button" data-'),
                    ('<button onclick=', '<button type="button" onclick='),
                    ('<button style=', '<button type="button" style='),
                    # Submit buttons (form context)
                    ('<button type="button" class="btn-primary">Submit', '<button type="submit" class="btn-primary">Submit'),
                    ('<button type="button" class="btn-primary">Save', '<button type="submit" class="btn-primary">Save'),
                    ('<button type="button" class="btn">Submit', '<button type="submit" class="btn">Submit'),
                    ('<button type="button" class="btn">Save', '<button type="submit" class="btn">Save'),
                ]
                
                for old, new in replacements:
                    content = content.replace(old, new)
                
                # Avoid double type attributes
                content = content.replace('type="button" type="button"', 'type="button"')
                content = content.replace('type="submit" type="button"', 'type="submit"')
                content = content.replace('type="button" type="submit"', 'type="submit"')
                
                if content != original_content:
                    with open(template_file, 'w', encoding='utf-8') as f:
                        f.write(content)
                    
                    changes = abs(len(content.split('type="')) - len(original_content.split('type="')))
                    self.fixes_count += changes
                    print(f"  Fixed {changes} buttons in {template_file.name}")
                    
            except Exception as e:
                print(f"  Error fixing {template_file}: {e}")
    
    def add_aria_labels_simple(self):
        """Add ARIA labels to icon buttons using simple patterns"""
        print("Adding ARIA labels to icon buttons...")
        
        template_files = list(self.templates_dir.rglob("*.html"))
        
        for template_file in template_files:
            try:
                with open(template_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                original_content = content
                
                # Common icon button patterns and their labels
                icon_replacements = [
                    # Font Awesome icons
                    ('<i class="fas fa-plus"></i>', '<i class="fas fa-plus"></i>', 'Add'),
                    ('<i class="fas fa-edit"></i>', '<i class="fas fa-edit"></i>', 'Edit'),
                    ('<i class="fas fa-trash"></i>', '<i class="fas fa-trash"></i>', 'Delete'),
                    ('<i class="fas fa-times"></i>', '<i class="fas fa-times"></i>', 'Close'),
                    ('<i class="fas fa-save"></i>', '<i class="fas fa-save"></i>', 'Save'),
                    ('<i class="fas fa-download"></i>', '<i class="fas fa-download"></i>', 'Download'),
                    ('<i class="fas fa-upload"></i>', '<i class="fas fa-upload"></i>', 'Upload'),
                    ('<i class="fas fa-search"></i>', '<i class="fas fa-search"></i>', 'Search'),
                    ('<i class="fas fa-print"></i>', '<i class="fas fa-print"></i>', 'Print'),
                    ('<i class="fas fa-share"></i>', '<i class="fas fa-share"></i>', 'Share'),
                    ('<i class="fas fa-copy"></i>', '<i class="fas fa-copy"></i>', 'Copy'),
                    ('<i class="fas fa-refresh"></i>', '<i class="fas fa-refresh"></i>', 'Refresh'),
                    ('<i class="fas fa-sync"></i>', '<i class="fas fa-sync"></i>', 'Refresh'),
                    ('<i class="fas fa-home"></i>', '<i class="fas fa-home"></i>', 'Home'),
                    ('<i class="fas fa-back"></i>', '<i class="fas fa-back"></i>', 'Back'),
                    ('<i class="fas fa-arrow-left"></i>', '<i class="fas fa-arrow-left"></i>', 'Back'),
                    ('<i class="fas fa-play"></i>', '<i class="fas fa-play"></i>', 'Play'),
                    ('<i class="fas fa-pause"></i>', '<i class="fas fa-pause"></i>', 'Pause'),
                    ('<i class="fas fa-stop"></i>', '<i class="fas fa-stop"></i>', 'Stop'),
                    ('<i class="fas fa-expand"></i>', '<i class="fas fa-expand"></i>', 'Expand'),
                    ('<i class="fas fa-compress"></i>', '<i class="fas fa-compress"></i>', 'Compress'),
                    ('<i class="fas fa-zoom-in"></i>', '<i class="fas fa-zoom-in"></i>', 'Zoom In'),
                    ('<i class="fas fa-zoom-out"></i>', '<i class="fas fa-zoom-out"></i>', 'Zoom Out'),
                    ('<i class="fas fa-arrows-alt"></i>', '<i class="fas fa-arrows-alt"></i>', 'Pan'),
                    ('<i class="fas fa-crosshairs"></i>', '<i class="fas fa-crosshairs"></i>', 'Crosshair'),
                    ('<i class="fas fa-ruler"></i>', '<i class="fas fa-ruler"></i>', 'Measure'),
                    ('<i class="fas fa-comment"></i>', '<i class="fas fa-comment"></i>', 'Comment'),
                    ('<i class="fas fa-tags"></i>', '<i class="fas fa-tags"></i>', 'Tags'),
                    ('<i class="fas fa-info"></i>', '<i class="fas fa-info"></i>', 'Information'),
                    ('<i class="fas fa-cog"></i>', '<i class="fas fa-cog"></i>', 'Settings'),
                    ('<i class="fas fa-user"></i>', '<i class="fas fa-user"></i>', 'User'),
                    ('<i class="fas fa-users"></i>', '<i class="fas fa-users"></i>', 'Users'),
                    ('<i class="fas fa-cube"></i>', '<i class="fas fa-cube"></i>', '3D View'),
                    ('<i class="fas fa-film"></i>', '<i class="fas fa-film"></i>', 'Cine'),
                    ('<i class="fas fa-camera"></i>', '<i class="fas fa-camera"></i>', 'Capture'),
                    ('<i class="fas fa-adjust"></i>', '<i class="fas fa-adjust"></i>', 'Adjust'),
                    ('<i class="fas fa-robot"></i>', '<i class="fas fa-robot"></i>', 'AI Analysis'),
                    ('<i class="fas fa-undo"></i>', '<i class="fas fa-undo"></i>', 'Undo'),
                    ('<i class="fas fa-redo"></i>', '<i class="fas fa-redo"></i>', 'Redo'),
                ]
                
                # Add aria-label to buttons containing only icons
                for icon_html, _, label in icon_replacements:
                    # Look for buttons that contain this icon and don't have aria-label
                    button_pattern = f'<button([^>]*?)>{icon_html}</button>'
                    
                    def add_label(match):
                        attrs = match.group(1)
                        if 'aria-label=' not in attrs and 'title=' not in attrs:
                            return f'<button{attrs} aria-label="{label}">{icon_html}</button>'
                        return match.group(0)
                    
                    content = re.sub(button_pattern, add_label, content)
                
                if content != original_content:
                    with open(template_file, 'w', encoding='utf-8') as f:
                        f.write(content)
                    
                    changes = content.count('aria-label=') - original_content.count('aria-label=')
                    if changes > 0:
                        self.fixes_count += changes
                        print(f"  Added {changes} ARIA labels in {template_file.name}")
                        
            except Exception as e:
                print(f"  Error adding ARIA labels to {template_file}: {e}")
    
    def fix_modal_roles(self):
        """Add ARIA roles to modals"""
        print("Adding ARIA roles to modals...")
        
        template_files = list(self.templates_dir.rglob("*.html"))
        
        for template_file in template_files:
            try:
                with open(template_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                original_content = content
                
                # Simple modal role fixes
                modal_replacements = [
                    ('class="modal"', 'class="modal" role="dialog" aria-modal="true"'),
                    ('id="modal"', 'id="modal" role="dialog" aria-modal="true"'),
                    ('id="dicomModal"', 'id="dicomModal" role="dialog" aria-modal="true"'),
                    ('id="printModal"', 'id="printModal" role="dialog" aria-modal="true"'),
                    ('id="threeContainer"', 'id="threeContainer" role="dialog" aria-modal="true"'),
                ]
                
                for old, new in modal_replacements:
                    if old in content and 'role=' not in content[content.find(old):content.find(old)+100]:
                        content = content.replace(old, new)
                
                if content != original_content:
                    with open(template_file, 'w', encoding='utf-8') as f:
                        f.write(content)
                    
                    changes = content.count('role="dialog"') - original_content.count('role="dialog"')
                    if changes > 0:
                        self.fixes_count += changes
                        print(f"  Added {changes} modal roles in {template_file.name}")
                        
            except Exception as e:
                print(f"  Error fixing modal roles in {template_file}: {e}")
    
    def create_button_utilities(self):
        """Create JavaScript utilities for button functionality"""
        print("Creating button utility functions...")
        
        js_dir = self.workspace_root / "static" / "js"
        js_dir.mkdir(parents=True, exist_ok=True)
        
        js_content = '''/**
 * Button Utilities for Noctis Pro PACS
 * Provides enhanced button functionality and error handling
 */

// Prevent double-clicks on buttons
document.addEventListener('DOMContentLoaded', function() {
    let clickTimeout = {};
    
    // Add click protection to all buttons
    document.querySelectorAll('button, .btn, .btn-control, .tool').forEach(function(button) {
        button.addEventListener('click', function(e) {
            const buttonId = this.id || this.className || 'anonymous';
            
            // Prevent double-clicks
            if (clickTimeout[buttonId]) {
                e.preventDefault();
                e.stopPropagation();
                return false;
            }
            
            clickTimeout[buttonId] = true;
            setTimeout(() => {
                delete clickTimeout[buttonId];
            }, 300);
        }, true);
        
        // Add keyboard support
        button.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                this.click();
            }
        });
        
        // Add focus management
        button.addEventListener('focus', function() {
            this.setAttribute('data-focused', 'true');
        });
        
        button.addEventListener('blur', function() {
            this.removeAttribute('data-focused');
        });
    });
    
    // Add loading state management
    window.setButtonLoading = function(button, isLoading) {
        if (typeof button === 'string') {
            button = document.querySelector(button);
        }
        
        if (!button) return;
        
        if (isLoading) {
            button.disabled = true;
            button.classList.add('loading');
            button.setAttribute('aria-busy', 'true');
        } else {
            button.disabled = false;
            button.classList.remove('loading');
            button.removeAttribute('aria-busy');
        }
    };
    
    // Safe error handling for button clicks
    window.safeButtonHandler = function(handler) {
        return function(event) {
            try {
                return handler.call(this, event);
            } catch (error) {
                console.error('Button handler error:', error);
                
                // Show user-friendly error
                const message = 'An error occurred. Please try again.';
                if (typeof showNotification === 'function') {
                    showNotification(message, 'error');
                } else {
                    alert(message);
                }
                
                return false;
            }
        };
    };
    
    // Enhanced modal handling
    window.openModal = function(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.style.display = 'flex';
            modal.setAttribute('aria-hidden', 'false');
            
            // Focus first focusable element
            const focusable = modal.querySelector('button, input, select, textarea, [tabindex]:not([tabindex="-1"])');
            if (focusable) {
                focusable.focus();
            }
            
            // Trap focus within modal
            modal.addEventListener('keydown', function(e) {
                if (e.key === 'Escape') {
                    closeModal(modalId);
                }
            });
        }
    };
    
    window.closeModal = function(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.style.display = 'none';
            modal.setAttribute('aria-hidden', 'true');
        }
    };
    
    console.log('Button utilities loaded successfully');
});'''
        
        js_file = js_dir / "button-utils.js"
        with open(js_file, 'w', encoding='utf-8') as f:
            f.write(js_content)
        
        print(f"  Created {js_file}")
        self.fixes_count += 1
    
    def update_css_styles(self):
        """Update CSS with better button styles"""
        print("Updating CSS button styles...")
        
        css_files = [
            self.workspace_root / "static" / "css" / "noctis-dashboard-style.css",
            self.workspace_root / "staticfiles" / "css" / "noctis-dashboard-style.css"
        ]
        
        additional_css = '''
/* Enhanced Button States */
.btn:focus,
.btn-control:focus,
.tool:focus {
    outline: 2px solid var(--accent-color);
    outline-offset: 2px;
}

.btn:disabled,
.btn-control:disabled,
.tool:disabled {
    opacity: 0.6 !important;
    cursor: not-allowed !important;
    pointer-events: none !important;
}

.btn.loading,
.btn-control.loading {
    position: relative;
    color: transparent !important;
}

.btn.loading::after,
.btn-control.loading::after {
    content: '';
    position: absolute;
    top: 50%;
    left: 50%;
    width: 16px;
    height: 16px;
    margin: -8px 0 0 -8px;
    border: 2px solid var(--text-secondary);
    border-top: 2px solid var(--accent-color);
    border-radius: 50%;
    animation: spin 1s linear infinite;
}

@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

/* Better hover states */
.btn:hover:not(:disabled):not(.loading),
.btn-control:hover:not(:disabled):not(.loading),
.tool:hover:not(.active):not(:disabled):not(.loading) {
    transform: translateY(-1px);
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
}

.btn:active:not(:disabled),
.btn-control:active:not(:disabled),
.tool:active:not(:disabled) {
    transform: translateY(0);
}

/* Modal improvements */
[role="dialog"] {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 1000;
}

[role="dialog"][aria-hidden="true"] {
    display: none !important;
}
'''
        
        for css_file in css_files:
            if css_file.exists():
                try:
                    with open(css_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    if '/* Enhanced Button States */' not in content:
                        content += '\n' + additional_css
                        
                        with open(css_file, 'w', encoding='utf-8') as f:
                            f.write(content)
                        
                        print(f"  Updated {css_file.name}")
                        self.fixes_count += 1
                        
                except Exception as e:
                    print(f"  Error updating {css_file}: {e}")
    
    def run_all_fixes(self):
        """Run all fixes"""
        print("="*60)
        print("RUNNING SIMPLE UI FIXES")
        print("="*60)
        
        self.fix_button_types_simple()
        self.add_aria_labels_simple()
        self.fix_modal_roles()
        self.create_button_utilities()
        self.update_css_styles()
        
        print(f"\n✅ Total fixes applied: {self.fixes_count}")
        print("\nNext steps:")
        print("1. Test the application to ensure all buttons work")
        print("2. Verify modals open and close properly")
        print("3. Check accessibility with screen reader")
        print("4. Validate CSS changes don't break styling")

def main():
    fixer = SimpleUIFixer()
    fixer.run_all_fixes()

if __name__ == "__main__":
    main()