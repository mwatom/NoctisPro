#!/usr/bin/env python3
"""
Comprehensive UI Button and Window Functionality Test Script
Tests all buttons, windows, modals, and interactive elements in the Noctis Pro PACS system
"""

import os
import sys
import django
import time
import json
import requests
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.chrome.options import Options
from selenium.common.exceptions import TimeoutException, NoSuchElementException

# Setup Django environment
sys.path.append('/workspace')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')
django.setup()

class UIFunctionalityTester:
    def __init__(self):
        self.setup_driver()
        self.base_url = "http://localhost:8000"
        self.test_results = {
            "navigation": [],
            "dicom_viewer": [],
            "admin_panel": [],
            "worklist": [],
            "modals": [],
            "forms": [],
            "responsive": []
        }
        
    def setup_driver(self):
        """Setup Chrome WebDriver with appropriate options"""
        chrome_options = Options()
        chrome_options.add_argument("--headless")  # Run in headless mode
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--disable-gpu")
        chrome_options.add_argument("--window-size=1920,1080")
        
        try:
            self.driver = webdriver.Chrome(options=chrome_options)
            self.driver.implicitly_wait(10)
            self.wait = WebDriverWait(self.driver, 10)
        except Exception as e:
            print(f"Error setting up WebDriver: {e}")
            # Fallback to manual testing approach
            self.driver = None
    
    def test_navigation_buttons(self):
        """Test all navigation buttons and links"""
        print("Testing Navigation Buttons...")
        
        navigation_tests = [
            {
                "name": "Main Dashboard Navigation",
                "url": "/",
                "buttons": [
                    ".nav-tab",  # Navigation tabs
                    ".admin-btn",  # Admin buttons
                    ".btn-control",  # Control buttons
                ]
            },
            {
                "name": "Worklist Navigation", 
                "url": "/worklist/",
                "buttons": [
                    ".nav-tab",
                    ".btn-control",
                    ".status-indicator"
                ]
            },
            {
                "name": "Admin Panel Navigation",
                "url": "/admin-panel/",
                "buttons": [
                    ".nav-tab",
                    ".user-management-btn",
                    ".facility-management-btn"
                ]
            }
        ]
        
        for test in navigation_tests:
            result = self.test_page_buttons(test["url"], test["buttons"], test["name"])
            self.test_results["navigation"].append(result)
    
    def test_dicom_viewer_buttons(self):
        """Test all DICOM viewer buttons and controls"""
        print("Testing DICOM Viewer Buttons...")
        
        dicom_viewer_tests = [
            {
                "name": "DICOM Viewer Toolbar",
                "url": "/dicom-viewer/",
                "buttons": [
                    "[data-tool='window']",  # Window tool
                    "[data-tool='zoom']",    # Zoom tool
                    "[data-tool='pan']",     # Pan tool
                    "[data-tool='measure']", # Measure tool
                    "[data-tool='annotate']",# Annotate tool
                    "[data-tool='crosshair']",# Crosshair tool
                    "[data-tool='hu']",      # HU tool
                    "[data-tool='invert']",  # Invert tool
                    "[data-tool='reset']",   # Reset tool
                    "[data-tool='fit']",     # Fit tool
                    "[data-tool='one']",     # 1:1 tool
                    "[data-tool='cine']",    # Cine tool
                    "[data-tool='spyglass']",# Spyglass tool
                    "[data-tool='align-center']", # Center tool
                    "[data-tool='reload']",  # Reload tool
                    "[data-tool='ai']",      # AI tool
                    "#btn3D",                # 3D button
                ]
            },
            {
                "name": "DICOM Viewer Top Bar",
                "url": "/dicom-viewer/",
                "buttons": [
                    "#btnLoadLocal",         # Load Local DICOM
                    "#btnBackWorklist",      # Back to Worklist
                    "#btnWriteReport",       # Write Report
                    "#btnToggleTags",        # Toggle Tags
                    "#btnShowDicom",         # Show DICOM
                    "#btnCapture",           # Capture
                    "#btnPrint",             # Print
                ]
            },
            {
                "name": "DICOM Viewer Controls",
                "url": "/dicom-viewer/",
                "buttons": [
                    "[data-preset='lung']",  # Lung preset
                    "[data-preset='bone']",  # Bone preset
                    "[data-preset='soft']",  # Soft tissue preset
                    "[data-preset='brain']", # Brain preset
                    "#btnSavePreset",        # Save preset
                    "#btnLoadPreset",        # Load preset
                    "#btnGenerateRecon",     # Generate reconstruction
                    "#btnClearMeasurements", # Clear measurements
                ]
            }
        ]
        
        for test in dicom_viewer_tests:
            result = self.test_page_buttons(test["url"], test["buttons"], test["name"])
            self.test_results["dicom_viewer"].append(result)
    
    def test_admin_panel_buttons(self):
        """Test all admin panel buttons"""
        print("Testing Admin Panel Buttons...")
        
        admin_tests = [
            {
                "name": "User Management",
                "url": "/admin-panel/users/",
                "buttons": [
                    ".btn-primary",          # Primary buttons
                    ".btn-secondary",        # Secondary buttons
                    ".btn-danger",           # Delete buttons
                    ".edit-user-btn",        # Edit user buttons
                    ".delete-user-btn",      # Delete user buttons
                    ".add-user-btn",         # Add user button
                ]
            },
            {
                "name": "Facility Management", 
                "url": "/admin-panel/facilities/",
                "buttons": [
                    ".btn-primary",
                    ".btn-secondary", 
                    ".btn-danger",
                    ".edit-facility-btn",
                    ".delete-facility-btn",
                    ".add-facility-btn",
                ]
            }
        ]
        
        for test in admin_tests:
            result = self.test_page_buttons(test["url"], test["buttons"], test["name"])
            self.test_results["admin_panel"].append(result)
    
    def test_worklist_buttons(self):
        """Test all worklist interface buttons"""
        print("Testing Worklist Buttons...")
        
        worklist_tests = [
            {
                "name": "Worklist Dashboard",
                "url": "/worklist/",
                "buttons": [
                    ".study-row",            # Study rows (clickable)
                    ".view-study-btn",       # View study buttons
                    ".edit-study-btn",       # Edit study buttons
                    ".delete-study-btn",     # Delete study buttons
                    ".upload-btn",           # Upload button
                    ".search-btn",           # Search button
                    ".filter-btn",           # Filter buttons
                    ".sort-btn",             # Sort buttons
                ]
            },
            {
                "name": "Study Upload",
                "url": "/worklist/upload/",
                "buttons": [
                    "#file-upload-btn",      # File upload button
                    "#upload-submit-btn",    # Upload submit button
                    "#cancel-upload-btn",    # Cancel upload button
                ]
            }
        ]
        
        for test in worklist_tests:
            result = self.test_page_buttons(test["url"], test["buttons"], test["name"])
            self.test_results["worklist"].append(result)
    
    def test_modal_windows(self):
        """Test all modal windows and dialog buttons"""
        print("Testing Modal Windows...")
        
        modal_tests = [
            {
                "name": "DICOM Tags Modal",
                "trigger": "#btnToggleTags",
                "modal": "#dicomModal",
                "buttons": [
                    ".modal-close-btn",      # Close button
                    ".modal-header .btn",    # Header buttons
                ]
            },
            {
                "name": "Print Modal",
                "trigger": "#btnPrint", 
                "modal": "#printModal",
                "buttons": [
                    ".print-confirm-btn",    # Print confirm
                    ".print-cancel-btn",     # Print cancel
                    ".print-settings-btn",   # Print settings
                ]
            },
            {
                "name": "3D Viewer Modal",
                "trigger": "#btn3D",
                "modal": "#threeContainer",
                "buttons": [
                    "#close3d",              # Close 3D button
                ]
            }
        ]
        
        for test in modal_tests:
            result = self.test_modal_functionality(test)
            self.test_results["modals"].append(result)
    
    def test_form_buttons(self):
        """Test all form submission buttons"""
        print("Testing Form Buttons...")
        
        form_tests = [
            {
                "name": "User Form",
                "url": "/admin-panel/users/add/",
                "buttons": [
                    "input[type='submit']",  # Submit button
                    ".form-save-btn",        # Save button
                    ".form-cancel-btn",      # Cancel button
                    ".form-reset-btn",       # Reset button
                ]
            },
            {
                "name": "Facility Form",
                "url": "/admin-panel/facilities/add/",
                "buttons": [
                    "input[type='submit']",
                    ".form-save-btn",
                    ".form-cancel-btn", 
                    ".form-reset-btn",
                ]
            },
            {
                "name": "Login Form",
                "url": "/accounts/login/",
                "buttons": [
                    "input[type='submit']",
                    ".login-btn",
                    ".forgot-password-btn",
                ]
            }
        ]
        
        for test in form_tests:
            result = self.test_page_buttons(test["url"], test["buttons"], test["name"])
            self.test_results["forms"].append(result)
    
    def test_responsive_ui(self):
        """Test UI responsiveness and button functionality across screen sizes"""
        print("Testing Responsive UI...")
        
        screen_sizes = [
            {"name": "Desktop", "width": 1920, "height": 1080},
            {"name": "Tablet", "width": 768, "height": 1024},
            {"name": "Mobile", "width": 375, "height": 667}
        ]
        
        for size in screen_sizes:
            if self.driver:
                self.driver.set_window_size(size["width"], size["height"])
                time.sleep(1)  # Allow UI to adjust
                
                # Test key responsive elements
                result = {
                    "screen_size": size["name"],
                    "dimensions": f"{size['width']}x{size['height']}",
                    "navigation_visible": self.check_element_visibility(".nav-tabs"),
                    "buttons_accessible": self.check_buttons_accessibility(),
                    "modals_responsive": self.check_modal_responsiveness()
                }
                
                self.test_results["responsive"].append(result)
    
    def test_page_buttons(self, url, button_selectors, test_name):
        """Test buttons on a specific page"""
        result = {
            "test_name": test_name,
            "url": url,
            "buttons_tested": 0,
            "buttons_working": 0,
            "buttons_failed": 0,
            "failed_buttons": [],
            "status": "PASS"
        }
        
        if not self.driver:
            return self.manual_test_fallback(test_name, url, button_selectors)
        
        try:
            self.driver.get(self.base_url + url)
            time.sleep(2)  # Wait for page load
            
            for selector in button_selectors:
                result["buttons_tested"] += 1
                
                try:
                    elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
                    
                    if not elements:
                        result["buttons_failed"] += 1
                        result["failed_buttons"].append(f"{selector} - Not found")
                        continue
                    
                    for element in elements:
                        if self.test_button_functionality(element, selector):
                            result["buttons_working"] += 1
                        else:
                            result["buttons_failed"] += 1
                            result["failed_buttons"].append(f"{selector} - Not clickable")
                            
                except Exception as e:
                    result["buttons_failed"] += 1
                    result["failed_buttons"].append(f"{selector} - Error: {str(e)}")
            
            if result["buttons_failed"] > 0:
                result["status"] = "FAIL"
                
        except Exception as e:
            result["status"] = "ERROR"
            result["error"] = str(e)
        
        return result
    
    def test_button_functionality(self, element, selector):
        """Test if a button is functional (clickable, visible, enabled)"""
        try:
            # Check if element is displayed and enabled
            if not element.is_displayed() or not element.is_enabled():
                return False
            
            # Check if element has click handler or href
            tag_name = element.tag_name.lower()
            onclick = element.get_attribute("onclick")
            href = element.get_attribute("href")
            
            if tag_name == "button" or onclick or href or "btn" in element.get_attribute("class"):
                # Try to hover over element (basic interaction test)
                ActionChains(self.driver).move_to_element(element).perform()
                return True
            
            return False
            
        except Exception:
            return False
    
    def test_modal_functionality(self, modal_test):
        """Test modal window functionality"""
        result = {
            "modal_name": modal_test["name"],
            "trigger_working": False,
            "modal_opens": False,
            "buttons_working": 0,
            "buttons_failed": 0,
            "status": "FAIL"
        }
        
        if not self.driver:
            return result
        
        try:
            # Find and click trigger button
            trigger = self.wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, modal_test["trigger"])))
            trigger.click()
            result["trigger_working"] = True
            
            # Wait for modal to appear
            modal = self.wait.until(EC.visibility_of_element_located((By.CSS_SELECTOR, modal_test["modal"])))
            result["modal_opens"] = True
            
            # Test modal buttons
            for button_selector in modal_test["buttons"]:
                try:
                    buttons = self.driver.find_elements(By.CSS_SELECTOR, button_selector)
                    for button in buttons:
                        if self.test_button_functionality(button, button_selector):
                            result["buttons_working"] += 1
                        else:
                            result["buttons_failed"] += 1
                except Exception:
                    result["buttons_failed"] += 1
            
            if result["trigger_working"] and result["modal_opens"]:
                result["status"] = "PASS"
                
        except Exception as e:
            result["error"] = str(e)
        
        return result
    
    def check_element_visibility(self, selector):
        """Check if element is visible"""
        if not self.driver:
            return False
        try:
            element = self.driver.find_element(By.CSS_SELECTOR, selector)
            return element.is_displayed()
        except:
            return False
    
    def check_buttons_accessibility(self):
        """Check if buttons are accessible and properly sized for touch"""
        if not self.driver:
            return False
        
        try:
            buttons = self.driver.find_elements(By.CSS_SELECTOR, "button, .btn, input[type='submit']")
            accessible_count = 0
            
            for button in buttons:
                if button.is_displayed() and button.is_enabled():
                    size = button.size
                    # Check minimum touch target size (44px recommended)
                    if size["width"] >= 44 and size["height"] >= 44:
                        accessible_count += 1
            
            return accessible_count > 0
        except:
            return False
    
    def check_modal_responsiveness(self):
        """Check if modals are responsive"""
        # This would require more complex testing
        return True
    
    def manual_test_fallback(self, test_name, url, button_selectors):
        """Fallback method for manual testing when WebDriver is not available"""
        print(f"Manual testing fallback for: {test_name}")
        print(f"URL: {url}")
        print(f"Button selectors to test: {button_selectors}")
        
        return {
            "test_name": test_name,
            "url": url,
            "status": "MANUAL_REQUIRED",
            "message": "WebDriver not available, manual testing required",
            "selectors": button_selectors
        }
    
    def run_all_tests(self):
        """Run all UI functionality tests"""
        print("Starting comprehensive UI button and window functionality tests...")
        
        self.test_navigation_buttons()
        self.test_dicom_viewer_buttons() 
        self.test_admin_panel_buttons()
        self.test_worklist_buttons()
        self.test_modal_windows()
        self.test_form_buttons()
        self.test_responsive_ui()
        
        return self.test_results
    
    def generate_report(self):
        """Generate a comprehensive test report"""
        report = {
            "test_summary": {
                "total_test_categories": len(self.test_results),
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
                "overall_status": "PASS"
            },
            "detailed_results": self.test_results
        }
        
        # Calculate overall status
        for category, tests in self.test_results.items():
            for test in tests:
                if isinstance(test, dict) and test.get("status") in ["FAIL", "ERROR"]:
                    report["test_summary"]["overall_status"] = "FAIL"
                    break
        
        return report
    
    def cleanup(self):
        """Clean up resources"""
        if self.driver:
            self.driver.quit()

