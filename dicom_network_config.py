#!/usr/bin/env python3
"""
DICOM Network Configuration for Remote AE Access
=================================================
This script configures the DICOM receiver for remote AE connections
through CloudFlare tunnels and direct IP access.
"""

import os
import sys
import json
from pathlib import Path

# Add Django project to path
BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.append(str(BASE_DIR))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'noctis_pro.settings')

import django
django.setup()

from worklist.models import Facility

def get_local_ip():
    """Get the local IP address for DICOM networking"""
    import socket
    try:
        # Connect to a remote address to determine local IP
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
        return local_ip
    except Exception:
        return "127.0.0.1"

def create_dicom_network_config():
    """Create DICOM network configuration for remote access"""
    
    config_dir = BASE_DIR / "config" / "dicom"
    config_dir.mkdir(parents=True, exist_ok=True)
    
    local_ip = get_local_ip()
    
    # DICOM network configuration
    dicom_config = {
        "receiver": {
            "aet": "NOCTIS_SCP",
            "port": 11112,
            "bind_address": "0.0.0.0",  # Listen on all interfaces
            "local_ip": local_ip,
            "max_pdu_size": 16384,
            "timeout": 30
        },
        "networking": {
            "allow_external": True,
            "require_facility_registration": True,
            "log_all_connections": True,
            "enable_echo_service": True
        },
        "cloudflare": {
            "tunnel_domain": "",  # Will be set by setup script
            "dicom_subdomain": "dicom",
            "public_port": 11112
        },
        "security": {
            "validate_ae_titles": True,
            "require_facility_match": True,
            "log_unauthorized_attempts": True,
            "max_connections_per_ae": 10
        }
    }
    
    # Save configuration
    config_file = config_dir / "network_config.json"
    with open(config_file, 'w') as f:
        json.dump(dicom_config, f, indent=2)
    
    print(f"✅ DICOM network configuration created: {config_file}")
    print(f"   Local IP detected: {local_ip}")
    print(f"   DICOM AET: {dicom_config['receiver']['aet']}")
    print(f"   DICOM Port: {dicom_config['receiver']['port']}")
    
    return config_file

def setup_example_facilities():
    """Set up example facilities for DICOM testing"""
    
    # Example facilities with different AE titles
    example_facilities = [
        {
            "name": "Main Hospital CT Scanner",
            "ae_title": "CT_MAIN_01",
            "description": "Primary CT scanner in radiology department",
            "is_active": True
        },
        {
            "name": "Emergency MRI Unit",
            "ae_title": "MRI_ER_01",
            "description": "Emergency department MRI scanner",
            "is_active": True
        },
        {
            "name": "Portable X-Ray Unit",
            "ae_title": "XRAY_PORT_01",
            "description": "Mobile X-ray unit for patient rooms",
            "is_active": True
        },
        {
            "name": "Ultrasound Department",
            "ae_title": "US_DEPT_01",
            "description": "Main ultrasound department",
            "is_active": True
        },
        {
            "name": "External Clinic",
            "ae_title": "CLINIC_EXT_01",
            "description": "External clinic sending studies",
            "is_active": True
        }
    ]
    
    created_count = 0
    for facility_data in example_facilities:
        facility, created = Facility.objects.get_or_create(
            ae_title=facility_data["ae_title"],
            defaults=facility_data
        )
        if created:
            created_count += 1
            print(f"✅ Created facility: {facility.name} (AET: {facility.ae_title})")
        else:
            print(f"ℹ️  Facility already exists: {facility.name} (AET: {facility.ae_title})")
    
    print(f"\n✅ Facility setup complete. {created_count} new facilities created.")
    return created_count

