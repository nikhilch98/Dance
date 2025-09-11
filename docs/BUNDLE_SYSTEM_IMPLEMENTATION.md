# Multi-Workshop Bundle System - Complete Implementation

## 🎯 Overview

The Nachna platform now supports a comprehensive multi-workshop bundle system that allows users to purchase multiple workshops together at discounted rates. Each workshop in a bundle maintains its own order record and QR code, while sharing a single payment.

## 🏗️ System Architecture

### Database Collections

#### 1. `bundle_templates` Collection
```javascript
{
  "_id": ObjectId,
  "template_id": "WEEKEND_001",
  "name": "Weekend Dance Package",
  "description": "3 workshops this weekend - Save ₹500!",
  "workshop_ids": ["WSH_001", "WSH_002", "WSH_003"],
  "bundle_price": 2500,
  "individual_prices": [999, 999, 999],
  "currency": "INR",
  "discount_percentage": 16.7,
  "valid_until": "2024-09-22T23:59:59Z",
  "max_participants": 50,
  "is_active": true,
  "created_at": "2024-09-15T10:00:00Z",
  "updated_at": "2024-09-15T10:00:00Z"
}
```

#### 2. `bundles` Collection
```javascript
{
  "_id": ObjectId,
  "bundle_id": "BUNDLE_WEEKEND_001_USER123_1697123456",
  "name": "Weekend Dance Package",
  "bundle_payment_id": "PAY_BUNDLE_WEEKEND_001_USER123_1697123456",
  "member_orders": [
    {
      "order_id": "ORD_001",
      "position": 1,
      "status": "paid"
    },
    {
      "order_id": "ORD_002",
      "position": 2,
      "status": "paid"
    },
    {
      "order_id": "ORD_003",
      "position": 3,
      "status": "paid"
    }
  ],
  "total_amount": 2500,
  "individual_amount": 833,
  "user_id": "USER123",
  "status": "completed", // active, completed, cancelled, expired
  "created_at": "2024-09-15T10:00:00Z",
  "completed_at": "2024-09-15T10:30:00Z"
}
```

#### 3. Enhanced `orders` Collection
```javascript
{
  "_id": ObjectId,
  "order_id": "ORD_001",
  "user_id": "USER123",
  "workshop_uuid": "WSH_001",
  "amount": 83300, // in paise
  "currency": "INR",
  "status": "paid",
  // Bundle-related fields
  "bundle_id": "BUNDLE_WEEKEND_001_USER123_1697123456",
  "bundle_payment_id": "PAY_BUNDLE_WEEKEND_001_USER123_1697123456",
  "is_bundle_order": true,
  "bundle_position": 1,
  "bundle_total_workshops": 3,
  "bundle_total_amount": 250000, // in paise
  // ... other existing fields
}
```

## 🔧 API Endpoints

### Bundle Management Endpoints

#### 1. Get Bundle Templates
```http
GET /api/orders/bundles/templates
```
**Response:**
```json
{
  "bundles": [
    {
      "template_id": "WEEKEND_001",
      "name": "Weekend Dance Package",
      "description": "3 workshops this weekend - Save ₹500!",
      "workshop_ids": ["WSH_001", "WSH_002", "WSH_003"],
      "bundle_price": 2500,
      "individual_prices": [999, 999, 999],
      "currency": "INR",
      "discount_percentage": 16.7,
      "valid_until": "2024-09-22T23:59:59Z"
    }
  ]
}
```

#### 2. Purchase Bundle
```http
POST /api/orders/bundles/purchase
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "template_id": "WEEKEND_001",
  "user_id": "USER123"
}
```
**Response:**
```json
{
  "success": true,
  "bundle_id": "BUNDLE_WEEKEND_001_USER123_1697123456",
  "payment_link_url": "https://rzp.io/bundle_123",
  "payment_link_id": "plink_bundle_123",
  "total_amount": 2500,
  "currency": "INR",
  "individual_orders": ["ORD_001", "ORD_002", "ORD_003"],
  "message": "Bundle 'Weekend Dance Package' created successfully"
}
```