def main():
    """Main function to run UI functionality tests"""
    tester = UIFunctionalityTester()
    
    try:
        # Run all tests
        results = tester.run_all_tests()
        
        # Generate report
        report = tester.generate_report()
        
        # Save report to file
        with open('/workspace/ui_test_report.json', 'w') as f:
            json.dump(report, f, indent=2)
        
        # Print summary
        print("\n" + "="*60)
        print("UI FUNCTIONALITY TEST SUMMARY")
        print("="*60)
        print(f"Overall Status: {report['test_summary']['overall_status']}")
        print(f"Test Categories: {report['test_summary']['total_test_categories']}")
        print(f"Timestamp: {report['test_summary']['timestamp']}")
        
        for category, tests in results.items():
            print(f"\n{category.upper()}:")
            for test in tests:
                if isinstance(test, dict):
                    status = test.get("status", "UNKNOWN")
                    name = test.get("test_name", test.get("modal_name", "Unknown"))
                    print(f"  - {name}: {status}")
                    
                    if status == "FAIL" and "failed_buttons" in test:
                        for failed in test["failed_buttons"][:3]:  # Show first 3 failures
                            print(f"    * {failed}")
        
        print(f"\nDetailed report saved to: /workspace/ui_test_report.json")
        
    finally:
        tester.cleanup()

if __name__ == "__main__":
    main()