import sys
import os
import numpy as np
import pydicom
from PyQt5.QtWidgets import (QApplication, QMainWindow, QVBoxLayout, QHBoxLayout, 
                             QWidget, QPushButton, QLabel, QSlider, QFileDialog, 
                             QScrollArea, QFrame, QGridLayout, QComboBox, QTextEdit,
                             QMessageBox, QInputDialog, QListWidget, QListWidgetItem)
from PyQt5.QtCore import Qt, QTimer, pyqtSignal
from PyQt5.QtGui import QPixmap, QImage, QPainter, QPen, QColor, QFont
import matplotlib
matplotlib.use('Qt5Agg')  # Force Qt5Agg backend
import matplotlib.pyplot as plt
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
from matplotlib.patches import Rectangle
import traceback


class DicomCanvas(FigureCanvas):
    """Custom matplotlib canvas for DICOM image display with improved rendering"""
    mouse_pressed = pyqtSignal(int, int)
    mouse_moved = pyqtSignal(int, int)
    mouse_released = pyqtSignal(int, int)
    
    def __init__(self, parent=None):
        # Create figure with specific settings for better rendering
        self.fig = Figure(figsize=(10, 10), facecolor='black', edgecolor='black')
        
        # Initialize parent class
        super().__init__(self.fig)
        self.setParent(parent)
        
        # Configure figure for optimal display
        self.fig.patch.set_facecolor('black')
        self.fig.patch.set_alpha(1.0)
        
        # Create subplot with no margins
        self.ax = self.fig.add_subplot(111)
        self.ax.set_facecolor('black')
        self.ax.axis('off')
        
        # Completely remove all margins and padding
        self.fig.subplots_adjust(left=0, right=1, top=1, bottom=0, hspace=0, wspace=0)
        self.ax.margins(0)
        
        # Set canvas properties for better performance
        self.setStyleSheet("background-color: black;")
        
        # Mouse tracking
        self.mouse_pressed_flag = False
        self.last_mouse_pos = None
        
        # Image display properties
        self.image_object = None
        self.aspect_ratio = 'equal'
        
        # Force immediate draw to initialize properly
        self.draw()
        
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
        # Handle zoom and slice navigation
        if event.modifiers() & Qt.ControlModifier:
            # Zoom
            delta = event.angleDelta().y()
            zoom_factor = 1.1 if delta > 0 else 0.9
            if self.parent():
                self.parent().handle_zoom(zoom_factor)
        else:
            # Slice navigation
            delta = event.angleDelta().y()
            direction = 1 if delta > 0 else -1
            if self.parent():
                self.parent().handle_slice_change(direction)
        super().wheelEvent(event)
    
    def resizeEvent(self, event):
        """Handle resize events to maintain proper display"""
        super().resizeEvent(event)
        # Force redraw on resize
        self.draw_idle()
    
    def clear_canvas(self):
        """Properly clear the canvas"""
        self.ax.clear()
        self.ax.set_facecolor('black')
        self.ax.axis('off')
        self.ax.margins(0)
        self.image_object = None
    
    def display_image(self, image_data, extent=None):
        """Display image with proper settings"""
        try:
            # Clear previous image
            if self.image_object:
                self.image_object.remove()
                self.image_object = None
            
            # Ensure image data is in correct format
            if image_data.dtype != np.uint8:
                image_data = image_data.astype(np.uint8)
            
            # Display image with optimized settings
            self.image_object = self.ax.imshow(
                image_data, 
                cmap='gray', 
                origin='upper',
                extent=extent,
                aspect='equal',
                interpolation='nearest',  # Better for medical images
                resample=True,
                alpha=1.0
            )
            
            # Set tight layout
            self.ax.set_aspect('equal')
            self.ax.autoscale(tight=True)
            
            return True
            
        except Exception as e:
            print(f"Error displaying image: {e}")
            return False