#### 3. Get Bundle Details
```http
GET /api/orders/bundles/{bundle_id}
Authorization: Bearer <jwt_token>
```
**Response:**
```json
{
  "bundle_id": "BUNDLE_WEEKEND_001_USER123_1697123456",
  "name": "Weekend Dance Package",
  "member_orders": [
    {
      "order_id": "ORD_001",
      "workshop_name": "Bollywood Basics",
      "status": "paid",
      "position": 1
    }
  ],
  "total_amount": 2500,
  "status": "completed",
  "created_at": "2024-09-15T10:00:00Z",
  "completed_at": "2024-09-15T10:30:00Z"
}
```

### Enhanced Existing Endpoints

#### 1. Create Payment Link (Enhanced)
```http
POST /api/orders/create-payment-link
```
**New Response Fields for Bundles:**
```json
{
  "success": true,
  "is_existing": false,
  "message": "Payment link created successfully",
  "order_id": "ORD_001",
  "payment_link_url": "https://rzp.io/...",
  "amount": 83300,
  "is_bundle": true,
  "bundle_id": "BUNDLE_WEEKEND_001",
  "bundle_name": "Weekend Dance Package",
  "bundle_total_amount": 250000
}
```

#### 2. User Orders (Enhanced)
```http
GET /api/orders/user
```
**Response includes bundle information:**
```json
{
  "orders": [
    {
      "order_id": "ORD_001",
      "workshop_details": {...},
      "amount": 83300,
      "status": "paid",
      // Bundle fields
      "is_bundle_order": true,
      "bundle_id": "BUNDLE_WEEKEND_001",
      "bundle_position": 1,
      "bundle_total_workshops": 3,
      "bundle_total_amount": 250000,
      "bundle_info": {
        "bundle_name": "Weekend Dance Package",
        "total_workshops": 3,
        "completed_workshops": 1,
        "shared_payment_amount": 2500,
        "other_orders": [
          {
            "order_id": "ORD_002",
            "workshop_name": "Hip Hop Moves",
            "status": "paid"
          }
        ]
      }
    }
  ]
}
```

## 🌐 Web Pages

### 1. Bundle Listing Page (`/bundles`)
- Displays all available bundle templates
- Shows pricing comparison and savings
- Includes workshop details for each bundle
- Responsive design with smooth animations

### 2. Bundle Detail Page (`/bundles/{template_id}`)
- Detailed bundle information
- Individual workshop breakdown
- Purchase flow with authentication
- Loading states and error handling

### 3. Enhanced Studio Booking Page
- Added "Bundles" link in share modal
- Bundle badge for bundle orders
- Bundle information display in order history

## 🔄 Bundle Purchase Flow

### Step 1: User Authentication
```javascript
// Check if user is authenticated
fetch('/api/auth/status')
  .then(response => response.json())
  .then(data => {
    if (data.authenticated) {
      proceedWithPurchase(data.user_id);
    } else {
      // Redirect to login
      window.location.href = '/studio?login_required=true&redirect=' + encodeURIComponent(window.location.pathname);
    }
  });
```

### Step 2: Bundle Creation
```javascript
// API call to create bundle
fetch('/api/orders/bundles/purchase', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    template_id: 'WEEKEND_001',
    user_id: userId
  })
})
.then(response => response.json())
.then(data => {
  if (data.success) {
    // Redirect to payment link
    window.location.href = data.payment_link_url;
  }
});
```

### Step 3: Payment Processing
- User completes payment via Razorpay
- Webhook processes bundle payment
- All orders in bundle updated to "paid"
- QR codes generated for each workshop
- Bundle status updated to "completed"

## 🔗 Bundle Webhook Processing

### Enhanced Webhook Handler
```python
# In app/api/razorpay.py
if razorpay_payment_link_reference_id.startswith("PAY_BUNDLE_"):
    # Process bundle payment
    bundle_orders = OrderOperations.get_orders_by_bundle_payment_id(
        razorpay_payment_link_reference_id
    )

    for bundle_order in bundle_orders:
        # Update each order status
        OrderOperations.update_order_status(
            bundle_order["order_id"], new_status
        )

    # Update bundle status
    BundleOperations.update_bundle_status(bundle_id, "completed")

    # Generate QR codes for all workshops
    await run_qr_generation_batch(order_ids)
```

## 📱 Mobile App Integration

### Bundle Display in Orders
- Bundle orders show "Bundle" badge
- Display bundle position (e.g., "Workshop 1 of 3")
- Show shared payment information
- Link to view other bundle orders

### QR Code Generation
- Individual QR codes for each workshop
- QR data includes bundle information
- Separate check-ins for each workshop

