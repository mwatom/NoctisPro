#!/usr/bin/env python3
import sys
import os
import argparse
import numpy as np
import pydicom
from PyQt5.QtWidgets import (QApplication, QMainWindow, QVBoxLayout, QHBoxLayout,
                             QWidget, QPushButton, QLabel, QSlider, QFileDialog,
                             QScrollArea, QFrame, QGridLayout, QComboBox, QTextEdit,
                             QMessageBox, QInputDialog, QListWidget)
from PyQt5.QtCore import Qt, QTimer, pyqtSignal
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
from io import BytesIO
import requests
from PIL import Image as PILImage


class DicomCanvas(FigureCanvas):
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
        self.fig.subplots_adjust(left=0, right=1, top=1, bottom=0)
        self.mouse_pressed_flag = False
        self.last_mouse_pos = None

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:  # type: ignore
            self.mouse_pressed_flag = True
            self.last_mouse_pos = (event.x(), event.y())
            self.mouse_pressed.emit(event.x(), event.y())
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self.mouse_pressed_flag:
            self.mouse_moved.emit(event.x(), event.y())
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.LeftButton:  # type: ignore
            self.mouse_pressed_flag = False
            self.mouse_released.emit(event.x(), event.y())
        super().mouseReleaseEvent(event)

    def wheelEvent(self, event):
        if event.modifiers() & Qt.ControlModifier:  # type: ignore
            delta = event.angleDelta().y()
            zoom_factor = 1.1 if delta > 0 else 0.9
            self.parent().handle_zoom(zoom_factor)
        else:
            delta = event.angleDelta().y()
            direction = 1 if delta > 0 else -1
            self.parent().handle_slice_change(direction)
        super().wheelEvent(event)


