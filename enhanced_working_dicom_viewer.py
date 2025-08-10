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
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
import traceback
import logging

# Set up logging for debugging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DicomCanvas(FigureCanvas):
    """Custom matplotlib canvas for DICOM image display"""
    mouse_pressed = pyqtSignal(int, int)
    mouse_moved = pyqtSignal(int, int)
    mouse_released = pyqtSignal(int, int)
    
    def __init__(self, parent=None):
        self.fig = Figure(figsize=(8, 8), facecolor='black')
        super().__init__(self.fig)
        self.setParent(parent)
        
        self.ax = self.fig.add_subplot(111)
        self.ax.set_facecolor('black')
        self.ax.axis('off')
        
        # Remove margins
        self.fig.subplots_adjust(left=0, right=1, top=1, bottom=0)
        
        # Mouse tracking
        self.mouse_pressed_flag = False
        self.last_mouse_pos = None
        
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
        try:
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
        except Exception as e:
            logger.error(f"Error in wheelEvent: {e}")
        super().wheelEvent(event)


class DicomViewer(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Enhanced DICOM Viewer")
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
        
        self._cached_image_data = None
        self._cached_image_params = (None, None, None, None)  # (index, window_width, window_level, inverted)
        
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
            ('info', 'Info', 'ℹ️'),
            ('load_dir', 'Load Dir', '📁')
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
        
        # Backend studies dropdown (keeping for compatibility)
        self.backend_combo = QComboBox()
        self.backend_combo.addItem("Select DICOM from System")
        self.backend_combo.setStyleSheet("padding: 6px; border-radius: 4px; font-size: 14px;")
        self.backend_combo.currentTextChanged.connect(self.handle_backend_study_select)
        top_layout.addWidget(self.backend_combo)
        
        # Patient info
        self.patient_info_label = QLabel("No DICOM loaded | Use Load DICOM Files to begin")
        self.patient_info_label.setStyleSheet("font-size: 14px; color: #ccc;")
        top_layout.addWidget(self.patient_info_label)
        
        top_layout.addStretch()
        center_layout.addWidget(top_bar)
        
    def create_viewport(self, center_layout):
        viewport_widget = QWidget()
        viewport_widget.setStyleSheet("background-color: black;")
        
        viewport_layout = QVBoxLayout(viewport_widget)
        viewport_layout.setContentsMargins(0, 0, 0, 0)
        
        # DICOM canvas
        self.canvas = DicomCanvas(self)
        self.canvas.mouse_pressed.connect(self.on_mouse_press)
        self.canvas.mouse_moved.connect(self.on_mouse_move)
        self.canvas.mouse_released.connect(self.on_mouse_release)
        
        viewport_layout.addWidget(self.canvas)
        
        # Overlay labels
        self.create_overlay_labels(viewport_widget)
        
        center_layout.addWidget(viewport_widget)
        
    def create_overlay_labels(self, viewport_widget):
        # Window/Level info with improved styling
        self.wl_label = QLabel("No image loaded")
        self.wl_label.setStyleSheet("""
            background-color: rgba(0, 0, 0, 150);
            color: white;
            padding: 10px;
            border-radius: 5px;
            font-size: 12px;
            font-family: monospace;
        """)
        self.wl_label.setParent(viewport_widget)
        self.wl_label.move(10, 10)
        
        # Zoom info with improved styling
        self.zoom_label = QLabel("Zoom: 100%")
        self.zoom_label.setStyleSheet("""
            background-color: rgba(0, 0, 0, 150);
            color: white;
            padding: 5px 10px;
            border-radius: 3px;
            font-size: 12px;
            font-family: monospace;
        """)
        self.zoom_label.setParent(viewport_widget)
        
        # Position zoom label at bottom left
        QTimer.singleShot(100, self.position_zoom_label)
        
    def position_zoom_label(self):
        if hasattr(self, 'zoom_label'):
            parent = self.zoom_label.parent()
            if parent:
                self.zoom_label.move(10, parent.height() - 40)
        
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
        
        # Measurements section
        self.create_measurements_section(panel_layout)
        
        panel_layout.addStretch()
        main_layout.addWidget(scroll_area)
        
    def create_window_level_section(self, panel_layout):
        # Window/Level section
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
        
        self.slice_value_label = QLabel("0/0")
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
        info_items = ['dimensions', 'pixel_spacing', 'series', 'institution', 'data_type', 'min_max']
        
        for item in info_items:
            label = QLabel(f"{item.replace('_', ' ').title()}: -")
            label.setStyleSheet("font-size: 11px; color: #ccc; margin-bottom: 3px;")
            label.setWordWrap(True)
            info_layout.addWidget(label)
            self.info_labels[item] = label
        
        panel_layout.addWidget(info_frame)
        
    def create_measurements_section(self, panel_layout):
        measurements_frame = QFrame()
        measurements_layout = QVBoxLayout(measurements_frame)
        
        measurements_title = QLabel("Measurements")
        measurements_title.setStyleSheet("font-size: 14px; font-weight: bold; color: white; margin-bottom: 10px;")
        measurements_layout.addWidget(measurements_title)
        
        clear_btn = QPushButton("Clear All")
        clear_btn.setStyleSheet("""
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
        clear_btn.clicked.connect(self.clear_measurements)
        measurements_layout.addWidget(clear_btn)
        
        self.measurements_list = QListWidget()
        self.measurements_list.setStyleSheet("""
            QListWidget {
                background-color: #444;
                color: white;
                border: 1px solid #555;
                font-size: 12px;
            }
        """)
        measurements_layout.addWidget(self.measurements_list)
        
        panel_layout.addWidget(measurements_frame)
        
    # Event handlers with enhanced error handling
    def handle_tool_click(self, tool):
        logger.info(f"Tool activated: {tool}")
        try:
            if tool == 'reset':
                self.reset_view()
            elif tool == 'invert':
                self.inverted = not self.inverted
                self.invalidate_cache()
                self.update_display()
            elif tool == 'crosshair':
                self.crosshair = not self.crosshair
                self.update_display()
            elif tool == 'info':
                self.show_detailed_info()
            elif tool == 'load_dir':
                self.load_dicom_directory()
            else:
                self.active_tool = tool
            
            # Update button styles
            for btn_key, btn in self.tool_buttons.items():
                if btn_key == tool and tool not in ['reset', 'invert', 'crosshair', 'info', 'load_dir']:
                    btn.setStyleSheet(btn.styleSheet().replace('#444', '#0078d4'))
                else:
                    btn.setStyleSheet(btn.styleSheet().replace('#0078d4', '#444'))
        except Exception as e:
            logger.error(f"Error in handle_tool_click: {e}")
            self.show_error(f"Tool error: {str(e)}")
                
    def handle_window_width_change(self, value):
        self.window_width = value
        self.ww_value_label.setText(str(value))
        self.invalidate_cache()
        self.update_display()
        
    def handle_window_level_change(self, value):
        self.window_level = value
        self.wl_value_label.setText(str(value))
        self.invalidate_cache()
        self.update_display()
        
    def handle_preset(self, preset):
        preset_values = self.window_presets[preset]
        self.window_width = preset_values['ww']
        self.window_level = preset_values['wl']
        
        self.ww_slider.setValue(self.window_width)
        self.wl_slider.setValue(self.window_level)
        
        self.invalidate_cache()
        self.update_display()
        
    def handle_slice_change_slider(self, value):
        if value < len(self.dicom_files):
            self.current_image_index = value
            self.slice_value_label.setText(f"{value + 1}/{len(self.dicom_files)}")
            self.invalidate_cache()
            self.update_display()
        
    def handle_slice_change(self, direction):
        new_index = self.current_image_index + direction
        if 0 <= new_index < len(self.dicom_files):
            self.current_image_index = new_index
            self.slice_slider.setValue(new_index)
            self.invalidate_cache()
            self.update_display()
            
    def handle_zoom_slider(self, value):
        self.zoom_factor = value / 100.0
        self.zoom_value_label.setText(f"{value}%")
        self.update_display()
        
    def handle_zoom(self, factor):
        try:
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
        except Exception as e:
            logger.error(f"Error in handle_zoom: {e}")
        
    def handle_backend_study_select(self, filename):
        if filename == "Select DICOM from System" or not filename:
            return
            
        # This would connect to a backend server
        # For now, just show a message
        QMessageBox.information(self, "Backend Study", f"Backend study selection: {filename}\n(Feature not implemented)")
        
    def widget_to_data_coords(self, x, y):
        try:
            inv = self.canvas.ax.transData.inverted()
            return inv.transform((x, y))
        except Exception as e:
            logger.error(f"Error in widget_to_data_coords: {e}")
            return (0, 0)

    def on_mouse_press(self, x, y):
        if self.current_image_data is None:
            return
        try:
            data_x, data_y = self.widget_to_data_coords(x, y)
            self.drag_start = (data_x, data_y)
            if self.active_tool == 'measure':
                self.current_measurement = {'start': (data_x, data_y), 'end': (data_x, data_y)}
            elif self.active_tool == 'annotate':
                text, ok = QInputDialog.getText(self, 'Annotation', 'Enter annotation text:')
                if ok and text:
                    self.annotations.append({'pos': (data_x, data_y), 'text': text})
                    self.update_display()
        except Exception as e:
            logger.error(f"Error in on_mouse_press: {e}")
                
    def update_overlays(self):
        try:
            # Remove all lines and texts except the image
            self.canvas.ax.lines.clear()
            self.canvas.ax.texts.clear()
            self.draw_measurements()
            self.draw_annotations()
            if self.crosshair:
                self.draw_crosshair()
            self.update_overlay_labels()
            self.canvas.draw_idle()
        except Exception as e:
            logger.error(f"Error updating overlays: {e}")

    def on_mouse_move(self, x, y):
        if not self.drag_start or self.current_image_data is None:
            return
        try:
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
                xlim = self.canvas.ax.get_xlim()
                ylim = self.canvas.ax.get_ylim()
                xcenter = (xlim[0] + xlim[1]) / 2
                ycenter = (ylim[0] + ylim[1]) / 2
                xwidth = (xlim[1] - xlim[0]) / zoom_delta
                yheight = (ylim[0] - ylim[1]) / zoom_delta
                new_xlim = (xcenter - xwidth/2, xcenter + xwidth/2)
                new_ylim = (ycenter + yheight/2, ycenter - yheight/2)
                self.canvas.ax.set_xlim(new_xlim)
                self.canvas.ax.set_ylim(new_ylim)
                self.view_xlim = new_xlim
                self.view_ylim = new_ylim
                self.zoom_factor *= zoom_delta
                self.zoom_factor = max(0.1, min(5.0, self.zoom_factor))
                zoom_percent = int(self.zoom_factor * 100)
                self.zoom_slider.setValue(zoom_percent)
                self.drag_start = (data_x, data_y)
                self.canvas.draw_idle()
            elif self.active_tool == 'windowing':
                # More responsive windowing with signal blocking
                self.window_width = max(1, self.window_width + dx * 2)
                self.window_level = max(-1000, min(1000, self.window_level + dy * 2))
                self.drag_start = (data_x, data_y)
                
                # Update sliders without triggering signals
                self.ww_slider.blockSignals(True)
                self.wl_slider.blockSignals(True)
                self.ww_slider.setValue(int(self.window_width))
                self.wl_slider.setValue(int(self.window_level))
                self.ww_slider.blockSignals(False)
                self.wl_slider.blockSignals(False)
                
                # Update labels
                self.ww_value_label.setText(str(int(self.window_width)))
                self.wl_value_label.setText(str(int(self.window_level)))
                
                self.invalidate_cache()
                self.update_display()
            elif self.active_tool == 'measure' and self.current_measurement:
                self.current_measurement['end'] = (data_x, data_y)
                self.update_overlays()
        except Exception as e:
            logger.error(f"Error in on_mouse_move: {e}")
            
    def on_mouse_release(self, x, y):
        try:
            if self.active_tool == 'measure' and self.current_measurement:
                data_x, data_y = self.widget_to_data_coords(x, y)
                self.current_measurement['end'] = (data_x, data_y)
                self.measurements.append(self.current_measurement)
                self.current_measurement = None
                self.update_measurements_list()
                self.update_overlays()
            
            self.drag_start = None
        except Exception as e:
            logger.error(f"Error in on_mouse_release: {e}")
        
    def load_dicom_files(self):
        try:
            file_dialog = QFileDialog()
            file_paths, _ = file_dialog.getOpenFileNames(
                self, "Select DICOM Files", "", "DICOM Files (*.dcm *.dicom);;All Files (*)"
            )
            
            if file_paths:
                self.load_dicom_data(file_paths)
        except Exception as e:
            logger.error(f"Error in load_dicom_files: {e}")
            self.show_error(f"Error loading DICOM files: {str(e)}")
    
    def load_dicom_directory(self):
        """Enhanced directory loading function"""
        try:
            directory = QFileDialog.getExistingDirectory(self, "Select DICOM Directory")
            if directory:
                # Find all DICOM files in directory
                file_paths = []
                for root, dirs, files in os.walk(directory):
                    for file in files:
                        if file.lower().endswith(('.dcm', '.dicom')) or '.' not in file:
                            file_paths.append(os.path.join(root, file))
                
                if file_paths:
                    self.load_dicom_data(file_paths)
                else:
                    QMessageBox.information(self, "No DICOM Files", "No DICOM files found in the selected directory.")
        except Exception as e:
            logger.error(f"Error in load_dicom_directory: {e}")
            self.show_error(f"Error loading DICOM directory: {str(e)}")
    
    def load_dicom_data(self, file_paths):
        """Enhanced DICOM data loading with better error handling"""
        try:
            self.dicom_files = []
            failed_files = []
            
            for file_path in file_paths:
                try:
                    dicom_data = pydicom.dcmread(file_path, force=True)
                    
                    # Check if pixel data exists
                    if hasattr(dicom_data, 'pixel_array'):
                        self.dicom_files.append(dicom_data)
                        logger.info(f"Successfully loaded: {file_path}")
                    else:
                        logger.warning(f"No pixel data in file: {file_path}")
                        failed_files.append(file_path)
                        
                except Exception as e:
                    logger.error(f"Could not load {file_path}: {e}")
                    failed_files.append(file_path)
            
            if failed_files:
                failed_msg = f"Failed to load {len(failed_files)} files:\n" + '\n'.join(failed_files[:5])
                if len(failed_files) > 5:
                    failed_msg += f"\n... and {len(failed_files) - 5} more"
                QMessageBox.warning(self, "Loading Issues", failed_msg)
            
            if self.dicom_files:
                # Sort by instance number if available
                self.dicom_files.sort(key=lambda x: getattr(x, 'InstanceNumber', 0))
                
                self.current_image_index = 0
                self.slice_slider.setRange(0, len(self.dicom_files) - 1)
                self.slice_slider.setValue(0)
                self.slice_value_label.setText(f"1/{len(self.dicom_files)}")
                
                # Set initial window/level from first image with better handling
                first_dicom = self.dicom_files[0]
                if hasattr(first_dicom, 'WindowWidth') and hasattr(first_dicom, 'WindowCenter'):
                    try:
                        ww = first_dicom.WindowWidth
                        wl = first_dicom.WindowCenter
                        # Handle multiple values
                        if isinstance(ww, (list, tuple)):
                            ww = ww[0]
                        if isinstance(wl, (list, tuple)):
                            wl = wl[0]
                        self.window_width = int(float(ww))
                        self.window_level = int(float(wl))
                        self.ww_slider.setValue(self.window_width)
                        self.wl_slider.setValue(self.window_level)
                    except Exception as e:
                        logger.warning(f"Could not parse window/level values: {e}")
                
                self.reset_view()
                self.invalidate_cache()
                self.update_patient_info()
                self.update_display()
                
                logger.info(f"Successfully loaded {len(self.dicom_files)} DICOM files")
            else:
                QMessageBox.warning(self, "No Valid Files", "No valid DICOM files with image data were found.")
                
        except Exception as e:
            logger.error(f"Error in load_dicom_data: {e}")
            self.show_error(f"Error loading DICOM data: {str(e)}")
                
    def update_patient_info(self):
        if not self.dicom_files:
            self.patient_info_label.setText("No DICOM loaded")
            return
            
        try:
            dicom_data = self.dicom_files[self.current_image_index]
            
            # Extract patient information with better formatting
            patient_name = getattr(dicom_data, 'PatientName', 'Unknown')
            study_date = getattr(dicom_data, 'StudyDate', 'Unknown')
            modality = getattr(dicom_data, 'Modality', 'Unknown')
            
            # Format patient name
            if hasattr(patient_name, 'family_name'):
                patient_name = f"{patient_name.family_name}, {patient_name.given_name}"
            else:
                patient_name = str(patient_name)
            
            # Format study date
            if len(str(study_date)) == 8:
                study_date = f"{study_date[:4]}-{study_date[4:6]}-{study_date[6:8]}"
            
            # Update patient info label
            self.patient_info_label.setText(f"Patient: {patient_name} | Study: {study_date} | Modality: {modality}")
            
            # Update image info with enhanced details
            rows = getattr(dicom_data, 'Rows', 'Unknown')
            cols = getattr(dicom_data, 'Columns', 'Unknown')
            pixel_spacing = getattr(dicom_data, 'PixelSpacing', None)
            series_description = getattr(dicom_data, 'SeriesDescription', 'Unknown')
            institution = getattr(dicom_data, 'InstitutionName', 'Unknown')
            
            self.info_labels['dimensions'].setText(f"Dimensions: {cols}×{rows}")
            
            if pixel_spacing:
                try:
                    if isinstance(pixel_spacing, list) and len(pixel_spacing) >= 2:
                        spacing_str = f"{float(pixel_spacing[0]):.2f}×{float(pixel_spacing[1]):.2f} mm"
                        self.info_labels['pixel_spacing'].setText(f"Pixel Spacing: {spacing_str}")
                    else:
                        self.info_labels['pixel_spacing'].setText(f"Pixel Spacing: {pixel_spacing}")
                except:
                    self.info_labels['pixel_spacing'].setText(f"Pixel Spacing: {pixel_spacing}")
            else:
                self.info_labels['pixel_spacing'].setText("Pixel Spacing: Unknown")
                
            self.info_labels['series'].setText(f"Series: {series_description}")
            self.info_labels['institution'].setText(f"Institution: {institution}")
            
            # Add data type and range info if available
            if hasattr(dicom_data, 'pixel_array'):
                try:
                    pixel_data = dicom_data.pixel_array
                    self.info_labels['data_type'].setText(f"Data Type: {pixel_data.dtype}")
                    self.info_labels['min_max'].setText(f"Range: {pixel_data.min()} - {pixel_data.max()}")
                except:
                    self.info_labels['data_type'].setText("Data Type: Unknown")
                    self.info_labels['min_max'].setText("Range: Unknown")
            
        except Exception as e:
            logger.error(f"Error updating patient info: {e}")
            self.patient_info_label.setText("Error reading DICOM metadata")
        
    def invalidate_cache(self):
        """Invalidate image cache to force refresh"""
        self._cached_image_data = None
        self._cached_image_params = (None, None, None, None)
        
    def update_display(self):
        if not self.dicom_files:
            return
        
        try:
            self.canvas.ax.clear()
            self.canvas.ax.set_facecolor('black')
            self.canvas.ax.axis('off')
            self.current_dicom = self.dicom_files[self.current_image_index]
            
            # Enhanced caching logic
            cache_params = (self.current_image_index, self.window_width, self.window_level, self.inverted)
            if self._cached_image_params == cache_params and self._cached_image_data is not None:
                image_data = self._cached_image_data
            else:
                if hasattr(self.current_dicom, 'pixel_array'):
                    try:
                        pixel_data = self.current_dicom.pixel_array
                        self.current_image_data = pixel_data.copy()
                        
                        # Handle different pixel data formats
                        if len(pixel_data.shape) > 2:
                            if len(pixel_data.shape) == 3:
                                if pixel_data.shape[2] == 3:  # RGB
                                    pixel_data = np.dot(pixel_data[...,:3], [0.2989, 0.5870, 0.1140])
                                else:
                                    pixel_data = pixel_data[:, :, 0]
                            else:
                                pixel_data = np.squeeze(pixel_data)
                        
                        self.current_image_data = pixel_data
                    except Exception as e:
                        logger.error(f"Error accessing pixel data: {e}")
                        return
                else:
                    return
                    
                image_data = self.apply_windowing(self.current_image_data)
                if self.inverted:
                    image_data = 255 - image_data
                self._cached_image_data = image_data
                self._cached_image_params = cache_params
                
            h, w = image_data.shape
            self.canvas.ax.imshow(image_data, cmap='gray', origin='upper', extent=(0, w, h, 0))
            
            # Always restore the current view limits
            if self.view_xlim and self.view_ylim:
                self.canvas.ax.set_xlim(self.view_xlim)
                self.canvas.ax.set_ylim(self.view_ylim)
            else:
                self.canvas.ax.set_xlim(0, w)
                self.canvas.ax.set_ylim(h, 0)
                self.view_xlim = (0, w)
                self.view_ylim = (h, 0)
                
            self.draw_measurements()
            self.draw_annotations()
            if self.crosshair:
                self.draw_crosshair()
            self.update_overlay_labels()
            self.canvas.draw()
            
        except Exception as e:
            logger.error(f"Error in update_display: {e}")
            self.show_error(f"Display error: {str(e)}")
        
    def apply_windowing(self, image_data):
        """Apply window/level to image data with enhanced error handling"""
        try:
            # Convert to float for calculations
            image_data = image_data.astype(np.float64)
            
            # Apply window/level
            min_val = self.window_level - self.window_width / 2
            max_val = self.window_level + self.window_width / 2
            
            # Avoid division by zero
            if max_val == min_val:
                max_val = min_val + 1
            
            # Clip and normalize
            image_data = np.clip(image_data, min_val, max_val)
            image_data = (image_data - min_val) / (max_val - min_val) * 255
            
            return image_data.astype(np.uint8)
        except Exception as e:
            logger.error(f"Error in apply_windowing: {e}")
            # Fallback: normalize to 0-255
            try:
                return ((image_data - image_data.min()) / (image_data.max() - image_data.min()) * 255).astype(np.uint8)
            except:
                return np.zeros_like(image_data, dtype=np.uint8)
        
    def draw_measurements(self):
        try:
            for measurement in self.measurements:
                start = measurement['start']
                end = measurement['end']
                x_data = [start[0], end[0]]
                y_data = [start[1], end[1]]
                self.canvas.ax.plot(x_data, y_data, 'r-', linewidth=2)
                distance = np.sqrt((x_data[1] - x_data[0])**2 + (y_data[1] - y_data[0])**2)
                distance_text = f"{distance:.1f} px"
                if self.current_dicom is not None and hasattr(self.current_dicom, 'PixelSpacing'):
                    pixel_spacing = self.current_dicom.PixelSpacing
                    if pixel_spacing is not None and len(pixel_spacing) >= 2:
                        try:
                            spacing_x = float(pixel_spacing[0])
                            spacing_y = float(pixel_spacing[1])
                            avg_spacing = (spacing_x + spacing_y) / 2
                            distance_mm = distance * avg_spacing
                            distance_text = f"{distance_mm:.1f} mm"
                        except Exception:
                            pass
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
        except Exception as e:
            logger.error(f"Error drawing measurements: {e}")
            
    def draw_annotations(self):
        try:
            for annotation in self.annotations:
                pos = annotation['pos']
                text = annotation['text']
                self.canvas.ax.text(pos[0], pos[1], text, color='yellow', 
                                  fontsize=12, ha='left', va='bottom',
                                  bbox=dict(boxstyle="round,pad=0.5", facecolor='black', alpha=0.8))
        except Exception as e:
            logger.error(f"Error drawing annotations: {e}")
                              
    def draw_crosshair(self):
        try:
            if self.current_image_data is not None:
                height, width = self.current_image_data.shape
                center_x = width // 2
                center_y = height // 2
                self.canvas.ax.axvline(x=center_x, color='cyan', linewidth=1, alpha=0.7)
                self.canvas.ax.axhline(y=center_y, color='cyan', linewidth=1, alpha=0.7)
        except Exception as e:
            logger.error(f"Error drawing crosshair: {e}")
            
    def update_overlay_labels(self):
        """Update overlay labels with current values"""
        try:
            if self.dicom_files:
                self.wl_label.setText(f"WW: {int(self.window_width)}\nWL: {int(self.window_level)}\nSlice: {self.current_image_index + 1}/{len(self.dicom_files)}")
            else:
                self.wl_label.setText("No image loaded")
            self.zoom_label.setText(f"Zoom: {int(self.zoom_factor * 100)}%")
        except Exception as e:
            logger.error(f"Error updating overlay labels: {e}")
        
    def update_measurements_list(self):
        """Update the measurements list widget"""
        try:
            self.measurements_list.clear()
            for i, measurement in enumerate(self.measurements):
                start = measurement['start']
                end = measurement['end']
                distance = np.sqrt((end[0] - start[0])**2 + (end[1] - start[1])**2)
                distance_text = f"{distance:.1f} px"
                if self.current_dicom is not None and hasattr(self.current_dicom, 'PixelSpacing'):
                    pixel_spacing = self.current_dicom.PixelSpacing
                    if pixel_spacing is not None and len(pixel_spacing) >= 2:
                        try:
                            spacing_x = float(pixel_spacing[0])
                            spacing_y = float(pixel_spacing[1])
                            avg_spacing = (spacing_x + spacing_y) / 2
                            distance_mm = distance * avg_spacing
                            distance_text = f"{distance_mm:.1f} mm"
                        except Exception:
                            pass
                item_text = f"Measurement {i+1}: {distance_text}"
                self.measurements_list.addItem(item_text)
        except Exception as e:
            logger.error(f"Error updating measurements list: {e}")
            
    def clear_measurements(self):
        """Clear all measurements"""
        try:
            self.measurements.clear()
            self.annotations.clear()
            self.current_measurement = None
            self.update_measurements_list()
            self.update_display()
        except Exception as e:
            logger.error(f"Error clearing measurements: {e}")
        
    def reset_view(self):
        try:
            self.zoom_factor = 1.0
            self.pan_x = 0
            self.pan_y = 0
            self.zoom_slider.setValue(100)
            if self.current_image_data is not None:
                h, w = self.current_image_data.shape
                self.view_xlim = (0, w)
                self.view_ylim = (h, 0)
            self.update_display()
        except Exception as e:
            logger.error(f"Error resetting view: {e}")
    
    def show_detailed_info(self):
        """Show detailed DICOM information"""
        if not self.current_dicom:
            QMessageBox.information(self, "No Image", "No DICOM image is currently loaded.")
            return
        
        try:
            info_text = "DICOM Information:\n\n"
            
            # Key DICOM tags
            important_tags = [
                'PatientName', 'PatientID', 'StudyDate', 'StudyTime',
                'Modality', 'SeriesDescription', 'StudyDescription',
                'InstitutionName', 'Manufacturer', 'ManufacturerModelName',
                'Rows', 'Columns', 'PixelSpacing', 'SliceThickness',
                'WindowWidth', 'WindowCenter', 'RescaleSlope', 'RescaleIntercept'
            ]
            
            for tag in important_tags:
                if hasattr(self.current_dicom, tag):
                    value = getattr(self.current_dicom, tag)
                    info_text += f"{tag}: {value}\n"
            
            # Show in message box with detailed view
            msg = QMessageBox()
            msg.setWindowTitle("DICOM Information")
            msg.setText(info_text)
            msg.setDetailedText(str(self.current_dicom))
            msg.exec_()
        except Exception as e:
            logger.error(f"Error showing detailed info: {e}")
            self.show_error(f"Error displaying DICOM info: {str(e)}")
    
    def show_error(self, message):
        """Show error message to user"""
        QMessageBox.critical(self, "Error", message)
        
    def resizeEvent(self, event):
        """Handle window resize events"""
        super().resizeEvent(event)
        # Reposition zoom label
        QTimer.singleShot(10, self.position_zoom_label)


def main():
    app = QApplication(sys.argv)
    
    # Set application style
    app.setStyle('Fusion')
    
    # Enhanced error handling
    def handle_exception(exc_type, exc_value, exc_traceback):
        if issubclass(exc_type, KeyboardInterrupt):
            sys.__excepthook__(exc_type, exc_value, exc_traceback)
            return
        
        logger.critical("Uncaught exception", exc_info=(exc_type, exc_value, exc_traceback))
        
    sys.excepthook = handle_exception
    
    # Create and show the main window
    try:
        viewer = DicomViewer()
        viewer.show()
        
        logger.info("Enhanced DICOM Viewer started successfully")
        
        # Start the application event loop
        sys.exit(app.exec_())
    except Exception as e:
        logger.critical(f"Failed to start application: {e}")
        QMessageBox.critical(None, "Startup Error", f"Failed to start Enhanced DICOM Viewer:\n{str(e)}")


if __name__ == '__main__':
    main()