#!/bin/bash

# NoctisPro Printer Setup Script
# This script helps configure printers for high-quality DICOM image printing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}$1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (sudo)"
   exit 1
fi

log_header "🖨️  NoctisPro Printer Setup for Your Facility"
echo
log_info "This script helps configure YOUR FACILITY'S chosen printer(s) for DICOM image printing"
log_info "It supports any CUPS-compatible printer with your preferred media (paper, film, etc.)"
echo

# Check if CUPS is installed
if ! command -v cupsd &> /dev/null; then
    log_info "Installing CUPS printing system..."
    apt update
    apt install -y cups cups-client cups-filters printer-driver-all
    apt install -y printer-driver-canon printer-driver-epson printer-driver-hplip printer-driver-brlaser
    systemctl enable cups
    systemctl start cups
    log_success "CUPS installed and started"
else
    log_success "CUPS is already installed"
fi

# Check CUPS service status
if systemctl is-active --quiet cups; then
    log_success "CUPS service is running"
else
    log_warning "Starting CUPS service..."
    systemctl start cups
fi

# Add noctis user to lpadmin group if exists
if id "noctis" &>/dev/null; then
    usermod -a -G lpadmin noctis
    usermod -a -G lp noctis
    log_success "Added noctis user to printer groups"
fi

# Configure CUPS for network access
log_info "Configuring CUPS for network access..."
cupsctl --remote-any
systemctl restart cups

# Show current printer status
log_header "📋 Current Printer Status"
echo
if lpstat -p &>/dev/null; then
    lpstat -p -d
else
    log_warning "No printers currently configured"
fi
echo

# Interactive printer setup
log_header "🔧 Printer Setup Options"
echo
echo "Choose an option:"
echo "1) Auto-detect and add USB printer"
echo "2) Add network printer (IP address)"  
echo "3) Open CUPS web interface for manual setup"
echo "4) Test existing printer"
echo "5) Configure printer for your facility's media preferences"
echo "6) Skip printer setup"
echo

