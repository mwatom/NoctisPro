#!/usr/bin/env python3
"""
UI Consistency Fix Script for NoctisPro
This script ensures all buttons and UI elements use consistent classes and styling.
"""

import os
import re
from pathlib import Path

class UIConsistencyFixer:
    def __init__(self):
        self.fixes_applied = 0
        self.files_processed = 0
        
        # Standard button class mappings
        self.button_replacements = {
            # Generic button classes to standardized ones
            r'class="btn btn-primary"': 'class="btn-medical"',
            r'class="btn btn-secondary"': 'class="btn-control"',
            r'class="btn btn-success"': 'class="btn-medical"',
            r'class="btn btn-info"': 'class="btn-control"',
            r'class="btn btn-warning"': 'class="btn-control"',
            r'class="btn btn-danger"': 'class="btn-control"',
            r'class="btn btn-outline-primary"': 'class="btn-control"',
            r'class="btn btn-outline-secondary"': 'class="btn-control"',
            
            # Common variations
            r'class="btn-primary"': 'class="btn-medical"',
            r'class="btn-secondary"': 'class="btn-control"',
            r'class="btn-success"': 'class="btn-medical"',
            r'class="btn-info"': 'class="btn-control"',
            
            # Form controls
            r'class="form-control"': 'class="form-control-medical"',
            r'class="form-select"': 'class="form-control-medical"',
            
            # Cards
            r'class="card"': 'class="card-medical"',
            r'class="card border"': 'class="card-medical"',
        }
        
        # CSS variable standardization
        self.css_variable_fixes = {
            r'#333333': 'var(--header-bg)',
            r'#252525': 'var(--card-surface)',
            r'#1a1a1a': 'var(--secondary-bg)',
            r'#0a0a0a': 'var(--primary-bg)',
            r'#00d4ff': 'var(--accent-color)',
            r'#ffffff': 'var(--text-primary)',
            r'#b3b3b3': 'var(--text-secondary)',
            r'#666666': 'var(--text-muted)',
            r'#404040': 'var(--border-color)',
        }
        
    def fix_template_file(self, file_path):
        """Fix UI consistency in a single template file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            original_content = content
            fixes_in_file = 0
            
            # Apply button class fixes
            for old_pattern, new_class in self.button_replacements.items():
                if re.search(old_pattern, content):
                    content = re.sub(old_pattern, new_class, content)
                    fixes_in_file += 1
                    
            # Apply CSS variable fixes
            for old_color, new_var in self.css_variable_fixes.items():
                if old_color in content:
                    content = content.replace(old_color, new_var)
                    fixes_in_file += 1
                    
            # Fix inconsistent spacing in buttons
            content = re.sub(r'<button\s+class="([^"]*)"([^>]*?)>\s*([^<]*?)\s*</button>', 
                           r'<button class="\1"\2>\3</button>', content)
            
            # Ensure all buttons have proper structure
            content = re.sub(r'<button([^>]*?)class="([^"]*?)"([^>]*?)onclick="([^"]*?)"([^>]*?)>', 
                           r'<button class="\2" onclick="\4"\1\3\5>', content)
            
            # Add consistent button hover effects
            if 'btn-medical' in content and 'btn-medical:hover' not in content:
                # This is handled by CSS, no need to add inline
                pass
                
            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                self.fixes_applied += fixes_in_file
                print(f"✅ Fixed {fixes_in_file} issues in {file_path}")
                return True
            else:
                print(f"✓ No issues found in {file_path}")
                return False
                
        except Exception as e:
            print(f"❌ Error processing {file_path}: {e}")
            return False
            
    def add_missing_css_variables(self, file_path):
        """Add missing CSS variables to template files"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            if '<style>' in content and ':root' not in content:
                # Add CSS variables if they're missing
                css_variables = '''
        :root {
            --primary-bg: #0a0a0a;
            --secondary-bg: #1a1a1a;
            --card-surface: #252525;
            --header-bg: #333333;
            --border-color: #404040;
            --accent-color: #00d4ff;
            --text-primary: #ffffff;
            --text-secondary: #b3b3b3;
            --text-muted: #666666;
            --success-color: #00ff88;
            --warning-color: #ffaa00;
            --danger-color: #ff4444;
        }
'''
                # Insert after opening style tag
                content = content.replace('<style>', f'<style>{css_variables}')
                
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"✅ Added CSS variables to {file_path}")
                return True
                
        except Exception as e:
            print(f"❌ Error adding CSS variables to {file_path}: {e}")
            
        return False
        
    def fix_button_functionality(self, file_path):
        """Ensure all buttons have proper onclick handlers"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            original_content = content
            
            # Fix common button patterns
            fixes = [
                # Ensure logout buttons work
                (r'<button([^>]*?)>.*?LOGOUT.*?</button>', 
                 lambda m: self.ensure_onclick(m.group(0), "window.location.href='{% url 'accounts:logout' %}'")),
                
                # Ensure navigation buttons work
                (r'<button([^>]*?)>.*?WORKLIST.*?</button>', 
                 lambda m: self.ensure_onclick(m.group(0), "window.location.href='{% url 'worklist:dashboard' %}'")),
                
                # Ensure admin buttons work
                (r'<button([^>]*?)>.*?ADMIN.*?</button>', 
                 lambda m: self.ensure_onclick(m.group(0), "window.location.href='{% url 'admin_panel:dashboard' %}'")),
            ]
            
            for pattern, replacement in fixes:
                content = re.sub(pattern, replacement, content, flags=re.IGNORECASE)
                
            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"✅ Fixed button functionality in {file_path}")
                return True
                
        except Exception as e:
            print(f"❌ Error fixing button functionality in {file_path}: {e}")
            
        return False
        
    def ensure_onclick(self, button_html, onclick_code):
        """Ensure a button has proper onclick handler"""
        if 'onclick=' in button_html:
            return button_html  # Already has onclick
        else:
            # Add onclick before closing >
            return button_html.replace('>', f' onclick="{onclick_code}">', 1)
            
    def process_templates(self):
        """Process all template files"""
        print("🔧 Starting UI Consistency Fixes...")
        
        template_dir = Path('templates')
        if not template_dir.exists():
            print("❌ Templates directory not found")
            return
            
        template_files = list(template_dir.rglob('*.html'))
        print(f"📁 Found {len(template_files)} template files")
        
        for template_file in template_files:
            self.files_processed += 1
            print(f"\n📄 Processing {template_file}...")
            
            # Apply fixes
            self.fix_template_file(template_file)
            self.add_missing_css_variables(template_file)
            self.fix_button_functionality(template_file)
            
    def create_global_css_file(self):
        """Create a global CSS file with consistent styles"""
        css_content = '''/* NoctisPro Global Styles - Production Ready */
:root {
    /* Unified color palette */
    --primary-bg: #0a0a0a;
    --secondary-bg: #1a1a1a;
    --card-surface: #252525;
    --header-bg: #333333;
    --border-color: #404040;
    --accent-color: #00d4ff;
    --text-primary: #ffffff;
    --text-secondary: #b3b3b3;
    --text-muted: #666666;
    --success-color: #00ff88;
    --warning-color: #ffaa00;
    --danger-color: #ff4444;
    
    /* Component-specific colors */
    --urgent-color: #ff0066;
    --scheduled-color: #4a90e2;
    --in-progress-color: #f5a623;
    --completed-color: #7ed321;
    --cancelled-color: #d0021b;
}

/* Global reset */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background: var(--primary-bg);
    color: var(--text-primary);
    line-height: 1.6;
    font-size: 12px;
}

/* Consistent button styles */
.btn-medical {
    background: linear-gradient(135deg, var(--accent-color) 0%, #00b8d4 100%);
    border: none;
    border-radius: 2px;
    color: white;
    font-weight: 500;
    padding: 12px 24px;
    cursor: pointer;
    transition: all 0.3s ease;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    font-size: 12px;
}

.btn-medical:hover {
    box-shadow: 0 6px 16px rgba(0, 212, 255, 0.25);
    transform: translateY(-1px);
    color: white;
}

.btn-control {
    background: var(--card-surface);
    border: 1px solid var(--border-color);
    color: var(--text-primary);
    padding: 8px 16px;
    border-radius: 2px;
    font-size: 11px;
    cursor: pointer;
    transition: all 0.2s ease;
    font-weight: 500;
}

.btn-control:hover {
    background: var(--accent-color);
    color: var(--primary-bg);
    border-color: var(--accent-color);
}

.btn-viewer {
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
}

.btn-viewer:hover {
    background: #00b8d4;
}

.btn-upload {
    background: var(--accent-color);
    color: var(--primary-bg);
    border: none;
    padding: 12px 24px;
    border-radius: 2px;
    font-weight: bold;
    cursor: pointer;
    font-size: 14px;
    transition: all 0.2s ease;
}

.btn-upload:hover {
    background: #00b8d4;
}

/* Form controls */
.form-control-medical {
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid var(--border-color);
    border-radius: 2px;
    color: var(--text-primary);
    padding: 12px 16px;
    transition: all 0.3s ease;
    font-size: 12px;
}

.form-control-medical:focus {
    border-color: var(--accent-color);
    box-shadow: 0 0 0 2px rgba(0, 212, 255, 0.1);
    outline: none;
}

/* Card styles */
.card-medical {
    background: var(--card-surface);
    border: 1px solid var(--border-color);
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    padding: 20px;
}

/* Navigation styles */
.nav-tab {
    padding: 8px 12px;
    background: var(--secondary-bg);
    border: 1px solid var(--border-color);
    border-radius: 2px;
    color: var(--text-secondary);
    font-weight: 600;
    letter-spacing: 0.5px;
    cursor: pointer;
    user-select: none;
    transition: all 0.2s ease;
}

.nav-tab.active,
.nav-tab:hover {
    background: var(--card-surface);
    color: var(--text-primary);
    border-color: var(--accent-color);
    box-shadow: 0 0 0 2px rgba(0, 212, 255, 0.1) inset;
}

/* Status indicators */
.status-online { color: var(--success-color); }
.status-offline { color: var(--danger-color); }
.status-warning { color: var(--warning-color); }

/* Responsive design */
@media (max-width: 768px) {
    .btn-medical,
    .btn-control,
    .btn-upload {
        padding: 8px 12px;
        font-size: 11px;
    }
    
    .card-medical {
        padding: 15px;
    }
}

/* Animation classes */
.fade-in {
    animation: fadeIn 0.3s ease-in;
}

@keyframes fadeIn {
    from { opacity: 0; transform: translateY(10px); }
    to { opacity: 1; transform: translateY(0); }
}

.slide-in {
    animation: slideIn 0.3s ease-out;
}

@keyframes slideIn {
    from { transform: translateX(-20px); opacity: 0; }
    to { transform: translateX(0); opacity: 1; }
}

/* Loading states */
.loading {
    opacity: 0.6;
    pointer-events: none;
}

.loading::after {
    content: '';
    position: absolute;
    top: 50%;
    left: 50%;
    width: 20px;
    height: 20px;
    margin: -10px 0 0 -10px;
    border: 2px solid var(--accent-color);
    border-radius: 50%;
    border-top-color: transparent;
    animation: spin 1s linear infinite;
}

@keyframes spin {
    to { transform: rotate(360deg); }
}'''

        css_file = Path('static/css/noctis-global.css')
        css_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(css_file, 'w', encoding='utf-8') as f:
            f.write(css_content)
            
        print(f"✅ Created global CSS file: {css_file}")
        
    def run_all_fixes(self):
        """Run all UI consistency fixes"""
        print("🚀 Starting UI Consistency Fixes for NoctisPro...")
        print("=" * 60)
        
        # Process templates
        self.process_templates()
        
        # Create global CSS
        self.create_global_css_file()
        
        # Summary
        print("\n" + "=" * 60)
        print("📊 UI CONSISTENCY SUMMARY")
        print("=" * 60)
        print(f"📁 Files processed: {self.files_processed}")
        print(f"🔧 Fixes applied: {self.fixes_applied}")
        print(f"✅ Global CSS created")
        
        if self.fixes_applied > 0:
            print(f"\n🎉 Applied {self.fixes_applied} UI consistency fixes!")
        else:
            print("\n✅ UI already consistent - no fixes needed!")
            
        print("\n📋 NEXT STEPS:")
        print("1. Include global CSS in base template:")
        print('   <link rel="stylesheet" href="{% static \'css/noctis-global.css\' %}">')
        print("2. Run collectstatic in production:")
        print("   python manage.py collectstatic --noinput")
        print("3. Test all buttons and UI elements")
        
        return True

if __name__ == '__main__':
    fixer = UIConsistencyFixer()
    fixer.run_all_fixes()