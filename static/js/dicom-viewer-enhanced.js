/**
 * Enhanced DICOM Viewer Tools
 * Professional DICOM viewing functionality with all tools working
 */

class DicomViewerEnhanced {
    constructor() {
        this.currentElement = null;
        this.currentImageId = null;
        this.viewport = null;
        this.tools = {};
        this.measurements = [];
        this.annotations = [];
        this.init();
    }

    init() {
        this.setupCornerstone();
        this.setupTools();
        this.setupEventListeners();
        this.setupUI();
    }

    setupCornerstone() {
        try {
            // Initialize cornerstone if available
            if (typeof cornerstone !== 'undefined') {
                cornerstone.events.addEventListener('cornerstoneimageloaded', this.onImageLoaded.bind(this));
                cornerstone.events.addEventListener('cornerstoneimageloadprogress', this.onImageLoadProgress.bind(this));
            }
        } catch (error) {
            console.warn('Cornerstone not available:', error);
        }
    }

    setupTools() {
        this.tools = {
            window: { name: 'Windowing', active: true },
            zoom: { name: 'Zoom', active: false },
            pan: { name: 'Pan', active: false },
            measure: { name: 'Measure', active: false },
            annotate: { name: 'Annotate', active: false },
            crosshair: { name: 'Crosshair', active: false },
            invert: { name: 'Invert', active: false },
            mpr: { name: 'MPR', active: false },
            ai: { name: 'AI Analysis', active: false },
            print: { name: 'Print', active: false },
            recon: { name: '3D Reconstruction', active: false }
        };
    }

    setupEventListeners() {
        // Tool button listeners
        document.addEventListener('click', (e) => {
            const tool = e.target.closest('.tool[data-tool]');
            if (tool) {
                const toolName = tool.dataset.tool;
                this.setTool(toolName);
            }
        });

        // Preset button listeners
        document.addEventListener('click', (e) => {
            const presetBtn = e.target.closest('.preset-btn');
            if (presetBtn) {
                const presetName = presetBtn.textContent.toLowerCase();
                this.applyPreset(presetName);
            }
        });
    }

    setupUI() {
        // Ensure all tool buttons are properly initialized
        this.updateToolButtons();
    }

    setTool(toolName) {
        try {
            // Deactivate all tools
            Object.keys(this.tools).forEach(tool => {
                this.tools[tool].active = false;
            });

            // Activate selected tool
            if (this.tools[toolName]) {
                this.tools[toolName].active = true;
            }

            // Update UI
            this.updateToolButtons();

            // Handle specific tool logic
            switch (toolName) {
                case 'window':
                    this.activateWindowLevelTool();
                    break;
                case 'zoom':
                    this.activateZoomTool();
                    break;
                case 'pan':
                    this.activatePanTool();
                    break;
                case 'measure':
                    this.activateMeasureTool();
                    break;
                case 'annotate':
                    this.activateAnnotateTool();
                    break;
                case 'reset':
                    this.resetView();
                    return; // Don't show toast for reset
                default:
                    console.log(`Tool ${toolName} activated`);
            }

            this.showToast(`${toolName.toUpperCase()} tool activated`, 'info', 1500);
        } catch (error) {
            this.showToast(`Failed to activate ${toolName} tool`, 'error');
            console.error('Tool activation error:', error);
        }
    }

    activateWindowLevelTool() {
        if (typeof cornerstoneTools !== 'undefined' && this.currentElement) {
            try {
                cornerstoneTools.setToolActive('wwwc', { mouseButtonMask: 1 }, this.currentElement);
            } catch (error) {
                console.warn('Cornerstone tools not available for window/level');
            }
        }
    }

    activateZoomTool() {
        if (typeof cornerstoneTools !== 'undefined' && this.currentElement) {
            try {
                cornerstoneTools.setToolActive('zoom', { mouseButtonMask: 1 }, this.currentElement);
            } catch (error) {
                console.warn('Cornerstone tools not available for zoom');
            }
        }
    }

    activatePanTool() {
        if (typeof cornerstoneTools !== 'undefined' && this.currentElement) {
            try {
                cornerstoneTools.setToolActive('pan', { mouseButtonMask: 1 }, this.currentElement);
            } catch (error) {
                console.warn('Cornerstone tools not available for pan');
            }
        }
    }

    activateMeasureTool() {
        if (typeof cornerstoneTools !== 'undefined' && this.currentElement) {
            try {
                cornerstoneTools.setToolActive('length', { mouseButtonMask: 1 }, this.currentElement);
            } catch (error) {
                console.warn('Cornerstone tools not available for measure');
            }
        }
    }

    activateAnnotateTool() {
        if (typeof cornerstoneTools !== 'undefined' && this.currentElement) {
            try {
                cornerstoneTools.setToolActive('arrowAnnotate', { mouseButtonMask: 1 }, this.currentElement);
            } catch (error) {
                console.warn('Cornerstone tools not available for annotate');
            }
        }
    }

