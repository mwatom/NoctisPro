// NoctisPro V2 JavaScript utilities

// Global utilities
window.NoctisPro = {
    // Show loading state
    showLoading: function(element) {
        if (element) {
            element.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Loading...';
            element.disabled = true;
        }
    },

    // Hide loading state
    hideLoading: function(element, originalText) {
        if (element) {
            element.innerHTML = originalText || element.innerHTML.replace(/<i[^>]*><\/i>\s*Loading\.\.\./, '');
            element.disabled = false;
        }
    },

    // Show toast notification
    showToast: function(message, type = 'info') {
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.innerHTML = `
            <div class="toast-content">
                <i class="fas fa-${this.getToastIcon(type)}"></i>
                <span>${message}</span>
            </div>
        `;
        
        document.body.appendChild(toast);
        
        // Show toast
        setTimeout(() => toast.classList.add('show'), 100);
        
        // Hide toast after 3 seconds
        setTimeout(() => {
            toast.classList.remove('show');
            setTimeout(() => document.body.removeChild(toast), 300);
        }, 3000);
    },

    // Get toast icon based on type
    getToastIcon: function(type) {
        const icons = {
            success: 'check-circle',
            error: 'exclamation-circle',
            warning: 'exclamation-triangle',
            info: 'info-circle'
        };
        return icons[type] || 'info-circle';
    },

    // Confirm dialog
    confirm: function(message, callback) {
        if (confirm(message)) {
            callback();
        }
    },

    // Format date
    formatDate: function(dateString) {
        const date = new Date(dateString);
        return date.toLocaleDateString();
    },

    // Format file size
    formatFileSize: function(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    },

    // AJAX helper
    ajax: function(url, options = {}) {
        const defaults = {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRFToken': this.getCsrfToken()
            }
        };
        
        const config = Object.assign(defaults, options);
        
        return fetch(url, config)
            .then(response => {
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                return response.json();
            });
    },

    // Get CSRF token
    getCsrfToken: function() {
        const token = document.querySelector('[name=csrfmiddlewaretoken]');
        if (token) {
            return token.value;
        }
        
        const metaToken = document.querySelector('meta[name="csrf-token"]');
        if (metaToken) {
            return metaToken.getAttribute('content');
        }
        
        return '';
    },

    // Initialize common functionality
    init: function() {
        // Add CSRF token to all forms
        const forms = document.querySelectorAll('form');
        forms.forEach(form => {
            if (!form.querySelector('[name="csrfmiddlewaretoken"]')) {
                const csrfInput = document.createElement('input');
                csrfInput.type = 'hidden';
                csrfInput.name = 'csrfmiddlewaretoken';
                csrfInput.value = this.getCsrfToken();
                form.appendChild(csrfInput);
            }
        });

        // Add loading states to buttons
        const buttons = document.querySelectorAll('button[type="submit"]');
        buttons.forEach(button => {
            button.addEventListener('click', function() {
                NoctisPro.showLoading(this);
            });
        });
    }
};

// Toast styles
const toastStyles = `
.toast {
    position: fixed;
    top: 20px;
    right: 20px;
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 6px;
    padding: 12px 16px;
    color: var(--text-primary);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    transform: translateX(400px);
    opacity: 0;
    transition: all 0.3s ease;
    z-index: 1000;
    max-width: 300px;
}

.toast.show {
    transform: translateX(0);
    opacity: 1;
}

.toast-content {
    display: flex;
    align-items: center;
    gap: 8px;
}

.toast-success {
    border-left: 4px solid var(--success-color);
}

.toast-error {
    border-left: 4px solid var(--danger-color);
}

.toast-warning {
    border-left: 4px solid var(--warning-color);
}

.toast-info {
    border-left: 4px solid var(--accent-color);
}
`;

// Inject toast styles
const styleSheet = document.createElement('style');
styleSheet.textContent = toastStyles;
document.head.appendChild(styleSheet);

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    NoctisPro.init();
});

// Export for module use
if (typeof module !== 'undefined' && module.exports) {
    module.exports = NoctisPro;
}