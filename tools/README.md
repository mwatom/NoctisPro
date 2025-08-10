# Noctis Pro - Standalone Tools

This directory contains standalone desktop applications that complement the web-based Noctis Pro system.

## Standalone DICOM Viewer

### Overview

The Standalone DICOM Viewer is an advanced PyQt5-based desktop application that provides enhanced DICOM viewing capabilities beyond what's available in the web interface. It offers:

- **Advanced Image Manipulation**: Windowing, zooming, panning, rotation
- **Measurement Tools**: Distance, angle, area measurements
- **Enhanced Display Options**: Multiple window presets (lung, bone, soft tissue, brain, etc.)
- **Annotation Support**: Drawing and text annotations
- **Multi-series Support**: Navigate through multiple DICOM series
- **Export Capabilities**: Save processed images and measurements

### Installation

1. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Verify PyQt5 Installation**:
   ```bash
   python -c "import PyQt5.QtWidgets; print('PyQt5 is installed successfully')"
   ```

### Usage

#### Method 1: Direct Launch (Command Line)
```bash
# From project root directory
python tools/launch_dicom_viewer.py

# Launch with specific DICOM file or directory
python tools/launch_dicom_viewer.py /path/to/dicom/files/
python tools/launch_dicom_viewer.py study.dcm

# Launch with debug mode
python tools/launch_dicom_viewer.py --debug
```

#### Method 2: Web Interface Integration
1. Navigate to the Noctis Pro web interface
2. Go to **Viewer → Standalone**
3. Click the **"Desktop Viewer"** button in the top-right corner
4. The standalone application will launch automatically

#### Method 3: Direct Python Execution
```bash
python tools/standalone_viewers/dicom_viewer.py
```

### Features

#### Image Display and Manipulation
- **Windowing**: Adjust window width and level for optimal contrast
- **Zooming**: Mouse wheel or keyboard shortcuts for zoom control
- **Panning**: Click and drag to pan across large images
- **Rotation**: Rotate images by 90-degree increments
- **Inversion**: Toggle image inversion (negative)
- **Reset**: Quick reset to original view

#### Window Presets
- **Lung**: WW=1500, WL=-600
- **Bone**: WW=2000, WL=300
- **Soft Tissue**: WW=400, WL=40
- **Brain**: WW=100, WL=50
- **Abdomen**: WW=350, WL=50
- **Mediastinum**: WW=350, WL=50

#### Measurement Tools
- **Distance**: Measure distances between points
- **Angle**: Measure angles between lines
- **Area**: Calculate areas of regions
- **Pixel Value**: Display pixel intensity values

#### Annotations
- **Text Annotations**: Add text labels to images
- **Drawing Tools**: Free-hand drawing on images
- **Arrow Annotations**: Point to specific features

### Technical Requirements

#### System Requirements
- **Operating System**: Windows 10+, macOS 10.14+, or Linux (Ubuntu 18.04+)
- **Python**: 3.8 or higher
- **Memory**: Minimum 4GB RAM (8GB recommended for large datasets)
- **Display**: 1920x1080 or higher resolution recommended

#### Python Dependencies
- PyQt5 >= 5.15.10
- pydicom >= 2.4.3
- numpy >= 1.24.3
- matplotlib >= 3.8.2
- Pillow >= 10.1.0

### Integration with Noctis Pro

The standalone viewer integrates with the main Noctis Pro system through:

1. **Web Interface**: Launch button in the web-based viewer
2. **Shared DICOM Processing**: Uses the same DICOM processing libraries
3. **Database Integration**: Can access studies from the Noctis Pro database
4. **User Authentication**: Respects user permissions and facility access

### Troubleshooting

#### Common Issues

**PyQt5 Not Found Error**:
```bash
# Install PyQt5
pip install PyQt5==5.15.10 PyQt5-tools==5.15.9.3.3
```

**Display Issues on Linux**:
```bash
# Install required system packages
sudo apt-get install python3-pyqt5 python3-pyqt5.qtcore python3-pyqt5.qtgui
```

**Permission Issues**:
- Ensure the user has read access to DICOM files
- On macOS, may need to grant Python access to files in System Preferences

#### Debug Mode
Enable debug mode for troubleshooting:
```bash
python tools/launch_dicom_viewer.py --debug
```

### Development

#### File Structure
```
tools/
├── standalone_viewers/
│   ├── __init__.py
│   └── dicom_viewer.py          # Main viewer application
├── launch_dicom_viewer.py       # Launcher script
└── README.md                    # This documentation
```

#### Extending the Viewer
The viewer is designed to be extensible. Common customizations:

1. **Adding New Tools**: Extend the `DicomViewer` class
2. **Custom Window Presets**: Modify the `window_presets` dictionary
3. **Export Formats**: Add new export options in the file menu
4. **Integration Points**: Add callbacks for web interface communication

### Security Considerations

- The desktop viewer runs with local user permissions
- DICOM files are processed locally on the user's machine
- No network communication except for optional web interface integration
- PHI (Protected Health Information) remains on the local system

### Performance Optimization

- **Large Datasets**: Use progressive loading for multi-series studies
- **Memory Management**: Images are cached intelligently to balance performance and memory usage
- **GPU Acceleration**: Future versions may include GPU-accelerated processing

### Support

For technical support:
1. Check the troubleshooting section above
2. Review the Noctis Pro main documentation
3. Contact your system administrator
4. Submit issues through the project repository

---

**Note**: This standalone viewer is part of the Noctis Pro ecosystem and is designed to complement, not replace, the web-based interface. It provides advanced features for users who need enhanced desktop DICOM viewing capabilities.