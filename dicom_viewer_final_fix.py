import sys
import os
import numpy as np
import pydicom
from PyQt5.QtWidgets import (QApplication, QMainWindow, QVBoxLayout, QHBoxLayout, 
                             QWidget, QPushButton, QLabel, QSlider, QFileDialog, 
                             QScrollArea, QFrame, QGridLayout, QComboBox, QTextEdit,
                             QMessageBox, QInputDialog, QListWidget, QListWidgetItem,
                             QSizePolicy)
from PyQt5.QtCore import Qt, QTimer, pyqtSignal, QThread, QObject
from PyQt5.QtGui import QPixmap, QImage, QPainter, QPen, QColor, QFont

# Force matplotlib to use Agg backend to avoid display issues
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.figure import Figure
import io
import traceback


class DicomProcessor(QObject):
    """Separate class to handle DICOM processing"""
    
    def process_image(self, dicom_data, window_width, window_level, inverted=False):
        """Process DICOM image data into displayable format"""
        try:
            # Get pixel array
            if not hasattr(dicom_data, 'pixel_array'):
                return None
            
            pixel_array = dicom_data.pixel_array.copy()
            
            # Handle different image dimensions
            if len(pixel_array.shape) == 3:
                if pixel_array.shape[2] == 3:
                    # RGB to grayscale
                    pixel_array = np.mean(pixel_array, axis=2)
                else:
                    # Multi-frame, take first
                    pixel_array = pixel_array[:, :, 0]
            
            # Convert to float for processing
            pixel_array = pixel_array.astype(np.float64)
            
            # Apply window/level
            min_val = window_level - window_width / 2
            max_val = window_level + window_width / 2
            
            # Clip values
            pixel_array = np.clip(pixel_array, min_val, max_val)
            
            # Normalize to 0-255
            if max_val - min_val != 0:
                pixel_array = (pixel_array - min_val) / (max_val - min_val) * 255
            else:
                pixel_array = np.zeros_like(pixel_array)
            
            # Convert to uint8
            pixel_array = pixel_array.astype(np.uint8)
            
            # Handle photometric interpretation
            if hasattr(dicom_data, 'PhotometricInterpretation'):
                if dicom_data.PhotometricInterpretation == 'MONOCHROME1':
                    pixel_array = 255 - pixel_array
            
            # Apply user inversion
            if inverted:
                pixel_array = 255 - pixel_array
            
            return pixel_array
            
        except Exception as e:
            print(f"Error processing image: {e}")
            return None


