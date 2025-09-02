/**
 * DICOM Viewer Visibility Fix
 * Ensures images are properly displayed and visible
 */

(function() {
    'use strict';
    
    // Fix for image visibility issues
    function ensureImageVisibility() {
        const dicomImage = document.getElementById('dicomImage');
        const imageContainer = document.getElementById('imageContainer');
        const singleView = document.getElementById('singleView');
        const welcomeScreen = document.getElementById('welcomeScreen');
        
        if (dicomImage) {
            // Ensure image has proper styling for visibility
            dicomImage.style.display = 'block';
            dicomImage.style.maxWidth = '100%';
            dicomImage.style.maxHeight = '100%';
            dicomImage.style.objectFit = 'contain';
            dicomImage.style.imageRendering = 'pixelated';
            dicomImage.style.imageRendering = 'crisp-edges';
            
            // Remove any hidden attributes
            dicomImage.removeAttribute('hidden');
            dicomImage.style.visibility = 'visible';
            dicomImage.style.opacity = dicomImage.style.opacity || '1';
        }
        
        if (imageContainer) {
            imageContainer.style.display = 'flex';
            imageContainer.style.alignItems = 'center';
            imageContainer.style.justifyContent = 'center';
            imageContainer.style.width = '100%';
            imageContainer.style.height = '100%';
            imageContainer.style.background = '#000000';
        }
        
        if (singleView) {
            singleView.style.display = 'flex';
            singleView.style.width = '100%';
            singleView.style.height = '100%';
        }
    }
    
    // Enhanced image loading with visibility fixes
    window.loadDicomImageWithVisibilityFix = async function(imageId, windowWidth = 400, windowLevel = 40, inverted = false) {
        try {
            // Ensure image container is visible first
            ensureImageVisibility();
            
            // Hide welcome screen if visible
            const welcomeScreen = document.getElementById('welcomeScreen');
            if (welcomeScreen) {
                welcomeScreen.style.display = 'none';
            }
            
            // Show single view
            const singleView = document.getElementById('singleView');
            if (singleView) {
                singleView.style.display = 'flex';
            }
            
            // Show loading state
            const dicomImage = document.getElementById('dicomImage');
            if (dicomImage) {
                dicomImage.style.opacity = '0.3';
            }
            
            // Load image with optimized settings
            const url = `/dicom-viewer/api/image/${imageId}/display/?ww=${windowWidth}&wl=${windowLevel}&invert=${inverted}&quality=fast`;
            
            const response = await fetch(url, {
                headers: {
                    'Accept': 'application/json',
                    'Cache-Control': 'max-age=300'
                },
                credentials: 'same-origin'
            });
            
            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: Failed to load image`);
            }
            
            const data = await response.json();
            
            if (data.image_data && dicomImage) {
                // Create a new image element to preload
                const img = new Image();
                
                img.onload = function() {
                    dicomImage.src = data.image_data;
                    dicomImage.style.opacity = '1';
                    dicomImage.style.display = 'block';
                    
                    // Ensure container is properly sized
                    ensureImageVisibility();
                    
                    // Trigger any update callbacks
                    if (typeof updateImageInfo === 'function' && data.image_info) {
                        updateImageInfo(data.image_info);
                    }
                    
                    console.log('DICOM image loaded and visible');
                };
                
                img.onerror = function() {
                    console.error('Failed to load DICOM image data');
                    dicomImage.style.opacity = '1';
                    showPlaceholderImage(dicomImage);
                };
                
                // Start loading
                img.src = data.image_data;
                
            } else {
                throw new Error('No image data received');
            }
            
        } catch (error) {
            console.error('DICOM loading error:', error);
            
            // Show placeholder on error
            const dicomImage = document.getElementById('dicomImage');
            if (dicomImage) {
                dicomImage.style.opacity = '1';
                showPlaceholderImage(dicomImage);
            }
            
            if (typeof showToast === 'function') {
                showToast(`Failed to load image: ${error.message}`, 'error');
            }
        }
    };
    
    // Show placeholder image when loading fails
    function showPlaceholderImage(imgElement) {
        // Create a simple placeholder
        const canvas = document.createElement('canvas');
        canvas.width = 512;
        canvas.height = 512;
        const ctx = canvas.getContext('2d');
        
        // Draw placeholder
        ctx.fillStyle = '#1a1a1a';
        ctx.fillRect(0, 0, 512, 512);
        
        ctx.fillStyle = '#666666';
        ctx.font = '16px Arial';
        ctx.textAlign = 'center';
        ctx.fillText('DICOM Image', 256, 240);
        ctx.fillText('Not Available', 256, 260);
        ctx.fillText('Please check image file', 256, 280);
        
        imgElement.src = canvas.toDataURL('image/jpeg', 0.8);
    }
    
    // Fix for viewport sizing issues
    function fixViewportSizing() {
        const viewport = document.querySelector('.viewport');
        const viewportContent = document.querySelector('.viewport-content');
        
        if (viewport) {
            viewport.style.position = 'relative';
            viewport.style.overflow = 'hidden';
            viewport.style.background = '#000000';
        }
        
        if (viewportContent) {
            viewportContent.style.width = '100%';
            viewportContent.style.height = '100%';
            viewportContent.style.display = 'flex';
            viewportContent.style.alignItems = 'center';
            viewportContent.style.justifyContent = 'center';
        }
    }
    
    // Auto-fix visibility issues when DOM is ready
    function initializeVisibilityFixes() {
        fixViewportSizing();
        ensureImageVisibility();
        
        // Override existing functions if they exist
        if (typeof window.updateImageDisplay === 'function') {
            const originalUpdate = window.updateImageDisplay;
            window.updateImageDisplay = async function() {
                ensureImageVisibility();
                return await originalUpdate.apply(this, arguments);
            };
        }
        
        // Fix study loading to show proper view
        if (typeof window.loadStudy === 'function') {
            const originalLoadStudy = window.loadStudy;
            window.loadStudy = async function(studyId) {
                const result = await originalLoadStudy.apply(this, arguments);
                
                // Ensure proper view is shown after loading
                setTimeout(() => {
                    const welcomeScreen = document.getElementById('welcomeScreen');
                    const singleView = document.getElementById('singleView');
                    
                    if (welcomeScreen) welcomeScreen.style.display = 'none';
                    if (singleView) singleView.style.display = 'flex';
                    
                    ensureImageVisibility();
                }, 100);
                
                return result;
            };
        }
        
        console.log('DICOM Visibility Fix initialized');
    }
    
    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initializeVisibilityFixes);
    } else {
        initializeVisibilityFixes();
    }
    
    // Re-check visibility when images are loaded
    document.addEventListener('DOMContentLoaded', function() {
        const dicomImage = document.getElementById('dicomImage');
        if (dicomImage) {
            dicomImage.addEventListener('load', ensureImageVisibility);
            dicomImage.addEventListener('error', function() {
                console.warn('DICOM image failed to load, showing placeholder');
                showPlaceholderImage(this);
            });
        }
    });
    
})();