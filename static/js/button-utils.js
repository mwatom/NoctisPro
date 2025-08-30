/**
 * Button Utilities for Noctis Pro PACS
 * Provides enhanced button functionality and error handling
 */

// Prevent double-clicks on buttons
document.addEventListener('DOMContentLoaded', function() {
    let clickTimeout = {};
    
    // Add click protection to all buttons
    document.querySelectorAll('button, .btn, .btn-control, .tool').forEach(function(button) {
        button.addEventListener('click', function(e) {
            const buttonId = this.id || this.className || 'anonymous';
            
            // Prevent double-clicks
            if (clickTimeout[buttonId]) {
                e.preventDefault();
                e.stopPropagation();
                return false;
            }
            
            clickTimeout[buttonId] = true;
            setTimeout(() => {
                delete clickTimeout[buttonId];
            }, 300);
        }, true);
        
        // Add keyboard support
        button.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                this.click();
            }
        });
        
        // Add focus management
        button.addEventListener('focus', function() {
            this.setAttribute('data-focused', 'true');
        });
        
        button.addEventListener('blur', function() {
            this.removeAttribute('data-focused');
        });
    });
    
    // Add loading state management
    window.setButtonLoading = function(button, isLoading) {
        if (typeof button === 'string') {
            button = document.querySelector(button);
        }
        
        if (!button) return;
        
        if (isLoading) {
            button.disabled = true;
            button.classList.add('loading');
            button.setAttribute('aria-busy', 'true');
        } else {
            button.disabled = false;
            button.classList.remove('loading');
            button.removeAttribute('aria-busy');
        }
    };
    
    // Safe error handling for button clicks
    window.safeButtonHandler = function(handler) {
        return function(event) {
            try {
                return handler.call(this, event);
            } catch (error) {
                console.error('Button handler error:', error);
                
                // Show user-friendly error
                const message = 'An error occurred. Please try again.';
                if (typeof showNotification === 'function') {
                    showNotification(message, 'error');
                } else {
                    alert(message);
                }
                
                return false;
            }
        };
    };
    
    // Enhanced modal handling
    window.openModal = function(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.style.display = 'flex';
            modal.setAttribute('aria-hidden', 'false');
            
            // Focus first focusable element
            const focusable = modal.querySelector('button, input, select, textarea, [tabindex]:not([tabindex="-1"])');
            if (focusable) {
                focusable.focus();
            }
            
            // Trap focus within modal
            modal.addEventListener('keydown', function(e) {
                if (e.key === 'Escape') {
                    closeModal(modalId);
                }
            });
        }
    };
    
    window.closeModal = function(modalId) {
        const modal = document.getElementById(modalId);
        if (modal) {
            modal.style.display = 'none';
            modal.setAttribute('aria-hidden', 'true');
        }
    };
    
    console.log('Button utilities loaded successfully');
});