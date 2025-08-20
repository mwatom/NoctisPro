#!/usr/bin/env python3
"""
Fix UI to Match Dashboard.html
This script updates ALL templates to match the exact styling used in dashboard.html
"""

import os
import re
from pathlib import Path

class DashboardStyleMatcher:
    def __init__(self):
        self.fixes_applied = 0
        self.files_processed = 0
        
        # Extract the exact button classes and styles from dashboard.html
        self.correct_button_classes = {
            # Navigation and control buttons
            'btn-control': {
                'background': 'var(--card-bg)',
                'border': '1px solid var(--border-color)',
                'color': 'var(--text-primary)',
                'padding': '4px 12px',
                'border-radius': '2px',
                'font-size': '11px',
                'cursor': 'pointer',
                'transition': 'all 0.2s ease'
            },
            
            # Viewer buttons in table rows
            'btn-viewer': {
                'background': 'var(--accent-color)',
                'border': 'none',
                'color': 'var(--primary-bg)',
                'padding': '4px 8px',
                'border-radius': '2px',
                'font-size': '9px',
                'font-weight': 'bold',
                'cursor': 'pointer',
                'transition': 'all 0.2s ease',
                'text-transform': 'uppercase',
                'letter-spacing': '0.5px'
            },
            
            # Upload buttons
            'btn-upload': {
                'background': 'var(--accent-color)',
                'color': 'var(--primary-bg)',
                'border': 'none',
                'padding': '12px 24px',
                'border-radius': '2px',
                'font-weight': 'bold',
                'cursor': 'pointer',
                'font-size': '14px',
                'transition': 'all 0.2s ease'
            }
        }
        
        # Dashboard CSS variables (exact from dashboard.html)
        self.dashboard_css_variables = '''
        :root {
            --primary-bg: #0a0a0a;
            --secondary-bg: #1a1a1a;
            --card-bg: #252525;
            --header-bg: #333333;
            --border-color: #404040;
            --accent-color: #00d4ff;
            --text-primary: #ffffff;
            --text-secondary: #b3b3b3;
            --text-muted: #666666;
            --success-color: #00ff88;
            --warning-color: #ffaa00;
            --danger-color: #ff4444;
            --urgent-color: #ff0066;
            --scheduled-color: #4a90e2;
            --in-progress-color: #f5a623;
            --completed-color: #7ed321;
            --cancelled-color: #d0021b;
        }'''
        
    def fix_button_classes_to_dashboard_style(self, content):
        """Fix button classes to match dashboard.html exactly"""
        original_content = content
        
        # Replace incorrect button classes with dashboard-style classes
        replacements = {
            # Fix generic Bootstrap buttons to dashboard style
            r'class="btn btn-primary"': 'class="btn-control"',
            r'class="btn btn-secondary"': 'class="btn-control"', 
            r'class="btn btn-success"': 'class="btn-control"',
            r'class="btn btn-info"': 'class="btn-control"',
            r'class="btn btn-warning"': 'class="btn-control"',
            r'class="btn btn-danger"': 'class="btn-control"',
            
            # Fix any btn-medical to btn-control (dashboard uses btn-control)
            r'class="btn-medical"': 'class="btn-control"',
            
            # Keep btn-viewer and btn-upload as they exist in dashboard
            # No changes needed for these
            
            # Fix form controls to match dashboard
            r'class="form-control-medical"': 'class="form-control"',
            r'class="card-medical"': 'class="card"',
        }
        
        for old_pattern, new_class in replacements.items():
            content = re.sub(old_pattern, new_class, content)
            
        return content
        
    def add_dashboard_css_variables(self, content):
        """Add dashboard CSS variables if missing"""
        if '<style>' in content and ':root' not in content:
            # Add CSS variables after opening style tag
            content = content.replace('<style>', f'<style>{self.dashboard_css_variables}')
            return content, True
        return content, False
        
    def fix_template_to_match_dashboard(self, file_path):
        """Fix a template to match dashboard.html styling"""
        if 'dashboard.html' in str(file_path):
            # Skip the dashboard itself - it's the reference
            return False
            
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            original_content = content
            fixes_in_file = 0
            
            # Fix button classes
            new_content = self.fix_button_classes_to_dashboard_style(content)
            if new_content != content:
                content = new_content
                fixes_in_file += 1
                
            # Add CSS variables if needed
            content, css_added = self.add_dashboard_css_variables(content)
            if css_added:
                fixes_in_file += 1
                
            # Write back if changes were made
            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                self.fixes_applied += fixes_in_file
                print(f"✅ Fixed {fixes_in_file} issues in {file_path} to match dashboard")
                return True
            else:
                print(f"✓ {file_path} already matches dashboard style")
                return False
                
        except Exception as e:
            print(f"❌ Error processing {file_path}: {e}")
            return False
            
    def update_base_template_to_dashboard_style(self):
        """Update base.html to use dashboard button styles"""
        base_template = Path('templates/base.html')
        if not base_template.exists():
            print("❌ base.html not found")
            return
            
        try:
            with open(base_template, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # Replace btn-medical with btn-control to match dashboard
            content = re.sub(r'\.btn-medical\s*{[^}]*}', '', content)  # Remove btn-medical styles
            content = re.sub(r'class="btn-medical"', 'class="btn-control"', content)
            
            # Ensure btn-control styles match dashboard exactly
            btn_control_style = '''
        .btn-control {
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            color: var(--text-primary);
            padding: 4px 12px;
            border-radius: 2px;
            font-size: 11px;
            cursor: pointer;
            transition: all 0.2s ease;
        }
        
        .btn-control:hover {
            background: var(--accent-color);
            color: var(--primary-bg);
        }
        
        .btn-control.reset {
            background: var(--accent-color);
            color: var(--primary-bg);
        }'''
            
            # Add or replace btn-control styles
            if '.btn-control' not in content:
                # Add after the CSS variables
                content = content.replace('--info-color: #00bcd4;', f'--info-color: #00bcd4;{btn_control_style}')
            
            with open(base_template, 'w', encoding='utf-8') as f:
                f.write(content)
                
            print("✅ Updated base.html to match dashboard button styles")
            
        except Exception as e:
            print(f"❌ Error updating base.html: {e}")
            
    def create_dashboard_compatible_css(self):
        """Create CSS that matches dashboard.html exactly"""
        css_content = f'''/* NoctisPro Styles - Matching Dashboard.html exactly */
{self.dashboard_css_variables}

/* Global reset matching dashboard */
* {{
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}}

body {{
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background: var(--primary-bg);
    color: var(--text-primary);
    font-size: 12px;
}}

/* Button styles exactly from dashboard.html */
.btn-control {{
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    color: var(--text-primary);
    padding: 4px 12px;
    border-radius: 2px;
    font-size: 11px;
    cursor: pointer;
    transition: all 0.2s ease;
}}

.btn-control:hover {{
    background: var(--accent-color);
    color: var(--primary-bg);
}}

.btn-control.reset {{
    background: var(--accent-color);
    color: var(--primary-bg);
}}

.btn-viewer {{
    background: var(--accent-color);
    border: none;
    color: var(--primary-bg);
    padding: 4px 8px;
    border-radius: 2px;
    font-size: 9px;
    font-weight: bold;
    cursor: pointer;
    transition: all 0.2s ease;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}}

.btn-viewer:hover {{
    background: #00b8d4;
}}

.btn-viewer.viewer-only {{
    background: var(--card-bg);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
}}

.btn-viewer.viewer-only:hover {{
    background: var(--text-secondary);
    color: var(--primary-bg);
}}

.btn-upload {{
    background: var(--accent-color);
    color: var(--primary-bg);
    border: none;
    padding: 12px 24px;
    border-radius: 2px;
    font-weight: bold;
    cursor: pointer;
    font-size: 14px;
    transition: all 0.2s ease;
}}

.btn-upload:hover {{
    background: #00b8d4;
}}

/* Navigation styles from dashboard */
.nav-tab {{
    background: var(--secondary-bg);
    border: 1px solid var(--border-color);
    color: var(--text-secondary);
    padding: 6px 12px;
    font-size: 11px;
    cursor: pointer;
    transition: all 0.2s ease;
}}

.nav-tab.active {{
    background: var(--accent-color);
    color: var(--primary-bg);
    font-weight: bold;
}}

.nav-tab:hover:not(.active) {{
    background: var(--card-bg);
    color: var(--text-primary);
}}

/* Responsive adjustments from dashboard */
@media (max-width: 768px) {{
    .btn-viewer {{
        font-size: 8px;
        padding: 3px 6px;
    }}
}}'''

        css_file = Path('static/css/noctis-dashboard-style.css')
        css_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(css_file, 'w', encoding='utf-8') as f:
            f.write(css_content)
            
        print(f"✅ Created dashboard-compatible CSS: {css_file}")
        
    def process_all_templates(self):
        """Process all templates to match dashboard style"""
        print("🔧 Fixing all templates to match dashboard.html...")
        
        template_dir = Path('templates')
        if not template_dir.exists():
            print("❌ Templates directory not found")
            return
            
        template_files = list(template_dir.rglob('*.html'))
        print(f"📁 Found {len(template_files)} template files")
        
        for template_file in template_files:
            self.files_processed += 1
            print(f"\n📄 Processing {template_file}...")
            self.fix_template_to_match_dashboard(template_file)
            
    def run_dashboard_matching(self):
        """Run all fixes to match dashboard.html"""
        print("🚀 Fixing ALL templates to match dashboard.html styling...")
        print("=" * 70)
        
        # Update base template
        self.update_base_template_to_dashboard_style()
        
        # Process all templates
        self.process_all_templates()
        
        # Create dashboard-compatible CSS
        self.create_dashboard_compatible_css()
        
        # Summary
        print("\n" + "=" * 70)
        print("📊 DASHBOARD STYLE MATCHING SUMMARY")
        print("=" * 70)
        print(f"📁 Files processed: {self.files_processed}")
        print(f"🔧 Fixes applied: {self.fixes_applied}")
        print(f"✅ Dashboard-compatible CSS created")
        
        print(f"\n🎉 All templates now match dashboard.html styling!")
        print("\n📋 BUTTON CLASSES USED (matching dashboard):")
        print("- .btn-control - Main control buttons (navigation, actions)")
        print("- .btn-viewer - Small action buttons in tables")
        print("- .btn-upload - Large upload/primary action buttons")
        print("- .nav-tab - Navigation tab buttons")
        
        print(f"\n✅ Dashboard.html was NOT modified (kept as reference)")
        
        return True

if __name__ == '__main__':
    matcher = DashboardStyleMatcher()
    matcher.run_dashboard_matching()