## 🛠️ Setup Instructions

### 1. Create Bundle Templates
```bash
# Run the bundle template creation script
python scripts/create_bundle_templates.py
```

### 2. Database Indexes
Ensure the following indexes are created:
```javascript
// bundles collection
db.bundles.createIndex({ "bundle_id": 1 });
db.bundles.createIndex({ "user_id": 1 });
db.bundles.createIndex({ "status": 1 });

// bundle_templates collection
db.bundle_templates.createIndex({ "template_id": 1 });
db.bundle_templates.createIndex({ "is_active": 1 });

// orders collection (enhanced)
db.orders.createIndex({ "bundle_id": 1 });
db.orders.createIndex({ "bundle_payment_id": 1 });
db.orders.createIndex({ "is_bundle_order": 1 });
```

### 3. Environment Variables
No additional environment variables required - uses existing MongoDB and Razorpay configuration.

## 🧪 Testing Scenarios

### 1. Complete Bundle Purchase Flow
1. User visits `/bundles`
2. Selects a bundle template
3. Clicks "Purchase Bundle"
4. Completes authentication if needed
5. Makes payment via Razorpay
6. Receives confirmation and QR codes

### 2. Bundle Order Management
1. View bundle orders in order history
2. See bundle information for each order
3. Access individual QR codes
4. Track bundle completion status

### 3. Webhook Processing
1. Simulate bundle payment completion
2. Verify all orders updated to "paid"
3. Confirm QR codes generated
4. Check bundle status updated

## 🔒 Security Considerations

### Authentication
- All bundle operations require valid JWT token
- User can only access their own bundles
- Bundle purchase validates user identity

### Payment Security
- Razorpay handles payment security
- Webhook signature verification
- Secure payment link generation

### Data Validation
- Bundle template validation
- Workshop existence verification
- Price calculation validation
- User permission checks

## 📊 Analytics & Reporting

### Bundle Performance Metrics
- Total bundles sold
- Revenue by bundle type
- Conversion rates
- Popular bundle combinations

### User Behavior
- Bundle vs individual workshop purchases
- Cart abandonment rates
- Payment completion rates
- User engagement with bundles

## 🚀 Future Enhancements

### Phase 2 Features
1. **Dynamic Bundles**: User-customizable bundle creation
2. **Bundle Recommendations**: AI-powered suggestions
3. **Time-limited Offers**: Flash sales and limited-time bundles
4. **Corporate Packages**: Team/group bundle discounts

### Phase 3 Features
1. **Bundle Subscriptions**: Recurring bundle payments
2. **Bundle Analytics**: Detailed performance insights
3. **Bundle Templates**: Admin interface for template management
4. **Advanced Pricing**: Tiered bundle pricing based on user segments

## 📋 Maintenance Tasks

### Regular Tasks
1. **Monitor Bundle Templates**: Ensure workshop_ids are valid
2. **Clean Up Expired Bundles**: Remove old bundle records
3. **Update Pricing**: Keep bundle pricing competitive
4. **Review Analytics**: Analyze bundle performance metrics

### Database Maintenance
1. **Index Optimization**: Monitor and optimize database indexes
2. **Data Cleanup**: Archive old bundle records
3. **Backup Verification**: Ensure bundle data is properly backed up

## 🐛 Troubleshooting

### Common Issues
1. **Bundle Payment Failed**: Check Razorpay webhook logs
2. **QR Code Not Generated**: Verify order status and background service
3. **Bundle Not Found**: Check bundle_id format and database
4. **Authentication Errors**: Verify JWT token validity

### Debug Commands
```bash
# Check bundle orders
db.orders.find({ "is_bundle_order": true }).limit(5)

# Check bundle records
db.bundles.find({}).limit(5)

# Check webhook logs
db.razorpay_webhook_logs.find({ "razorpay_payment_link_reference_id": { $regex: "^PAY_BUNDLE_" } }).limit(5)
```

## 📞 Support

For technical support or questions about the bundle system:
- Check the webhook logs for payment issues
- Verify database connectivity and indexes
- Review server logs for API errors
- Test with the provided bundle templates

---

**Implementation Complete**: The multi-workshop bundle system is now fully implemented and ready for production use. Users can purchase bundles, receive individual QR codes for each workshop, and track their bundle progress through both web and mobile interfaces.