class DicomViewer(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Python DICOM Viewer")
        self.setGeometry(100, 100, 1400, 900)
        self.setStyleSheet("background-color: #2a2a2a; color: white;")

        self.dicom_files = []
        self.current_image_index = 0
        self.current_image_data = None
        self.current_dicom = None

        self.window_width = 400
        self.window_level = 40
        self.zoom_factor = 1.0
        self.pan_x = 0
        self.pan_y = 0
        self.inverted = False
        self.crosshair = False

        self.active_tool = 'windowing'
        self.measurements = []
        self.annotations = []
        self.current_measurement = None
        self.drag_start = None

        self.window_presets = {
            'lung': {'ww': 1500, 'wl': -600},
            'bone': {'ww': 2000, 'wl': 300},
            'soft': {'ww': 400, 'wl': 40},
            'brain': {'ww': 100, 'wl': 50}
        }

        self.view_xlim = None
        self.view_ylim = None

        self._cached_image_data = None
        self._cached_image_params = (None, None, None, None)

        # Backend mode (web API parity)
        self.backend_mode = False
        self.base_url = os.environ.get('DICOM_VIEWER_BASE_URL', 'http://127.0.0.1:8000/viewer')
        if self.base_url.endswith('/'):
            self.base_url = self.base_url[:-1]
        self.backend_study = None
        self.backend_series = None
        self.backend_images = []  # list of dicts with id, etc.
        self.series_options = []  # list of (label, id)

        self.init_ui()

    def init_ui(self):
        main_widget = QWidget()
        self.setCentralWidget(main_widget)

        main_layout = QHBoxLayout(main_widget)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        self.create_toolbar(main_layout)

        center_widget = QWidget()
        center_layout = QVBoxLayout(center_widget)
        center_layout.setContentsMargins(0, 0, 0, 0)

        self.create_top_bar(center_layout)
        self.create_viewport(center_layout)
        main_layout.addWidget(center_widget, 1)

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
            btn.setFixedSize(70, 50)
            btn.setStyleSheet("""
                QPushButton { background-color: #444; color: white; border: none; border-radius: 5px; font-size: 10px; }
                QPushButton:hover { background-color: #555; }
                QPushButton:pressed { background-color: #0078d4; }
            """
            )
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

        load_btn = QPushButton("Load DICOM Files")
        load_btn.setStyleSheet("""
            QPushButton { background-color: #0078d4; color: white; border: none; padding: 8px 16px; border-radius: 4px; font-size: 14px; }
            QPushButton:hover { background-color: #106ebe; }
        """
        )
        load_btn.clicked.connect(self.load_dicom_files)
        top_layout.addWidget(load_btn)

        folder_btn = QPushButton("Load DICOM Folder")
        folder_btn.setStyleSheet("""
            QPushButton { background-color: #0b8457; color: white; border: none; padding: 8px 16px; border-radius: 4px; font-size: 14px; }
            QPushButton:hover { background-color: #086b46; }
        """
        )
        folder_btn.clicked.connect(self.load_dicom_folder)
        top_layout.addWidget(folder_btn)

        self.backend_combo = QComboBox()
        self.backend_combo.addItem("Select Series")
        self.backend_combo.setStyleSheet("padding: 6px; border-radius: 4px; font-size: 14px;")
        self.backend_combo.currentTextChanged.connect(self.handle_backend_study_select)
        top_layout.addWidget(self.backend_combo)

        self.patient_info_label = QLabel("Patient: - | Study Date: - | Modality: -")
        self.patient_info_label.setStyleSheet("font-size: 14px; color: #ccc;")
        top_layout.addWidget(self.patient_info_label)

        top_layout.addStretch()
        center_layout.addWidget(top_bar)

    def create_viewport(self, center_layout):
        viewport_widget = QWidget()
        viewport_widget.setStyleSheet("background-color: black;")

        viewport_layout = QVBoxLayout(viewport_widget)
        viewport_layout.setContentsMargins(0, 0, 0, 0)

        self.canvas = DicomCanvas(self)
        self.canvas.mouse_pressed.connect(self.on_mouse_press)
        self.canvas.mouse_moved.connect(self.on_mouse_move)
        self.canvas.mouse_released.connect(self.on_mouse_release)

        viewport_layout.addWidget(self.canvas)
        self.create_overlay_labels(viewport_widget)
        center_layout.addWidget(viewport_widget)

    def create_overlay_labels(self, viewport_widget):
        self.wl_label = QLabel("WW: 400\nWL: 40\nSlice: 1/1")
        self.wl_label.setStyleSheet("""
            background-color: rgba(0, 0, 0, 0);
            color: white;
            padding: 10px;
            border-radius: 5px;
            font-size: 12px;
        """
        )
        self.wl_label.setParent(viewport_widget)
        self.wl_label.move(10, 10)

        self.zoom_label = QLabel("Zoom: 100%")
        self.zoom_label.setStyleSheet("""
            background-color: rgba(0, 0, 0, 0);
            color: white;
            padding: 5px 10px;
            border-radius: 3px;
            font-size: 12px;
        """
        )
        self.zoom_label.setParent(viewport_widget)
        QTimer.singleShot(100, self.position_zoom_label)

    def position_zoom_label(self):
        if hasattr(self, 'zoom_label'):
            parent = self.zoom_label.parent()
            if parent:
                self.zoom_label.move(10, parent.height() - 40)  # type: ignore

    def create_right_panel(self, main_layout):
        right_panel = QWidget()
        right_panel.setFixedWidth(250)
        right_panel.setStyleSheet("background-color: #333; border-left: 1px solid #555;")

        scroll_area = QScrollArea()
        scroll_area.setWidget(right_panel)
        scroll_area.setWidgetResizable(True)
        scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)  # type: ignore

        panel_layout = QVBoxLayout(right_panel)
        panel_layout.setContentsMargins(20, 20, 20, 20)
        panel_layout.setSpacing(20)

        self.create_window_level_section(panel_layout)
        self.create_navigation_section(panel_layout)
        self.create_transform_section(panel_layout)
        self.create_image_info_section(panel_layout)
        self.create_measurements_section(panel_layout)

        panel_layout.addStretch()
        main_layout.addWidget(scroll_area)

    def create_window_level_section(self, panel_layout):
        wl_frame = QFrame()
        wl_layout = QVBoxLayout(wl_frame)

        wl_title = QLabel("Window/Level")
        wl_title.setStyleSheet("font-size: 14px; font-weight: bold; color: white; margin-bottom: 10px;")
        wl_layout.addWidget(wl_title)

        ww_label = QLabel("Window Width")
        ww_label.setStyleSheet("font-size: 12px; color: #ccc;")
        wl_layout.addWidget(ww_label)

        self.ww_value_label = QLabel(str(self.window_width))
        self.ww_value_label.setStyleSheet("font-size: 12px; color: #ccc;")
        self.ww_value_label.setAlignment(Qt.AlignRight)  # type: ignore

        ww_header = QHBoxLayout()
        ww_header.addWidget(ww_label)
        ww_header.addWidget(self.ww_value_label)
        wl_layout.addLayout(ww_header)

        self.ww_slider = QSlider(Qt.Horizontal)  # type: ignore
        self.ww_slider.setRange(1, 4000)
        self.ww_slider.setValue(self.window_width)
        self.ww_slider.valueChanged.connect(self.handle_window_width_change)
        wl_layout.addWidget(self.ww_slider)

        wl_label = QLabel("Window Level")
        wl_label.setStyleSheet("font-size: 12px; color: #ccc;")
        wl_layout.addWidget(wl_label)

        self.wl_value_label = QLabel(str(self.window_level))
        self.wl_value_label.setStyleSheet("font-size: 12px; color: #ccc;")
        self.wl_value_label.setAlignment(Qt.AlignRight)  # type: ignore

        wl_header = QHBoxLayout()
        wl_header.addWidget(wl_label)
        wl_header.addWidget(self.wl_value_label)
        wl_layout.addLayout(wl_header)

        self.wl_slider = QSlider(Qt.Horizontal)  # type: ignore
        self.wl_slider.setRange(-1000, 1000)
        self.wl_slider.setValue(self.window_level)
        self.wl_slider.valueChanged.connect(self.handle_window_level_change)
        wl_layout.addWidget(self.wl_slider)

        preset_layout = QGridLayout()
        preset_layout.setSpacing(5)

        preset_buttons = ['lung', 'bone', 'soft', 'brain']
        for i, preset in enumerate(preset_buttons):
            btn = QPushButton(preset.capitalize())
            btn.setStyleSheet("""
                QPushButton { background-color: #444; color: white; border: none; padding: 8px 4px; border-radius: 3px; font-size: 11px; }
                QPushButton:hover { background-color: #555; }
            """
            )
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

        slice_label = QLabel("Slice")
        slice_label.setStyleSheet("font-size: 12px; color: #ccc;")
        nav_layout.addWidget(slice_label)

        self.slice_value_label = QLabel("1")
        self.slice_value_label.setStyleSheet("font-size: 12px; color: #ccc;")
        self.slice_value_label.setAlignment(Qt.AlignRight)  # type: ignore

        slice_header = QHBoxLayout()
        slice_header.addWidget(slice_label)
        slice_header.addWidget(self.slice_value_label)
        nav_layout.addLayout(slice_header)

        self.slice_slider = QSlider(Qt.Horizontal)  # type: ignore
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

        zoom_label = QLabel("Zoom")
        zoom_label.setStyleSheet("font-size: 12px; color: #ccc;")
        transform_layout.addWidget(zoom_label)

        self.zoom_value_label = QLabel("100%")
        self.zoom_value_label.setStyleSheet("font-size: 12px; color: #ccc;")
        self.zoom_value_label.setAlignment(Qt.AlignRight)  # type: ignore

        zoom_header = QHBoxLayout()
        zoom_header.addWidget(zoom_label)
        zoom_header.addWidget(self.zoom_value_label)
        transform_layout.addLayout(zoom_header)

        self.zoom_slider = QSlider(Qt.Horizontal)  # type: ignore
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

    def create_measurements_section(self, panel_layout):
        measurements_frame = QFrame()
        measurements_layout = QVBoxLayout(measurements_frame)

        measurements_title = QLabel("Measurements")
        measurements_title.setStyleSheet("font-size: 14px; font-weight: bold; color: white; margin-bottom: 10px;")
        measurements_layout.addWidget(measurements_title)

        clear_btn = QPushButton("Clear All")
        clear_btn.setStyleSheet("""
            QPushButton { background-color: #444; color: white; border: none; padding: 8px 4px; border-radius: 3px; font-size: 11px; }
            QPushButton:hover { background-color: #555; }
        """
        )
        clear_btn.clicked.connect(self.clear_measurements)
        measurements_layout.addWidget(clear_btn)

        self.measurements_list = QListWidget()
        self.measurements_list.setStyleSheet("""
            QListWidget { background-color: #444; color: white; border: 1px solid #555; font-size: 12px; }
        """
        )
        measurements_layout.addWidget(self.measurements_list)

        panel_layout.addWidget(measurements_frame)

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
            QMessageBox.information(self, "AI Analysis", "AI analysis result: (stub) No backend connected.")
        elif tool == 'recon':
            QMessageBox.information(self, "3D Reconstruction", "3D reconstruction feature is not implemented yet.")
        else:
            self.active_tool = tool
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

    def handle_zoom(self, factor):
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
        self.update_display()

    def handle_backend_study_select(self, text):
        if not self.backend_mode:
            return
        if not text or text == "Select Series":
            return
        # map to id
        for label, sid in self.series_options:
            if label == text:
                try:
                    self._load_backend_series(sid)
                except Exception as e:
                    QMessageBox.warning(self, "Error", f"Failed to load series: {str(e)}")
                return

    # Backend integration methods
    def _fetch_json(self, path: str):
        url = f"{self.base_url}{path}"
        r = requests.get(url, timeout=10)
        r.raise_for_status()
        return r.json()

    def _fetch_png_as_array(self, url: str):
        r = requests.get(url, timeout=15)
        r.raise_for_status()
        img = PILImage.open(BytesIO(r.content)).convert('L')
        return np.array(img)

    def load_backend_study(self, study_id: int):
        try:
            self.backend_mode = True
            data = self._fetch_json(f"/study/{study_id}/")
            self.backend_study = data.get('study')
            series_list = data.get('series_list') or []
            # Fill combo with series
            self.series_options = []
            self.backend_combo.blockSignals(True)
            self.backend_combo.clear()
            self.backend_combo.addItem("Select Series")
            for s in series_list:
                label = f"Series {s.get('series_number')} - {s.get('modality')} ({s.get('image_count')} images)"
                self.series_options.append((label, s.get('id')))
                self.backend_combo.addItem(label)
            self.backend_combo.blockSignals(False)
            # Patient info
            if self.backend_study:
                self.patient_info_label.setText(f"Patient: {self.backend_study.get('patient_name','-')} | Study Date: {self.backend_study.get('study_date','-')} | Modality: {self.backend_study.get('modality','-')}")
            # Auto-load first series
            if self.series_options:
                self.backend_combo.setCurrentText(self.series_options[0][0])
                self._load_backend_series(self.series_options[0][1])
        except Exception as e:
            QMessageBox.warning(self, "Error", f"Failed to load study {study_id}: {str(e)}")

    def _load_backend_series(self, series_id: int):
        data = self._fetch_json(f"/series/{series_id}/images/")
        self.backend_series = data.get('series')
        self.backend_images = data.get('images') or []
        self.current_image_index = 0
        if hasattr(self, 'slice_slider'):
            self.slice_slider.setRange(0, max(0, len(self.backend_images) - 1))
            self.slice_slider.setValue(0)
        # Try initial WW/WL
        if self.backend_images:
            first = self.backend_images[0]
            ww = first.get('window_width')
            wl = first.get('window_center')
            if ww is not None and wl is not None:
                try:
                    self.window_width = float(ww)
                    self.window_level = float(wl)
                    self.ww_slider.setValue(int(self.window_width))
                    self.wl_slider.setValue(int(self.window_level))
                except Exception:
                    pass
        self.update_display()

    def widget_to_data_coords(self, x, y):
        inv = self.canvas.ax.transData.inverted()
        return inv.transform((x, y))

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

    def update_overlays(self):
        self.canvas.ax.lines.clear()
        self.canvas.ax.texts.clear()
        self.draw_measurements()
        self.draw_annotations()
        if self.crosshair:
            self.draw_crosshair()
        self.update_overlay_labels()
        self.canvas.draw_idle()

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
            self.current_measurement['end'] = (data_x, data_y)
            self.measurements.append(self.current_measurement)
            self.current_measurement = None
            self.update_measurements_list()
            self.update_overlays()
        self.drag_start = None

    def load_dicom_files(self):
        file_dialog = QFileDialog()
        file_paths, _ = file_dialog.getOpenFileNames(self, "Select DICOM Files", "", "DICOM Files (*.dcm *.dicom);;All Files (*)")
        if file_paths:
            self._load_dicom_paths(file_paths)

    def load_dicom_folder(self):
        directory = QFileDialog.getExistingDirectory(self, "Select DICOM Folder", "")
        if directory:
            paths = []
            for root, dirs, files in os.walk(directory):
                for name in files:
                    if name.lower().endswith('.dcm') or name.lower().endswith('.dicom'):
                        paths.append(os.path.join(root, name))
            if not paths:
                QMessageBox.information(self, "No DICOM files", "No .dcm or .dicom files found in the selected folder.")
                return
            self._load_dicom_paths(paths)

    def _load_dicom_paths(self, paths):
        self.dicom_files = []
        for file_path in paths:
            try:
                dicom_data = pydicom.dcmread(file_path)
                self.dicom_files.append(dicom_data)
            except Exception as e:
                QMessageBox.warning(self, "Error", f"Could not load {file_path}: {str(e)}")
        if self.dicom_files:
            self.dicom_files.sort(key=lambda x: getattr(x, 'InstanceNumber', 0))
            self.current_image_index = 0
            self.slice_slider.setRange(0, len(self.dicom_files) - 1)
            self.slice_slider.setValue(0)
            first_dicom = self.dicom_files[0]
            self.current_dicom = first_dicom
            self.display_dicom(first_dicom)
            modality = getattr(first_dicom, 'Modality', 'Unknown')
            patient_name = getattr(first_dicom, 'PatientName', 'Unknown')
            study_date = getattr(first_dicom, 'StudyDate', 'Unknown')
            self.patient_info_label.setText(f"Patient: {patient_name} | Study Date: {study_date} | Modality: {modality}")

    def update_patient_info(self):
        if not self.dicom_files:
            return
        dicom_data = self.dicom_files[self.current_image_index]
        patient_name = getattr(dicom_data, 'PatientName', 'Unknown')
        study_date = getattr(dicom_data, 'StudyDate', 'Unknown')
        modality = getattr(dicom_data, 'Modality', 'Unknown')
        self.patient_info_label.setText(f"Patient: {patient_name} | Study Date: {study_date} | Modality: {modality}")
        rows = getattr(dicom_data, 'Rows', 'Unknown')
        cols = getattr(dicom_data, 'Columns', 'Unknown')
        pixel_spacing = getattr(dicom_data, 'PixelSpacing', ['Unknown', 'Unknown'])
        series_description = getattr(dicom_data, 'SeriesDescription', 'Unknown')
        institution = getattr(dicom_data, 'InstitutionName', 'Unknown')
        self.info_labels['dimensions'].setText(f"Dimensions: {cols}x{rows}")
        if isinstance(pixel_spacing, list) and len(pixel_spacing) >= 2:
            self.info_labels['pixel_spacing'].setText(f"Pixel Spacing: {pixel_spacing[0]}\\{pixel_spacing[1]}")
        else:
            self.info_labels['pixel_spacing'].setText(f"Pixel Spacing: {pixel_spacing}")
        self.info_labels['series'].setText(f"Series: {series_description}")
        self.info_labels['institution'].setText(f"Institution: {institution}")

    def update_display(self):
        if self.backend_mode:
            if not self.backend_images:
                return
            try:
                img_meta = self.backend_images[self.current_image_index]
                invert_flag = 'true' if self.inverted else 'false'
                url = f"{self.base_url}/image/{img_meta['id']}/?ww={int(self.window_width)}&wl={int(self.window_level)}&invert={invert_flag}"
                image_data = self._fetch_png_as_array(url)
                self.current_image_data = image_data
                self.canvas.ax.clear()
                self.canvas.ax.set_facecolor('black')
                self.canvas.ax.axis('off')
                h, w = image_data.shape
                self.canvas.ax.imshow(image_data, cmap='gray', origin='upper', extent=(0, w, h, 0))
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
                return
            except Exception as e:
                QMessageBox.warning(self, "Display Error", f"Failed to render backend image: {str(e)}")
                return
        if not self.dicom_files:
            return
        self.canvas.ax.clear()
        self.canvas.ax.set_facecolor('black')
        self.canvas.ax.axis('off')
        self.current_dicom = self.dicom_files[self.current_image_index]
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
        h, w = image_data.shape
        self.canvas.ax.imshow(image_data, cmap='gray', origin='upper', extent=(0, w, h, 0))
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

    def apply_windowing(self, image_data):
        image_data = image_data.astype(np.float32)
        min_val = self.window_level - self.window_width / 2
        max_val = self.window_level + self.window_width / 2
        image_data = np.clip(image_data, min_val, max_val)
        image_data = (image_data - min_val) / (max_val - min_val) * 255
        return image_data.astype(np.uint8)

    def draw_measurements(self):
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
                        distance_cm = distance_mm / 10.0
                        distance_text = f"{distance_mm:.1f} mm / {distance_cm:.2f} cm"
                    except Exception:
                        pass
            mid_x = (x_data[0] + x_data[1]) / 2
            mid_y = (y_data[0] + y_data[1]) / 2
            self.canvas.ax.text(mid_x, mid_y, distance_text, color='red', fontsize=10, ha='center', va='center',
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
            self.canvas.ax.text(pos[0], pos[1], text, color='yellow', fontsize=12, ha='left', va='bottom',
                                bbox=dict(boxstyle="round,pad=0.5", facecolor='black', alpha=0.8))

    def draw_crosshair(self):
        if self.current_image_data is not None:
            height, width = self.current_image_data.shape
            center_x = width // 2
            center_y = height // 2
            self.canvas.ax.axvline(x=center_x, color='cyan', linewidth=1, alpha=0.7)
            self.canvas.ax.axhline(y=center_y, color='cyan', linewidth=1, alpha=0.7)

    def update_overlay_labels(self):
        self.wl_label.setText(f"WW: {int(self.window_width)}\nWL: {int(self.window_level)}\nSlice: {self.current_image_index + 1}/{len(self.dicom_files)}")
        self.zoom_label.setText(f"Zoom: {int(self.zoom_factor * 100)}%")

    def update_measurements_list(self):
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
                        distance_cm = distance_mm / 10.0
                        distance_text = f"{distance_mm:.1f} mm / {distance_cm:.2f} cm"
                    except Exception:
                        pass
            item_text = f"Measurement {i+1}: {distance_text}"
            self.measurements_list.addItem(item_text)

    def clear_measurements(self):
        self.measurements.clear()
        self.annotations.clear()
        self.current_measurement = None
        self.update_measurements_list()
        self.update_display()

    def reset_view(self):
        self.zoom_factor = 1.0
        self.pan_x = 0
        self.pan_y = 0
        self.zoom_slider.setValue(100)
        if self.current_image_data is not None:
            h, w = self.current_image_data.shape
            self.view_xlim = (0, w)
            self.view_ylim = (h, 0)
        self.update_display()

    def open_path(self, path):
        paths = []
        if os.path.isdir(path):
            for root, _, files in os.walk(path):
                for name in files:
                    if name.lower().endswith(('.dcm', '.dicom')):
                        paths.append(os.path.join(root, name))
        elif os.path.isfile(path):
            paths = [path]
        else:
            QMessageBox.warning(self, "Error", f"Path not found: {path}")
            return
        if not paths:
            QMessageBox.warning(self, "Error", f"No DICOM files found in: {path}")
            return
        self._load_dicom_paths(paths)


def main():
    parser = argparse.ArgumentParser(description='Python PyQt5 DICOM Viewer')
    parser.add_argument('--path', help='Path to a DICOM file or directory to open')
    parser.add_argument('--study-id', help='Study ID to load from backend (reserved)', type=int)
    args = parser.parse_args()

    app = QApplication(sys.argv)
    app.setStyle('Fusion')

    viewer = DicomViewer()
    viewer.show()

    if args.path:
        viewer.open_path(args.path)
    if args.study_id:
        viewer.load_backend_study(args.study_id)

    sys.exit(app.exec_())


if __name__ == '__main__':
    main()