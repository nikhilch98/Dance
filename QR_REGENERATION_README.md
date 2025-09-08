# QR Code Regeneration Guide

This guide explains how to regenerate QR codes for existing orders after updates to the QR generation system (such as adding the Nachna logo).

## Overview

The QR code regeneration system allows you to:
- Regenerate QR codes for existing orders with updated branding
- Generate QR codes for orders that don't have them
- View statistics about QR code coverage
- Test QR code generation functionality

## Methods to Regenerate QR Codes

### 1. Command Line Script (Recommended for large datasets)

Use the `regenerate_qr_codes.py` script for comprehensive regeneration:

```bash
# Regenerate QR codes for all existing orders
python3 regenerate_qr_codes.py --mode regenerate

# Generate QR codes for orders missing them
python3 regenerate_qr_codes.py --mode missing

# Show QR code statistics
python3 regenerate_qr_codes.py --mode stats

# Limit to specific number of orders
python3 regenerate_qr_codes.py --mode regenerate --limit 100

# Use custom batch size
python3 regenerate_qr_codes.py --mode regenerate --batch-size 5
```

### 2. API Endpoints (For admin interface integration)

#### Regenerate QR Codes
```http
POST /api/rewards/admin/regenerate-qr-codes
Content-Type: application/json

{
  "mode": "regenerate",  // or "missing"
  "limit": 100          // optional limit
}
```

#### Get QR Statistics
```http
GET /api/rewards/admin/qr-statistics
```

#### Test QR Generation
```http
POST /api/rewards/admin/test-qr-logo
```

## What Gets Updated

When QR codes are regenerated, the following improvements are applied:

### ✅ New Features Added:
- **Nachna Logo**: Professional logo embedded in center of QR code
- **Better Background**: White circular background with subtle shadow
- **Enhanced Styling**: Improved visual appearance
- **Higher Error Correction**: Better scannability with logo embedded
- **Updated Branding**: Latest Nachna visual identity

### 📊 Before vs After:
- **Before**: Plain QR code with basic styling
- **After**: QR code with Nachna logo, professional background, enhanced error correction

## Performance Considerations

### Batch Processing:
- **Script**: Processes in batches of 10 orders concurrently
- **API**: Processes in batches of 5 orders to avoid timeouts
- **Progress Tracking**: Real-time progress updates in logs

### Expected Performance:
- **Small batches (10-50 orders)**: ~30 seconds
- **Medium batches (100-500 orders)**: ~2-5 minutes
- **Large batches (1000+ orders)**: ~10-30 minutes

## Monitoring & Troubleshooting

### Check Progress:
```bash
# Monitor script logs
tail -f regenerate_qr_codes.py.log

# Check API response for detailed results
curl -X GET "http://localhost:8000/api/rewards/admin/qr-statistics"
```

### Common Issues:

#### 1. Logo File Not Found
**Error**: `Nachna logo file not found at static/assets/logo.png`
**Solution**: Ensure the logo file exists at the correct path

#### 2. Database Connection Issues
**Error**: `Error fetching orders for QR codes`
**Solution**: Check MongoDB connection and database permissions

#### 3. User Data Missing
**Error**: `User not found for order`
**Solution**: Some orders may reference deleted users - these will be skipped

#### 4. Memory Issues
**Error**: `MemoryError` on large batches
**Solution**: Reduce batch size or limit the number of orders

## Verification

After regeneration, verify the changes:

1. **Visual Check**: QR codes should show the Nachna logo prominently
2. **Scannability**: QR codes should still scan correctly
3. **Statistics**: Check coverage percentage increased
4. **API Test**: Use the test endpoint to verify functionality

## Example Usage Scenarios

### Scenario 1: Brand Update
```bash
# After updating the Nachna logo
python3 regenerate_qr_codes.py --mode regenerate --limit 100
```

### Scenario 2: Missing QR Codes
```bash
# Generate QR codes for orders that don't have them
python3 regenerate_qr_codes.py --mode missing
```

### Scenario 3: Testing Changes
```bash
# Test with small batch first
python3 regenerate_qr_codes.py --mode regenerate --limit 10 --batch-size 2
```

## API Response Examples

### Statistics Response:
```json
{
  "success": true,
  "total_paid_orders": 150,
  "orders_with_qr_codes": 140,
  "orders_without_qr_codes": 10,
  "qr_coverage_percentage": 93.33,
  "needs_regeneration": 140,
  "needs_generation": 10
}
```

### Regeneration Response:
```json
{
  "success": true,
  "message": "QR code regeneration completed",
  "total_orders": 140,
  "processed": 140,
  "successful": 135,
  "failed": 5,
  "success_rate": 96.43
}
```

## Best Practices

1. **Test First**: Always test with a small batch first
2. **Monitor Progress**: Watch logs for progress and errors
3. **Backup**: Consider backing up order data before large regenerations
4. **Staged Rollout**: Process in phases for large datasets
5. **Verify Results**: Check statistics and sample QR codes after completion

## Technical Details

### QR Code Improvements:
- **Logo Size**: 20% of QR code dimensions
- **Error Correction**: High level (H) for logo compatibility
- **Resolution**: Optimized for mobile scanning
- **Format**: PNG with base64 encoding
- **Caching**: Intelligent caching to avoid duplicates

### Database Updates:
- Updates `qr_code_data` field with new base64 image
- Updates `qr_code_generated_at` timestamp
- Maintains all existing order data
- Non-destructive operation (old QR codes are replaced)

This regeneration system ensures all your QR codes display the latest Nachna branding while maintaining full functionality! 🎨📱✨
