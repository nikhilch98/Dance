# Tiered Pricing System Guide

## Overview
The Nachna platform supports flexible tiered pricing for workshops, allowing you to set different prices based on various conditions like registration count, time, or custom tiers.

## Supported Pricing Formats

### 1. **Quantity-Based Tiered Pricing** (NEW - Enhanced)
Set different prices based on the number of completed registrations.

#### Format:
```
First X spots: ₹AMOUNT/-
After X spots: ₹AMOUNT/-
```

#### Examples:

**Example 1: Simple two-tier pricing**
```python
pricing_info="First 10 spots: ₹850/-\nAfter 10 spots: ₹950/-"
```
- First 10 people pay ₹850
- Everyone after pays ₹950

**Example 2: Multiple tiers**
```python
pricing_info="First 5 spots: ₹700/-\nFirst 15 spots: ₹850/-\nAfter 15 spots: ₹1000/-"
```
- First 5 people: ₹700
- Next 10 people (6-15): ₹850  
- Everyone after 15: ₹1000

**Example 3: Early bird with final tier**
```python
pricing_info="First 20 spots: ₹799/-\nAfter 20 spots: ₹999/-"
```

### 2. **Time-Based Tiered Pricing**
Set different prices based on registration dates.

#### Format:
```
Early Bird (Till DATE): ₹AMOUNT/-
Standard (AFTER DATE): ₹AMOUNT/-
```

#### Examples:

**Example 1: Early bird deadline**
```python
pricing_info="Early Bird (Till 18th Sept): ₹799/-\nStandard (19th-20th Sept): ₹999/-"
```

**Example 2: Multiple deadlines**
```python
pricing_info="Super Early (Till 15th Sept): ₹699/-\nEarly Bird (Till 20th Sept): ₹799/-\nStandard (After 20th Sept): ₹999/-"
```

### 3. **Simple/Fixed Pricing**
Single fixed price for all registrations.

#### Format:
```
₹AMOUNT/-
or
TIER_NAME: ₹AMOUNT/-
```

#### Examples:

**Example 1: Single price**
```python
pricing_info="₹999/-"
```

**Example 2: Named tiers (for multi-class packages)**
```python
pricing_info="Single Class: 1100/-\nTwo Classes: 2000/-\nThree Classes: 2700/-"
```

### 4. **Mixed Pricing with Bundles**
Combine individual pricing with bundle options.

#### Format:
```
INDIVIDUAL_PRICING
BUNDLE: BUNDLE_INFO
```

#### Example:
```python
pricing_info="First 10 spots: ₹850/-\nAfter 10 spots: ₹950/-\nBUNDLE: Three Classes Bundle: THREE_CLASSES_BUNDLE: uuid1,uuid2,uuid3: 2700: INR: Save ₹600"
```

## How It Works

### Quantity-Based Pricing Logic

1. **System counts completed paid orders** for the workshop
2. **Evaluates each pricing tier** in the order they appear
3. **Selects the appropriate tier**:
   - If "First X spots" and `completed_count < X` → Use this price (marked as Early Bird)
   - If "After X spots" and `completed_count >= X` → Use this price
4. **Displays tier information** to the user

### Priority System

When multiple pricing options are available, the system prioritizes:
1. **Early Bird tiers** (First X spots where count < X)
2. **Single Class options** (for non-bundle purchases)
3. **Standard tiers** (After X spots or default pricing)
4. **First available option** (fallback)

## Implementation Examples

### Royal Dance Space - Simple Two-Tier
```python
ManualWorkshopEntry(
    by="Chirag Gupta", 
    song="kufar",
    pricing_info="First 10 spots: ₹850/-\nAfter 10 spots: ₹950/-",
    event_type=EventType.WORKSHOP, 
    day=29, month=11, year=2025, 
    start_time="05:00 PM",
    end_time="07:00 PM", 
    registration_link="a", 
    artist_id_list=["chirag_guptaaaa"],
    registration_link_type="nachna", 
    workshop_uuid="beinrtribe_chirag_gupta_workshop_06_12_2025_kufar"
)
```

### Manifest - Multi-Class Package
```python
ManualWorkshopEntry(
    by="Dharmik Samani", 
    song="chhan ke mohalla",
    pricing_info="Single Class: 1100/-\nTwo Classes: 2000/-\nThree Classes: 2700/-",
    event_type=EventType.WORKSHOP, 
    day=7, month=12, year=2025, 
    start_time="01:00 PM",
    end_time="03:00 PM", 
    registration_link="a", 
    artist_id_list=["dharmiksamani"],
    registration_link_type="nachna", 
    workshop_uuid="beinrtribe_dharmik_samani_workshop_7_12_2025_chhan_ke_mohalla"
)
```