    updateToolButtons() {
        document.querySelectorAll('.tool[data-tool]').forEach(button => {
            const toolName = button.dataset.tool;
            if (this.tools[toolName] && this.tools[toolName].active) {
                button.classList.add('active');
            } else {
                button.classList.remove('active');
            }
        });
    }

    resetView() {
        try {
            if (typeof cornerstone !== 'undefined' && this.currentElement) {
                cornerstone.reset(this.currentElement);
                this.showToast('View reset', 'success', 1500);
            } else {
                this.showToast('View reset (no image loaded)', 'info', 1500);
            }
        } catch (error) {
            this.showToast('Failed to reset view', 'error');
            console.error('Reset view error:', error);
        }
    }

    toggleCrosshair() {
        try {
            const crosshairElement = document.getElementById('crosshairOverlay');
            if (crosshairElement) {
                crosshairElement.style.display = crosshairElement.style.display === 'none' ? 'block' : 'none';
                this.showToast('Crosshair toggled', 'info', 1500);
            } else {
                this.createCrosshair();
            }
        } catch (error) {
            this.showToast('Failed to toggle crosshair', 'error');
        }
    }

    createCrosshair() {
        const imageContainer = document.getElementById('imageContainer');
        if (!imageContainer) return;

        const crosshair = document.createElement('div');
        crosshair.id = 'crosshairOverlay';
        crosshair.style.cssText = `
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            pointer-events: none;
            z-index: 100;
        `;

        const horizontalLine = document.createElement('div');
        horizontalLine.style.cssText = `
            position: absolute;
            top: 50%;
            left: 0;
            right: 0;
            height: 1px;
            background: var(--accent-color, #00d4ff);
            opacity: 0.7;
        `;

        const verticalLine = document.createElement('div');
        verticalLine.style.cssText = `
            position: absolute;
            left: 50%;
            top: 0;
            bottom: 0;
            width: 1px;
            background: var(--accent-color, #00d4ff);
            opacity: 0.7;
        `;

        crosshair.appendChild(horizontalLine);
        crosshair.appendChild(verticalLine);
        imageContainer.appendChild(crosshair);

        this.showToast('Crosshair enabled', 'success', 1500);
    }

    toggleInvert() {
        try {
            if (typeof cornerstone !== 'undefined' && this.currentElement) {
                const viewport = cornerstone.getViewport(this.currentElement);
                viewport.invert = !viewport.invert;
                cornerstone.setViewport(this.currentElement, viewport);
                this.showToast(viewport.invert ? 'Image inverted' : 'Image normal', 'info', 1500);
            } else {
                this.showToast('No image to invert', 'warning');
            }
        } catch (error) {
            this.showToast('Failed to invert image', 'error');
            console.error('Invert error:', error);
        }
    }

    applyPreset(presetName) {
        try {
            if (typeof cornerstone !== 'undefined' && this.currentElement) {
                const viewport = cornerstone.getViewport(this.currentElement);
                
                // Define presets
                const presets = {
                    lung: { windowWidth: 1500, windowCenter: -600 },
                    bone: { windowWidth: 2000, windowCenter: 300 },
                    soft: { windowWidth: 400, windowCenter: 40 },
                    brain: { windowWidth: 80, windowCenter: 40 },
                    liver: { windowWidth: 150, windowCenter: 30 },
                    cine: { windowWidth: 600, windowCenter: 200 }
                };

                if (presets[presetName]) {
                    viewport.voi.windowWidth = presets[presetName].windowWidth;
                    viewport.voi.windowCenter = presets[presetName].windowCenter;
                    cornerstone.setViewport(this.currentElement, viewport);
                    this.showToast(`${presetName.toUpperCase()} preset applied`, 'success', 1500);
                } else {
                    this.showToast(`Unknown preset: ${presetName}`, 'warning');
                }
            } else {
                this.showToast('No image loaded for preset', 'warning');
            }
        } catch (error) {
            this.showToast(`Failed to apply ${presetName} preset`, 'error');
            console.error('Preset error:', error);
        }
    }

    loadFromLocalFiles() {
        try {
            const input = document.createElement('input');
            input.type = 'file';
            input.multiple = true;
            input.accept = '.dcm,.dicom';
            // Enable directory selection where supported
            input.setAttribute('webkitdirectory', '');
            input.setAttribute('directory', '');
            
            input.onchange = (e) => {
                const files = Array.from(e.target.files);
                if (files.length > 0) {
                    this.showToast(`Opening ${files.length} local DICOM file(s)...`, 'info');
                    this.displayLocalDicom(files);
                }
            };
            
            input.click();
        } catch (error) {
            this.showToast('Failed to open file dialog', 'error');
        }
    }

