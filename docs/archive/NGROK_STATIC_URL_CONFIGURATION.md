# Ngrok Static URL Configuration

## Static URL Details

**Static Domain**: `mallard-shining-curiously.ngrok-free.app`
**Full URL**: `https://mallard-shining-curiously.ngrok-free.app`

## Configuration Added to Bulletproof Deployment

### Environment Variables Added:
```bash
# Ngrok Static URL Configuration
NGROK_USE_STATIC=true
NGROK_STATIC_URL=mallard-shining-curiously.ngrok-free.app
NGROK_STATIC_DOMAIN=mallard-shining-curiously.ngrok-free.app
NGROK_REGION=us
```

### ALLOWED_HOSTS Updated:
```bash
ALLOWED_HOSTS=localhost,127.0.0.1,*.ngrok.io,*.ngrok-free.app,mallard-shining-curiously.ngrok-free.app
```

### Ngrok Startup Logic:
The bulletproof deployment now includes intelligent ngrok startup:

1. **Static URL (Priority 1)**: If `NGROK_USE_STATIC=true` and `NGROK_STATIC_URL` is set
   ```bash
   ngrok http --url="mallard-shining-curiously.ngrok-free.app" 8000
   ```

2. **Authenticated Static Domain (Priority 2)**: If `NGROK_AUTHTOKEN` and `NGROK_STATIC_DOMAIN` are set
   ```bash
   ngrok http --authtoken="$NGROK_AUTHTOKEN" --url="$NGROK_STATIC_DOMAIN" 8000
   ```

3. **Dynamic Domain (Fallback)**: Default behavior
   ```bash
   ngrok http 8000
   ```

## System Features Added:

### ✅ Ngrok Installation
- Automatic ngrok installation via official repository
- Fallback to direct binary download if repository fails
- Graceful degradation if ngrok cannot be installed

### ✅ Static URL Tracking
- Creates `current_ngrok_url.txt` with the active URL
- Shows static URL in deployment success message
- Includes static URL in all application endpoints

### ✅ Service Integration
- Ngrok starts automatically with the application
- PID tracking for process management
- Proper logging to `logs/ngrok.log`

## Application Endpoints with Static URL:

Once deployed, the application will be available at:

- **Main Application**: `https://mallard-shining-curiously.ngrok-free.app/`
- **Admin Panel**: `https://mallard-shining-curiously.ngrok-free.app/admin/`
- **DICOM Viewer**: `https://mallard-shining-curiously.ngrok-free.app/dicom-viewer/`
- **Worklist**: `https://mallard-shining-curiously.ngrok-free.app/worklist/`
- **Health Check**: `https://mallard-shining-curiously.ngrok-free.app/health/`
- **API Endpoints**: `https://mallard-shining-curiously.ngrok-free.app/api/`

## Deployment Usage:

The static URL configuration is now automatically included when running:
```bash
sudo ./deploy_production_bulletproof.sh
```

The deployment will:
1. Install ngrok automatically
2. Configure the static URL environment
3. Start the application with the static tunnel
4. Display the public URL in the success message

## Verification:

After deployment, verify the static URL is working:
```bash
curl -I https://mallard-shining-curiously.ngrok-free.app
```

Should return a proper HTTP response indicating the application is accessible via the static URL.

## Benefits of Static URL:

1. **Consistent Access**: Same URL every time the application starts
2. **No Manual Configuration**: Automatic setup in bulletproof deployment
3. **Professional Appearance**: Clean, memorable URL for demonstrations
4. **CUPS Integration**: Stable URL for printing service callbacks
5. **API Reliability**: External services can depend on consistent endpoint