class DicomImageWidget(QLabel):
    """Custom QLabel widget for displaying DICOM images"""
    
    mouse_pressed = pyqtSignal(int, int)
    mouse_moved = pyqtSignal(int, int)
    mouse_released = pyqtSignal(int, int)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMinimumSize(400, 400)
        self.setStyleSheet("background-color: black; border: 1px solid #555;")
        self.setAlignment(Qt.AlignCenter)
        self.setScaledContents(False)
        
        # Image properties
        self.image_array = None
        self.zoom_factor = 1.0
        self.pan_x = 0
        self.pan_y = 0
        
        # Mouse tracking
        self.setMouseTracking(True)
        self.mouse_pressed_flag = False
        self.last_mouse_pos = None
        
        # Display properties
        self.fit_to_window = True
        
        # Initial display
        self.show_placeholder()
    
    def show_placeholder(self):
        """Show placeholder text"""
        self.setText("No DICOM image loaded\n\nUse 'Load DICOM Files' to start")
        self.setStyleSheet("background-color: black; color: #666; border: 1px solid #555; font-size: 14px;")
    
    def display_image(self, image_array):
        """Display numpy array as image"""
        try:
            if image_array is None:
                self.show_placeholder()
                return False
            
            self.image_array = image_array
            h, w = image_array.shape
            
            # Create QImage from numpy array
            qimage = QImage(image_array.data, w, h, w, QImage.Format_Grayscale8)
            
            # Convert to QPixmap
            pixmap = QPixmap.fromImage(qimage)
            
            # Apply zoom and fit
            if self.fit_to_window:
                # Scale to fit widget while maintaining aspect ratio
                widget_size = self.size()
                scaled_pixmap = pixmap.scaled(
                    widget_size, 
                    Qt.KeepAspectRatio, 
                    Qt.SmoothTransformation
                )
            else:
                # Apply zoom factor
                new_size = pixmap.size() * self.zoom_factor
                scaled_pixmap = pixmap.scaled(
                    new_size,
                    Qt.KeepAspectRatio,
                    Qt.SmoothTransformation
                )
            
            # Set the pixmap
            self.setPixmap(scaled_pixmap)
            self.setStyleSheet("background-color: black; border: 1px solid #555;")
            
            return True
            
        except Exception as e:
            print(f"Error displaying image: {e}")
            self.setText(f"Error displaying image: {str(e)}")
            return False
    
    def zoom_in(self):
        """Zoom in"""
        self.zoom_factor = min(self.zoom_factor * 1.2, 5.0)
        self.fit_to_window = False
        if self.image_array is not None:
            self.display_image(self.image_array)
    
    def zoom_out(self):
        """Zoom out"""
        self.zoom_factor = max(self.zoom_factor / 1.2, 0.1)
        self.fit_to_window = False
        if self.image_array is not None:
            self.display_image(self.image_array)
    
    def reset_view(self):
        """Reset view to fit window"""
        self.zoom_factor = 1.0
        self.pan_x = 0
        self.pan_y = 0
        self.fit_to_window = True
        if self.image_array is not None:
            self.display_image(self.image_array)
    
    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.mouse_pressed_flag = True
            self.last_mouse_pos = (event.x(), event.y())
            self.mouse_pressed.emit(event.x(), event.y())
        super().mousePressEvent(event)
    
    def mouseMoveEvent(self, event):
        if self.mouse_pressed_flag:
            self.mouse_moved.emit(event.x(), event.y())
        super().mouseMoveEvent(event)
    
    def mouseReleaseEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.mouse_pressed_flag = False
            self.mouse_released.emit(event.x(), event.y())
        super().mouseReleaseEvent(event)
    
    def wheelEvent(self, event):
        """Handle mouse wheel for zoom"""
        if event.modifiers() & Qt.ControlModifier:
            # Zoom
            delta = event.angleDelta().y()
            if delta > 0:
                self.zoom_in()
            else:
                self.zoom_out()
        else:
            # Pass to parent for slice navigation
            if self.parent():
                self.parent().handle_wheel_slice(event.angleDelta().y())
        super().wheelEvent(event)