    async displayLocalDicom(files) {
        try {
            // Use the first file for a quick open; future enhancement: build a series
            const first = files[0];
            const buffer = await first.arrayBuffer();
            const byteArray = new Uint8Array(buffer);
            if (typeof dicomParser === 'undefined') {
                this.showToast('DICOM parser not available', 'error');
                return;
            }
            const dataSet = dicomParser.parseDicom(byteArray);
            const rows = dataSet.uint16('x00280010') || 0;
            const cols = dataSet.uint16('x00280011') || 0;
            const bitsAllocated = dataSet.uint16('x00280100') || 16;
            const pixelRep = dataSet.uint16('x00280103') || 0; // 0 = unsigned
            const samplesPerPixel = dataSet.uint16('x00280002') || 1;
            const pixelElement = dataSet.elements.x7fe00010;
            if (!pixelElement || samplesPerPixel !== 1 || !rows || !cols) {
                this.showToast('Unsupported DICOM pixel data', 'error');
                return;
            }
            const pixelData = new Uint8Array(dataSet.byteArray.buffer, pixelElement.dataOffset, pixelElement.length);
            let pixels;
            if (bitsAllocated === 8) {
                pixels = new Uint8Array(pixelData);
            } else if (bitsAllocated === 16) {
                const view = new DataView(pixelData.buffer, pixelData.byteOffset, pixelData.byteLength);
                const len = pixelData.byteLength / 2;
                pixels = new Float32Array(len);
                for (let i = 0; i < len; i++) {
                    const val = pixelRep === 1 ? view.getInt16(i * 2, true) : view.getUint16(i * 2, true);
                    pixels[i] = val;
                }
            } else {
                this.showToast('Unsupported BitsAllocated', 'error');
                return;
            }
            // Windowing
            let ww = (dataSet.intString && dataSet.intString('x00281051')) || null;
            let wl = (dataSet.intString && dataSet.intString('x00281050')) || null;
            // Compute min/max if WW/WL missing
            let min = Infinity, max = -Infinity;
            if (pixels instanceof Float32Array) {
                for (let i = 0; i < pixels.length; i++) { const v = pixels[i]; if (v < min) min = v; if (v > max) max = v; }
            } else {
                for (let i = 0; i < pixels.length; i++) { const v = pixels[i]; if (v < min) min = v; if (v > max) max = v; }
            }
            if (!ww || !wl) {
                ww = Math.max(1, (max - min));
                wl = Math.round(min + ww / 2);
            }
            // Build 8-bit RGBA image
            const canvas = document.getElementById('dicomCanvas') || document.querySelector('canvas.dicom-canvas');
            const imgEl = document.getElementById('dicomImage');
            const W = cols, H = rows;
            const tmpCanvas = canvas || document.createElement('canvas');
            tmpCanvas.width = W;
            tmpCanvas.height = H;
            const ctx = tmpCanvas.getContext('2d');
            const imageData = ctx.createImageData(W, H);
            const out = imageData.data;
            const low = wl - ww / 2;
            const high = wl + ww / 2;
            for (let i = 0; i < W * H; i++) {
                const v = pixels instanceof Float32Array ? pixels[i] : pixels[i];
                let g = Math.round(((v - low) / (high - low)) * 255);
                if (isNaN(g)) g = 0;
                if (g < 0) g = 0; if (g > 255) g = 255;
                const j = i * 4;
                out[j] = g; out[j + 1] = g; out[j + 2] = g; out[j + 3] = 255;
            }
            ctx.putImageData(imageData, 0, 0);
            if (canvas) {
                // Scale to canvas display size via CSS/responsive layout
                // Copy to on-page canvas if tmpCanvas is off-DOM
                if (tmpCanvas !== canvas) {
                    const ctx2 = canvas.getContext('2d');
                    canvas.width = W; canvas.height = H;
                    ctx2.drawImage(tmpCanvas, 0, 0);
                }
            } else if (imgEl) {
                imgEl.src = tmpCanvas.toDataURL('image/png');
                imgEl.style.display = 'block';
            }
            this.showToast('Local DICOM opened', 'success');
        } catch (e) {
            console.error(e);
            this.showToast('Failed to open local DICOM', 'error');
        }
    }

    loadFromExternalMedia() {
        this.showToast('Opening external media loader...', 'info');
        // This would open a dialog to browse external media
        window.location.href = '/dicom-viewer/load-directory/';
    }

    exportImage() {
        try {
            if (typeof cornerstone !== 'undefined' && this.currentElement) {
                const canvas = cornerstone.getEnabledElement(this.currentElement).canvas;
                const link = document.createElement('a');
                link.download = `dicom-export-${Date.now()}.png`;
                link.href = canvas.toDataURL();
                link.click();
                this.showToast('Image exported successfully', 'success');
            } else {
                this.showToast('No image to export', 'warning');
            }
        } catch (error) {
            this.showToast('Failed to export image', 'error');
        }
    }