### Complex Time + Quantity Tiers
```python
ManualWorkshopEntry(
    by="Vivek & Aakanksha", 
    song="mayya mayya",
    pricing_info="First 5 spots: ₹699/-\nFirst 15 spots: ₹799/-\nAfter 15 spots: ₹999/-",
    event_type=EventType.WORKSHOP, 
    day=20, month=9, year=2025, 
    start_time="04:00 PM",
    end_time="06:00 PM", 
    registration_link="a", 
    artist_id_list=["vicky__pedia","aakanksha5678"],
    registration_link_type="nachna", 
    workshop_uuid="theroyaldancespace_vivek_aakanksha_workshop_20_9_2025_mayya"
)
```

## User Experience

### What Users See

**Before 10 registrations:**
```
Price: ₹850
Tier: Early Bird (First 10 spots)
Status: 7/10 spots filled
```

**After 10 registrations:**
```
Price: ₹950
Tier: Standard (After 10 spots)
Status: 12+ registrations
```

### Mobile App Display
- Current price is shown prominently
- Tier information is displayed as a badge
- Users can see if they qualify for early bird pricing

### Web Booking Display
- Same pricing logic applies
- Pricing info is displayed in the workshop card
- Real-time updates based on registration count

## Testing Recommendations

### Test Case 1: First 10 Spots
1. Create workshop with "First 10 spots: ₹850/-\nAfter 10 spots: ₹950/-"
2. Make 9 registrations
3. Verify 10th registration shows ₹850
4. Make 11th registration
5. Verify 11th registration shows ₹950

### Test Case 2: Multiple Tiers
1. Create workshop with three tiers (First 5, First 15, After 15)
2. Test pricing at 4, 5, 14, 15, and 16 registrations
3. Verify correct price at each milestone

### Test Case 3: Bundle + Tiered Pricing
1. Create workshop with quantity-based pricing + bundle option
2. Verify individual pricing respects tier
3. Verify bundle pricing is independent of individual tiers

## API Integration

### Getting Workshop Pricing
```python
GET /api/workshops/{workshop_uuid}
```

Response includes:
```json
{
  "uuid": "workshop_uuid",
  "pricing_info": "First 10 spots: ₹850/-\nAfter 10 spots: ₹950/-",
  "current_price": 850.0,  // Auto-calculated based on registrations
  "tier_info": "Early Bird (First 10 spots)"
}
```

### Creating Order
```python
POST /api/orders/create
{
  "workshop_uuid": "workshop_uuid",
  "user_id": "user_id"
}
```

System automatically:
1. Calculates current tier price
2. Checks registration count
3. Applies appropriate pricing
4. Returns order with tier information

## Database Schema

### Workshop Document
```json
{
  "uuid": "workshop_uuid",
  "pricing_info": "First 10 spots: ₹850/-\nAfter 10 spots: ₹950/-",
  "current_price": 850.0,
  "payment_link": "a",
  "payment_link_type": "nachna",
  ...
}
```

### Order Document
```json
{
  "order_id": "order_123",
  "workshop_uuid": "workshop_uuid",
  "amount": 85000,  // in paise
  "tier_info": "Early Bird (First 10 spots)",
  "is_early_bird": true,
  ...
}
```

## Best Practices

### DO ✅
- Use clear tier names ("First X spots", "After X spots")
- Include currency symbol (₹) and format (/-) consistently
- Set reasonable tier limits based on venue capacity
- Test pricing transitions between tiers
- Combine with bundle options for maximum flexibility

### DON'T ❌
- Use ambiguous tier names
- Set tier limits higher than venue capacity
- Mix multiple pricing formats in confusing ways
- Forget to test edge cases (exactly at tier boundary)
- Change pricing after registrations have started

## Troubleshooting

### Issue: Pricing not updating correctly
- Check `get_completed_orders_count()` is working
- Verify pricing_info format matches supported patterns
- Check logs for parsing errors

### Issue: Wrong tier displayed
- Verify completed_count calculation
- Check tier conditions (< vs >=)
- Ensure pricing_info uses correct format

### Issue: Early bird not working
- Confirm completed_count < limit
- Check "First X spots" format is exact
- Verify ₹ symbol is present

## Future Enhancements

Potential additions:
- Time-of-day based pricing
- Group/couple discounts
- Loyalty program integration
- Dynamic pricing based on demand
- Waitlist pricing tiers

---

**Last Updated:** November 30, 2025
**Version:** 1.0

