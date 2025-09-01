/**
 * Complete MPR and Reconstruction Suite for DICOM Viewer
 * Includes all reconstruction formats with crosshair functionality
 */

// MPR and 3D state variables
let mprMode = false;
let mprImages = { axial: null, sagittal: null, coronal: null };
let mprIndices = { axial: 0, sagittal: 0, coronal: 0 };
let mprCrosshair = { x: 50, y: 50, z: 50 };
let activePlane = 'axial';
let volumeData = null;
let volumeMetadata = null;
let orthogonalSync = true;

// Complete Reconstruction Functions
window.ReconstructionSuite = {
    
    // MPR (Multi-Planar Reconstruction)
    generateMPR: async function() {
        if (!currentSeries) {
            showToast('Please load a series first', 'warning');
            return;
        }
        
        try {
            showLoading('Generating MPR views...');
            
            const response = await fetch(`/dicom-viewer/api/mpr/${currentSeries.id}/?ww=${windowWidth}&wl=${windowLevel}&invert=${inverted}`);
            const data = await response.json();
            
            if (data.views) {
                document.getElementById('mprAxial').src = data.views.axial;
                document.getElementById('mprSagittal').src = data.views.sagittal;
                document.getElementById('mprCoronal').src = data.views.coronal;
                
                mprImages = data.views;
                volumeMetadata = data.metadata;
                
                this.switchToMPRView();
                this.initializeCrosshairs();
                
                hideLoading();
                showToast('MPR views generated successfully', 'success');
            } else {
                hideLoading();
                showToast('Failed to generate MPR views', 'error');
            }
            
        } catch (error) {
            hideLoading();
            console.error('Error generating MPR:', error);
            showToast('Error generating MPR views', 'error');
        }
    },
    
    // MIP (Maximum Intensity Projection)
    generateMIP: async function() {
        if (!currentSeries) {
            showToast('Please load a series first', 'warning');
            return;
        }
        
        try {
            showLoading('Generating MIP views...');
            
            const response = await fetch(`/dicom-viewer/api/mip/${currentSeries.id}/?ww=${windowWidth}&wl=${windowLevel}&invert=${inverted}`);
            const data = await response.json();
            
            if (data.success && data.mip_views) {
                document.getElementById('mprAxial').src = data.mip_views.axial;
                document.getElementById('mprSagittal').src = data.mip_views.sagittal;
                document.getElementById('mprCoronal').src = data.mip_views.coronal;
                
                this.switchToMPRView();
                this.initializeCrosshairs();
                
                hideLoading();
                showToast('MIP views generated successfully', 'success');
            } else {
                hideLoading();
                showToast('Failed to generate MIP views', 'error');
            }
            
        } catch (error) {
            hideLoading();
            console.error('Error generating MIP:', error);
            showToast('Error generating MIP views', 'error');
        }
    },
    
    // Bone 3D Reconstruction
    generateBone3D: async function() {
        if (!currentSeries) {
            showToast('Please load a series first', 'warning');
            return;
        }
        
        try {
            showLoading('Generating bone 3D reconstruction...');
            
            const response = await fetch(`/dicom-viewer/api/bone/${currentSeries.id}/?threshold=200&mesh=true&quality=normal`);
            const data = await response.json();
            
            if (data.bone_views) {
                document.getElementById('mprAxial').src = data.bone_views.axial;
                document.getElementById('mprSagittal').src = data.bone_views.sagittal;
                document.getElementById('mprCoronal').src = data.bone_views.coronal;
                
                this.switchToMPRView();
                this.initializeCrosshairs();
                
                hideLoading();
                showToast('Bone 3D reconstruction completed', 'success');
            } else {
                hideLoading();
                showToast('Failed to generate bone 3D reconstruction', 'error');
            }
            
        } catch (error) {
            hideLoading();
            console.error('Error generating bone 3D:', error);
            showToast('Error generating bone 3D reconstruction', 'error');
        }
    },
    
    // Volume Rendering
    generateVolumeRender: async function() {
        if (!currentSeries) {
            showToast('Please load a series first', 'warning');
            return;
        }
        
        try {
            showLoading('Generating volume rendering...');
            
            const response = await fetch(`/dicom-viewer/api/volume/${currentSeries.id}/?ww=${windowWidth}&wl=${windowLevel}&invert=${inverted}`);
            const data = await response.json();
            
            if (data.success && data.volume_views) {
                document.getElementById('mprAxial').src = data.volume_views.axial;
                document.getElementById('mprSagittal').src = data.volume_views.sagittal;
                document.getElementById('mprCoronal').src = data.volume_views.coronal;
                
                this.switchToMPRView();
                this.initializeCrosshairs();
                
                hideLoading();
                showToast('Volume rendering completed', 'success');
            } else {
                hideLoading();
                showToast('Failed to generate volume rendering', 'error');
            }
            
        } catch (error) {
            hideLoading();
            console.error('Error generating volume rendering:', error);
            showToast('Error generating volume rendering', 'error');
        }
    },
    
    // MRI Reconstruction
    generateMRI: async function(tissueType = 'brain') {
        if (!currentSeries) {
            showToast('Please load a series first', 'warning');
            return;
        }
        
        try {
            showLoading(`Generating MRI ${tissueType} reconstruction...`);
            
            const response = await fetch(`/dicom-viewer/api/mri/${currentSeries.id}/?tissue_type=${tissueType}&ww=${windowWidth}&wl=${windowLevel}&invert=${inverted}`);
            const data = await response.json();
            
            if (data.success && data.mri_views) {
                document.getElementById('mprAxial').src = data.mri_views.axial;
                document.getElementById('mprSagittal').src = data.mri_views.sagittal;
                document.getElementById('mprCoronal').src = data.mri_views.coronal;
                
                this.switchToMPRView();
                this.initializeCrosshairs();
                
                hideLoading();
                showToast(`MRI ${tissueType} reconstruction completed`, 'success');
                
                if (data.contrast_analysis) {
                    console.log('MRI Contrast Analysis:', data.contrast_analysis);
                }
            } else {
                hideLoading();
                showToast('Failed to generate MRI reconstruction', 'error');
            }
            
        } catch (error) {
            hideLoading();
            console.error('Error generating MRI:', error);
            showToast('Error generating MRI reconstruction', 'error');
        }
    },
    
    // PET Reconstruction
    generatePET: async function() {
        if (!currentSeries) {
            showToast('Please load a series first', 'warning');
            return;
        }
        
        try {
            showLoading('Generating PET SUV reconstruction...');
            
            const response = await fetch(`/dicom-viewer/api/pet/${currentSeries.id}/?ww=${windowWidth}&wl=${windowLevel}&invert=${inverted}`);
            const data = await response.json();
            
            if (data.success && data.pet_views) {
                document.getElementById('mprAxial').src = data.pet_views.axial;
                document.getElementById('mprSagittal').src = data.pet_views.sagittal;
                document.getElementById('mprCoronal').src = data.pet_views.coronal;
                
                this.switchToMPRView();
                this.initializeCrosshairs();
                
                hideLoading();
                showToast('PET SUV reconstruction completed', 'success');
                
                if (data.hotspots && data.hotspots.length > 0) {
                    showToast(`Detected ${data.hotspots.length} PET hotspots`, 'info');
                }
            } else {
                hideLoading();
                showToast('Failed to generate PET reconstruction', 'error');
            }
            
        } catch (error) {
            hideLoading();
            console.error('Error generating PET:', error);
            showToast('Error generating PET reconstruction', 'error');
        }
    },
    
    // SPECT Reconstruction
    generateSPECT: async function(tracerType = 'tc99m') {
        if (!currentSeries) {
            showToast('Please load a series first', 'warning');
            return;
        }
        
        try {
            showLoading(`Generating SPECT ${tracerType.toUpperCase()} reconstruction...`);
            
            const response = await fetch(`/dicom-viewer/api/spect/${currentSeries.id}/?tracer=${tracerType}&ww=${windowWidth}&wl=${windowLevel}&invert=${inverted}`);
            const data = await response.json();
            
            if (data.success && data.spect_views) {
                document.getElementById('mprAxial').src = data.spect_views.axial;
                document.getElementById('mprSagittal').src = data.spect_views.sagittal;
                document.getElementById('mprCoronal').src = data.spect_views.coronal;
                
                this.switchToMPRView();
                this.initializeCrosshairs();
                
                hideLoading();
                showToast(`SPECT ${tracerType.toUpperCase()} reconstruction completed`, 'success');
                
                if (data.defects && data.defects.length > 0) {
                    showToast(`Detected ${data.defects.length} perfusion defects`, 'warning');
                }
            } else {
                hideLoading();
                showToast('Failed to generate SPECT reconstruction', 'error');
            }
            
        } catch (error) {
            hideLoading();
            console.error('Error generating SPECT:', error);
            showToast('Error generating SPECT reconstruction', 'error');
        }
    },
    
    // Nuclear Medicine Reconstruction
    generateNuclear: async function(isotope = 'tc99m') {
        if (!currentSeries) {
            showToast('Please load a series first', 'warning');
            return;
        }
        
        try {
            showLoading(`Generating ${isotope.toUpperCase()} nuclear medicine reconstruction...`);
            
            const response = await fetch(`/dicom-viewer/api/nuclear/${currentSeries.id}/?isotope=${isotope}&ww=${windowWidth}&wl=${windowLevel}&invert=${inverted}`);
            const data = await response.json();
            
            if (data.success && data.nuclear_views) {
                document.getElementById('mprAxial').src = data.nuclear_views.axial;
                document.getElementById('mprSagittal').src = data.nuclear_views.sagittal;
                document.getElementById('mprCoronal').src = data.nuclear_views.coronal;
                
                this.switchToMPRView();
                this.initializeCrosshairs();
                
                hideLoading();
                showToast(`${isotope.toUpperCase()} nuclear medicine reconstruction completed`, 'success');
            } else {
                hideLoading();
                showToast('Failed to generate nuclear medicine reconstruction', 'error');
            }
            
        } catch (error) {
            hideLoading();
            console.error('Error generating nuclear medicine:', error);
            showToast('Error generating nuclear medicine reconstruction', 'error');
        }
    },
    
    // Switch to MPR view
    switchToMPRView: function() {
        document.getElementById('singleView').style.display = 'none';
        document.getElementById('mprView').style.display = 'grid';
        mprMode = true;
        
        // Update MPR button state
        const mprBtn = document.querySelector('[data-tool="mpr"]');
        if (mprBtn) {
            mprBtn.classList.add('active');
        }
    },
    
    // Initialize crosshair system
    initializeCrosshairs: function() {
        mprCrosshair = { x: 50, y: 50, z: 50 }; // Center position
        this.updateAllCrosshairs();
        this.setupMPRInteractions();
    },
    
    // Setup MPR viewport interactions
    setupMPRInteractions: function() {
        const mprViewports = document.querySelectorAll('.mpr-viewport');
        
        mprViewports.forEach(viewport => {
            const plane = viewport.getAttribute('data-plane');
            if (plane === '3d') return; // Skip 3D viewport
            
            // Remove existing listeners to prevent duplicates
            const existingHandler = viewport._mprMouseMoveHandler;
            if (existingHandler) {
                viewport.removeEventListener('mousemove', existingHandler);
                viewport.removeEventListener('click', existingHandler);
            }
            
            // Create new handlers
            const mouseMoveHandler = (e) => this.handleMPRMouseMove(e, plane);
            const clickHandler = (e) => this.handleMPRClick(e, plane);
            
            // Store handlers for later removal
            viewport._mprMouseMoveHandler = mouseMoveHandler;
            viewport._mprClickHandler = clickHandler;
            
            // Add new listeners
            viewport.addEventListener('mousemove', mouseMoveHandler);
            viewport.addEventListener('click', clickHandler);
        });
    },
    
    // Handle mouse movement in MPR viewports
    handleMPRMouseMove: function(e, plane) {
        if (!orthogonalSync || !mprMode) return;
        
        const viewport = e.currentTarget;
        const rect = viewport.getBoundingClientRect();
        const x = ((e.clientX - rect.left) / rect.width) * 100;
        const y = ((e.clientY - rect.top) / rect.height) * 100;
        
        // Update crosshair position based on plane
        this.updateCrosshairPosition(plane, x, y);
    },
    
    // Handle clicks in MPR viewports
    handleMPRClick: function(e, plane) {
        this.setActivePlane(plane);
        
        if (orthogonalSync) {
            const viewport = e.currentTarget;
            const rect = viewport.getBoundingClientRect();
            const x = ((e.clientX - rect.left) / rect.width) * 100;
            const y = ((e.clientY - rect.top) / rect.height) * 100;
            
            // Lock crosshair position and update images
            this.updateCrosshairPosition(plane, x, y, true);
            this.updateOrthogonalImages(plane, x, y);
        }
    },
    
    // Set active plane
    setActivePlane: function(plane) {
        activePlane = plane;
        
        // Update visual state
        document.querySelectorAll('.mpr-viewport').forEach(vp => {
            vp.classList.remove('active');
        });
        const activeViewport = document.querySelector(`[data-plane="${plane}"]`);
        if (activeViewport) {
            activeViewport.classList.add('active');
        }
        
        // Update crosshairs if orthogonal sync is enabled
        if (orthogonalSync) {
            this.updateAllCrosshairs();
        }
    },
    
    // Update crosshair position
    updateCrosshairPosition: function(plane, x, y, lock = false) {
        // Update crosshair coordinates based on plane
        if (plane === 'axial') {
            mprCrosshair.x = x;
            mprCrosshair.y = y;
        } else if (plane === 'sagittal') {
            mprCrosshair.z = x;
            mprCrosshair.y = y;
        } else if (plane === 'coronal') {
            mprCrosshair.x = x;
            mprCrosshair.z = y;
        }
        
        // Update crosshair display on all planes
        if (lock) {
            this.updateCrosshairDisplay();
        }
    },
    
    // Update crosshair display
    updateCrosshairDisplay: function() {
        const planes = ['axial', 'sagittal', 'coronal'];
        
        planes.forEach(plane => {
            const crosshair = document.getElementById(`crosshair${plane.charAt(0).toUpperCase() + plane.slice(1)}`);
            if (!crosshair) return;
            
            const hLine = crosshair.querySelector('.crosshair-line-h-mpr');
            const vLine = crosshair.querySelector('.crosshair-line-v-mpr');
            
            if (plane === 'axial') {
                if (hLine) hLine.style.top = `${mprCrosshair.y}%`;
                if (vLine) vLine.style.left = `${mprCrosshair.x}%`;
            } else if (plane === 'sagittal') {
                if (hLine) hLine.style.top = `${mprCrosshair.y}%`;
                if (vLine) vLine.style.left = `${mprCrosshair.z}%`;
            } else if (plane === 'coronal') {
                if (hLine) hLine.style.top = `${mprCrosshair.z}%`;
                if (vLine) vLine.style.left = `${mprCrosshair.x}%`;
            }
        });
    },
    
    // Update all crosshairs
    updateAllCrosshairs: function() {
        if (!orthogonalSync || !mprMode) return;
        
        // Show crosshairs on all MPR viewports
        const planes = ['axial', 'sagittal', 'coronal'];
        planes.forEach(plane => {
            const crosshair = document.getElementById(`crosshair${plane.charAt(0).toUpperCase() + plane.slice(1)}`);
            if (crosshair) {
                crosshair.classList.add('active');
            }
        });
        
        this.updateCrosshairDisplay();
    },
    
    // Update orthogonal images on crosshair movement
    updateOrthogonalImages: async function(activePlane, x, y) {
        if (!currentSeries || !mprMode) return;
        
        try {
            // Calculate slice indices based on crosshair position
            const sliceData = {
                plane: activePlane,
                x_percent: x,
                y_percent: y,
                crosshair_x: mprCrosshair.x,
                crosshair_y: mprCrosshair.y,
                crosshair_z: mprCrosshair.z
            };
            
            // Request updated orthogonal slices
            const response = await fetch(`/dicom-viewer/api/mpr/${currentSeries.id}/update/`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRFToken': getCSRFToken()
                },
                body: JSON.stringify({
                    ...sliceData,
                    ww: windowWidth,
                    wl: windowLevel,
                    invert: inverted
                })
            });
            
            const data = await response.json();
            
            if (data.success && data.updated_views) {
                // Update the other two planes (not the active one)
                if (activePlane !== 'axial' && data.updated_views.axial) {
                    document.getElementById('mprAxial').src = data.updated_views.axial;
                }
                if (activePlane !== 'sagittal' && data.updated_views.sagittal) {
                    document.getElementById('mprSagittal').src = data.updated_views.sagittal;
                }
                if (activePlane !== 'coronal' && data.updated_views.coronal) {
                    document.getElementById('mprCoronal').src = data.updated_views.coronal;
                }
                
                // Update crosshairs on all planes
                this.updateCrosshairDisplay();
            }
            
        } catch (error) {
            console.error('Error updating orthogonal images:', error);
        }
    }
};

// Global functions for backward compatibility
window.generateMPR = () => ReconstructionSuite.generateMPR();
window.generateMIP = () => ReconstructionSuite.generateMIP();
window.generateBone3D = () => ReconstructionSuite.generateBone3D();
window.generateVolumeRender = () => ReconstructionSuite.generateVolumeRender();
window.generateMRI = (tissueType) => ReconstructionSuite.generateMRI(tissueType);
window.generatePET = () => ReconstructionSuite.generatePET();
window.generateSPECT = (tracerType) => ReconstructionSuite.generateSPECT(tracerType);
window.generateNuclear = (isotope) => ReconstructionSuite.generateNuclear(isotope);

window.setActivePlane = (plane) => ReconstructionSuite.setActivePlane(plane);
window.updateCrosshairOverlay = (plane) => {
    if (!orthogonalSync) return;
    const crosshair = document.getElementById(`crosshair${plane.charAt(0).toUpperCase() + plane.slice(1)}`);
    if (crosshair && mprMode) {
        crosshair.classList.add('active');
    }
};

window.toggleMPR = () => ReconstructionSuite.generateMPR();

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    // Initialize MPR system
    mprCrosshair = { x: 50, y: 50, z: 50 };
    orthogonalSync = true;
});