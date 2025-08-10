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
import matplotlib.pyplot as plt
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
import requests
import json


class DicomCanvas(FigureCanvas):
    """Enhanced matplotlib canvas for DICOM image display with improved interaction"""
    mouse_pressed = pyqtSignal(int, int)
    mouse_moved = pyqtSignal(int, int)
    mouse_released = pyqtSignal(int, int)
    
    def __init__(self, parent=None):
        self.fig = Figure(figsize=(10, 10), facecolor='black')
        super().__init__(self.fig)
        self.setParent(parent)
        
        # Create subplot with proper configuration
        self.ax = self.fig.add_subplot(111)
        self.ax.set_facecolor('black')
        self.ax.axis('off')
        
        # Remove all margins and padding for full image display
        self.fig.subplots_adjust(left=0, right=1, top=1, bottom=0)
        self.fig.patch.set_facecolor('black')
        
        # Enhanced mouse tracking
        self.mouse_pressed_flag = False
        self.last_mouse_pos = None
        self.drag_start_pos = None
        
        # Enable mouse tracking for continuous position updates
        self.setMouseTracking(True)
        
        # Image display properties
        self.image_object = None
        self.current_extent = None
        
    def clear_canvas(self):
        """Clear the canvas completely"""
        self.ax.clear()
        self.ax.set_facecolor('black')
        self.ax.axis('off')
        self.current_extent = None
        self.image_object = None
        
    def display_image(self, image_data, extent=None):
        """Display image with proper extent handling"""
        if extent is None:
            h, w = image_data.shape
            extent = (0, w, h, 0)
            
        self.current_extent = extent
        
        # Clear previous content
        self.ax.clear()
        self.ax.set_facecolor('black')
        self.ax.axis('off')
        
        # Display the image
        self.image_object = self.ax.imshow(
            image_data, 
            cmap='gray', 
            origin='upper', 
            extent=extent,
            interpolation='nearest',  # Better for medical images
            aspect='equal'
        )
        
        # Set initial view
        self.ax.set_xlim(extent[0], extent[1])
        self.ax.set_ylim(extent[2], extent[3])
        
    def get_image_coordinates(self, widget_x, widget_y):
        """Convert widget coordinates to image coordinates"""
        if self.current_extent is None:
            return None, None
            
        try:
            # Transform from widget coordinates to data coordinates
            inv_trans = self.ax.transData.inverted()
            data_coords = inv_trans.transform((widget_x, widget_y))
            
            # Check if coordinates are within image bounds
            x, y = data_coords
            if (self.current_extent[0] <= x <= self.current_extent[1] and 
                self.current_extent[3] <= y <= self.current_extent[2]):
                return x, y
            else:
                return None, None
        except:
            return None, None
    
    def mousePressEvent(self, event):
        """Enhanced mouse press handling"""
        if event.button() == Qt.LeftButton:
            self.mouse_pressed_flag = True
            self.last_mouse_pos = (event.x(), event.y())
            self.drag_start_pos = (event.x(), event.y())
            self.mouse_pressed.emit(event.x(), event.y())
        super().mousePressEvent(event)
    
    def mouseMoveEvent(self, event):
        """Enhanced mouse move handling with continuous updates"""
        current_pos = (event.x(), event.y())
        
        # Always emit mouse position for cursor tracking
        if hasattr(self.parent(), 'update_cursor_info'):
            img_x, img_y = self.get_image_coordinates(event.x(), event.y())
            if img_x is not None and img_y is not None:
                self.parent().update_cursor_info(img_x, img_y)
        
        # Handle dragging operations
        if self.mouse_pressed_flag:
            self.mouse_moved.emit(event.x(), event.y())
            
        self.last_mouse_pos = current_pos
        super().mouseMoveEvent(event)
    
    def mouseReleaseEvent(self, event):
        """Enhanced mouse release handling"""
        if event.button() == Qt.LeftButton:
            self.mouse_pressed_flag = False
            self.mouse_released.emit(event.x(), event.y())
            self.drag_start_pos = None
        super().mouseReleaseEvent(event)
    
    def wheelEvent(self, event):
        """Enhanced wheel event handling for zoom and slice navigation"""
        if not hasattr(self.parent(), 'handle_zoom') or not hasattr(self.parent(), 'handle_slice_change'):
            super().wheelEvent(event)
            return
            
        # Get mouse position for zoom center
        mouse_x, mouse_y = event.x(), event.y()
        
        if event.modifiers() & Qt.ControlModifier:
            # Zoom with mouse position as center
            delta = event.angleDelta().y()
            zoom_factor = 1.15 if delta > 0 else 1/1.15
            self.parent().handle_zoom(zoom_factor, mouse_x, mouse_y)
        else:
            # Slice navigation
            delta = event.angleDelta().y()
            direction = 1 if delta > 0 else -1
            self.parent().handle_slice_change(direction)
        super().wheelEvent(event)
        
    def leaveEvent(self, event):
        """Handle mouse leaving the canvas"""
        if hasattr(self.parent(), 'update_cursor_info'):
            self.parent().update_cursor_info(None, None)
        super().leaveEvent(event)


