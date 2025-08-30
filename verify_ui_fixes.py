#!/usr/bin/env python3
"""
UI Fixes Verification Script
Verifies that all button and window functionality fixes have been applied correctly
"""

import os
import re
import json
from pathlib import Path
from collections import defaultdict

class UIFixesVerifier:
    def __init__(self):
        self.workspace_root = Path("/workspace")
        self.templates_dir = self.workspace_root / "templates"
        self.verification_results = defaultdict(list)
        
    def verify_button_types(self):
        """Verify that buttons have proper type attributes"""
        print("Verifying button type attributes...")
        
        template_files = list(self.templates_dir.rglob("*.html"))
        total_buttons = 0
        buttons_with_type = 0
        buttons_without_type = []
        
        for template_file in template_files:
            try:
                with open(template_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Find all button tags
                button_matches = re.finditer(r'<button[^>]*>', content, re.IGNORECASE)
                
                for match in button_matches:
                    total_buttons += 1
                    button_html = match.group(0)
                    
                    if 'type=' in button_html:
                        buttons_with_type += 1
                    else:
                        buttons_without_type.append({
                            "file": str(template_file.relative_to(self.workspace_root)),
                            "button": button_html[:100] + "..." if len(button_html) > 100 else button_html
                        })
                        
            except Exception as e:
                print(f"  Error verifying {template_file}: {e}")
        
        self.verification_results["button_types"] = {
            "total_buttons": total_buttons,
            "buttons_with_type": buttons_with_type,
            "buttons_without_type": len(buttons_without_type),
            "missing_type_buttons": buttons_without_type[:10],  # Show first 10
            "percentage_fixed": (buttons_with_type / total_buttons * 100) if total_buttons > 0 else 0
        }
        
        print(f"  Found {total_buttons} buttons total")
        print(f"  {buttons_with_type} have type attributes ({buttons_with_type/total_buttons*100:.1f}%)")
        print(f"  {len(buttons_without_type)} still missing type attributes")
    
    def verify_aria_labels(self):
        """Verify that icon buttons have proper ARIA labels"""
        print("Verifying ARIA labels on icon buttons...")
        
        template_files = list(self.templates_dir.rglob("*.html"))
        total_icon_buttons = 0
        icon_buttons_with_labels = 0
        icon_buttons_without_labels = []
        
        for template_file in template_files:
            try:
                with open(template_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Find buttons that contain only icons (fa- classes)
                icon_button_pattern = r'<button[^>]*>(\s*<i[^>]*class=["\'][^"\']*fa-[^"\']*["\'][^>]*></i>\s*)</button>'
                icon_button_matches = re.finditer(icon_button_pattern, content, re.IGNORECASE)
                
                for match in icon_button_matches:
                    total_icon_buttons += 1
                    button_html = match.group(0)
                    
                    if 'aria-label=' in button_html or 'title=' in button_html:
                        icon_buttons_with_labels += 1
                    else:
                        icon_buttons_without_labels.append({
                            "file": str(template_file.relative_to(self.workspace_root)),
                            "button": button_html[:100] + "..." if len(button_html) > 100 else button_html
                        })
                        
            except Exception as e:
                print(f"  Error verifying {template_file}: {e}")
        
        self.verification_results["aria_labels"] = {
            "total_icon_buttons": total_icon_buttons,
            "icon_buttons_with_labels": icon_buttons_with_labels,
            "icon_buttons_without_labels": len(icon_buttons_without_labels),
            "missing_label_buttons": icon_buttons_without_labels[:10],
            "percentage_fixed": (icon_buttons_with_labels / total_icon_buttons * 100) if total_icon_buttons > 0 else 0
        }
        
        print(f"  Found {total_icon_buttons} icon buttons total")
        print(f"  {icon_buttons_with_labels} have ARIA labels ({icon_buttons_with_labels/total_icon_buttons*100:.1f}%)")
        print(f"  {len(icon_buttons_without_labels)} still missing ARIA labels")
    
    def verify_modal_roles(self):
        """Verify that modals have proper ARIA roles"""
        print("Verifying modal ARIA roles...")
        
        template_files = list(self.templates_dir.rglob("*.html"))
        total_modals = 0
        modals_with_roles = 0
        modals_without_roles = []
        
        for template_file in template_files:
            try:
                with open(template_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Find modal elements
                modal_patterns = [
                    r'<div[^>]*class=["\'][^"\']*modal[^"\']*["\'][^>]*>',
                    r'<div[^>]*id=["\'][^"\']*modal[^"\']*["\'][^>]*>',
                    r'<dialog[^>]*>'
                ]
                
                for pattern in modal_patterns:
                    modal_matches = re.finditer(pattern, content, re.IGNORECASE)
                    
                    for match in modal_matches:
                        total_modals += 1
                        modal_html = match.group(0)
                        
                        if 'role=' in modal_html:
                            modals_with_roles += 1
                        else:
                            modals_without_roles.append({
                                "file": str(template_file.relative_to(self.workspace_root)),
                                "modal": modal_html[:100] + "..." if len(modal_html) > 100 else modal_html
                            })
                            
            except Exception as e:
                print(f"  Error verifying {template_file}: {e}")
        
        self.verification_results["modal_roles"] = {
            "total_modals": total_modals,
            "modals_with_roles": modals_with_roles,
            "modals_without_roles": len(modals_without_roles),
            "missing_role_modals": modals_without_roles[:10],
            "percentage_fixed": (modals_with_roles / total_modals * 100) if total_modals > 0 else 0
        }
        
        print(f"  Found {total_modals} modals total")
        print(f"  {modals_with_roles} have ARIA roles ({modals_with_roles/total_modals*100:.1f}%)")
        print(f"  {len(modals_without_roles)} still missing ARIA roles")
    
    def verify_css_enhancements(self):
        """Verify that CSS enhancements have been added"""
        print("Verifying CSS enhancements...")
        
        css_files = [
            self.workspace_root / "static" / "css" / "noctis-dashboard-style.css",
            self.workspace_root / "staticfiles" / "css" / "noctis-dashboard-style.css"
        ]
        
        css_features_found = {
            "hover_states": False,
            "disabled_states": False,
            "focus_states": False,
            "loading_states": False,
            "animations": False
        }
        
        for css_file in css_files:
            if css_file.exists():
                try:
                    with open(css_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    # Check for various CSS enhancements
                    if ':hover' in content:
                        css_features_found["hover_states"] = True
                    if ':disabled' in content:
                        css_features_found["disabled_states"] = True
                    if ':focus' in content:
                        css_features_found["focus_states"] = True
                    if '.loading' in content:
                        css_features_found["loading_states"] = True
                    if '@keyframes' in content or 'animation:' in content:
                        css_features_found["animations"] = True
                        
                except Exception as e:
                    print(f"  Error verifying {css_file}: {e}")
        
        self.verification_results["css_enhancements"] = css_features_found
        
        features_count = sum(css_features_found.values())
        print(f"  Found {features_count}/5 CSS enhancement features")
        for feature, found in css_features_found.items():
            status = "✓" if found else "✗"
            print(f"    {status} {feature.replace('_', ' ').title()}")
    
    def verify_javascript_utilities(self):
        """Verify that JavaScript utilities have been created"""
        print("Verifying JavaScript utilities...")
        
        js_file = self.workspace_root / "static" / "js" / "button-utils.js"
        js_features_found = {
            "file_exists": js_file.exists(),
            "click_protection": False,
            "keyboard_support": False,
            "loading_states": False,
            "error_handling": False,
            "modal_handling": False
        }
        
        if js_file.exists():
            try:
                with open(js_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Check for various JavaScript features
                if 'clickTimeout' in content or 'double-click' in content.lower():
                    js_features_found["click_protection"] = True
                if 'keydown' in content and ('Enter' in content or 'Space' in content):
                    js_features_found["keyboard_support"] = True
                if 'setButtonLoading' in content:
                    js_features_found["loading_states"] = True
                if 'safeButtonHandler' in content or 'try' in content:
                    js_features_found["error_handling"] = True
                if 'openModal' in content or 'closeModal' in content:
                    js_features_found["modal_handling"] = True
                    
            except Exception as e:
                print(f"  Error verifying {js_file}: {e}")
        
        self.verification_results["javascript_utilities"] = js_features_found
        
        features_count = sum(js_features_found.values())
        print(f"  Found {features_count}/6 JavaScript utility features")
        for feature, found in js_features_found.items():
            status = "✓" if found else "✗"
            print(f"    {status} {feature.replace('_', ' ').title()}")
    
    def check_common_ui_patterns(self):
        """Check for common UI patterns and potential issues"""
        print("Checking common UI patterns...")
        
        template_files = list(self.templates_dir.rglob("*.html"))
        patterns_found = {
            "form_buttons": 0,
            "navigation_buttons": 0,
            "action_buttons": 0,
            "modal_triggers": 0,
            "interactive_elements": 0
        }
        
        for template_file in template_files:
            try:
                with open(template_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Count different types of interactive elements
                patterns_found["form_buttons"] += len(re.findall(r'type=["\']submit["\']', content, re.IGNORECASE))
                patterns_found["navigation_buttons"] += len(re.findall(r'class=["\'][^"\']*nav[^"\']*["\']', content, re.IGNORECASE))
                patterns_found["action_buttons"] += len(re.findall(r'class=["\'][^"\']*btn[^"\']*["\']', content, re.IGNORECASE))
                patterns_found["modal_triggers"] += len(re.findall(r'data-toggle=["\']modal["\']|data-bs-toggle=["\']modal["\']', content, re.IGNORECASE))
                patterns_found["interactive_elements"] += len(re.findall(r'onclick=|addEventListener', content, re.IGNORECASE))
                
            except Exception as e:
                print(f"  Error checking patterns in {template_file}: {e}")
        
        self.verification_results["ui_patterns"] = patterns_found
        
        print(f"  UI Pattern Summary:")
        for pattern, count in patterns_found.items():
            print(f"    {pattern.replace('_', ' ').title()}: {count}")
    
    def generate_verification_report(self):
        """Generate comprehensive verification report"""
        
        # Calculate overall scores
        button_type_score = self.verification_results["button_types"]["percentage_fixed"]
        aria_label_score = self.verification_results["aria_labels"]["percentage_fixed"]
        modal_role_score = self.verification_results["modal_roles"]["percentage_fixed"]
        css_score = sum(self.verification_results["css_enhancements"].values()) / 5 * 100
        js_score = sum(self.verification_results["javascript_utilities"].values()) / 6 * 100
        
        overall_score = (button_type_score + aria_label_score + modal_role_score + css_score + js_score) / 5
        
        report = {
            "verification_summary": {
                "timestamp": __import__("time").strftime("%Y-%m-%d %H:%M:%S"),
                "overall_score": round(overall_score, 1),
                "individual_scores": {
                    "button_types": round(button_type_score, 1),
                    "aria_labels": round(aria_label_score, 1),
                    "modal_roles": round(modal_role_score, 1),
                    "css_enhancements": round(css_score, 1),
                    "javascript_utilities": round(js_score, 1)
                }
            },
            "detailed_results": dict(self.verification_results),
            "recommendations": [],
            "status": "PASS" if overall_score >= 80 else "NEEDS_IMPROVEMENT"
        }
        
        # Generate recommendations based on scores
        if button_type_score < 90:
            report["recommendations"].append("Add type attributes to remaining buttons")
        if aria_label_score < 80:
            report["recommendations"].append("Add ARIA labels to icon-only buttons")
        if modal_role_score < 90:
            report["recommendations"].append("Add proper ARIA roles to modal dialogs")
        if css_score < 80:
            report["recommendations"].append("Complete CSS enhancements for button states")
        if js_score < 80:
            report["recommendations"].append("Implement remaining JavaScript utility functions")
        
        if overall_score >= 95:
            report["recommendations"].append("Excellent! All major UI issues have been addressed")
        elif overall_score >= 80:
            report["recommendations"].append("Good progress! Minor improvements needed")
        else:
            report["recommendations"].append("Significant work still needed to improve UI functionality")
        
        return report
    
    def run_verification(self):
        """Run complete verification process"""
        print("="*60)
        print("UI FIXES VERIFICATION")
        print("="*60)
        
        self.verify_button_types()
        self.verify_aria_labels()
        self.verify_modal_roles()
        self.verify_css_enhancements()
        self.verify_javascript_utilities()
        self.check_common_ui_patterns()
        
        return self.generate_verification_report()

def main():
    """Main function to run verification"""
    verifier = UIFixesVerifier()
    
    try:
        report = verifier.run_verification()
        
        # Save report
        with open('/workspace/ui_verification_report.json', 'w') as f:
            json.dump(report, f, indent=2)
        
        # Print summary
        print("\n" + "="*60)
        print("VERIFICATION SUMMARY")
        print("="*60)
        print(f"Overall Score: {report['verification_summary']['overall_score']}%")
        print(f"Status: {report['status']}")
        
        print("\nIndividual Scores:")
        for category, score in report['verification_summary']['individual_scores'].items():
            print(f"  {category.replace('_', ' ').title()}: {score}%")
        
        print("\nRecommendations:")
        for rec in report['recommendations']:
            print(f"  - {rec}")
        
        print(f"\nDetailed report saved to: /workspace/ui_verification_report.json")
        
    except Exception as e:
        print(f"Error during verification: {e}")

if __name__ == "__main__":
    main()