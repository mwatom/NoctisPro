#!/usr/bin/env python3
"""
UI Issues Fix Script
Automatically fixes common button and window functionality issues identified in the static analysis
"""

import os
import re
import json
from pathlib import Path
from collections import defaultdict

class UIIssueFixer:
    def __init__(self):
        self.workspace_root = Path("/workspace")
        self.templates_dir = self.workspace_root / "templates"
        self.fixes_applied = defaultdict(list)
        self.backup_dir = self.workspace_root / "ui_fixes_backup"
        self.backup_dir.mkdir(exist_ok=True)
        
    def create_backup(self, file_path):
        """Create backup of file before modifying"""
        backup_path = self.backup_dir / file_path.name
        counter = 1
        while backup_path.exists():
            backup_path = self.backup_dir / f"{file_path.stem}_{counter}{file_path.suffix}"
            counter += 1
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            with open(backup_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return backup_path
        except Exception as e:
            print(f"Failed to create backup for {file_path}: {e}")
            return None
    
    def fix_button_type_attributes(self):
        """Fix missing type attributes on buttons"""
        print("Fixing missing button type attributes...")
        
        template_files = list(self.templates_dir.rglob("*.html"))
        
        for template_file in template_files:
            try:
                with open(template_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                original_content = content
                
                # Find buttons without type attribute
                button_pattern = r'<button([^>]*?)(?<!type=["\'][^"\']*["\'])([^>]*?)>'
                
                def add_type_attribute(match):
                    attrs_before = match.group(1)
                    attrs_after = match.group(2)
                    
                    # Check if this is likely a submit button (in form context or has submit-related class/id)
                    full_match = match.group(0)
                    if ('submit' in full_match.lower() or 
                        'form' in attrs_before.lower() or 
                        'form' in attrs_after.lower()):
                        return f'<button{attrs_before} type="submit"{attrs_after}>'
                    else:
                        return f'<button{attrs_before} type="button"{attrs_after}>'
                
                content = re.sub(button_pattern, add_type_attribute, content)
                
                if content != original_content:
                    backup_path = self.create_backup(template_file)
                    if backup_path:
                        with open(template_file, 'w', encoding='utf-8') as f:
                            f.write(content)
                        
                        changes = content.count('type="button"') + content.count('type="submit"') - original_content.count('type="button"') - original_content.count('type="submit"')
                        self.fixes_applied["button_type_attributes"].append({
                            "file": str(template_file.relative_to(self.workspace_root)),
                            "changes": changes,
                            "backup": str(backup_path.relative_to(self.workspace_root))
                        })
                        
            except Exception as e:
                print(f"Error fixing {template_file}: {e}")
    
    def fix_button_accessibility(self):
        """Fix accessibility issues with buttons"""
        print("Fixing button accessibility issues...")
        
        template_files = list(self.templates_dir.rglob("*.html"))
        
        for template_file in template_files:
            try:
                with open(template_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                original_content = content
                changes_made = 0
                
                # Find buttons with only icons and no text
                icon_button_pattern = r'<button([^>]*?)>(\s*<i[^>]*class=["\'][^"\']*fa[^"\']*["\'][^>]*></i>\s*)</button>'
                
                def add_aria_label(match):
                    nonlocal changes_made
                    attrs = match.group(1)
                    icon_html = match.group(2)
                    
                    # Skip if already has aria-label or title
                    if 'aria-label' in attrs or 'title' in attrs:
                        return match.group(0)
                    
                    # Extract icon class to determine purpose
                    icon_match = re.search(r'fa-([^\s"\']+)', icon_html)
                    if icon_match:
                        icon_name = icon_match.group(1)
                        
                        # Map common icon names to labels
                        icon_labels = {
                            'plus': 'Add',
                            'edit': 'Edit', 
                            'pencil': 'Edit',
                            'trash': 'Delete',
                            'times': 'Close',
                            'close': 'Close',
                            'save': 'Save',
                            'download': 'Download',
                            'upload': 'Upload',
                            'search': 'Search',
                            'filter': 'Filter',
                            'sort': 'Sort',
                            'print': 'Print',
                            'share': 'Share',
                            'copy': 'Copy',
                            'cut': 'Cut',
                            'paste': 'Paste',
                            'undo': 'Undo',
                            'redo': 'Redo',
                            'refresh': 'Refresh',
                            'sync': 'Refresh',
                            'home': 'Home',
                            'back': 'Back',
                            'forward': 'Forward',
                            'play': 'Play',
                            'pause': 'Pause',
                            'stop': 'Stop',
                            'expand': 'Expand',
                            'compress': 'Compress',
                            'zoom-in': 'Zoom In',
                            'zoom-out': 'Zoom Out',
                            'arrows-alt': 'Pan',
                            'crosshairs': 'Crosshair',
                            'ruler': 'Measure',
                            'comment': 'Comment',
                            'tags': 'Tags',
                            'info': 'Information',
                            'cog': 'Settings',
                            'gear': 'Settings',
                            'user': 'User',
                            'users': 'Users',
                            'hospital': 'Facility',
                            'cube': '3D View',
                            'film': 'Cine',
                            'camera': 'Capture',
                            'adjust': 'Adjust',
                            'robot': 'AI Analysis'
                        }
                        
                        label = icon_labels.get(icon_name, icon_name.replace('-', ' ').title())
                        changes_made += 1
                        return f'<button{attrs} aria-label="{label}">{icon_html}</button>'
                    
                    return match.group(0)
                
                content = re.sub(icon_button_pattern, add_aria_label, content)
                
                if content != original_content:
                    backup_path = self.create_backup(template_file)
                    if backup_path:
                        with open(template_file, 'w', encoding='utf-8') as f:
                            f.write(content)
                        
                        self.fixes_applied["accessibility_labels"].append({
                            "file": str(template_file.relative_to(self.workspace_root)),
                            "changes": changes_made,
                            "backup": str(backup_path.relative_to(self.workspace_root))
                        })
                        
            except Exception as e:
                print(f"Error fixing accessibility in {template_file}: {e}")
    
    def fix_modal_accessibility(self):
        """Fix accessibility issues with modals"""
        print("Fixing modal accessibility issues...")
        
        template_files = list(self.templates_dir.rglob("*.html"))
        
        for template_file in template_files:
            try:
                with open(template_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                original_content = content
                changes_made = 0
                
                # Fix modals without proper ARIA roles
                modal_pattern = r'<div([^>]*?)(?:class=["\'][^"\']*modal[^"\']*["\']|id=["\'][^"\']*modal[^"\']*["\'])([^>]*?)>'
                
                def add_modal_aria(match):
                    nonlocal changes_made
                    attrs_before = match.group(1)
                    attrs_after = match.group(2)
                    
                    full_attrs = attrs_before + attrs_after
                    
                    # Skip if already has role
                    if 'role=' in full_attrs:
                        return match.group(0)
                    
                    changes_made += 1
                    return f'<div{attrs_before} role="dialog" aria-modal="true"{attrs_after}>'
                
                content = re.sub(modal_pattern, add_modal_aria, content)
                
                if content != original_content:
                    backup_path = self.create_backup(template_file)
                    if backup_path:
                        with open(template_file, 'w', encoding='utf-8') as f:
                            f.write(content)
                        
                        self.fixes_applied["modal_accessibility"].append({
                            "file": str(template_file.relative_to(self.workspace_root)),
                            "changes": changes_made,
                            "backup": str(backup_path.relative_to(self.workspace_root))
                        })
                        
            except Exception as e:
                print(f"Error fixing modal accessibility in {template_file}: {e}")
    
    def add_css_button_states(self):
        """Add missing hover and disabled states to CSS"""
        print("Adding missing CSS button states...")
        
        css_files = [
            self.workspace_root / "static" / "css" / "noctis-dashboard-style.css",
            self.workspace_root / "staticfiles" / "css" / "noctis-dashboard-style.css"
        ]
        
        button_state_css = """
/* Enhanced button states for better UX */
.btn:hover:not(:disabled),
.btn-control:hover:not(:disabled),
.tool:hover:not(.active):not(:disabled) {
    transform: translateY(-1px);
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
    transition: all 0.2s ease;
}

.btn:disabled,
.btn-control:disabled,
.tool:disabled {
    opacity: 0.6;
    cursor: not-allowed;
    pointer-events: none;
}

.btn:active:not(:disabled),
.btn-control:active:not(:disabled),
.tool:active:not(:disabled) {
    transform: translateY(0);
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
}

/* Focus states for accessibility */
.btn:focus,
.btn-control:focus,
.tool:focus {
    outline: 2px solid var(--accent-color);
    outline-offset: 2px;
}

/* Loading state for buttons */
.btn.loading,
.btn-control.loading {
    position: relative;
    color: transparent;
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
"""
        
        for css_file in css_files:
            if css_file.exists():
                try:
                    with open(css_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # Check if button states already exist
                    if 'Enhanced button states' not in content:
                        backup_path = self.create_backup(css_file)
                        if backup_path:
                            # Append the button states CSS
                            content += "\n" + button_state_css
                            
                            with open(css_file, 'w', encoding='utf-8') as f:
                                f.write(content)
                            
                            self.fixes_applied["css_button_states"].append({
                                "file": str(css_file.relative_to(self.workspace_root)),
                                "backup": str(backup_path.relative_to(self.workspace_root))
                            })
                            
                except Exception as e:
                    print(f"Error fixing CSS in {css_file}: {e}")
    
    def add_javascript_error_handling(self):
        """Add error handling to JavaScript button handlers"""
        print("Adding JavaScript error handling...")
        
        # Create a utility JavaScript file for button error handling
        js_utility_content = """
// Button utility functions for error handling and UX improvements
(function() {
    'use strict';
    
    // Add loading state to buttons
    function setButtonLoading(button, loading = true) {
        if (loading) {
            button.classList.add('loading');
            button.disabled = true;
        } else {
            button.classList.remove('loading');
            button.disabled = false;
        }
    }
    
    // Safe click handler wrapper
    function safeClickHandler(handler) {
        return function(event) {
            try {
                return handler.call(this, event);
            } catch (error) {
                console.error('Button click handler error:', error);
                // Show user-friendly error message
                if (typeof showNotification === 'function') {
                    showNotification('An error occurred. Please try again.', 'error');
                }
                return false;
            }
        };
    }
    
    // Debounce function to prevent double-clicks
    function debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }
    
    // Initialize button enhancements
    document.addEventListener('DOMContentLoaded', function() {
        // Add double-click protection to all buttons
        document.querySelectorAll('button, .btn, .btn-control').forEach(button => {
            let clicking = false;
            
            button.addEventListener('click', function(e) {
                if (clicking) {
                    e.preventDefault();
                    e.stopPropagation();
                    return false;
                }
                
                clicking = true;
                setTimeout(() => { clicking = false; }, 300);
            }, true);
            
            // Add keyboard support
            button.addEventListener('keydown', function(e) {
                if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    this.click();
                }
            });
        });
        
        // Add ARIA live region for dynamic content
        if (!document.getElementById('aria-live-region')) {
            const liveRegion = document.createElement('div');
            liveRegion.id = 'aria-live-region';
            liveRegion.setAttribute('aria-live', 'polite');
            liveRegion.setAttribute('aria-atomic', 'true');
            liveRegion.style.position = 'absolute';
            liveRegion.style.left = '-10000px';
            liveRegion.style.width = '1px';
            liveRegion.style.height = '1px';
            liveRegion.style.overflow = 'hidden';
            document.body.appendChild(liveRegion);
        }
    });
    
    // Export utilities globally
    window.ButtonUtils = {
        setLoading: setButtonLoading,
        safeHandler: safeClickHandler,
        debounce: debounce
    };
})();
"""
        
        js_file = self.workspace_root / "static" / "js" / "button-utils.js"
        js_file.parent.mkdir(parents=True, exist_ok=True)
        
        try:
            with open(js_file, 'w', encoding='utf-8') as f:
                f.write(js_utility_content)
            
            self.fixes_applied["javascript_utilities"].append({
                "file": str(js_file.relative_to(self.workspace_root)),
                "description": "Button utility functions for error handling and UX"
            })
            
        except Exception as e:
            print(f"Error creating JavaScript utilities: {e}")
    
    def update_base_template(self):
        """Update base template to include the new JavaScript utilities"""
        print("Updating base template...")
        
        base_template = self.workspace_root / "templates" / "base.html"
        
        if base_template.exists():
            try:
                with open(base_template, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Check if button-utils.js is already included
                if 'button-utils.js' not in content:
                    backup_path = self.create_backup(base_template)
                    if backup_path:
                        # Add the script tag before closing body tag
                        script_tag = '    <script src="{% static \'js/button-utils.js\' %}"></script>\n</body>'
                        content = content.replace('</body>', script_tag)
                        
                        with open(base_template, 'w', encoding='utf-8') as f:
                            f.write(content)
                        
                        self.fixes_applied["base_template_update"].append({
                            "file": str(base_template.relative_to(self.workspace_root)),
                            "backup": str(backup_path.relative_to(self.workspace_root)),
                            "change": "Added button-utils.js script"
                        })
                        
            except Exception as e:
                print(f"Error updating base template: {e}")
    
    def run_all_fixes(self):
        """Run all UI fixes"""
        print("Starting comprehensive UI fixes...")
        
        self.fix_button_type_attributes()
        self.fix_button_accessibility()
        self.fix_modal_accessibility()
        self.add_css_button_states()
        self.add_javascript_error_handling()
        self.update_base_template()
        
        return dict(self.fixes_applied)
    
    def generate_fix_report(self):
        """Generate report of all fixes applied"""
        fixes = self.run_all_fixes()
        
        report = {
            "fix_summary": {
                "timestamp": __import__("time").strftime("%Y-%m-%d %H:%M:%S"),
                "total_fix_categories": len(fixes),
                "backup_directory": str(self.backup_dir.relative_to(self.workspace_root))
            },
            "fixes_applied": fixes,
            "next_steps": [
                "Test all fixed buttons and modals manually",
                "Verify accessibility improvements with screen reader",
                "Check that CSS changes don't break existing styling",
                "Test JavaScript utilities in browser console",
                "Run the application and verify all functionality works"
            ]
        }
        
        # Calculate totals
        total_files_modified = 0
        total_changes = 0
        
        for category, category_fixes in fixes.items():
            total_files_modified += len(category_fixes)
            for fix in category_fixes:
                if isinstance(fix, dict) and "changes" in fix:
                    total_changes += fix["changes"]
        
        report["fix_summary"]["total_files_modified"] = total_files_modified
        report["fix_summary"]["total_changes"] = total_changes
        
        return report

def main():
    """Main function to run UI fixes"""
    fixer = UIIssueFixer()
    
    try:
        report = fixer.generate_fix_report()
        
        # Save report
        with open('/workspace/ui_fixes_report.json', 'w') as f:
            json.dump(report, f, indent=2)
        
        # Print summary
        print("\n" + "="*60)
        print("UI FIXES SUMMARY")
        print("="*60)
        print(f"Total Files Modified: {report['fix_summary']['total_files_modified']}")
        print(f"Total Changes Made: {report['fix_summary']['total_changes']}")
        print(f"Backup Directory: {report['fix_summary']['backup_directory']}")
        
        print("\nFixes Applied:")
        for category, fixes in report['fixes_applied'].items():
            print(f"  - {category.replace('_', ' ').title()}: {len(fixes)} files")
        
        print("\nNext Steps:")
        for step in report['next_steps']:
            print(f"  - {step}")
        
        print(f"\nDetailed report saved to: /workspace/ui_fixes_report.json")
        
    except Exception as e:
        print(f"Error during fixes: {e}")

if __name__ == "__main__":
    main()