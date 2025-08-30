#!/usr/bin/env python3
"""
Static UI Analysis Script
Analyzes HTML templates and JavaScript files to identify potential button and window issues
"""

import os
import re
import json
from pathlib import Path
from collections import defaultdict

class StaticUIAnalyzer:
    def __init__(self):
        self.workspace_root = Path("/workspace")
        self.templates_dir = self.workspace_root / "templates"
        self.issues = defaultdict(list)
        self.button_inventory = defaultdict(list)
        
    def analyze_templates(self):
        """Analyze all HTML templates for button and window issues"""
        print("Analyzing HTML templates...")
        
        template_files = list(self.templates_dir.rglob("*.html"))
        
        for template_file in template_files:
            try:
                with open(template_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                    self.analyze_template_content(template_file, content)
            except Exception as e:
                self.issues["file_read_errors"].append(f"{template_file}: {str(e)}")
    
    def analyze_template_content(self, file_path, content):
        """Analyze individual template content"""
        relative_path = file_path.relative_to(self.workspace_root)
        
        # Find all buttons
        button_patterns = [
            r'<button[^>]*>(.*?)</button>',
            r'<input[^>]*type=["\']submit["\'][^>]*>',
            r'<input[^>]*type=["\']button["\'][^>]*>',
            r'<a[^>]*class=["\'][^"\']*btn[^"\']*["\'][^>]*>',
            r'<div[^>]*class=["\'][^"\']*btn[^"\']*["\'][^>]*>',
        ]
        
        for pattern in button_patterns:
            matches = re.finditer(pattern, content, re.IGNORECASE | re.DOTALL)
            for match in matches:
                button_html = match.group(0)
                self.analyze_button(relative_path, button_html, match.start())
        
        # Find modals and dialogs
        modal_patterns = [
            r'<div[^>]*class=["\'][^"\']*modal[^"\']*["\'][^>]*>',
            r'<div[^>]*id=["\'][^"\']*modal[^"\']*["\'][^>]*>',
            r'<dialog[^>]*>',
        ]
        
        for pattern in modal_patterns:
            matches = re.finditer(pattern, content, re.IGNORECASE)
            for match in matches:
                modal_html = match.group(0)
                self.analyze_modal(relative_path, modal_html, match.start())
        
        # Check for JavaScript event handlers
        js_patterns = [
            r'onclick=["\'][^"\']*["\']',
            r'addEventListener\(["\']click["\']',
            r'\.click\(',
            r'\.on\(["\']click["\']',
        ]
        
        for pattern in js_patterns:
            matches = re.finditer(pattern, content, re.IGNORECASE)
            for match in matches:
                self.button_inventory["js_handlers"].append({
                    "file": str(relative_path),
                    "handler": match.group(0),
                    "line": content[:match.start()].count('\n') + 1
                })
    
    def analyze_button(self, file_path, button_html, position):
        """Analyze individual button for potential issues"""
        issues = []
        
        # Check for missing accessibility attributes
        if 'aria-label' not in button_html and 'title' not in button_html:
            # Check if button has visible text
            text_match = re.search(r'<button[^>]*>(.*?)</button>', button_html, re.DOTALL)
            if text_match:
                text_content = re.sub(r'<[^>]+>', '', text_match.group(1)).strip()
                if not text_content:
                    issues.append("Button lacks accessible text or aria-label")
        
        # Check for disabled buttons without proper styling
        if 'disabled' in button_html and 'disabled:' not in button_html:
            issues.append("Disabled button may lack proper styling")
        
        # Check for missing click handlers
        has_onclick = 'onclick' in button_html
        has_id = re.search(r'id=["\']([^"\']+)["\']', button_html)
        has_class = re.search(r'class=["\']([^"\']+)["\']', button_html)
        
        if not has_onclick and not has_id and not has_class:
            issues.append("Button may lack click handler")
        
        # Check for proper button type
        if '<button' in button_html and 'type=' not in button_html:
            issues.append("Button missing explicit type attribute")
        
        # Record button info
        button_info = {
            "file": str(file_path),
            "html": button_html[:100] + "..." if len(button_html) > 100 else button_html,
            "issues": issues,
            "has_id": bool(has_id),
            "has_class": bool(has_class),
            "has_onclick": has_onclick
        }
        
        self.button_inventory["buttons"].append(button_info)
        
        if issues:
            self.issues["button_issues"].extend([f"{file_path}: {issue}" for issue in issues])
    
    def analyze_modal(self, file_path, modal_html, position):
        """Analyze modal windows for potential issues"""
        issues = []
        
        # Check for proper modal structure
        if 'role="dialog"' not in modal_html and 'role="modal"' not in modal_html:
            issues.append("Modal lacks proper ARIA role")
        
        # Check for close button accessibility
        if 'aria-label' not in modal_html or 'close' not in modal_html.lower():
            issues.append("Modal may lack accessible close button")
        
        # Record modal info
        modal_info = {
            "file": str(file_path),
            "html": modal_html[:100] + "..." if len(modal_html) > 100 else modal_html,
            "issues": issues
        }
        
        self.button_inventory["modals"].append(modal_info)
        
        if issues:
            self.issues["modal_issues"].extend([f"{file_path}: {issue}" for issue in issues])
    
    def check_css_button_styles(self):
        """Check CSS files for button styling issues"""
        print("Analyzing CSS files...")
        
        css_files = list(self.workspace_root.rglob("*.css"))
        
        for css_file in css_files:
            try:
                with open(css_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                    self.analyze_css_content(css_file, content)
            except Exception as e:
                self.issues["css_read_errors"].append(f"{css_file}: {str(e)}")
    
    def analyze_css_content(self, file_path, content):
        """Analyze CSS content for button styling issues"""
        relative_path = file_path.relative_to(self.workspace_root)
        
        # Check for button hover states
        button_selectors = re.findall(r'(\.btn[^{]*|button[^{]*)\s*{', content, re.IGNORECASE)
        hover_selectors = re.findall(r'(\.btn[^{]*:hover|button[^{]*:hover)\s*{', content, re.IGNORECASE)
        
        if button_selectors and not hover_selectors:
            self.issues["css_issues"].append(f"{relative_path}: Buttons may lack hover states")
        
        # Check for disabled button styles
        disabled_selectors = re.findall(r'(\.btn[^{]*:disabled|button[^{]*:disabled)\s*{', content, re.IGNORECASE)
        
        if button_selectors and not disabled_selectors:
            self.issues["css_issues"].append(f"{relative_path}: Buttons may lack disabled states")
    
    def check_javascript_handlers(self):
        """Check JavaScript files for button event handlers"""
        print("Analyzing JavaScript files...")
        
        js_files = list(self.workspace_root.rglob("*.js"))
        
        for js_file in js_files:
            try:
                with open(js_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                    self.analyze_js_content(js_file, content)
            except Exception as e:
                self.issues["js_read_errors"].append(f"{js_file}: {str(e)}")
    
    def analyze_js_content(self, file_path, content):
        """Analyze JavaScript content for event handler issues"""
        relative_path = file_path.relative_to(self.workspace_root)
        
        # Find event listeners
        event_patterns = [
            r'addEventListener\(["\']click["\'][^)]*\)',
            r'\.on\(["\']click["\'][^)]*\)',
            r'\.click\([^)]*\)',
            r'onclick\s*=\s*["\'][^"\']*["\']',
        ]
        
        handlers_found = []
        for pattern in event_patterns:
            matches = re.finditer(pattern, content, re.IGNORECASE)
            handlers_found.extend([match.group(0) for match in matches])
        
        if handlers_found:
            self.button_inventory["js_files"].append({
                "file": str(relative_path),
                "handlers_count": len(handlers_found),
                "handlers": handlers_found[:5]  # First 5 handlers
            })
    
    def generate_button_inventory(self):
        """Generate comprehensive button inventory"""
        inventory = {
            "summary": {
                "total_buttons": len(self.button_inventory["buttons"]),
                "total_modals": len(self.button_inventory["modals"]),
                "total_js_handlers": len(self.button_inventory["js_handlers"]),
                "total_issues": sum(len(issues) for issues in self.issues.values())
            },
            "buttons_by_file": defaultdict(list),
            "modals_by_file": defaultdict(list),
            "common_button_classes": defaultdict(int),
            "accessibility_issues": [],
            "functionality_issues": []
        }
        
        # Group buttons by file
        for button in self.button_inventory["buttons"]:
            file_name = button["file"]
            inventory["buttons_by_file"][file_name].append(button)
            
            # Extract button classes
            class_match = re.search(r'class=["\']([^"\']+)["\']', button["html"])
            if class_match:
                classes = class_match.group(1).split()
                for cls in classes:
                    if 'btn' in cls:
                        inventory["common_button_classes"][cls] += 1
            
            # Categorize issues
            for issue in button.get("issues", []):
                if "accessible" in issue or "aria" in issue:
                    inventory["accessibility_issues"].append(f"{file_name}: {issue}")
                else:
                    inventory["functionality_issues"].append(f"{file_name}: {issue}")
        
        # Group modals by file
        for modal in self.button_inventory["modals"]:
            file_name = modal["file"]
            inventory["modals_by_file"][file_name].append(modal)
        
        return inventory
    
    def run_analysis(self):
        """Run complete static analysis"""
        print("Starting static UI analysis...")
        
        self.analyze_templates()
        self.check_css_button_styles()
        self.check_javascript_handlers()
        
        inventory = self.generate_button_inventory()
        
        return {
            "issues": dict(self.issues),
            "inventory": inventory,
            "button_details": dict(self.button_inventory)
        }
    
    def generate_report(self):
        """Generate analysis report"""
        results = self.run_analysis()
        
        report = {
            "analysis_summary": {
                "timestamp": __import__("time").strftime("%Y-%m-%d %H:%M:%S"),
                "files_analyzed": {
                    "templates": len(list(self.templates_dir.rglob("*.html"))),
                    "css_files": len(list(self.workspace_root.rglob("*.css"))),
                    "js_files": len(list(self.workspace_root.rglob("*.js")))
                },
                "total_issues": sum(len(issues) for issues in results["issues"].values()),
                "total_buttons": results["inventory"]["summary"]["total_buttons"],
                "total_modals": results["inventory"]["summary"]["total_modals"]
            },
            "critical_issues": [],
            "recommendations": [],
            "detailed_results": results
        }
        
        # Identify critical issues
        for issue_type, issues in results["issues"].items():
            if "accessibility" in issue_type or "handler" in issue_type:
                report["critical_issues"].extend(issues)
        
        # Generate recommendations
        if results["inventory"]["accessibility_issues"]:
            report["recommendations"].append("Add proper ARIA labels and accessible text to buttons")
        
        if results["inventory"]["functionality_issues"]:
            report["recommendations"].append("Ensure all buttons have proper click handlers")
        
        if results["issues"].get("css_issues"):
            report["recommendations"].append("Add hover and disabled states to button styles")
        
        return report

def main():
    """Main function to run static analysis"""
    analyzer = StaticUIAnalyzer()
    
    try:
        report = analyzer.generate_report()
        
        # Save report
        with open('/workspace/static_ui_analysis_report.json', 'w') as f:
            json.dump(report, f, indent=2)
        
        # Print summary
        print("\n" + "="*60)
        print("STATIC UI ANALYSIS SUMMARY")
        print("="*60)
        print(f"Files Analyzed:")
        print(f"  - Templates: {report['analysis_summary']['files_analyzed']['templates']}")
        print(f"  - CSS Files: {report['analysis_summary']['files_analyzed']['css_files']}")
        print(f"  - JS Files: {report['analysis_summary']['files_analyzed']['js_files']}")
        print(f"Total Issues Found: {report['analysis_summary']['total_issues']}")
        print(f"Total Buttons Found: {report['analysis_summary']['total_buttons']}")
        print(f"Total Modals Found: {report['analysis_summary']['total_modals']}")
        
        print("\nCritical Issues:")
        for issue in report['critical_issues'][:10]:  # Show first 10
            print(f"  - {issue}")
        
        print("\nRecommendations:")
        for rec in report['recommendations']:
            print(f"  - {rec}")
        
        print(f"\nDetailed report saved to: /workspace/static_ui_analysis_report.json")
        
    except Exception as e:
        print(f"Error during analysis: {e}")

if __name__ == "__main__":
    main()