def create_dicom_connection_guide():
    """Create a guide for connecting remote DICOM devices"""
    
    guide_file = BASE_DIR / "docs" / "DICOM_CONNECTION_GUIDE.md"
    guide_file.parent.mkdir(parents=True, exist_ok=True)
    
    local_ip = get_local_ip()
    
    guide_content = f"""# DICOM Connection Guide for NoctisPro PACS

## Connection Methods

### 1. Direct IP Connection (Local Network)
- **Server IP**: `{local_ip}`
- **Port**: `11112`
- **AET**: `NOCTIS_SCP`

### 2. CloudFlare Tunnel (Internet Access)
- **Hostname**: `dicom.yourdomain.com` (replace with your domain)
- **Port**: `11112`
- **AET**: `NOCTIS_SCP`

### 3. ngrok Integration (Temporary URLs)
- Use ngrok to expose port 11112
- Configure your imaging device with the ngrok URL and port
- AET remains `NOCTIS_SCP`

## Configuring Your Imaging Device

### Step 1: Register Your Facility
Before sending images, ensure your facility is registered in NoctisPro:

1. Access the admin panel: `http://localhost:8000/admin/` (or your public URL)
2. Log in with admin credentials
3. Go to "Facilities" and add your imaging device:
   - **Name**: Descriptive name for your device/location
   - **AE Title**: Unique identifier for your device (e.g., `CT_MAIN_01`)
   - **Description**: Optional description
   - **Active**: Check this box

### Step 2: Configure Your DICOM Device

#### For GE Healthcare Devices:
```
Destination AET: NOCTIS_SCP
Destination IP: {local_ip} (or your CloudFlare domain)
Destination Port: 11112
Source AET: [Your registered AE Title]
```

#### For Siemens Devices:
```
Called AE Title: NOCTIS_SCP
Calling AE Title: [Your registered AE Title]
Remote Host: {local_ip} (or your CloudFlare domain)
Remote Port: 11112
```

#### For Philips Devices:
```
Remote AE Title: NOCTIS_SCP
Remote Host: {local_ip} (or your CloudFlare domain)
Remote Port: 11112
Local AE Title: [Your registered AE Title]
```

### Step 3: Test Connection

#### DICOM Echo Test (C-ECHO)
Most DICOM devices support echo testing. Use these settings:
- **Remote AET**: `NOCTIS_SCP`
- **Remote Host**: `{local_ip}` or your public domain
- **Remote Port**: `11112`

#### Test Image Send (C-STORE)
1. Select a test image on your device
2. Send to the configured destination
3. Check the NoctisPro web interface for the received image

## Registered AE Titles

The following AE titles are pre-configured:

| AE Title | Description | Status |
|----------|-------------|---------|
| CT_MAIN_01 | Main Hospital CT Scanner | Active |
| MRI_ER_01 | Emergency MRI Unit | Active |
| XRAY_PORT_01 | Portable X-Ray Unit | Active |
| US_DEPT_01 | Ultrasound Department | Active |
| CLINIC_EXT_01 | External Clinic | Active |

## Troubleshooting

### Connection Issues
1. **Firewall**: Ensure port 11112 is open on your server
2. **Network**: Verify network connectivity between devices
3. **AE Title**: Ensure your device's AE title is registered in NoctisPro

### Image Not Appearing
1. Check the DICOM receiver logs: `tail -f logs/dicom_receiver.log`
2. Verify your facility is active in the admin panel
3. Ensure your device is sending to the correct AET (`NOCTIS_SCP`)

### CloudFlare Tunnel Issues
1. Verify tunnel is running: `sudo systemctl status cloudflared-tunnel`
2. Check tunnel configuration: `config/cloudflare/config.yml`
3. Verify DNS records are properly configured

## Network Security

### Firewall Configuration
If using direct IP access, configure your firewall:

```bash
# Allow DICOM port
sudo ufw allow 11112/tcp

# Allow web interface (if needed)
sudo ufw allow 8000/tcp
```

### VPN Access
For enhanced security, consider accessing NoctisPro through a VPN:
1. Set up VPN server on your network
2. Connect remote devices through VPN
3. Use local IP addresses for DICOM connections

## Monitoring

### Connection Logs
Monitor DICOM connections:
```bash
# View real-time DICOM logs
tail -f logs/dicom_receiver.log

# View connection statistics
grep "C-STORE" logs/dicom_receiver.log | tail -20
```

### Health Checks
Verify DICOM service health:
```bash
# Test local connection
timeout 5 bash -c "</dev/tcp/localhost/11112" && echo "DICOM port accessible" || echo "DICOM port not accessible"

# Test remote connection (replace with your IP)
timeout 5 bash -c "</dev/tcp/{local_ip}/11112" && echo "Remote DICOM accessible" || echo "Remote DICOM not accessible"
```

## Support

For additional support:
1. Check the deployment logs: `logs/dicom_receiver.log`
2. Verify facility configuration in admin panel
3. Test connectivity with DICOM echo commands
4. Review network firewall settings

---

*Generated by NoctisPro PACS DICOM Configuration Script*
*Server IP: {local_ip} | Port: 11112 | AET: NOCTIS_SCP*
"""

    with open(guide_file, 'w') as f:
        f.write(guide_content)
    
    print(f"✅ DICOM connection guide created: {guide_file}")
    return guide_file

def main():
    """Main configuration function"""
    print("🔧 Configuring DICOM Network for Remote AE Access")
    print("=" * 50)
    
    # Create network configuration
    config_file = create_dicom_network_config()
    
    # Setup example facilities
    setup_example_facilities()
    
    # Create connection guide
    guide_file = create_dicom_connection_guide()
    
    print("\n🎉 DICOM Network Configuration Complete!")
    print("=" * 50)
    print(f"Configuration file: {config_file}")
    print(f"Connection guide: {guide_file}")
    print(f"Local IP address: {get_local_ip()}")
    print("DICOM AET: NOCTIS_SCP")
    print("DICOM Port: 11112")
    print("\nNext steps:")
    print("1. Configure your imaging devices with the above settings")
    print("2. Ensure port 11112 is accessible from your devices")
    print("3. Test connectivity using DICOM echo commands")

if __name__ == '__main__':
    main()