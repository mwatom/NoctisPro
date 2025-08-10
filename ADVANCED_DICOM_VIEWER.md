# Advanced DICOM Viewer

## Overview

The Advanced DICOM Viewer is a comprehensive medical imaging interface that provides professional-grade tools for viewing and analyzing DICOM files. It extends the existing Noctis Pro PACS system with enhanced features for standalone DICOM file analysis.

## Features

### Core Functionality
- **Multi-format Support**: Supports .dcm and .dicom files
- **Drag & Drop Interface**: Easy file loading with visual feedback
- **Advanced Windowing**: Real-time window/level adjustment with presets
- **Multi-tool Support**: Windowing, zoom, pan, measure, annotate tools
- **Full-screen Mode**: Immersive viewing experience
- **Keyboard Shortcuts**: Professional workflow acceleration

### Advanced Tools
- **Window/Level Presets**: Lung, Bone, Soft Tissue, Brain, Abdomen, Mediastinum
- **Image Manipulation**: Zoom (10%-1000%), pan, invert, reset
- **Navigation Controls**: Previous/next image, cine mode playback
- **Real-time Information**: Overlay displays for technical parameters
- **DICOM Tag Viewer**: Complete metadata inspection

### User Interface
- **Dark Professional Theme**: Optimized for medical imaging
- **Responsive Design**: Works on various screen sizes
- **Left Toolbar**: Quick access to imaging tools
- **Right Panel**: Detailed controls and information
- **Information Overlays**: Real-time display of image parameters

## File Structure

```
[Deprecated] The previous web-based advanced viewer was removed in favor of the C++ desktop viewer.
dicom_viewer/
├── urls.py                            # URL routing
├── views.py                           # View functions
```

## URL Access

The advanced viewer is accessible at:
- `/dicom_viewer/advanced/` - Advanced standalone DICOM viewer

## Usage Instructions

### Loading DICOM Files

1. **Via Button**: Click "Load DICOM Files" in the header
2. **Drag & Drop**: Drag DICOM files directly onto the viewer
3. **Supported Formats**: .dcm, .dicom files

### Tool Usage

#### Windowing (W/L)
- **Mouse**: Click and drag to adjust window/level
- **Sliders**: Use the right panel controls
- **Presets**: Click preset buttons for common tissue types
- **Keyboard**: Number keys 1-5 for tool selection

#### Navigation
- **Mouse Wheel**: Zoom in/out
- **Shift + Mouse Wheel**: Navigate through image series
- **Arrow Keys**: Previous/next image
- **Space**: Play/pause cine mode

#### Tools
- **Zoom**: Mouse wheel or zoom slider
- **Pan**: Click and drag with pan tool active
- **Reset**: R key or reset button
- **Invert**: I key or invert checkbox
- **Fullscreen**: F key or fullscreen button

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Arrow Keys | Navigate images |
| Space | Play/Pause cine |
| R | Reset view |
| I | Invert image |
| F | Fit to window |
| 1 | Windowing tool |
| 2 | Zoom tool |
| 3 | Pan tool |
| 4 | Measure tool |
| 5 | Annotate tool |

## Technical Implementation

### Frontend Technologies
- **HTML5 Canvas**: High-performance image rendering
- **JavaScript ES6+**: Modern browser features
- **CSS3**: Advanced styling and animations
- **Bootstrap**: Responsive framework integration

### Backend Integration
- **Django Framework**: Python web framework
- **pydicom**: DICOM file parsing
- **numpy**: Image processing
- **PIL/Pillow**: Image manipulation

### API Endpoints
- `POST /dicom_viewer/upload/` - Upload DICOM files
- `GET /dicom_viewer/api/image/{id}/display/` - Get processed images
- `POST /dicom_viewer/launch-desktop/` - Launch desktop viewer

## File Processing Flow

1. **Upload**: Files uploaded via FormData to Django backend
2. **Parsing**: pydicom extracts DICOM metadata and pixel data
3. **Processing**: Window/level adjustments applied server-side
4. **Encoding**: Images converted to base64 for client display
5. **Rendering**: Canvas-based display with transformations

## Security Features

- **CSRF Protection**: All form submissions protected
- **File Validation**: Only DICOM files accepted
- **User Authentication**: Login required for access
- **Permission Checks**: Facility-based access control

## Browser Compatibility

- **Chrome**: Full support (recommended)
- **Firefox**: Full support
- **Safari**: Full support
- **Edge**: Full support
- **Mobile**: Limited support (responsive design included)

## Performance Considerations

- **Large Files**: Progressive loading with indicators
- **Memory Management**: Efficient canvas operations
- **Network**: Optimized API calls
- **Caching**: Client-side image caching

## Customization Options

### Window/Level Presets
Add new presets by modifying the `setWindowPreset()` function:

```javascript
case 'custom':
    newWidth = 500;
    newCenter = 100;
    break;
```

### Tool Extensions
New tools can be added by:
1. Adding tool button to toolbar
2. Implementing tool logic in JavaScript
3. Adding cursor and interaction handlers

## Troubleshooting

### Common Issues

1. **No Image Display**
   - Check file format (.dcm/.dicom)
   - Verify file integrity
   - Check browser console for errors

2. **Slow Performance**
   - Reduce image size
   - Close other browser tabs
   - Check network connection

3. **Upload Failures**
   - Verify CSRF token
   - Check file size limits
   - Ensure proper file permissions

### Browser Console
Enable developer tools (F12) to view detailed error messages and debugging information.

## Integration with Main System

The Advanced DICOM Viewer integrates seamlessly with:
- **Worklist Management**: Direct access from study lists
- **User Authentication**: Facility-based permissions
- **Desktop Viewer**: Launch external applications
- **Reporting System**: Integration with reporting workflows

## Future Enhancements

Potential improvements include:
- **3D Reconstruction**: Volume rendering capabilities
- **AI Integration**: Automated analysis features
- **Multi-planar Reconstruction**: MPR viewing
- **Measurement Tools**: Distance and area calculations
- **Annotation System**: Persistent markup capabilities
- **Print Support**: High-quality image printing
- **Export Features**: Various format exports

## Support

For technical support or feature requests, please refer to the main Noctis Pro PACS documentation or contact the development team.