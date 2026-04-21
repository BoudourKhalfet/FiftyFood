# Payment System Setup Guide

## Overview
This FiftyFood payment system integrates three payment methods:
1. **Stripe** (Card Payments)
2. **Konnect** (E-Dinar / D17)
3. **PayPal**

## Backend Configuration

### Environment Variables (.env)

Create a `.env` file in the `backend` directory with the following:

```env
# ========== STRIPE ==========
STRIPE_SECRET_KEY=sk_test_your_secret_key_here
STRIPE_PUBLISHABLE_KEY=pk_test_your_publishable_key_here

# ========== KONNECT (E-Dinar/D17) ==========
KONNECT_API_KEY=your_konnect_api_key_here
KONNECT_BASE_URL=https://api.konnect.tn  # or sandbox for testing

# ========== PAYPAL ==========
PAYPAL_CLIENT_ID=your_paypal_client_id_here
PAYPAL_CLIENT_SECRET=your_paypal_client_secret_here
PAYPAL_MODE=sandbox  # or 'live' for production

# ========== URLs ==========
BASE_URL=http://localhost:3000  # Or your production URL
PUBLIC_BACKEND_URL=http://localhost:3000
FRONTEND_URL=http://localhost:5174  # Flutter web or frontend URL
```

### Backend Endpoints

All payment endpoints require JWT authentication.

#### 1. Create Stripe Payment Intent
```
POST /payments/create-intent
Authorization: Bearer <JWT_TOKEN>

Body:
{
  "orderId": "order_123",
  "amount": 29.99,
  "email": "customer@example.com"  // optional
}

Response:
{
  "clientSecret": "pi_..._secret_...",
  "publishableKey": "pk_test_..."
}
```

#### 2. Create Konnect Payment
```
POST /payments/konnect
Authorization: Bearer <JWT_TOKEN>

Body:
{
  "orderId": "order_123",
  "firstName": "John",
  "lastName": "Doe",
  "email": "john@example.com",
  "phone": "+216XXXXXXXX"  // optional
}

Response:
{
  "paymentUrl": "https://konnect.tn/pay/...",
  "paymentId": "payment_123"
}
```

#### 3. Create PayPal Payment
```
POST /payments/paypal
Authorization: Bearer <JWT_TOKEN>

Body:
{
  "orderId": "order_123"
}

Response:
{
  "paypalOrderId": "7GL12345678",
  "approvalUrl": "https://www.paypal.com/checkoutnow?token=..."
}
```

#### 4. Verify Konnect Payment
```
GET /payments/konnect/:paymentId/verify/:orderId

Response:
{
  "status": "completed",
  "amount": 29.99,
  "orderId": "order_123",
  "isSuccessful": true
}
```

#### 5. Capture PayPal Payment
```
POST /payments/paypal/:paypalOrderId/capture/:orderId

Response:
{
  "status": "COMPLETED",
  "isSuccessful": true,
  "amount": 29.99,
  "orderId": "order_123"
}
```

#### 6. Confirm Stripe Payment
```
POST /payments/confirm-stripe/:orderId/:paymentIntentId

Response:
{
  "status": "succeeded",
  "amount": 29.99,
  "orderId": "order_123"
}
```

## Flutter Configuration

### Required Packages

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  shared_preferences: ^2.2.0
  url_launcher: ^6.2.0
  
  # Optional: For Stripe integration
  # flutter_stripe: ^10.0.0
  
  # Optional: For PayPal integration
  # paypal_flutter: ^1.0.0
```

### Integration Steps

1. **Import Payment Service**:
```dart
import 'package:fiftyfood/services/payment_service.dart';
import 'package:fiftyfood/widgets/payment_method_selector.dart';
import 'package:fiftyfood/screens/checkout/order_checkout_screen.dart';
```

2. **Use in Your Checkout Screen**:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => OrderCheckoutScreen(
      orderId: 'order_123',
      totalAmount: 29.99,
      orderDetails: orderData,
    ),
  ),
);
```

## Payment Flow Diagrams

### Stripe Flow
```
User selects Card → Backend creates payment intent → 
Stripe Sheet opens → User completes payment → 
Backend confirms payment → Order marked as PAID
```

### Konnect Flow
```
User selects E-Dinar → Backend creates Konnect payment → 
WebView opens with payment URL → User pays on Konnect → 
Redirected back → Backend verifies payment → 
Order marked as PAID
```

### PayPal Flow
```
User selects PayPal → Backend creates PayPal order → 
PayPal page opens → User approves payment → 
Redirected back → Backend captures payment → 
Order marked as PAID
```

## Database Schema Addition

Add this to your Prisma schema if it doesn't exist:

```prisma
model Payment {
  id            String   @id @default(cuid())
  orderId       String
  order         Order    @relation(fields: [orderId], references: [id])
  method        String   // CARD, EDINAR, PAYPAL
  amount        Float
  status        String   // PENDING, PAID, FAILED
  externalId    String?  // Stripe ID, Konnect ID, or PayPal ID
  metadata      Json?    // Additional data
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  @@index([orderId])
  @@index([externalId])
}
```

Run migration:
```bash
npx prisma migrate dev --name add_payments
```

## Order Status Updates

When payments are processed, orders update with these statuses:

| Status | Meaning |
|--------|---------|
| PENDING | Payment initiated but not completed |
| CONFIRMED | Payment successful, order confirmed |
| FAILED | Payment failed, order cancelled |
| CANCELLED | User cancelled the order |

## Error Handling

All payment endpoints return appropriate HTTP status codes:

- `200/201`: Success
- `400`: Bad Request (invalid order, missing fields)
- `401`: Unauthorized (no JWT token)
- `403`: Forbidden (not order owner)
- `500`: Server error

## Testing

### Test Credentials

#### Stripe (Sandbox)
- Card: `4242 4242 4242 4242`
- Expiry: Any future date (e.g., 12/25)
- CVC: Any 3 digits (e.g., 123)

#### PayPal (Sandbox)
- Create test accounts at https://developer.paypal.com/dashboard

#### Konnect (Sandbox)
- Contact Konnect for sandbox credentials

## Production Deployment

1. Replace all `_sandbox` and `_test` credentials with production keys
2. Update `PAYPAL_MODE` to `live`
3. Update `BASE_URL` and `PUBLIC_BACKEND_URL` to production URL
4. Enable HTTPS for all payment redirects
5. Set up webhook handlers for payment notifications

## Troubleshooting

### Payment Intent Creation Fails
- Check Stripe credentials in `.env`
- Ensure JWT token is valid
- Verify order exists

### Konnect Payment URL Doesn't Open
- Check if `url_launcher` package is properly configured
- Verify `FRONTEND_URL` is correct

### PayPal Approval Loop
- Ensure redirect URLs are configured correctly
- Check PayPal Developer Dashboard for app settings

## Support

For issues, contact:
- **Stripe**: https://support.stripe.com
- **Konnect**: https://konnect.tn/support
- **PayPal**: https://developer.paypal.com/support