read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        log_info "Scanning for USB printers..."
        
        # Check for USB printers
        if lsusb | grep -i "printer\|canon\|epson\|hp\|brother" &>/dev/null; then
            log_success "USB printer detected!"
            lsusb | grep -i "printer\|canon\|epson\|hp\|brother"
            
            echo
            read -p "Enter name for your facility's printer (e.g., FacilityPrinter): " printer_name
            
            if [ -z "$printer_name" ]; then
                printer_name="FacilityPrinter"
            fi
            
            # Try to add USB printer automatically
            log_info "Adding USB printer: $printer_name"
            
            # Get USB device info
            usb_device=$(lsusb | grep -i "printer\|canon\|epson\|hp\|brother" | head -1)
            
            if [ ! -z "$usb_device" ]; then
                # Add printer with generic driver
                lpadmin -p "$printer_name" -E -v "usb://auto" -m everywhere
                
                # Set as default
                lpadmin -d "$printer_name"
                
                log_success "Printer '$printer_name' added successfully!"
            else
                log_error "Could not detect USB printer details"
            fi
        else
            log_warning "No USB printers detected. Please ensure printer is connected and powered on."
        fi
        ;;
        
    2)
        log_info "Setting up network printer..."
        echo
        read -p "Enter printer IP address: " printer_ip
                 read -p "Enter name for your facility's printer (e.g., FacilityPrinter): " printer_name
         
         if [ -z "$printer_name" ]; then
             printer_name="FacilityPrinter"
         fi
        
        if [ ! -z "$printer_ip" ]; then
            log_info "Adding network printer: $printer_name at $printer_ip"
            
            # Try IPP first, then fallback to socket
            if lpadmin -p "$printer_name" -E -v "ipp://$printer_ip/ipp/print" -m everywhere; then
                log_success "Network printer added via IPP"
            elif lpadmin -p "$printer_name" -E -v "socket://$printer_ip:9100" -m everywhere; then
                log_success "Network printer added via socket"
            else
                log_error "Failed to add network printer"
            fi
            
            # Set as default
            lpadmin -d "$printer_name"
        else
            log_error "No IP address provided"
        fi
        ;;
        
    3)
        log_info "Opening CUPS web interface..."
        log_info "Please open your web browser and go to: http://localhost:631"
        log_info "Navigate to Administration > Add Printer"
        log_info "Follow the wizard to add your printer"
        echo
        read -p "Press Enter after you've added your printer through the web interface..."
        ;;
        
    4)
        log_info "Testing existing printers..."
        
        if lpstat -p &>/dev/null; then
            echo "Available printers:"
            lpstat -p
            echo
            
            read -p "Enter printer name to test: " test_printer
            
            if [ ! -z "$test_printer" ]; then
                log_info "Sending test print to $test_printer..."
                echo "NoctisPro Printer Test - $(date)" | lp -d "$test_printer"
                
                if [ $? -eq 0 ]; then
                    log_success "Test print sent successfully!"
                    log_info "Check your printer for output"
                else
                    log_error "Test print failed"
                fi
            fi
        else
            log_warning "No printers configured"
        fi
        ;;
        
    5)
        log_info "Configuring printer for glossy paper printing..."
        
        if lpstat -p &>/dev/null; then
            echo "Available printers:"
            lpstat -p
            echo
            
            read -p "Enter printer name to configure: " config_printer
            
            if [ ! -z "$config_printer" ]; then
                log_info "Configuring $config_printer for medical imaging..."
                
                # Set optimal settings for medical images on glossy paper
                lpadmin -p "$config_printer" -o media=A4
                lpadmin -p "$config_printer" -o print-quality=5
                lpadmin -p "$config_printer" -o ColorModel=RGB
                lpadmin -p "$config_printer" -o media-type=photographic-glossy
                lpadmin -p "$config_printer" -o Resolution=1200dpi
                lpadmin -p "$config_printer" -o orientation-requested=3
                
                log_success "Printer configured for glossy paper printing!"
                
                # Test with glossy settings
                read -p "Send test print with glossy settings? (y/n): " test_glossy
                if [[ $test_glossy =~ ^[Yy]$ ]]; then
                    echo "NoctisPro Glossy Paper Test - $(date)" | lp -d "$config_printer" -o media-type=photographic-glossy -o print-quality=5
                    log_success "Glossy test print sent!"
                fi
            fi
        else
            log_warning "No printers configured. Please add a printer first."
        fi
        ;;
        
    6)
        log_info "Skipping printer setup"
        ;;
        
    *)
        log_error "Invalid choice"
        exit 1
        ;;
esac

echo
log_header "📋 Final Printer Status"
echo

# Show final printer status
if lpstat -p &>/dev/null; then
    log_success "Configured printers:"
    lpstat -p -d
    echo
    
    # Show printer options for each printer
    for printer in $(lpstat -p | awk '{print $2}'); do
        echo "Settings for $printer:"
        lpoptions -p "$printer" | head -5
        echo
    done
else
    log_warning "No printers configured"
fi

# Show CUPS service status
log_info "CUPS service status:"
systemctl status cups --no-pager -l

echo
log_header "🎯 Next Steps"
echo
echo "1. Test print functionality in NoctisPro:"
echo "   - Open DICOM viewer"
echo "   - Click Print button"
echo "   - Select glossy paper option"
echo "   - Verify high-quality output"
echo
echo "2. For additional printer setup:"
echo "   - Web interface: http://localhost:631"
echo "   - Command line: lpadmin -p PrinterName -E -v device-uri -m everywhere"
echo
echo "3. Troubleshooting:"
echo "   - Check CUPS logs: journalctl -u cups -f"
echo "   - Test printing: echo 'test' | lp"
echo "   - Check printer queue: lpq"
echo

log_success "Printer setup completed!"
echo
log_info "You can re-run this script anytime to add more printers or reconfigure existing ones"