# QR Code System Deployment Guide

## Fixed Import Error

✅ **Issue Resolved**: The import error `cannot import name 'settings'` has been fixed.

**What was fixed:**
- Changed `from app.config.settings import settings` to `from app.config.settings import get_settings`
- Updated QRCodeService to use `get_settings()` pattern consistent with other services
- Added background QR service initialization to app startup

## Deployment Steps

### 1. Install Dependencies
The QR code dependencies are already included in `requirements.txt`:
```bash
pip install -r requirements.txt
```

### 2. Server Restart
After deploying the updated code, restart the FastAPI server:
```bash
# Kill existing process
pkill -f "python.*main.py"

# Start new process
python -m app.main
```

### 3. Verify Background Service
Check server logs for these startup messages:
```
MongoDB connection pool initialized
Cache invalidation watcher started
Workshop notification watcher started
Background QR code generation service started
```

### 4. Test QR Generation
- Check existing paid orders will automatically get QR codes within 5 minutes
- Use the manual trigger endpoint: `POST /api/orders/qr-generation/trigger`
- Check service status: `GET /api/orders/qr-generation/status`

## System Behavior

### Automatic QR Generation
- Runs every 5 minutes in background
- Processes 20 orders per batch
- Only generates QR codes for paid orders without existing QR codes
- Includes comprehensive logging for monitoring

### QR Code Security Features
- HMAC-SHA256 cryptographic signatures
- 30-day validity period
- Unique nonces prevent replay attacks
- Embedded nachna logo for branding
- Tamper-proof verification

### Admin Verification
- New "QR Scanner" tab in admin dashboard
- Real-time camera scanning
- Instant verification with detailed results
- Clear fraud detection warnings

## Monitoring

### Check QR Generation Status
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     https://nachna.com/api/orders/qr-generation/status
```

### Manual Trigger (if needed)
```bash
curl -X POST \
     -H "Authorization: Bearer YOUR_TOKEN" \
     https://nachna.com/api/orders/qr-generation/trigger
```

### View Server Logs
```bash
tail -f /var/log/nachna/app.log
```

## Rollback Plan

If any issues occur, the QR system can be disabled by:
1. Commenting out the QR service startup in `app/main.py`
2. Restarting the server
3. The rest of the app will continue working normally

## Success Indicators

✅ Server starts without import errors  
✅ Background QR service runs automatically  
✅ QR codes appear in order responses  
✅ Admin QR scanner works  
✅ Existing app functionality unchanged  

The QR system is fully backward compatible and will not affect any existing functionality.