class DicomViewer(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Python DICOM Viewer - Canvas Fixed")
        self.setGeometry(100, 100, 1400, 900)
        self.setStyleSheet("background-color: #2a2a2a; color: white;")
        
        # DICOM data
        self.dicom_files = []
        self.current_image_index = 0
        self.current_image_data = None
        self.current_dicom = None
        
        # Display parameters
        self.window_width = 400
        self.window_level = 40
        self.zoom_factor = 1.0
        self.pan_x = 0
        self.pan_y = 0
        self.inverted = False
        self.crosshair = False
        
        # Tools
        self.active_tool = 'windowing'
        self.measurements = []
        self.annotations = []
        self.current_measurement = None
        self.drag_start = None
        
        # Window presets
        self.window_presets = {
            'lung': {'ww': 1500, 'wl': -600},
            'bone': {'ww': 2000, 'wl': 300},
            'soft': {'ww': 400, 'wl': 40},
            'brain': {'ww': 100, 'wl': 50}
        }
        
        self.view_xlim = None
        self.view_ylim = None
        
        # Enhanced caching
        self._cached_image_data = None
        self._cached_image_params = (None, None, None, None)
        
        # Canvas state
        self.canvas_initialized = False
        
        self.init_ui()
        
        # Initialize canvas after UI is set up
        QTimer.singleShot(100, self.initialize_canvas)
        
    def initialize_canvas(self):
        """Initialize canvas after UI setup"""
        try:
            self.canvas.clear_canvas()
            self.canvas_initialized = True
            print("Canvas initialized successfully")
        except Exception as e:
            print(f"Canvas initialization error: {e}")
        
    def init_ui(self):
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        
        # Main layout
        main_layout = QHBoxLayout(main_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        
        # Left toolbar
        self.create_toolbar(main_layout)
        
        # Center area
        center_widget = QWidget()
        center_layout = QVBoxLayout(center_widget)
        center_layout.setContentsMargins(0, 0, 0, 0)
        
        # Top bar
        self.create_top_bar(center_layout)
        
        # Viewport
        self.create_viewport(center_layout)
        
        main_layout.addWidget(center_widget, 1)
        
        # Right panel
        self.create_right_panel(main_layout)
        
    def create_toolbar(self, main_layout):
        toolbar = QWidget()
        toolbar.setFixedWidth(80)
        toolbar.setStyleSheet("background-color: #333; border-right: 1px solid #555;")
        
        toolbar_layout = QVBoxLayout(toolbar)
        toolbar_layout.setContentsMargins(5, 10, 5, 10)
        toolbar_layout.setSpacing(5)
        
        tools = [
            ('windowing', 'Window', '🔄'),
            ('zoom', 'Zoom', '🔍'),
            ('pan', 'Pan', '✋'),
            ('measure', 'Measure', '📏'),
            ('annotate', 'Annotate', '📝'),
            ('crosshair', 'Crosshair', '✚'),
            ('invert', 'Invert', '⚫'),
            ('reset', 'Reset', '🔄'),
            ('refresh', 'Refresh', '🔃'),
            ('fit', 'Fit', '📐')
        ]
        
        self.tool_buttons = {}
        for tool_key, tool_label, tool_icon in tools:
            btn = QPushButton(f"{tool_icon}\n{tool_label}")
            btn.setFixedSize(70, 50)
            btn.setStyleSheet("""
                QPushButton {
                    background-color: #444;
                    color: white;
                    border: none;
                    border-radius: 5px;
                    font-size: 10px;
                }
                QPushButton:hover {
                    background-color: #555;
                }
                QPushButton:pressed {
                    background-color: #0078d4;
                }
            """)
            btn.clicked.connect(lambda checked, tool=tool_key: self.handle_tool_click(tool))
            toolbar_layout.addWidget(btn)
            self.tool_buttons[tool_key] = btn
        
        toolbar_layout.addStretch()
        main_layout.addWidget(toolbar)
        
    def create_top_bar(self, center_layout):
        top_bar = QWidget()
        top_bar.setFixedHeight(50)
        top_bar.setStyleSheet("background-color: #333; border-bottom: 1px solid #555;")
        
        top_layout = QHBoxLayout(top_bar)
        top_layout.setContentsMargins(20, 0, 20, 0)
        
        # Load DICOM button
        load_btn = QPushButton("Load DICOM Files")
        load_btn.setStyleSheet("""
            QPushButton {
                background-color: #0078d4;
                color: white;
                border: none;
                padding: 8px 16px;
                border-radius: 4px;
                font-size: 14px;
            }
            QPushButton:hover {
                background-color: #106ebe;
            }
        """)
        load_btn.clicked.connect(self.load_dicom_files)
        top_layout.addWidget(load_btn)
        
        # Load directory button
        load_dir_btn = QPushButton("Load DICOM Directory")
        load_dir_btn.setStyleSheet("""
            QPushButton {
                background-color: #0078d4;
                color: white;
                border: none;
                padding: 8px 16px;
                border-radius: 4px;
                font-size: 14px;
            }
            QPushButton:hover {
                background-color: #106ebe;
            }
        """)
        load_dir_btn.clicked.connect(self.load_dicom_directory)
        top_layout.addWidget(load_dir_btn)
        
        # Patient info
        self.patient_info_label = QLabel("No DICOM loaded")
        self.patient_info_label.setStyleSheet("font-size: 14px; color: #ccc;")
        top_layout.addWidget(self.patient_info_label)
        
        top_layout.addStretch()
        center_layout.addWidget(top_bar)
        
    def create_viewport(self, center_layout):
        viewport_widget = QWidget()
        viewport_widget.setStyleSheet("background-color: black; border: 1px solid #555;")
        viewport_widget.setMinimumSize(600, 600)
        
        viewport_layout = QVBoxLayout(viewport_widget)
        viewport_layout.setContentsMargins(2, 2, 2, 2)
        
        # DICOM canvas with improved initialization
        self.canvas = DicomCanvas(self)
        self.canvas.setSizePolicy(self.canvas.sizePolicy().Expanding, self.canvas.sizePolicy().Expanding)
        
        # Connect signals
        self.canvas.mouse_pressed.connect(self.on_mouse_press)
        self.canvas.mouse_moved.connect(self.on_mouse_move)
        self.canvas.mouse_released.connect(self.on_mouse_release)
        
        viewport_layout.addWidget(self.canvas)
        
        # Overlay labels
        self.create_overlay_labels(viewport_widget)
        
        center_layout.addWidget(viewport_widget)
        
    def create_overlay_labels(self, viewport_widget):
        # Window/Level info
        self.wl_label = QLabel("WW: 400\nWL: 40\nSlice: 0/0")
        self.wl_label.setStyleSheet("""
            background-color: rgba(0, 0, 0, 180);
            color: white;
            padding: 10px;
            border-radius: 5px;
            font-size: 12px;
            font-family: monospace;
        """)
        self.wl_label.setParent(viewport_widget)
        self.wl_label.move(10, 10)
        
        # Status info
        self.status_label = QLabel("Ready")
        self.status_label.setStyleSheet("""
            background-color: rgba(0, 0, 0, 180);
            color: white;
            padding: 5px 10px;
            border-radius: 3px;
            font-size: 12px;
        """)
        self.status_label.setParent(viewport_widget)
        
        # Position status label
        QTimer.singleShot(100, self.position_status_label)
        
    def position_status_label(self):
        if hasattr(self, 'status_label'):
            parent = self.status_label.parent()
            if parent:
                self.status_label.move(10, parent.height() - 40)
        
    def create_right_panel(self, main_layout):
        right_panel = QWidget()
        right_panel.setFixedWidth(250)
        right_panel.setStyleSheet("background-color: #333; border-left: 1px solid #555;")
        
        scroll_area = QScrollArea()
        scroll_area.setWidget(right_panel)
        scroll_area.setWidgetResizable(True)
        scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        
        panel_layout = QVBoxLayout(right_panel)
        panel_layout.setContentsMargins(20, 20, 20, 20)
        panel_layout.setSpacing(20)
        
        # Window/Level section
        self.create_window_level_section(panel_layout)
        
        # Navigation section
        self.create_navigation_section(panel_layout)
        
        # Transform section
        self.create_transform_section(panel_layout)
        
        # Image info section
        self.create_image_info_section(panel_layout)
        
        panel_layout.addStretch()
        main_layout.addWidget(scroll_area)
        
    def create_window_level_section(self, panel_layout):
        wl_frame = QFrame()
        wl_layout = QVBoxLayout(wl_frame)
        
        wl_title = QLabel("Window/Level")
        wl_title.setStyleSheet("font-size: 14px; font-weight: bold; color: white; margin-bottom: 10px;")
        wl_layout.addWidget(wl_title)
        
        # Window Width slider
        ww_label = QLabel("Window Width")
        ww_label.setStyleSheet("font-size: 12px; color: #ccc;")
        wl_layout.addWidget(ww_label)
        
        self.ww_value_label = QLabel(str(self.window_width))
        self.ww_value_label.setStyleSheet("font-size: 12px; color: #ccc;")
        self.ww_value_label.setAlignment(Qt.AlignRight)
        
        ww_header = QHBoxLayout()
        ww_header.addWidget(ww_label)
        ww_header.addWidget(self.ww_value_label)
        wl_layout.addLayout(ww_header)
        
        self.ww_slider = QSlider(Qt.Horizontal)
        self.ww_slider.setRange(1, 4000)
        self.ww_slider.setValue(self.window_width)
        self.ww_slider.valueChanged.connect(self.handle_window_width_change)
        wl_layout.addWidget(self.ww_slider)
        
        # Window Level slider
        wl_label = QLabel("Window Level")
        wl_label.setStyleSheet("font-size: 12px; color: #ccc;")
        wl_layout.addWidget(wl_label)
        
        self.wl_value_label = QLabel(str(self.window_level))
        self.wl_value_label.setStyleSheet("font-size: 12px; color: #ccc;")
        self.wl_value_label.setAlignment(Qt.AlignRight)
        
        wl_header = QHBoxLayout()
        wl_header.addWidget(wl_label)
        wl_header.addWidget(self.wl_value_label)
        wl_layout.addLayout(wl_header)
        
        self.wl_slider = QSlider(Qt.Horizontal)
        self.wl_slider.setRange(-1000, 1000)
        self.wl_slider.setValue(self.window_level)
        self.wl_slider.valueChanged.connect(self.handle_window_level_change)
        wl_layout.addWidget(self.wl_slider)
        
        # Preset buttons
        preset_layout = QGridLayout()
        preset_layout.setSpacing(5)
        
        preset_buttons = ['lung', 'bone', 'soft', 'brain']
        for i, preset in enumerate(preset_buttons):
            btn = QPushButton(preset.capitalize())
            btn.setStyleSheet("""
                QPushButton {
                    background-color: #444;
                    color: white;
                    border: none;
                    padding: 8px 4px;
                    border-radius: 3px;
                    font-size: 11px;
                }
                QPushButton:hover {
                    background-color: #555;
                }
            """)
            btn.clicked.connect(lambda checked, p=preset: self.handle_preset(p))
            preset_layout.addWidget(btn, i // 2, i % 2)
        
        wl_layout.addLayout(preset_layout)
        panel_layout.addWidget(wl_frame)
        
    def create_navigation_section(self, panel_layout):
        nav_frame = QFrame()
        nav_layout = QVBoxLayout(nav_frame)
        
        nav_title = QLabel("Image Navigation")
        nav_title.setStyleSheet("font-size: 14px; font-weight: bold; color: white; margin-bottom: 10px;")
        nav_layout.addWidget(nav_title)
        
        # Slice slider
        slice_label = QLabel("Slice")
        slice_label.setStyleSheet("font-size: 12px; color: #ccc;")
        nav_layout.addWidget(slice_label)
        
        self.slice_value_label = QLabel("0")
        self.slice_value_label.setStyleSheet("font-size: 12px; color: #ccc;")
        self.slice_value_label.setAlignment(Qt.AlignRight)

        slice_header = QHBoxLayout()
        slice_header.addWidget(slice_label)
        slice_header.addWidget(self.slice_value_label)
        nav_layout.addLayout(slice_header)
        
        self.slice_slider = QSlider(Qt.Horizontal)
        self.slice_slider.setRange(0, 0)
        self.slice_slider.setValue(0)
        self.slice_slider.valueChanged.connect(self.handle_slice_change_slider)
        nav_layout.addWidget(self.slice_slider)
        
        panel_layout.addWidget(nav_frame)
        
    def create_transform_section(self, panel_layout):
        transform_frame = QFrame()
        transform_layout = QVBoxLayout(transform_frame)
        
        transform_title = QLabel("Transform")
        transform_title.setStyleSheet("font-size: 14px; font-weight: bold; color: white; margin-bottom: 10px;")
        transform_layout.addWidget(transform_title)
        
        # Zoom slider
        zoom_label = QLabel("Zoom")
        zoom_label.setStyleSheet("font-size: 12px; color: #ccc;")
        transform_layout.addWidget(zoom_label)
        
        self.zoom_value_label = QLabel("100%")
        self.zoom_value_label.setStyleSheet("font-size: 12px; color: #ccc;")
        self.zoom_value_label.setAlignment(Qt.AlignRight)
        
        zoom_header = QHBoxLayout()
        zoom_header.addWidget(zoom_label)
        zoom_header.addWidget(self.zoom_value_label)
        transform_layout.addLayout(zoom_header)
        
        self.zoom_slider = QSlider(Qt.Horizontal)
        self.zoom_slider.setRange(25, 500)
        self.zoom_slider.setValue(100)
        self.zoom_slider.valueChanged.connect(self.handle_zoom_slider)
        transform_layout.addWidget(self.zoom_slider)
        
        panel_layout.addWidget(transform_frame)
        
    def create_image_info_section(self, panel_layout):
        info_frame = QFrame()
        info_layout = QVBoxLayout(info_frame)
        
        info_title = QLabel("Image Info")
        info_title.setStyleSheet("font-size: 14px; font-weight: bold; color: white; margin-bottom: 10px;")
        info_layout.addWidget(info_title)
        
        self.info_labels = {}
        info_items = ['dimensions', 'pixel_spacing', 'series', 'institution']
        
        for item in info_items:
            label = QLabel(f"{item.replace('_', ' ').title()}: -")
            label.setStyleSheet("font-size: 12px; color: #ccc; margin-bottom: 5px;")
            info_layout.addWidget(label)
            self.info_labels[item] = label
        
        panel_layout.addWidget(info_frame)
        
    def load_dicom_files(self):
        """Load individual DICOM files"""
        file_dialog = QFileDialog()
        file_paths, _ = file_dialog.getOpenFileNames(
            self, "Select DICOM Files", "", "DICOM Files (*.dcm *.dicom);;All Files (*)"
        )
        
        if file_paths:
            self.process_dicom_files(file_paths)
    
    def load_dicom_directory(self):
        """Load all DICOM files from a directory"""
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
                                  "No DICOM files found in the selected directory.")
    
    def is_dicom_file(self, file_path):
        """Check if a file is a DICOM file"""
        try:
            pydicom.dcmread(file_path, stop_before_pixels=True)
            return True
        except:
            return False
    
    def process_dicom_files(self, file_paths):
        """Process and load DICOM files with enhanced validation"""
        self.dicom_files = []
        failed_files = []
        
        self.update_status(f"Loading {len(file_paths)} DICOM files...")
        
        for i, file_path in enumerate(file_paths):
            try:
                print(f"Processing [{i+1}/{len(file_paths)}]: {file_path}")
                dicom_data = pydicom.dcmread(file_path)
                
                # Enhanced validation
                if not hasattr(dicom_data, 'pixel_array'):
                    print(f"Warning: {file_path} has no pixel data")
                    continue
                
                # Test pixel array access
                try:
                    pixel_array = dicom_data.pixel_array
                    if pixel_array is None or pixel_array.size == 0:
                        print(f"Warning: {file_path} has invalid pixel data")
                        continue
                except Exception as pixel_error:
                    print(f"Warning: Cannot access pixel data in {file_path}: {pixel_error}")
                    continue
                
                self.dicom_files.append(dicom_data)
                print(f"Successfully loaded: {file_path}")
                
            except Exception as e:
                print(f"Error loading {file_path}: {str(e)}")
                failed_files.append(file_path)
        
        if self.dicom_files:
            print(f"Successfully loaded {len(self.dicom_files)} DICOM files")
            
            # Sort files properly
            self.dicom_files.sort(key=self.get_sort_key)
            
            # Reset view state
            self.current_image_index = 0
            self.slice_slider.setRange(0, len(self.dicom_files) - 1)
            self.slice_slider.setValue(0)
            
            # Clear cache
            self._cached_image_data = None
            self._cached_image_params = (None, None, None, None)
            
            # Initialize display
            self.set_initial_window_level()
            self.update_patient_info()
            self.update_display()
            
            self.update_status(f"Loaded {len(self.dicom_files)} images")
            
            if failed_files:
                QMessageBox.warning(self, "Some Files Failed", 
                                  f"Successfully loaded {len(self.dicom_files)} files.\n"
                                  f"Failed to load {len(failed_files)} files.")
        else:
            self.update_status("No valid DICOM files loaded")
            QMessageBox.warning(self, "No Valid DICOM Files", 
                              "No valid DICOM files with image data were found.")
    
    def get_sort_key(self, dicom_data):
        """Get sort key for DICOM files"""
        if hasattr(dicom_data, 'InstanceNumber'):
            return dicom_data.InstanceNumber
        elif hasattr(dicom_data, 'SliceLocation'):
            return dicom_data.SliceLocation
        elif hasattr(dicom_data, 'ImagePositionPatient') and dicom_data.ImagePositionPatient:
            return dicom_data.ImagePositionPatient[2]
        else:
            return 0
    
    def set_initial_window_level(self):
        """Set initial window/level from DICOM or calculate from image"""
        if not self.dicom_files:
            return
        
        first_dicom = self.dicom_files[0]
        
        # Try DICOM tags first
        if hasattr(first_dicom, 'WindowWidth') and hasattr(first_dicom, 'WindowCenter'):
            if isinstance(first_dicom.WindowWidth, (list, tuple)):
                self.window_width = float(first_dicom.WindowWidth[0])
            else:
                self.window_width = float(first_dicom.WindowWidth)
            
            if isinstance(first_dicom.WindowCenter, (list, tuple)):
                self.window_level = float(first_dicom.WindowCenter[0])
            else:
                self.window_level = float(first_dicom.WindowCenter)
        else:
            # Calculate from pixel data
            try:
                pixel_array = first_dicom.pixel_array
                min_val = np.percentile(pixel_array, 2)
                max_val = np.percentile(pixel_array, 98)
                
                self.window_width = max_val - min_val
                self.window_level = (max_val + min_val) / 2
                
                print(f"Calculated window/level: WW={self.window_width:.1f}, WL={self.window_level:.1f}")
            except Exception as e:
                print(f"Error calculating window/level: {e}")
                self.window_width = 400
                self.window_level = 40
        
        # Update UI
        self.ww_slider.setValue(int(self.window_width))
        self.wl_slider.setValue(int(self.window_level))
        self.ww_value_label.setText(str(int(self.window_width)))
        self.wl_value_label.setText(str(int(self.window_level)))
    
    def update_patient_info(self):
        if not self.dicom_files:
            self.patient_info_label.setText("No DICOM loaded")
            return
            
        dicom_data = self.dicom_files[self.current_image_index]
        
        # Extract information
        patient_name = getattr(dicom_data, 'PatientName', 'Unknown')
        study_date = getattr(dicom_data, 'StudyDate', 'Unknown')
        modality = getattr(dicom_data, 'Modality', 'Unknown')
        
        self.patient_info_label.setText(f"Patient: {patient_name} | Study: {study_date} | {modality}")
        
        # Update image info
        rows = getattr(dicom_data, 'Rows', 'Unknown')
        cols = getattr(dicom_data, 'Columns', 'Unknown')
        pixel_spacing = getattr(dicom_data, 'PixelSpacing', ['Unknown', 'Unknown'])
        series_description = getattr(dicom_data, 'SeriesDescription', 'Unknown')
        institution = getattr(dicom_data, 'InstitutionName', 'Unknown')
        
        self.info_labels['dimensions'].setText(f"Dimensions: {cols}x{rows}")
        
        if isinstance(pixel_spacing, list) and len(pixel_spacing) >= 2:
            self.info_labels['pixel_spacing'].setText(f"Pixel Spacing: {pixel_spacing[0]:.2f}x{pixel_spacing[1]:.2f}")
        else:
            self.info_labels['pixel_spacing'].setText(f"Pixel Spacing: {pixel_spacing}")
            
        self.info_labels['series'].setText(f"Series: {series_description}")
        self.info_labels['institution'].setText(f"Institution: {institution}")
    
    def update_display(self):
        """Enhanced display update with better error handling"""
        if not self.dicom_files or not self.canvas_initialized:
            return
        
        try:
            self.update_status("Updating display...")
            
            # Clear canvas properly
            self.canvas.clear_canvas()
            
            self.current_dicom = self.dicom_files[self.current_image_index]
            
            # Check cache
            cache_params = (self.current_image_index, self.window_width, self.window_level, self.inverted)
            if self._cached_image_params == cache_params and self._cached_image_data is not None:
                image_data = self._cached_image_data
            else:
                # Process image
                if not hasattr(self.current_dicom, 'pixel_array'):
                    self.update_status("Error: No pixel data")
                    return
                
                self.current_image_data = self.current_dicom.pixel_array.copy()
                
                print(f"Processing image - Shape: {self.current_image_data.shape}, "
                      f"Type: {self.current_image_data.dtype}, "
                      f"Range: {self.current_image_data.min()}-{self.current_image_data.max()}")
                
                # Handle multi-dimensional images
                if len(self.current_image_data.shape) == 3:
                    if self.current_image_data.shape[2] == 3:
                        # RGB to grayscale
                        self.current_image_data = np.mean(self.current_image_data, axis=2)
                    else:
                        # Multi-frame, take first
                        self.current_image_data = self.current_image_data[:, :, 0]
                
                # Apply windowing
                image_data = self.apply_windowing(self.current_image_data)
                
                # Handle photometric interpretation
                if hasattr(self.current_dicom, 'PhotometricInterpretation'):
                    if self.current_dicom.PhotometricInterpretation == 'MONOCHROME1':
                        image_data = 255 - image_data
                
                # Apply user inversion
                if self.inverted:
                    image_data = 255 - image_data
                
                # Cache result
                self._cached_image_data = image_data
                self._cached_image_params = cache_params
            
            h, w = image_data.shape
            
            # Display image with proper extent
            success = self.canvas.display_image(image_data, extent=(0, w, h, 0))
            
            if success:
                # Set view limits
                if self.view_xlim and self.view_ylim:
                    self.canvas.ax.set_xlim(self.view_xlim)
                    self.canvas.ax.set_ylim(self.view_ylim)
                else:
                    self.canvas.ax.set_xlim(0, w)
                    self.canvas.ax.set_ylim(h, 0)
                    self.view_xlim = (0, w)
                    self.view_ylim = (h, 0)
                
                # Draw overlays
                self.draw_measurements()
                self.draw_annotations()
                if self.crosshair:
                    self.draw_crosshair()
                
                # Force canvas update
                self.canvas.draw()
                
                self.update_overlay_labels()
                self.update_status("Display updated")
            else:
                self.update_status("Failed to display image")
                
        except Exception as e:
            error_msg = f"Error updating display: {e}"
            print(error_msg)
            print(traceback.format_exc())
            self.update_status(f"Display error: {str(e)}")
            QMessageBox.warning(self, "Display Error", error_msg)
        
    def apply_windowing(self, image_data):
        """Apply window/level with improved handling"""
        # Convert to float for calculations
        image_data = image_data.astype(np.float64)
        
        # Apply window/level
        min_val = self.window_level - self.window_width / 2
        max_val = self.window_level + self.window_width / 2
        
        # Clip and normalize
        image_data = np.clip(image_data, min_val, max_val)
        
        # Avoid division by zero
        if max_val - min_val != 0:
            image_data = (image_data - min_val) / (max_val - min_val) * 255
        else:
            image_data = np.zeros_like(image_data)
        
        return image_data.astype(np.uint8)

    def handle_tool_click(self, tool):
        print(f"Tool activated: {tool}")
        if tool == 'reset':
            self.reset_view()
        elif tool == 'refresh':
            self.refresh_display()
        elif tool == 'fit':
            self.fit_to_window()
        elif tool == 'invert':
            self.inverted = not self.inverted
            self._cached_image_data = None
            self.update_display()
        elif tool == 'crosshair':
            self.crosshair = not self.crosshair
            self.update_display()
        else:
            self.active_tool = tool
        
        # Update button styles
        for btn_key, btn in self.tool_buttons.items():
            if btn_key == tool and tool not in ['reset', 'refresh', 'fit', 'invert', 'crosshair']:
                btn.setStyleSheet(btn.styleSheet().replace('#444', '#0078d4'))
            else:
                btn.setStyleSheet(btn.styleSheet().replace('#0078d4', '#444'))
    
    def refresh_display(self):
        """Force refresh of the display"""
        self._cached_image_data = None
        self._cached_image_params = (None, None, None, None)
        if self.canvas_initialized:
            self.canvas.clear_canvas()
        self.update_display()
    
    def fit_to_window(self):
        """Fit image to window"""
        if self.current_image_data is not None:
            h, w = self.current_image_data.shape
            self.view_xlim = (0, w)
            self.view_ylim = (h, 0)
            self.zoom_factor = 1.0
            self.zoom_slider.setValue(100)
            self.update_display()
                
    def handle_window_width_change(self, value):
        self.window_width = value
        self.ww_value_label.setText(str(value))
        self._cached_image_data = None
        self.update_display()
        
    def handle_window_level_change(self, value):
        self.window_level = value
        self.wl_value_label.setText(str(value))
        self._cached_image_data = None
        self.update_display()
        
    def handle_preset(self, preset):
        preset_values = self.window_presets[preset]
        self.window_width = preset_values['ww']
        self.window_level = preset_values['wl']
        
        self.ww_slider.setValue(self.window_width)
        self.wl_slider.setValue(self.window_level)
        
        self._cached_image_data = None
        self.update_display()
        
    def handle_slice_change_slider(self, value):
        if value < len(self.dicom_files):
            self.current_image_index = value
            self.slice_value_label.setText(str(value + 1))
            self.update_display()
            self.update_patient_info()
        
    def handle_slice_change(self, direction):
        new_index = self.current_image_index + direction
        if 0 <= new_index < len(self.dicom_files):
            self.current_image_index = new_index
            self.slice_slider.setValue(new_index)
            self.update_display()
            
    def handle_zoom_slider(self, value):
        self.zoom_factor = value / 100.0
        self.zoom_value_label.setText(f"{value}%")
        self.update_display()
        
    def handle_zoom(self, factor):
        if not self.current_image_data:
            return
            
        xlim = self.canvas.ax.get_xlim()
        ylim = self.canvas.ax.get_ylim()
        xcenter = (xlim[0] + xlim[1]) / 2
        ycenter = (ylim[0] + ylim[1]) / 2
        xwidth = (xlim[1] - xlim[0]) / factor
        yheight = (ylim[0] - ylim[1]) / factor
        new_xlim = (xcenter - xwidth/2, xcenter + xwidth/2)
        new_ylim = (ycenter + yheight/2, ycenter - yheight/2)
        self.canvas.ax.set_xlim(new_xlim)
        self.canvas.ax.set_ylim(new_ylim)
        self.view_xlim = new_xlim
        self.view_ylim = new_ylim
        self.zoom_factor *= factor
        self.zoom_factor = max(0.1, min(5.0, self.zoom_factor))
        zoom_percent = int(self.zoom_factor * 100)
        self.zoom_slider.setValue(zoom_percent)
        self.canvas.draw_idle()
        
    def widget_to_data_coords(self, x, y):
        try:
            inv = self.canvas.ax.transData.inverted()
            return inv.transform((x, y))
        except:
            return (0, 0)

    def on_mouse_press(self, x, y):
        if self.current_image_data is None:
            return
        data_x, data_y = self.widget_to_data_coords(x, y)
        self.drag_start = (data_x, data_y)
        if self.active_tool == 'measure':
            self.current_measurement = {'start': (data_x, data_y), 'end': (data_x, data_y)}
        elif self.active_tool == 'annotate':
            text, ok = QInputDialog.getText(self, 'Annotation', 'Enter annotation text:')
            if ok and text:
                self.annotations.append({'pos': (data_x, data_y), 'text': text})
                self.update_display()

    def on_mouse_move(self, x, y):
        if not self.drag_start or self.current_image_data is None:
            return
        data_x, data_y = self.widget_to_data_coords(x, y)
        dx = data_x - self.drag_start[0]
        dy = data_y - self.drag_start[1]
        
        if self.active_tool == 'pan':
            xlim = self.canvas.ax.get_xlim()
            ylim = self.canvas.ax.get_ylim()
            new_xlim = (xlim[0] - dx, xlim[1] - dx)
            new_ylim = (ylim[0] - dy, ylim[1] - dy)
            self.canvas.ax.set_xlim(new_xlim)
            self.canvas.ax.set_ylim(new_ylim)
            self.view_xlim = new_xlim
            self.view_ylim = new_ylim
            self.drag_start = (data_x, data_y)
            self.canvas.draw_idle()
        elif self.active_tool == 'zoom':
            zoom_delta = 1 + dy * 0.01
            self.handle_zoom(zoom_delta)
            self.drag_start = (data_x, data_y)
        elif self.active_tool == 'windowing':
            self.window_width = max(1, self.window_width + dx * 2)
            self.window_level = max(-1000, min(1000, self.window_level + dy * 2))
            self.drag_start = (data_x, data_y)
            self.ww_slider.setValue(int(self.window_width))
            self.wl_slider.setValue(int(self.window_level))
            self._cached_image_data = None
            self.update_display()
        elif self.active_tool == 'measure' and self.current_measurement:
            self.current_measurement['end'] = (data_x, data_y)
            self.update_overlays()

    def on_mouse_release(self, x, y):
        if self.active_tool == 'measure' and self.current_measurement:
            data_x, data_y = self.widget_to_data_coords(x, y)
            self.current_measurement['end'] = (data_x, data_y)
            self.measurements.append(self.current_measurement)
            self.current_measurement = None
            self.update_overlays()
        
        self.drag_start = None

    def update_overlays(self):
        self.canvas.ax.lines.clear()
        self.canvas.ax.texts.clear()
        self.draw_measurements()
        self.draw_annotations()
        if self.crosshair:
            self.draw_crosshair()
        self.canvas.draw_idle()
        
    def draw_measurements(self):
        for measurement in self.measurements:
            start = measurement['start']
            end = measurement['end']
            x_data = [start[0], end[0]]
            y_data = [start[1], end[1]]
            self.canvas.ax.plot(x_data, y_data, 'r-', linewidth=2)
            distance = np.sqrt((x_data[1] - x_data[0])**2 + (y_data[1] - y_data[0])**2)
            distance_text = f"{distance:.1f} px"
            mid_x = (x_data[0] + x_data[1]) / 2
            mid_y = (y_data[0] + y_data[1]) / 2
            self.canvas.ax.text(mid_x, mid_y, distance_text, color='red', 
                              fontsize=10, ha='center', va='center',
                              bbox=dict(boxstyle="round,pad=0.3", facecolor='black', alpha=0.7))
        if self.current_measurement:
            start = self.current_measurement['start']
            end = self.current_measurement['end']
            x_data = [start[0], end[0]]
            y_data = [start[1], end[1]]
            self.canvas.ax.plot(x_data, y_data, 'y--', linewidth=2, alpha=0.7)
            
    def draw_annotations(self):
        for annotation in self.annotations:
            pos = annotation['pos']
            text = annotation['text']
            self.canvas.ax.text(pos[0], pos[1], text, color='yellow', 
                              fontsize=12, ha='left', va='bottom',
                              bbox=dict(boxstyle="round,pad=0.5", facecolor='black', alpha=0.8))
                              
    def draw_crosshair(self):
        if self.current_image_data is not None:
            height, width = self.current_image_data.shape
            center_x = width // 2
            center_y = height // 2
            self.canvas.ax.axvline(x=center_x, color='cyan', linewidth=1, alpha=0.7)
            self.canvas.ax.axhline(y=center_y, color='cyan', linewidth=1, alpha=0.7)
            
    def update_overlay_labels(self):
        """Update overlay labels"""
        slice_info = f"{self.current_image_index + 1}/{len(self.dicom_files)}" if self.dicom_files else "0/0"
        self.wl_label.setText(f"WW: {int(self.window_width)}\nWL: {int(self.window_level)}\nSlice: {slice_info}")
        
    def update_status(self, message):
        """Update status label"""
        if hasattr(self, 'status_label'):
            self.status_label.setText(message)
        
    def reset_view(self):
        """Reset view to default"""
        self.zoom_factor = 1.0
        self.pan_x = 0
        self.pan_y = 0
        self.zoom_slider.setValue(100)
        if self.current_image_data is not None:
            h, w = self.current_image_data.shape
            self.view_xlim = (0, w)
            self.view_ylim = (h, 0)
        self.measurements.clear()
        self.annotations.clear()
        self.update_display()
        
    def resizeEvent(self, event):
        """Handle window resize"""
        super().resizeEvent(event)
        QTimer.singleShot(10, self.position_status_label)


def main():
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    
    viewer = DicomViewer()
    viewer.show()
    
    sys.exit(app.exec_())


if __name__ == '__main__':
    main()