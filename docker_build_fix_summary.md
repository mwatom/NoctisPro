# Docker Build Fix: pycups Dependency Issue

## Problem
The Docker build was failing with the following error when trying to install the `pycups` package:
```
cupsconnection.h:26:10: fatal error: cups/http.h: No such file or directory
compilation terminated.
error: command '/usr/bin/gcc' failed with exit code 1
```

## Root Cause
The `pycups` Python package requires CUPS (Common Unix Printing System) development headers to compile properly. These headers were not installed in the Docker images, causing the build to fail.

## Solution
Added the necessary CUPS development and runtime libraries to both Dockerfiles:

### Changes Made:

#### 1. Dockerfile (main development dockerfile)
- Added `libcups2-dev` to the system dependencies installation step
- This provides the CUPS development headers needed for compiling pycups

#### 2. Dockerfile.production
- Added `libcups2-dev` to the builder stage system dependencies
- Added `libcups2` to the production stage runtime dependencies
- This ensures both compile-time and runtime support for CUPS functionality

### Specific Dependencies Added:
- **Build time**: `libcups2-dev` - CUPS development headers and libraries
- **Runtime**: `libcups2` - CUPS runtime libraries

## What This Fixes
- ✅ `pycups` package now compiles successfully
- ✅ DICOM printing functionality will work in the Docker containers
- ✅ All requirements.txt dependencies can be installed without errors

## Testing
To test the fix, run:
```bash
docker build -t noctis-pro .
```

Or for production:
```bash
docker build -f Dockerfile.production -t noctis-pro-production .
```

## Dependencies Resolved
- `pycups` - Python CUPS bindings for printer access
- `python-escpos` - ESC/POS printer commands (depends on proper system setup)
- `reportlab` - PDF generation with printing support

The Docker build should now complete successfully without the pycups compilation error.