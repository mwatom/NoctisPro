/**
 * DICOM Performance Optimization Fix
 * Addresses image loading speed and visibility issues
 */

(function() {
    'use strict';
    
    // Enhanced image loading with preloading and caching
    const ImagePreloader = {
        cache: new Map(),
        loadingQueue: new Map(),
        maxCacheSize: 50,
        
        // Preload next/previous images for smooth navigation
        preloadAdjacentImages: function(currentIndex, images) {
            if (!images || images.length === 0) return;
            
            // Preload next 2 and previous 2 images
            const indices = [];
            for (let i = -2; i <= 2; i++) {
                const idx = currentIndex + i;
                if (idx >= 0 && idx < images.length && idx !== currentIndex) {
                    indices.push(idx);
                }
            }
            
            indices.forEach(idx => {
                const image = images[idx];
                if (image && !this.cache.has(image.id)) {
                    this.preloadImage(image.id);
                }
            });
        },
        
        // Preload image in background
        preloadImage: function(imageId) {
            if (this.cache.has(imageId) || this.loadingQueue.has(imageId)) {
                return Promise.resolve(this.cache.get(imageId));
            }
            
            const promise = this.loadImageData(imageId);
            this.loadingQueue.set(imageId, promise);
            
            promise.then(data => {
                this.loadingQueue.delete(imageId);
                if (data) {
                    this.cacheImage(imageId, data);
                }
            }).catch(error => {
                this.loadingQueue.delete(imageId);
                console.warn(`Failed to preload image ${imageId}:`, error);
            });
            
            return promise;
        },
        
        // Load image data with optimized settings
        loadImageData: async function(imageId, windowWidth = 400, windowLevel = 40, inverted = false) {
            try {
                const url = `/dicom-viewer/api/image/${imageId}/display/?ww=${windowWidth}&wl=${windowLevel}&invert=${inverted}&quality=fast`;
                
                const response = await fetch(url, {
                    method: 'GET',
                    headers: {
                        'Accept': 'application/json',
                        'Cache-Control': 'max-age=300' // Cache for 5 minutes
                    },
                    credentials: 'same-origin'
                });
                
                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}`);
                }
                
                return await response.json();
            } catch (error) {
                console.error(`Error loading image ${imageId}:`, error);
                throw error;
            }
        },
        
        // Cache image with LRU eviction
        cacheImage: function(imageId, data) {
            if (this.cache.size >= this.maxCacheSize) {
                // Remove oldest entry
                const firstKey = this.cache.keys().next().value;
                this.cache.delete(firstKey);
            }
            this.cache.set(imageId, data);
        },
        
        // Get cached image or load it
        getImage: async function(imageId, windowWidth = 400, windowLevel = 40, inverted = false) {
            const cacheKey = `${imageId}_${windowWidth}_${windowLevel}_${inverted}`;
            
            if (this.cache.has(cacheKey)) {
                return this.cache.get(cacheKey);
            }
            
            if (this.loadingQueue.has(imageId)) {
                return await this.loadingQueue.get(imageId);
            }
            
            return await this.preloadImage(imageId);
        }
    };
    
    // Enhanced image display function
    window.updateImageDisplayOptimized = async function() {
        if (!window.images || !window.images.length || window.currentImageIndex < 0 || window.currentImageIndex >= window.images.length) {
            return;
        }
        
        const currentImage = window.images[window.currentImageIndex];
        if (!currentImage) return;
        
        try {
            // Show loading with better UX
            showLoadingOptimized('Loading image...');
            
            // Get image data (from cache or load)
            const data = await ImagePreloader.getImage(
                currentImage.id, 
                window.windowWidth || 400, 
                window.windowLevel || 40, 
                window.inverted || false
            );
            
            if (data && data.image_data) {
                const dicomImage = document.getElementById('dicomImage');
                
                // Preload the image to avoid flicker
                const img = new Image();
                img.onload = function() {
                    dicomImage.src = data.image_data;
                    dicomImage.style.opacity = '1';
                    hideLoadingOptimized();
                    
                    if (typeof updateImageInfo === 'function') {
                        updateImageInfo(data.image_info);
                    }
                    if (typeof updateOverlayInfo === 'function') {
                        updateOverlayInfo();
                    }
                    if (typeof updateMeasurementOverlay === 'function') {
                        updateMeasurementOverlay();
                    }
                    if (typeof updateAnnotationOverlay === 'function') {
                        updateAnnotationOverlay();
                    }
                    
                    // Preload adjacent images for smooth navigation
                    ImagePreloader.preloadAdjacentImages(window.currentImageIndex, window.images);
                };
                
                img.onerror = function() {
                    hideLoadingOptimized();
                    showToastOptimized('Failed to load image', 'error');
                };
                
                // Start loading
                dicomImage.style.opacity = '0.3';
                img.src = data.image_data;
                
            } else {
                hideLoadingOptimized();
                showToastOptimized('No image data received', 'error');
            }
            
        } catch (error) {
            hideLoadingOptimized();
            console.error('Error updating image display:', error);
            showToastOptimized('Error loading image', 'error');
        }
    };
    
    // Optimized loading indicator
    function showLoadingOptimized(message = 'Loading...') {
        let indicator = document.getElementById('loadingIndicatorOptimized');
        if (!indicator) {
            indicator = document.createElement('div');
            indicator.id = 'loadingIndicatorOptimized';
            indicator.style.cssText = `
                position: absolute;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                background: rgba(0, 0, 0, 0.9);
                color: #00d4ff;
                padding: 16px 24px;
                border-radius: 8px;
                z-index: 1000;
                font-size: 14px;
                font-weight: 500;
                display: flex;
                align-items: center;
                gap: 12px;
                border: 1px solid #00d4ff;
                box-shadow: 0 4px 20px rgba(0, 212, 255, 0.3);
            `;
            
            const viewport = document.querySelector('.viewport') || document.body;
            viewport.appendChild(indicator);
        }
        
        indicator.innerHTML = `
            <div style="
                width: 20px;
                height: 20px;
                border: 2px solid rgba(0, 212, 255, 0.3);
                border-top: 2px solid #00d4ff;
                border-radius: 50%;
                animation: spin 1s linear infinite;
            "></div>
            ${message}
        `;
        indicator.style.display = 'flex';
    }
    
    function hideLoadingOptimized() {
        const indicator = document.getElementById('loadingIndicatorOptimized');
        if (indicator) {
            indicator.style.display = 'none';
        }
    }
    
    function showToastOptimized(message, type = 'info') {
        if (typeof window.showToast === 'function') {
            window.showToast(message, type);
        } else if (window.DicomViewerUtils && typeof window.DicomViewerUtils.showToast === 'function') {
            window.DicomViewerUtils.showToast(message, type);
        } else {
            console.log(`${type.toUpperCase()}: ${message}`);
        }
    }
    
    // Override the default updateImageDisplay function
    if (typeof window.updateImageDisplay !== 'undefined') {
        window.updateImageDisplayOriginal = window.updateImageDisplay;
    }
    window.updateImageDisplay = window.updateImageDisplayOptimized;
    
    // Enhanced series loading with batch optimization
    window.loadSeriesOptimized = async function(seriesId) {
        if (!seriesId) return;
        
        try {
            showLoadingOptimized('Loading series images...');
            
            const response = await fetch(`/dicom-viewer/web/series/${seriesId}/images/`);
            const data = await response.json();
            
            if (data.series && data.images) {
                window.currentSeries = data.series;
                window.images = data.images;
                window.currentImageIndex = 0;
                
                // Update UI elements
                if (document.getElementById('seriesStatus')) {
                    document.getElementById('seriesStatus').textContent = 
                        `${window.currentSeries.series_description} (${window.images.length} images)`;
                }
                if (document.getElementById('imageCount')) {
                    document.getElementById('imageCount').textContent = window.images.length;
                }
                
                // Update slice slider
                const sliceSlider = document.getElementById('sliceSlider');
                if (sliceSlider) {
                    sliceSlider.max = Math.max(0, window.images.length - 1);
                    sliceSlider.value = 0;
                }
                
                // Update series info
                if (document.getElementById('seriesInfo')) {
                    document.getElementById('seriesInfo').innerHTML = `
                        <div>Images: ${window.images.length}</div>
                        <div>Modality: ${window.currentSeries.modality}</div>
                        <div>Thickness: ${window.currentSeries.slice_thickness || 'N/A'}</div>
                    `;
                }
                
                // Load modality-specific reconstruction options
                if (typeof loadModalityReconstructionOptions === 'function') {
                    await loadModalityReconstructionOptions(seriesId);
                }
                
                // Load first image with optimization
                await window.updateImageDisplayOptimized();
                
                hideLoadingOptimized();
                showToastOptimized(`Loaded ${window.images.length} images`, 'success');
                
                // Start preloading adjacent images
                ImagePreloader.preloadAdjacentImages(0, window.images);
                
            } else {
                hideLoadingOptimized();
                showToastOptimized('Failed to load series images', 'error');
            }
            
        } catch (error) {
            hideLoadingOptimized();
            console.error('Error loading series:', error);
            showToastOptimized('Error loading series', 'error');
        }
    };
    
    // Override loadSeries if it exists
    if (typeof window.loadSeries !== 'undefined') {
        window.loadSeriesOriginal = window.loadSeries;
    }
    window.loadSeries = window.loadSeriesOptimized;
    
    // Add CSS for smooth transitions
    const style = document.createElement('style');
    style.textContent = `
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .dicom-image {
            transition: opacity 0.2s ease-in-out !important;
        }
        
        .image-container {
            transition: all 0.1s ease !important;
        }
        
        .viewport-content {
            transition: opacity 0.2s ease-in-out !important;
        }
    `;
    document.head.appendChild(style);
    
    // Clear cache when window is about to unload to free memory
    window.addEventListener('beforeunload', function() {
        ImagePreloader.cache.clear();
        ImagePreloader.loadingQueue.clear();
    });
    
    console.log('DICOM Performance Fix loaded successfully');
    
})();