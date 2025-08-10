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
- **Database Integration**: Direct access to Noctis Pro studies
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

#### Method 1: Web Interface Integration (Recommended)
1. Navigate to the Noctis Pro web interface
2. Open any study in the DICOM viewer
3. Click the **"Desktop Viewer"** button in the top toolbar
4. The standalone application will launch automatically with the study loaded

#### Method 2: Direct Launch with Study ID
```bash
# Launch with specific study from database
python tools/launch_dicom_viewer.py --study-id 123

# Launch with debug mode
python tools/launch_dicom_viewer.py --study-id 123 --debug
```

#### Method 3: Direct Launch with DICOM Files
```bash
# Launch with specific DICOM file or directory
python tools/launch_dicom_viewer.py /path/to/dicom/files/
python tools/launch_dicom_viewer.py study.dcm

# Launch with debug mode
python tools/launch_dicom_viewer.py /path/to/dicom/files/ --debug
```

#### Method 4: Standalone Mode (No Database)
```bash
# Launch without database integration
python tools/launch_dicom_viewer.py --standalone

# Launch specific files in standalone mode
python tools/launch_dicom_viewer.py /path/to/dicom/files/ --standalone
```

#### Method 5: Direct Python Execution
```bash
python tools/standalone_viewers/dicom_viewer.py
```

### Features

#### Database Integration
- **Study Loading**: Load complete studies directly from the Noctis Pro database
- **Series Navigation**: Browse through multiple series within a study
- **Patient Information**: Display comprehensive patient and study metadata
- **Seamless Integration**: Launch from web interface with one click

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
- **Distance**: Measure distances between points with real-world units
- **Angle**: Measure angles between lines
- **Area**: Calculate areas of regions
- **Pixel Value**: Display pixel intensity values
- **Annotations**: Add text labels and drawings

#### Multi-Series Support
- **Series Navigation**: Dropdown selector for multi-series studies
- **Automatic Loading**: Smart loading of the first available series
- **Series Information**: Display series description, modality, and image count

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
- Django >= 4.0 (for database integration)

### Integration with Noctis Pro

The standalone viewer integrates seamlessly with the main Noctis Pro system through:

1. **Web Interface**: One-click launch button in study viewer
2. **Database Access**: Direct loading of studies from the database
3. **User Authentication**: Respects user permissions and facility access
4. **Shared Processing**: Uses the same DICOM processing libraries
5. **Real-time Updates**: Synchronized with web-based viewer changes

### Advanced Features

#### Command Line Options
```bash
python tools/launch_dicom_viewer.py [OPTIONS] [PATH]

Options:
  --study-id ID         Load study with specific database ID
  --debug              Enable debug mode with verbose output
  --standalone         Force standalone mode (no database)
  -h, --help           Show help message
```

#### Programming Interface
```python
from tools.standalone_viewers import DicomViewer

# Create viewer instance
viewer = DicomViewer()

# Load study from database (requires Django setup)
viewer = DicomViewer(study_id=123)

# Load DICOM files from path
viewer = DicomViewer(dicom_path="/path/to/dicom/files")

# Show the viewer
viewer.show()
```

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

**Database Connection Issues**:
- Ensure Django is properly configured
- Check database connectivity
- Verify user permissions for study access

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
│   ├── __init__.py                 # Module exports
│   └── dicom_viewer.py            # Main viewer application
├── launch_dicom_viewer.py         # Launcher script
└── README.md                      # This documentation
```

#### Extending the Viewer
The viewer is designed to be extensible. Common customizations:

1. **Adding New Tools**: Extend the `DicomViewer` class
2. **Custom Window Presets**: Modify the `window_presets` dictionary
3. **Export Formats**: Add new export options in the file menu
4. **Integration Points**: Add callbacks for web interface communication

#### API Integration
The viewer can be integrated into other applications:
```python
# Launch with specific study
from tools.standalone_viewers import main
main(study_id=123)

# Launch with DICOM files
main(dicom_path="/path/to/files")
```

### Security Considerations

- The desktop viewer runs with local user permissions
- DICOM files are processed locally on the user's machine
- Database access respects user authentication and facility permissions
- PHI (Protected Health Information) remains on the local system
- No network communication except for optional database integration

### Performance Optimization

- **Large Datasets**: Uses progressive loading for multi-series studies
- **Memory Management**: Images are cached intelligently to balance performance and memory usage
- **Database Queries**: Optimized queries for fast study loading
- **Rendering**: Hardware-accelerated rendering where available

### Support

For technical support:
1. Check the troubleshooting section above
2. Use debug mode to identify issues
3. Review the Noctis Pro main documentation
4. Contact your system administrator
5. Submit issues through the project repository

---

**Note**: This standalone viewer is part of the Noctis Pro ecosystem and is designed to complement, not replace, the web-based interface. It provides advanced features for users who need enhanced desktop DICOM viewing capabilities with seamless integration to the main system.