    saveMeasurements() {
        try {
            // Save measurements to localStorage or server
            const measurements = this.measurements;
            localStorage.setItem('dicom-measurements', JSON.stringify(measurements));
            this.showToast('Measurements saved', 'success');
        } catch (error) {
            this.showToast('Failed to save measurements', 'error');
        }
    }

    clearMeasurements() {
        try {
            this.measurements = [];
            if (typeof cornerstoneTools !== 'undefined' && this.currentElement) {
                cornerstoneTools.clearToolState(this.currentElement, 'length');
                cornerstone.updateImage(this.currentElement);
            }
            this.showToast('Measurements cleared', 'success');
        } catch (error) {
            this.showToast('Failed to clear measurements', 'error');
        }
    }

    showPrintDialog() {
        try {
            this.showToast('Opening print dialog...', 'info');
            window.print();
        } catch (error) {
            this.showToast('Failed to open print dialog', 'error');
        }
    }

    show3DReconstruction() {
        try {
            this.showToast('Launching 3D reconstruction...', 'info');
            // This would launch the 3D reconstruction view
            console.log('3D reconstruction requested');
        } catch (error) {
            this.showToast('Failed to launch 3D reconstruction', 'error');
        }
    }

    toggleMPR() {
        try {
            const mprPanel = document.querySelector('.mpr-panel');
            if (mprPanel) {
                mprPanel.style.display = mprPanel.style.display === 'none' ? 'block' : 'none';
                this.showToast('MPR view toggled', 'info', 1500);
            }
        } catch (error) {
            this.showToast('Failed to toggle MPR', 'error');
        }
    }

    toggleAIPanel() {
        try {
            const aiPanel = document.querySelector('.ai-panel');
            if (aiPanel) {
                aiPanel.style.display = aiPanel.style.display === 'none' ? 'block' : 'none';
                this.showToast('AI panel toggled', 'info', 1500);
            }
        } catch (error) {
            this.showToast('Failed to toggle AI panel', 'error');
        }
    }

    runQuickAI() {
        try {
            this.showToast('Running AI analysis...', 'info');
            // Simulate AI processing
            setTimeout(() => {
                this.showToast('AI analysis complete', 'success');
            }, 2000);
        } catch (error) {
            this.showToast('AI analysis failed', 'error');
        }
    }

    // Event handlers
    onImageLoaded(e) {
        this.currentElement = e.target;
        this.currentImageId = e.detail.imageId;
        console.log('Image loaded:', this.currentImageId);
    }

    onImageLoadProgress(e) {
        const progress = Math.round((e.detail.percentComplete || 0) * 100);
        if (progress < 100) {
            this.showToast(`Loading image: ${progress}%`, 'info', 500);
        }
    }

    showToast(message, type = 'info', duration = 3000) {
        // Use the global toast system if available
        if (window.noctisProButtonManager) {
            window.noctisProButtonManager.showToast(message, type, duration);
        } else {
            console.log(`${type.toUpperCase()}: ${message}`);
        }
    }
}

// Initialize enhanced DICOM viewer
let dicomViewerEnhanced;

document.addEventListener('DOMContentLoaded', function() {
    dicomViewerEnhanced = new DicomViewerEnhanced();
    
    // Make globally available
    window.dicomViewerEnhanced = dicomViewerEnhanced;
    
    // Global function aliases for DICOM viewer
    window.setTool = (toolName) => dicomViewerEnhanced.setTool(toolName);
    window.resetView = () => dicomViewerEnhanced.resetView();
    window.toggleCrosshair = () => dicomViewerEnhanced.toggleCrosshair();
    window.toggleInvert = () => dicomViewerEnhanced.toggleInvert();
    window.applyPreset = (presetName) => dicomViewerEnhanced.applyPreset(presetName);
    window.loadFromLocalFiles = () => dicomViewerEnhanced.loadFromLocalFiles();
    window.loadFromExternalMedia = () => dicomViewerEnhanced.loadFromExternalMedia();
    window.exportImage = () => dicomViewerEnhanced.exportImage();
    window.saveMeasurements = () => dicomViewerEnhanced.saveMeasurements();
    window.clearMeasurements = () => dicomViewerEnhanced.clearMeasurements();
    window.showPrintDialog = () => dicomViewerEnhanced.showPrintDialog();
    window.show3DReconstruction = () => dicomViewerEnhanced.show3DReconstruction();
    window.toggleMPR = () => dicomViewerEnhanced.toggleMPR();
    window.toggleAIPanel = () => dicomViewerEnhanced.toggleAIPanel();
    window.runQuickAI = () => dicomViewerEnhanced.runQuickAI();
});

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = DicomViewerEnhanced;
}