class DicomViewer(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Advanced DICOM Viewer")
        self.setGeometry(100, 100, 1600, 1000)
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
            'brain': {'ww': 100, 'wl': 50},
            'abdomen': {'ww': 350, 'wl': 50},
            'mediastinum': {'ww': 350, 'wl': 50}
        }
        
        # View state
        self.view_xlim = None
        self.view_ylim = None
        
        # Image caching
        self._cached_image_data = None
        self._cached_image_params = (None, None, None, None)
        
        # Cursor information
        self.cursor_x = None
        self.cursor_y = None
        
        self.init_ui()
        
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
        
        # Top bar (removed system selector)
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
            ('ai', 'AI', '🤖'),
            ('recon', '3D', '🧊')
        ]
        
        self.tool_buttons = {}
        for tool_key, tool_label, tool_icon in tools:
            btn = QPushButton(f"{tool_icon}\n{tool_label}")
            btn.setFixedSize(70, 55)
            btn.setStyleSheet("""
                QPushButton {
                    background-color: #444;
                    color: white;
                    border: none;
                    border-radius: 5px;
                    font-size: 10px;
                    font-weight: bold;
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
        top_bar.setFixedHeight(60)
        top_bar.setStyleSheet("background-color: #333; border-bottom: 1px solid #555;")
        
        top_layout = QHBoxLayout(top_bar)
        top_layout.setContentsMargins(20, 0, 20, 0)
        
        # Load DICOM button
        load_btn = QPushButton("📁 Load DICOM Files")
        load_btn.setStyleSheet("""
            QPushButton {
                background-color: #0078d4;
                color: white;
                border: none;
                padding: 12px 20px;
                border-radius: 6px;
                font-size: 14px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #106ebe;
            }
        """)
        load_btn.clicked.connect(self.load_dicom_files)
        top_layout.addWidget(load_btn)
        
        top_layout.addSpacing(20)
        
        # Patient info
        self.patient_info_label = QLabel("No DICOM files loaded")
        self.patient_info_label.setStyleSheet("font-size: 14px; color: #ccc; font-weight: bold;")
        top_layout.addWidget(self.patient_info_label)
        
        top_layout.addStretch()
        
        # Cursor info
        self.cursor_info_label = QLabel("Position: -")
        self.cursor_info_label.setStyleSheet("font-size: 12px; color: #aaa;")
        top_layout.addWidget(self.cursor_info_label)
        
        center_layout.addWidget(top_bar)
        
    def create_viewport(self, center_layout):
        viewport_widget = QWidget()
        viewport_widget.setStyleSheet("background-color: black; border: 2px solid #555;")
        
        viewport_layout = QVBoxLayout(viewport_widget)
        viewport_layout.setContentsMargins(2, 2, 2, 2)
        
        # Enhanced DICOM canvas
        self.canvas = DicomCanvas(self)
        self.canvas.mouse_pressed.connect(self.on_mouse_press)
        self.canvas.mouse_moved.connect(self.on_mouse_move)
        self.canvas.mouse_released.connect(self.on_mouse_release)
        
        viewport_layout.addWidget(self.canvas)
        
        # Overlay labels
        self.create_overlay_labels(viewport_widget)
        
        center_layout.addWidget(viewport_widget)
        
    def create_overlay_labels(self, viewport_widget):
        # Window/Level info (top-left)
        self.wl_label = QLabel("WW: 400\nWL: 40\nSlice: 1/1")
        self.wl_label.setStyleSheet("""
            background-color: rgba(0, 0, 0, 150);
            color: white;
            padding: 10px;
            border-radius: 5px;
            font-size: 12px;
            font-weight: bold;
            border: 1px solid rgba(255, 255, 255, 50);
        """)
        self.wl_label.setParent(viewport_widget)
        self.wl_label.move(15, 15)
        
        # Zoom info (bottom-left)
        self.zoom_label = QLabel("Zoom: 100%")
        self.zoom_label.setStyleSheet("""
            background-color: rgba(0, 0, 0, 150);
            color: white;
            padding: 8px 12px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
            border: 1px solid rgba(255, 255, 255, 50);
        """)
        self.zoom_label.setParent(viewport_widget)
        
        # Tool info (top-right)
        self.tool_label = QLabel("Tool: Windowing")
        self.tool_label.setStyleSheet("""
            background-color: rgba(0, 120, 212, 150);
            color: white;
            padding: 8px 12px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
            border: 1px solid rgba(255, 255, 255, 50);
        """)
        self.tool_label.setParent(viewport_widget)
        
        # Position labels on timer
        QTimer.singleShot(100, self.position_overlay_labels)
        
    def position_overlay_labels(self):
        """Position overlay labels correctly"""
        if hasattr(self, 'zoom_label') and hasattr(self, 'tool_label'):
            parent = self.zoom_label.parent()
            if parent:
                # Bottom-left for zoom
                self.zoom_label.move(15, parent.height() - 50)
                # Top-right for tool
                self.tool_label.move(parent.width() - self.tool_label.width() - 15, 15)
        
    def update_cursor_info(self, x, y):
        """Update cursor position information"""
        if x is not None and y is not None:
            self.cursor_x = x
            self.cursor_y = y
            
            # Get pixel value if we have image data
            pixel_value = "-"
            if (self.current_image_data is not None and 
                0 <= int(x) < self.current_image_data.shape[1] and 
                0 <= int(y) < self.current_image_data.shape[0]):
                pixel_value = f"{self.current_image_data[int(y), int(x)]}"
            
            self.cursor_info_label.setText(f"Position: ({int(x)}, {int(y)}) | Value: {pixel_value}")
        else:
            self.cursor_x = None
            self.cursor_y = None
            self.cursor_info_label.setText("Position: -")

    def create_right_panel(self, main_layout):
        right_panel = QWidget()
        right_panel.setFixedWidth(280)
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
        
        # Measurements section
        self.create_measurements_section(panel_layout)
        
        panel_layout.addStretch()
        main_layout.addWidget(scroll_area)

    def create_window_level_section(self, panel_layout):
        wl_frame = QFrame()
        wl_frame.setStyleSheet("QFrame { border: 1px solid #555; border-radius: 5px; padding: 10px; }")
        wl_layout = QVBoxLayout(wl_frame)
        
        wl_title = QLabel("🔧 Window/Level")
        wl_title.setStyleSheet("font-size: 14px; font-weight: bold; color: #0078d4; margin-bottom: 10px;")
        wl_layout.addWidget(wl_title)
        
        # Window Width slider
        ww_label = QLabel("Window Width")
        ww_label.setStyleSheet("font-size: 12px; color: #ccc;")
        wl_layout.addWidget(ww_label)
        
        self.ww_value_label = QLabel(str(self.window_width))
        self.ww_value_label.setStyleSheet("font-size: 12px; color: #ccc; font-weight: bold;")
        self.ww_value_label.setAlignment(Qt.AlignRight)
        
        ww_header = QHBoxLayout()
        ww_header.addWidget(ww_label)
        ww_header.addWidget(self.ww_value_label)
        wl_layout.addLayout(ww_header)
        
        self.ww_slider = QSlider(Qt.Horizontal)
        self.ww_slider.setRange(1, 4000)
        self.ww_slider.setValue(self.window_width)
        self.ww_slider.valueChanged.connect(self.handle_window_width_change)
        self.ww_slider.setStyleSheet("""
            QSlider::groove:horizontal {
                border: 1px solid #555;
                height: 8px;
                background: #222;
                border-radius: 4px;
            }
            QSlider::handle:horizontal {
                background: #0078d4;
                border: 1px solid #555;
                width: 18px;
                border-radius: 9px;
            }
        """)
        wl_layout.addWidget(self.ww_slider)
        
        # Window Level slider
        wl_label_text = QLabel("Window Level")
        wl_label_text.setStyleSheet("font-size: 12px; color: #ccc;")
        wl_layout.addWidget(wl_label_text)
        
        self.wl_value_label = QLabel(str(self.window_level))
        self.wl_value_label.setStyleSheet("font-size: 12px; color: #ccc; font-weight: bold;")
        self.wl_value_label.setAlignment(Qt.AlignRight)
        
        wl_header = QHBoxLayout()
        wl_header.addWidget(wl_label_text)
        wl_header.addWidget(self.wl_value_label)
        wl_layout.addLayout(wl_header)
        
        self.wl_slider = QSlider(Qt.Horizontal)
        self.wl_slider.setRange(-1000, 1000)
        self.wl_slider.setValue(self.window_level)
        self.wl_slider.valueChanged.connect(self.handle_window_level_change)
        self.wl_slider.setStyleSheet("""
            QSlider::groove:horizontal {
                border: 1px solid #555;
                height: 8px;
                background: #222;
                border-radius: 4px;
            }
            QSlider::handle:horizontal {
                background: #0078d4;
                border: 1px solid #555;
                width: 18px;
                border-radius: 9px;
            }
        """)
        wl_layout.addWidget(self.wl_slider)
        
        # Enhanced preset buttons
        preset_layout = QGridLayout()
        preset_layout.setSpacing(5)
        
        preset_buttons = ['lung', 'bone', 'soft', 'brain', 'abdomen', 'mediastinum']
        for i, preset in enumerate(preset_buttons):
            btn = QPushButton(preset.capitalize())
            btn.setStyleSheet("""
                QPushButton {
                    background-color: #444;
                    color: white;
                    border: none;
                    padding: 8px 4px;
                    border-radius: 3px;
                    font-size: 10px;
                    font-weight: bold;
                }
                QPushButton:hover {
                    background-color: #0078d4;
                }
            """)
            btn.clicked.connect(lambda checked, p=preset: self.handle_preset(p))
            preset_layout.addWidget(btn, i // 2, i % 2)
        
        wl_layout.addLayout(preset_layout)
        panel_layout.addWidget(wl_frame)
        
    def create_navigation_section(self, panel_layout):
        nav_frame = QFrame()
        nav_frame.setStyleSheet("QFrame { border: 1px solid #555; border-radius: 5px; padding: 10px; }")
        nav_layout = QVBoxLayout(nav_frame)
        
        nav_title = QLabel("🧭 Navigation")
        nav_title.setStyleSheet("font-size: 14px; font-weight: bold; color: #0078d4; margin-bottom: 10px;")
        nav_layout.addWidget(nav_title)
        
        # Slice slider
        slice_label = QLabel("Slice")
        slice_label.setStyleSheet("font-size: 12px; color: #ccc;")
        nav_layout.addWidget(slice_label)
        
        self.slice_value_label = QLabel("1")
        self.slice_value_label.setStyleSheet("font-size: 12px; color: #ccc; font-weight: bold;")
        self.slice_value_label.setAlignment(Qt.AlignRight)

        slice_header = QHBoxLayout()
        slice_header.addWidget(slice_label)
        slice_header.addWidget(self.slice_value_label)
        nav_layout.addLayout(slice_header)
        
        self.slice_slider = QSlider(Qt.Horizontal)
        self.slice_slider.setRange(0, 0)
        self.slice_slider.setValue(0)
        self.slice_slider.valueChanged.connect(self.handle_slice_change_slider)
        self.slice_slider.setStyleSheet("""
            QSlider::groove:horizontal {
                border: 1px solid #555;
                height: 8px;
                background: #222;
                border-radius: 4px;
            }
            QSlider::handle:horizontal {
                background: #0078d4;
                border: 1px solid #555;
                width: 18px;
                border-radius: 9px;
            }
        """)
        nav_layout.addWidget(self.slice_slider)
        
        panel_layout.addWidget(nav_frame)
        
    def create_transform_section(self, panel_layout):
        transform_frame = QFrame()
        transform_frame.setStyleSheet("QFrame { border: 1px solid #555; border-radius: 5px; padding: 10px; }")
        transform_layout = QVBoxLayout(transform_frame)
        
        transform_title = QLabel("🔄 Transform")
        transform_title.setStyleSheet("font-size: 14px; font-weight: bold; color: #0078d4; margin-bottom: 10px;")
        transform_layout.addWidget(transform_title)
        
        # Zoom slider
        zoom_label = QLabel("Zoom")
        zoom_label.setStyleSheet("font-size: 12px; color: #ccc;")
        transform_layout.addWidget(zoom_label)
        
        self.zoom_value_label = QLabel("100%")
        self.zoom_value_label.setStyleSheet("font-size: 12px; color: #ccc; font-weight: bold;")
        self.zoom_value_label.setAlignment(Qt.AlignRight)
        
        zoom_header = QHBoxLayout()
        zoom_header.addWidget(zoom_label)
        zoom_header.addWidget(self.zoom_value_label)
        transform_layout.addLayout(zoom_header)
        
        self.zoom_slider = QSlider(Qt.Horizontal)
        self.zoom_slider.setRange(25, 500)
        self.zoom_slider.setValue(100)
        self.zoom_slider.valueChanged.connect(self.handle_zoom_slider)
        self.zoom_slider.setStyleSheet("""
            QSlider::groove:horizontal {
                border: 1px solid #555;
                height: 8px;
                background: #222;
                border-radius: 4px;
            }
            QSlider::handle:horizontal {
                background: #0078d4;
                border: 1px solid #555;
                width: 18px;
                border-radius: 9px;
            }
        """)
        transform_layout.addWidget(self.zoom_slider)
        
        panel_layout.addWidget(transform_frame)
        
    def create_image_info_section(self, panel_layout):
        info_frame = QFrame()
        info_frame.setStyleSheet("QFrame { border: 1px solid #555; border-radius: 5px; padding: 10px; }")
        info_layout = QVBoxLayout(info_frame)
        
        info_title = QLabel("ℹ️ Image Info")
        info_title.setStyleSheet("font-size: 14px; font-weight: bold; color: #0078d4; margin-bottom: 10px;")
        info_layout.addWidget(info_title)
        
        self.info_labels = {}
        info_items = ['dimensions', 'pixel_spacing', 'series', 'institution']
        
        for item in info_items:
            label = QLabel(f"{item.replace('_', ' ').title()}: -")
            label.setStyleSheet("font-size: 11px; color: #ccc; margin-bottom: 3px;")
            label.setWordWrap(True)
            info_layout.addWidget(label)
            self.info_labels[item] = label
        
        panel_layout.addWidget(info_frame)
        
    def create_measurements_section(self, panel_layout):
        measurements_frame = QFrame()
        measurements_frame.setStyleSheet("QFrame { border: 1px solid #555; border-radius: 5px; padding: 10px; }")
        measurements_layout = QVBoxLayout(measurements_frame)
        
        measurements_title = QLabel("📏 Measurements")
        measurements_title.setStyleSheet("font-size: 14px; font-weight: bold; color: #0078d4; margin-bottom: 10px;")
        measurements_layout.addWidget(measurements_title)
        
        clear_btn = QPushButton("🗑️ Clear All")
        clear_btn.setStyleSheet("""
            QPushButton {
                background-color: #d32f2f;
                color: white;
                border: none;
                padding: 8px 4px;
                border-radius: 3px;
                font-size: 11px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #f44336;
            }
        """)
        clear_btn.clicked.connect(self.clear_measurements)
        measurements_layout.addWidget(clear_btn)
        
        self.measurements_list = QListWidget()
        self.measurements_list.setStyleSheet("""
            QListWidget {
                background-color: #444;
                color: white;
                border: 1px solid #555;
                font-size: 11px;
                border-radius: 3px;
            }
            QListWidget::item {
                padding: 5px;
                border-bottom: 1px solid #555;
            }
            QListWidget::item:selected {
                background-color: #0078d4;
            }
        """)
        measurements_layout.addWidget(self.measurements_list)
        
        panel_layout.addWidget(measurements_frame)

    # Event handlers
    def handle_tool_click(self, tool):
        if tool == 'reset':
            self.reset_view()
        elif tool == 'invert':
            self.inverted = not self.inverted
            self.update_display()
        elif tool == 'crosshair':
            self.crosshair = not self.crosshair
            self.update_display()
        elif tool == 'ai':
            QMessageBox.information(self, "AI Analysis", "🤖 AI analysis feature coming soon!\n\nThis will provide automated analysis of DICOM images.")
        elif tool == 'recon':
            QMessageBox.information(self, "3D Reconstruction", "🧊 3D reconstruction feature coming soon!\n\nThis will create 3D models from DICOM slices.")
        else:
            self.active_tool = tool
        
        # Update tool label
        self.tool_label.setText(f"Tool: {tool.capitalize()}")
        
        # Update button styles
        for btn_key, btn in self.tool_buttons.items():
            if btn_key == tool and tool not in ['reset', 'invert', 'crosshair', 'ai', 'recon']:
                btn.setStyleSheet(btn.styleSheet().replace('#444', '#0078d4'))
            else:
                btn.setStyleSheet(btn.styleSheet().replace('#0078d4', '#444'))

    def handle_window_width_change(self, value):
        self.window_width = value
        self.ww_value_label.setText(str(value))
        self.update_display()
        
    def handle_window_level_change(self, value):
        self.window_level = value
        self.wl_value_label.setText(str(value))
        self.update_display()
        
    def handle_preset(self, preset):
        if preset in self.window_presets:
            preset_values = self.window_presets[preset]
            self.window_width = preset_values['ww']
            self.window_level = preset_values['wl']
            
            self.ww_slider.setValue(self.window_width)
            self.wl_slider.setValue(self.window_level)
            
            self.update_display()
        
    def handle_slice_change_slider(self, value):
        self.current_image_index = value
        self.slice_value_label.setText(str(value + 1))
        self.update_display()
        
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
        
    def handle_zoom(self, factor, mouse_x=None, mouse_y=None):
        """Enhanced zoom with mouse position as center"""
        if self.current_image_data is None:
            return
            
        # Get current view limits
        xlim = self.canvas.ax.get_xlim()
        ylim = self.canvas.ax.get_ylim()
        
        if mouse_x is not None and mouse_y is not None:
            # Zoom centered on mouse position
            img_x, img_y = self.canvas.get_image_coordinates(mouse_x, mouse_y)
            if img_x is not None and img_y is not None:
                xcenter, ycenter = img_x, img_y
            else:
                xcenter = (xlim[0] + xlim[1]) / 2
                ycenter = (ylim[0] + ylim[1]) / 2
        else:
            # Zoom centered on current view
            xcenter = (xlim[0] + xlim[1]) / 2
            ycenter = (ylim[0] + ylim[1]) / 2
        
        # Calculate new view limits
        xwidth = (xlim[1] - xlim[0]) / factor
        yheight = (ylim[0] - ylim[1]) / factor
        
        new_xlim = (xcenter - xwidth/2, xcenter + xwidth/2)
        new_ylim = (ycenter + yheight/2, ycenter - yheight/2)
        
        # Apply new limits
        self.canvas.ax.set_xlim(new_xlim)
        self.canvas.ax.set_ylim(new_ylim)
        self.view_xlim = new_xlim
        self.view_ylim = new_ylim
        
        # Update zoom factor
        self.zoom_factor *= factor
        self.zoom_factor = max(0.1, min(10.0, self.zoom_factor))
        zoom_percent = int(self.zoom_factor * 100)
        self.zoom_slider.setValue(zoom_percent)
        
        self.canvas.draw_idle()

    def widget_to_data_coords(self, x, y):
        """Convert widget coordinates to data coordinates"""
        return self.canvas.get_image_coordinates(x, y)

    def on_mouse_press(self, x, y):
        if self.current_image_data is None:
            return
        data_x, data_y = self.widget_to_data_coords(x, y)
        if data_x is None or data_y is None:
            return
            
        self.drag_start = (data_x, data_y)
        
        if self.active_tool == 'measure':
            self.current_measurement = {'start': (data_x, data_y), 'end': (data_x, data_y)}
        elif self.active_tool == 'annotate':
            text, ok = QInputDialog.getText(self, 'Annotation', 'Enter annotation text:')
            if ok and text:
                self.annotations.append({'pos': (data_x, data_y), 'text': text})
                self.update_overlays()

    def on_mouse_move(self, x, y):
        if not self.drag_start or self.current_image_data is None:
            return
        data_x, data_y = self.widget_to_data_coords(x, y)
        if data_x is None or data_y is None:
            return
            
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
            self.update_display()
        elif self.active_tool == 'measure' and self.current_measurement:
            self.current_measurement['end'] = (data_x, data_y)
            self.update_overlays()

    def on_mouse_release(self, x, y):
        if self.active_tool == 'measure' and self.current_measurement:
            data_x, data_y = self.widget_to_data_coords(x, y)
            if data_x is not None and data_y is not None:
                self.current_measurement['end'] = (data_x, data_y)
                self.measurements.append(self.current_measurement)
                self.current_measurement = None
                self.update_measurements_list()
                self.update_overlays()
        
        self.drag_start = None

    def load_dicom_files(self):
        file_dialog = QFileDialog()
        file_dialog.setFileMode(QFileDialog.ExistingFiles)
        file_paths, _ = file_dialog.getOpenFileNames(
            self, "Select DICOM Files", "", 
            "DICOM Files (*.dcm *.dicom *.DCM *.DICOM);;All Files (*)"
        )
        
        if file_paths:
            self.dicom_files = []
            successfully_loaded = 0
            
            for file_path in file_paths:
                try:
                    dicom_data = pydicom.dcmread(file_path)
                    # Verify it has pixel data
                    if hasattr(dicom_data, 'pixel_array'):
                        self.dicom_files.append(dicom_data)
                        successfully_loaded += 1
                except Exception as e:
                    print(f"Could not load {file_path}: {str(e)}")
            
            if successfully_loaded > 0:
                # Sort by instance number if available
                self.dicom_files.sort(key=lambda x: getattr(x, 'InstanceNumber', 0))
                
                self.current_image_index = 0
                self.slice_slider.setRange(0, len(self.dicom_files) - 1)
                self.slice_slider.setValue(0)
                
                # Set initial window/level from first image
                first_dicom = self.dicom_files[0]
                if hasattr(first_dicom, 'WindowWidth') and hasattr(first_dicom, 'WindowCenter'):
                    if isinstance(first_dicom.WindowWidth, (list, tuple)):
                        self.window_width = first_dicom.WindowWidth[0]
                    else:
                        self.window_width = first_dicom.WindowWidth
                        
                    if isinstance(first_dicom.WindowCenter, (list, tuple)):
                        self.window_level = first_dicom.WindowCenter[0]
                    else:
                        self.window_level = first_dicom.WindowCenter
                        
                    self.ww_slider.setValue(int(self.window_width))
                    self.wl_slider.setValue(int(self.window_level))
                
                self.update_patient_info()
                self.update_display()
                
                QMessageBox.information(self, "Success", 
                    f"Successfully loaded {successfully_loaded} DICOM file(s)")
            else:
                QMessageBox.warning(self, "Error", 
                    "No valid DICOM files could be loaded")

    def update_patient_info(self):
        if not self.dicom_files:
            self.patient_info_label.setText("No DICOM files loaded")
            return
            
        dicom_data = self.dicom_files[self.current_image_index]
        
        # Extract patient information
        patient_name = getattr(dicom_data, 'PatientName', 'Unknown')
        study_date = getattr(dicom_data, 'StudyDate', 'Unknown')
        modality = getattr(dicom_data, 'Modality', 'Unknown')
        
        # Format study date
        if study_date != 'Unknown' and len(str(study_date)) == 8:
            formatted_date = f"{study_date[:4]}-{study_date[4:6]}-{study_date[6:8]}"
        else:
            formatted_date = study_date
        
        self.patient_info_label.setText(
            f"Patient: {patient_name} | Study: {formatted_date} | Modality: {modality} | "
            f"Images: {len(self.dicom_files)}"
        )
        
        # Update image info
        rows = getattr(dicom_data, 'Rows', 'Unknown')
        cols = getattr(dicom_data, 'Columns', 'Unknown')
        pixel_spacing = getattr(dicom_data, 'PixelSpacing', 'Unknown')
        series_description = getattr(dicom_data, 'SeriesDescription', 'Unknown')
        institution = getattr(dicom_data, 'InstitutionName', 'Unknown')
        
        self.info_labels['dimensions'].setText(f"Dimensions: {cols}×{rows}")
        
        if pixel_spacing != 'Unknown' and hasattr(pixel_spacing, '__len__') and len(pixel_spacing) >= 2:
            self.info_labels['pixel_spacing'].setText(f"Pixel Spacing: {pixel_spacing[0]:.2f}×{pixel_spacing[1]:.2f} mm")
        else:
            self.info_labels['pixel_spacing'].setText(f"Pixel Spacing: {pixel_spacing}")
            
        self.info_labels['series'].setText(f"Series: {series_description}")
        self.info_labels['institution'].setText(f"Institution: {institution}")

    def update_display(self):
        if not self.dicom_files:
            return
            
        self.current_dicom = self.dicom_files[self.current_image_index]
        
        # Caching logic
        cache_params = (self.current_image_index, self.window_width, self.window_level, self.inverted)
        if self._cached_image_params == cache_params and self._cached_image_data is not None:
            image_data = self._cached_image_data
        else:
            if hasattr(self.current_dicom, 'pixel_array'):
                self.current_image_data = self.current_dicom.pixel_array.copy()
            else:
                return
            
            image_data = self.apply_windowing(self.current_image_data)
            if self.inverted:
                image_data = 255 - image_data
            
            self._cached_image_data = image_data
            self._cached_image_params = cache_params
        
        # Display image using enhanced canvas
        h, w = image_data.shape
        extent = (0, w, h, 0)
        self.canvas.display_image(image_data, extent)
        
        # Restore view limits if they exist
        if self.view_xlim and self.view_ylim:
            self.canvas.ax.set_xlim(self.view_xlim)
            self.canvas.ax.set_ylim(self.view_ylim)
        else:
            self.view_xlim = (0, w)
            self.view_ylim = (h, 0)
        
        # Update overlays
        self.update_overlays()
        self.canvas.draw()

    def apply_windowing(self, image_data):
        """Apply window/level to image data with enhanced contrast"""
        image_data = image_data.astype(np.float32)
        
        min_val = self.window_level - self.window_width / 2
        max_val = self.window_level + self.window_width / 2
        
        # Apply window/level with smooth clipping
        image_data = np.clip(image_data, min_val, max_val)
        
        # Normalize to 0-255 range
        if max_val != min_val:
            image_data = (image_data - min_val) / (max_val - min_val) * 255
        else:
            image_data = np.zeros_like(image_data)
        
        return image_data.astype(np.uint8)

    def update_overlays(self):
        """Update all overlays on the image"""
        # Clear existing overlays
        for line in self.canvas.ax.lines[:]:
            line.remove()
        for text in self.canvas.ax.texts[:]:
            text.remove()
        
        # Redraw overlays
        self.draw_measurements()
        self.draw_annotations()
        if self.crosshair:
            self.draw_crosshair()
        
        self.update_overlay_labels()
        self.canvas.draw_idle()

    def draw_measurements(self):
        """Draw measurement lines and labels"""
        for measurement in self.measurements:
            start = measurement['start']
            end = measurement['end']
            x_data = [start[0], end[0]]
            y_data = [start[1], end[1]]
            
            # Draw line
            self.canvas.ax.plot(x_data, y_data, 'r-', linewidth=2, alpha=0.8)
            
            # Draw endpoints
            self.canvas.ax.plot(x_data[0], y_data[0], 'ro', markersize=6)
            self.canvas.ax.plot(x_data[1], y_data[1], 'ro', markersize=6)
            
            # Calculate distance
            distance = np.sqrt((x_data[1] - x_data[0])**2 + (y_data[1] - y_data[0])**2)
            distance_text = f"{distance:.1f} px"
            
            # Convert to real world units if possible
            if self.current_dicom and hasattr(self.current_dicom, 'PixelSpacing'):
                pixel_spacing = self.current_dicom.PixelSpacing
                if pixel_spacing and len(pixel_spacing) >= 2:
                    try:
                        spacing_x = float(pixel_spacing[0])
                        spacing_y = float(pixel_spacing[1])
                        avg_spacing = (spacing_x + spacing_y) / 2
                        distance_mm = distance * avg_spacing
                        distance_text = f"{distance_mm:.1f} mm"
                    except:
                        pass
            
            # Draw label
            mid_x = (x_data[0] + x_data[1]) / 2
            mid_y = (y_data[0] + y_data[1]) / 2
            self.canvas.ax.text(mid_x, mid_y, distance_text, color='red', 
                              fontsize=10, ha='center', va='center', weight='bold',
                              bbox=dict(boxstyle="round,pad=0.3", facecolor='black', 
                                       edgecolor='red', alpha=0.8))
        
        # Draw current measurement being created
        if self.current_measurement:
            start = self.current_measurement['start']
            end = self.current_measurement['end']
            x_data = [start[0], end[0]]
            y_data = [start[1], end[1]]
            self.canvas.ax.plot(x_data, y_data, 'y--', linewidth=2, alpha=0.7)
            self.canvas.ax.plot(x_data[0], y_data[0], 'yo', markersize=6)

    def draw_annotations(self):
        """Draw text annotations"""
        for annotation in self.annotations:
            pos = annotation['pos']
            text = annotation['text']
            self.canvas.ax.text(pos[0], pos[1], text, color='yellow', 
                              fontsize=12, ha='left', va='bottom', weight='bold',
                              bbox=dict(boxstyle="round,pad=0.5", facecolor='black', 
                                       edgecolor='yellow', alpha=0.9))

    def draw_crosshair(self):
        """Draw crosshair at image center"""
        if self.current_image_data is not None:
            height, width = self.current_image_data.shape
            center_x = width // 2
            center_y = height // 2
            
            # Draw crosshair lines
            self.canvas.ax.axvline(x=center_x, color='cyan', linewidth=1, alpha=0.7, linestyle='--')
            self.canvas.ax.axhline(y=center_y, color='cyan', linewidth=1, alpha=0.7, linestyle='--')

    def update_overlay_labels(self):
        """Update overlay labels with current values"""
        total_files = len(self.dicom_files) if self.dicom_files else 1
        self.wl_label.setText(f"WW: {int(self.window_width)}\nWL: {int(self.window_level)}\nSlice: {self.current_image_index + 1}/{total_files}")
        self.zoom_label.setText(f"Zoom: {int(self.zoom_factor * 100)}%")

    def update_measurements_list(self):
        """Update the measurements list widget"""
        self.measurements_list.clear()
        for i, measurement in enumerate(self.measurements):
            start = measurement['start']
            end = measurement['end']
            distance = np.sqrt((end[0] - start[0])**2 + (end[1] - start[1])**2)
            distance_text = f"{distance:.1f} px"
            
            if self.current_dicom and hasattr(self.current_dicom, 'PixelSpacing'):
                pixel_spacing = self.current_dicom.PixelSpacing
                if pixel_spacing and len(pixel_spacing) >= 2:
                    try:
                        spacing_x = float(pixel_spacing[0])
                        spacing_y = float(pixel_spacing[1])
                        avg_spacing = (spacing_x + spacing_y) / 2
                        distance_mm = distance * avg_spacing
                        distance_text = f"{distance_mm:.1f} mm"
                    except:
                        pass
            
            item_text = f"#{i+1}: {distance_text}"
            self.measurements_list.addItem(item_text)

    def clear_measurements(self):
        """Clear all measurements and annotations"""
        self.measurements.clear()
        self.annotations.clear()
        self.current_measurement = None
        self.update_measurements_list()
        self.update_overlays()

    def reset_view(self):
        """Reset view to default state"""
        self.zoom_factor = 1.0
        self.pan_x = 0
        self.pan_y = 0
        self.zoom_slider.setValue(100)
        
        if self.current_image_data is not None:
            h, w = self.current_image_data.shape
            self.view_xlim = (0, w)
            self.view_ylim = (h, 0)
            self.canvas.ax.set_xlim(self.view_xlim)
            self.canvas.ax.set_ylim(self.view_ylim)
            self.canvas.draw_idle()

    def resizeEvent(self, event):
        """Handle window resize events"""
        super().resizeEvent(event)
        QTimer.singleShot(10, self.position_overlay_labels)


def main():
    app = QApplication(sys.argv)
    
    # Set application style and properties
    app.setStyle('Fusion')
    app.setApplicationName("Advanced DICOM Viewer")
    app.setApplicationVersion("2.0")
    
    # Create and show the main window
    viewer = DicomViewer()
    viewer.show()
    
    # Start the application event loop
    sys.exit(app.exec_())


if __name__ == '__main__':
    main()