class DicomViewer(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("DICOM Viewer - FINAL FIX")
        self.setGeometry(100, 100, 1400, 900)
        self.setStyleSheet("background-color: #2a2a2a; color: white;")
        
        # DICOM data
        self.dicom_files = []
        self.current_image_index = 0
        self.current_dicom = None
        
        # Display parameters
        self.window_width = 400
        self.window_level = 40
        self.inverted = False
        
        # Tools
        self.active_tool = 'windowing'
        self.measurements = []
        self.annotations = []
        
        # Window presets
        self.window_presets = {
            'lung': {'ww': 1500, 'wl': -600},
            'bone': {'ww': 2000, 'wl': 300},
            'soft': {'ww': 400, 'wl': 40},
            'brain': {'ww': 100, 'wl': 50},
            'abdomen': {'ww': 350, 'wl': 50}
        }
        
        # Processing
        self.processor = DicomProcessor()
        
        # Cache
        self._cached_image = None
        self._cached_params = None
        
        self.init_ui()
        
    def init_ui(self):
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        
        # Main layout
        main_layout = QHBoxLayout(main_widget)
        main_layout.setContentsMargins(5, 5, 5, 5)
        main_layout.setSpacing(5)
        
        # Left panel - controls
        self.create_left_panel(main_layout)
        
        # Center - image display
        self.create_center_panel(main_layout)
        
        # Right panel - info
        self.create_right_panel(main_layout)
        
    def create_left_panel(self, main_layout):
        left_panel = QWidget()
        left_panel.setFixedWidth(200)
        left_panel.setStyleSheet("background-color: #333; border-radius: 5px;")
        
        left_layout = QVBoxLayout(left_panel)
        left_layout.setContentsMargins(10, 10, 10, 10)
        left_layout.setSpacing(10)
        
        # Title
        title = QLabel("DICOM Viewer")
        title.setStyleSheet("font-size: 16px; font-weight: bold; color: white; margin-bottom: 10px;")
        left_layout.addWidget(title)
        
        # Load buttons
        load_file_btn = QPushButton("📁 Load DICOM Files")
        load_file_btn.setStyleSheet(self.get_button_style())
        load_file_btn.clicked.connect(self.load_dicom_files)
        left_layout.addWidget(load_file_btn)
        
        load_dir_btn = QPushButton("📂 Load Directory")
        load_dir_btn.setStyleSheet(self.get_button_style())
        load_dir_btn.clicked.connect(self.load_dicom_directory)
        left_layout.addWidget(load_dir_btn)
        
        # Separator
        separator = QFrame()
        separator.setFrameShape(QFrame.HLine)
        separator.setStyleSheet("color: #555;")
        left_layout.addWidget(separator)
        
        # Window/Level controls
        wl_label = QLabel("Window/Level")
        wl_label.setStyleSheet("font-size: 14px; font-weight: bold; color: white;")
        left_layout.addWidget(wl_label)
        
        # Window Width
        ww_layout = QHBoxLayout()
        ww_layout.addWidget(QLabel("Width:"))
        self.ww_value_label = QLabel(str(self.window_width))
        self.ww_value_label.setStyleSheet("color: #0078d4; font-weight: bold;")
        self.ww_value_label.setAlignment(Qt.AlignRight)
        ww_layout.addWidget(self.ww_value_label)
        left_layout.addLayout(ww_layout)
        
        self.ww_slider = QSlider(Qt.Horizontal)
        self.ww_slider.setRange(1, 4000)
        self.ww_slider.setValue(self.window_width)
        self.ww_slider.valueChanged.connect(self.handle_window_width_change)
        left_layout.addWidget(self.ww_slider)
        
        # Window Level
        wl_layout = QHBoxLayout()
        wl_layout.addWidget(QLabel("Level:"))
        self.wl_value_label = QLabel(str(self.window_level))
        self.wl_value_label.setStyleSheet("color: #0078d4; font-weight: bold;")
        self.wl_value_label.setAlignment(Qt.AlignRight)
        wl_layout.addWidget(self.wl_value_label)
        left_layout.addLayout(wl_layout)
        
        self.wl_slider = QSlider(Qt.Horizontal)
        self.wl_slider.setRange(-1000, 1000)
        self.wl_slider.setValue(self.window_level)
        self.wl_slider.valueChanged.connect(self.handle_window_level_change)
        left_layout.addWidget(self.wl_slider)
        
        # Presets
        presets_label = QLabel("Presets:")
        presets_label.setStyleSheet("font-size: 12px; color: white; margin-top: 10px;")
        left_layout.addWidget(presets_label)
        
        preset_layout = QGridLayout()
        preset_layout.setSpacing(5)
        
        presets = list(self.window_presets.keys())
        for i, preset in enumerate(presets):
            btn = QPushButton(preset.title())
            btn.setStyleSheet(self.get_small_button_style())
            btn.clicked.connect(lambda checked, p=preset: self.apply_preset(p))
            preset_layout.addWidget(btn, i // 2, i % 2)
        
        left_layout.addLayout(preset_layout)
        
        # Navigation
        nav_separator = QFrame()
        nav_separator.setFrameShape(QFrame.HLine)
        nav_separator.setStyleSheet("color: #555;")
        left_layout.addWidget(nav_separator)
        
        nav_label = QLabel("Navigation")
        nav_label.setStyleSheet("font-size: 14px; font-weight: bold; color: white;")
        left_layout.addWidget(nav_label)
        
        # Slice control
        slice_layout = QHBoxLayout()
        slice_layout.addWidget(QLabel("Slice:"))
        self.slice_value_label = QLabel("0/0")
        self.slice_value_label.setStyleSheet("color: #0078d4; font-weight: bold;")
        self.slice_value_label.setAlignment(Qt.AlignRight)
        slice_layout.addWidget(self.slice_value_label)
        left_layout.addLayout(slice_layout)
        
        self.slice_slider = QSlider(Qt.Horizontal)
        self.slice_slider.setRange(0, 0)
        self.slice_slider.setValue(0)
        self.slice_slider.valueChanged.connect(self.handle_slice_change)
        left_layout.addWidget(self.slice_slider)
        
        # View controls
        view_separator = QFrame()
        view_separator.setFrameShape(QFrame.HLine)
        view_separator.setStyleSheet("color: #555;")
        left_layout.addWidget(view_separator)
        
        view_label = QLabel("View Controls")
        view_label.setStyleSheet("font-size: 14px; font-weight: bold; color: white;")
        left_layout.addWidget(view_label)
        
        # Control buttons
        controls = [
            ("🔄 Reset View", self.reset_view),
            ("⚫ Invert", self.toggle_invert),
            ("🔍+ Zoom In", self.zoom_in),
            ("🔍- Zoom Out", self.zoom_out)
        ]
        
        for text, func in controls:
            btn = QPushButton(text)
            btn.setStyleSheet(self.get_small_button_style())
            btn.clicked.connect(func)
            left_layout.addWidget(btn)
        
        left_layout.addStretch()
        main_layout.addWidget(left_panel)
    
    def create_center_panel(self, main_layout):
        center_panel = QWidget()
        center_layout = QVBoxLayout(center_panel)
        center_layout.setContentsMargins(0, 0, 0, 0)
        center_layout.setSpacing(5)
        
        # Status bar
        self.status_label = QLabel("Ready - Load DICOM files to begin")
        self.status_label.setStyleSheet("""
            background-color: #444; 
            color: white; 
            padding: 8px; 
            border-radius: 3px;
            font-size: 12px;
        """)
        center_layout.addWidget(self.status_label)
        
        # Image display widget
        self.image_widget = DicomImageWidget()
        self.image_widget.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        center_layout.addWidget(self.image_widget)
        
        # Image info overlay
        self.info_overlay = QLabel()
        self.info_overlay.setStyleSheet("""
            background-color: rgba(0, 0, 0, 180);
            color: white;
            padding: 10px;
            border-radius: 5px;
            font-family: monospace;
            font-size: 12px;
        """)
        self.info_overlay.setParent(self.image_widget)
        self.info_overlay.move(10, 10)
        self.info_overlay.setText("WW: 400 | WL: 40\nSlice: 0/0")
        
        main_layout.addWidget(center_panel, 1)
    
    def create_right_panel(self, main_layout):
        right_panel = QWidget()
        right_panel.setFixedWidth(250)
        right_panel.setStyleSheet("background-color: #333; border-radius: 5px;")
        
        right_layout = QVBoxLayout(right_panel)
        right_layout.setContentsMargins(10, 10, 10, 10)
        right_layout.setSpacing(10)
        
        # Patient info
        info_title = QLabel("Patient Information")
        info_title.setStyleSheet("font-size: 14px; font-weight: bold; color: white;")
        right_layout.addWidget(info_title)
        
        self.patient_info = QLabel("No DICOM loaded")
        self.patient_info.setStyleSheet("color: #ccc; font-size: 12px;")
        self.patient_info.setWordWrap(True)
        right_layout.addWidget(self.patient_info)
        
        # Image info
        img_separator = QFrame()
        img_separator.setFrameShape(QFrame.HLine)
        img_separator.setStyleSheet("color: #555;")
        right_layout.addWidget(img_separator)
        
        img_title = QLabel("Image Information")
        img_title.setStyleSheet("font-size: 14px; font-weight: bold; color: white;")
        right_layout.addWidget(img_title)
        
        self.image_info = QLabel("No image loaded")
        self.image_info.setStyleSheet("color: #ccc; font-size: 12px;")
        self.image_info.setWordWrap(True)
        right_layout.addWidget(self.image_info)
        
        right_layout.addStretch()
        main_layout.addWidget(right_panel)
    
    def get_button_style(self):
        return """
            QPushButton {
                background-color: #0078d4;
                color: white;
                border: none;
                padding: 10px;
                border-radius: 5px;
                font-size: 14px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #106ebe;
            }
            QPushButton:pressed {
                background-color: #005a9e;
            }
        """
    
    def get_small_button_style(self):
        return """
            QPushButton {
                background-color: #444;
                color: white;
                border: none;
                padding: 6px;
                border-radius: 3px;
                font-size: 12px;
            }
            QPushButton:hover {
                background-color: #555;
            }
            QPushButton:pressed {
                background-color: #0078d4;
            }
        """
    
    def load_dicom_files(self):
        """Load individual DICOM files"""
        file_dialog = QFileDialog()
        file_paths, _ = file_dialog.getOpenFileNames(
            self, "Select DICOM Files", "", "DICOM Files (*.dcm *.dicom);;All Files (*)"
        )
        
        if file_paths:
            self.process_dicom_files(file_paths)
    
    def load_dicom_directory(self):
        """Load all DICOM files from directory"""
        directory = QFileDialog.getExistingDirectory(self, "Select DICOM Directory")
        
        if directory:
            dicom_files = []
            for root, dirs, files in os.walk(directory):
                for file in files:
                    file_path = os.path.join(root, file)
                    if (file.lower().endswith(('.dcm', '.dicom')) or 
                        self.is_dicom_file(file_path)):
                        dicom_files.append(file_path)
            
            if dicom_files:
                self.process_dicom_files(dicom_files)
            else:
                QMessageBox.warning(self, "No DICOM Files", 
                                  "No DICOM files found in directory.")
    
    def is_dicom_file(self, file_path):
        """Check if file is DICOM"""
        try:
            pydicom.dcmread(file_path, stop_before_pixels=True)
            return True
        except:
            return False
    
    def process_dicom_files(self, file_paths):
        """Process and load DICOM files"""
        self.dicom_files = []
        successful_count = 0
        
        self.update_status(f"Loading {len(file_paths)} files...")
        
        for i, file_path in enumerate(file_paths):
            try:
                dicom_data = pydicom.dcmread(file_path)
                
                # Validate pixel data
                if not hasattr(dicom_data, 'pixel_array'):
                    continue
                
                # Test pixel access
                try:
                    pixel_test = dicom_data.pixel_array
                    if pixel_test is None or pixel_test.size == 0:
                        continue
                except:
                    continue
                
                self.dicom_files.append(dicom_data)
                successful_count += 1
                
            except Exception as e:
                print(f"Failed to load {file_path}: {e}")
        
        if self.dicom_files:
            # Sort files
            self.dicom_files.sort(key=self.get_sort_key)
            
            # Setup navigation
            self.current_image_index = 0
            self.slice_slider.setRange(0, len(self.dicom_files) - 1)
            self.slice_slider.setValue(0)
            
            # Set initial window/level
            self.set_initial_window_level()
            
            # Update display
            self.update_display()
            self.update_info()
            
            self.update_status(f"Loaded {successful_count} DICOM images successfully")
            
        else:
            self.update_status("No valid DICOM files found")
            QMessageBox.warning(self, "Load Failed", "No valid DICOM files found.")
    
    def get_sort_key(self, dicom_data):
        """Get sort key for DICOM files"""
        if hasattr(dicom_data, 'InstanceNumber'):
            return dicom_data.InstanceNumber
        elif hasattr(dicom_data, 'SliceLocation'):
            return dicom_data.SliceLocation
        elif hasattr(dicom_data, 'ImagePositionPatient') and dicom_data.ImagePositionPatient:
            return dicom_data.ImagePositionPatient[2]
        return 0
    
    def set_initial_window_level(self):
        """Set initial window/level from DICOM"""
        if not self.dicom_files:
            return
        
        first_dicom = self.dicom_files[0]
        
        # Try DICOM tags
        if hasattr(first_dicom, 'WindowWidth') and hasattr(first_dicom, 'WindowCenter'):
            ww = first_dicom.WindowWidth
            wl = first_dicom.WindowCenter
            
            if isinstance(ww, (list, tuple)):
                ww = ww[0]
            if isinstance(wl, (list, tuple)):
                wl = wl[0]
            
            self.window_width = float(ww)
            self.window_level = float(wl)
        else:
            # Calculate from image
            try:
                pixel_array = first_dicom.pixel_array
                min_val = np.percentile(pixel_array, 2)
                max_val = np.percentile(pixel_array, 98)
                self.window_width = max_val - min_val
                self.window_level = (max_val + min_val) / 2
            except:
                self.window_width = 400
                self.window_level = 40
        
        # Update UI
        self.ww_slider.setValue(int(self.window_width))
        self.wl_slider.setValue(int(self.window_level))
        self.ww_value_label.setText(str(int(self.window_width)))
        self.wl_value_label.setText(str(int(self.window_level)))
    
    def update_display(self):
        """Update image display"""
        if not self.dicom_files:
            return
        
        try:
            self.current_dicom = self.dicom_files[self.current_image_index]
            
            # Check cache
            current_params = (self.current_image_index, self.window_width, self.window_level, self.inverted)
            if self._cached_params == current_params and self._cached_image is not None:
                image_data = self._cached_image
            else:
                # Process image
                image_data = self.processor.process_image(
                    self.current_dicom, 
                    self.window_width, 
                    self.window_level, 
                    self.inverted
                )
                
                if image_data is None:
                    self.update_status("Failed to process image")
                    return
                
                # Cache result
                self._cached_image = image_data
                self._cached_params = current_params
            
            # Display image
            success = self.image_widget.display_image(image_data)
            
            if success:
                self.update_status(f"Displaying image {self.current_image_index + 1}/{len(self.dicom_files)}")
                self.update_overlay()
            else:
                self.update_status("Failed to display image")
                
        except Exception as e:
            error_msg = f"Display error: {str(e)}"
            print(error_msg)
            self.update_status(error_msg)
    
    def update_overlay(self):
        """Update overlay information"""
        slice_info = f"{self.current_image_index + 1}/{len(self.dicom_files)}"
        self.info_overlay.setText(f"WW: {int(self.window_width)} | WL: {int(self.window_level)}\nSlice: {slice_info}")
        self.slice_value_label.setText(slice_info)
    
    def update_info(self):
        """Update patient and image information"""
        if not self.dicom_files:
            return
        
        dicom = self.current_dicom
        
        # Patient info
        patient_name = getattr(dicom, 'PatientName', 'Unknown')
        patient_id = getattr(dicom, 'PatientID', 'Unknown')
        study_date = getattr(dicom, 'StudyDate', 'Unknown')
        modality = getattr(dicom, 'Modality', 'Unknown')
        
        patient_text = f"""Patient: {patient_name}
ID: {patient_id}
Study Date: {study_date}
Modality: {modality}"""
        
        self.patient_info.setText(patient_text)
        
        # Image info
        rows = getattr(dicom, 'Rows', 'Unknown')
        cols = getattr(dicom, 'Columns', 'Unknown')
        pixel_spacing = getattr(dicom, 'PixelSpacing', ['Unknown', 'Unknown'])
        slice_thickness = getattr(dicom, 'SliceThickness', 'Unknown')
        
        if isinstance(pixel_spacing, list) and len(pixel_spacing) >= 2:
            spacing_text = f"{pixel_spacing[0]:.2f} x {pixel_spacing[1]:.2f} mm"
        else:
            spacing_text = str(pixel_spacing)
        
        image_text = f"""Dimensions: {cols} x {rows}
Pixel Spacing: {spacing_text}
Slice Thickness: {slice_thickness} mm
Window/Level: {int(self.window_width)}/{int(self.window_level)}"""
        
        self.image_info.setText(image_text)
    
    def handle_window_width_change(self, value):
        """Handle window width change"""
        self.window_width = value
        self.ww_value_label.setText(str(value))
        self._cached_image = None
        self.update_display()
    
    def handle_window_level_change(self, value):
        """Handle window level change"""
        self.window_level = value
        self.wl_value_label.setText(str(value))
        self._cached_image = None
        self.update_display()
    
    def apply_preset(self, preset):
        """Apply window/level preset"""
        values = self.window_presets[preset]
        self.window_width = values['ww']
        self.window_level = values['wl']
        
        self.ww_slider.setValue(self.window_width)
        self.wl_slider.setValue(self.window_level)
        
        self._cached_image = None
        self.update_display()
    
    def handle_slice_change(self, value):
        """Handle slice change"""
        if 0 <= value < len(self.dicom_files):
            self.current_image_index = value
            self.update_display()
            self.update_info()
    
    def handle_wheel_slice(self, delta):
        """Handle wheel event for slice navigation"""
        direction = 1 if delta > 0 else -1
        new_index = self.current_image_index + direction
        if 0 <= new_index < len(self.dicom_files):
            self.current_image_index = new_index
            self.slice_slider.setValue(new_index)
    
    def reset_view(self):
        """Reset view"""
        self.image_widget.reset_view()
        self.update_status("View reset")
    
    def toggle_invert(self):
        """Toggle image inversion"""
        self.inverted = not self.inverted
        self._cached_image = None
        self.update_display()
        self.update_status(f"Inversion {'ON' if self.inverted else 'OFF'}")
    
    def zoom_in(self):
        """Zoom in"""
        self.image_widget.zoom_in()
        self.update_status("Zoomed in")
    
    def zoom_out(self):
        """Zoom out"""
        self.image_widget.zoom_out()
        self.update_status("Zoomed out")
    
    def update_status(self, message):
        """Update status bar"""
        self.status_label.setText(message)
        print(f"Status: {message}")


def main():
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    
    # Set application properties
    app.setApplicationName("DICOM Viewer")
    app.setApplicationVersion("1.0")
    
    viewer = DicomViewer()
    viewer.show()
    
    print("DICOM Viewer started successfully")
    print("Load DICOM files using the buttons in the left panel")
    
    sys.exit(app.exec_())


if __name__ == '__main__':
    main()