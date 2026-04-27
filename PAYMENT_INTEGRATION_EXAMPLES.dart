// Example: How to integrate Payment System into your Order Flow

// ============================================
// EXAMPLE 1: From Order Creation to Checkout
// ============================================

import 'package:fiftyfood/services/payment_service.dart';
import 'package:fiftyfood/screens/checkout/order_checkout_screen.dart';

class OrderService {
  // After order is created and stored in database
  Future<void> proceedToCheckout({
    required String orderId,
    required double totalAmount,
    required Map<String, dynamic> orderDetails,
  }) async {
    // Navigate to checkout with order data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderCheckoutScreen(
          orderId: orderId,
          totalAmount: totalAmount,
          orderDetails: orderDetails,
        ),
      ),
    );
  }
}

// ============================================
// EXAMPLE 2: Backend - Updated Order Creation
// ============================================

// In orders.service.ts (NestJS backend)

async createOrder(userId: string, dto: CreateOrderDto) {
  // Create order with PENDING payment status
  const order = await this.prisma.order.create({
    data: {
      clientId: userId,
      restaurantId: dto.restaurantId,
      offerId: dto.offerId,
      total: dto.total,
      quantity: dto.quantity,
      status: 'PENDING', // Order awaiting payment
      deliveryAddress: dto.deliveryAddress,
      notes: dto.notes,
    },
  });

  return {
    id: order.id,
    total: order.total,
    status: order.status,
    message: 'Please proceed to payment',
  };
}

// ============================================
// EXAMPLE 3: Complete User Journey
// ============================================

class OrderJourneyScreen extends StatefulWidget {
  @override
  State<OrderJourneyScreen> createState() => _OrderJourneyScreenState();
}

class _OrderJourneyScreenState extends State<OrderJourneyScreen> {
  // Step 1: User sees offer details
  void _viewOfferDetails() {
    // Show offer details...
  }

  // Step 2: User clicks "Order Now"
  void _placeOrder() async {
    try {
      // Create order via API
      final orderResponse = await http.post(
        Uri.parse('http://localhost:3000/orders'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'offerId': 'offer_123',
          'restaurantId': 'rest_123',
          'quantity': 2,
          'total': 29.99,
          'deliveryAddress': '123 Main St',
        }),
      );

      if (orderResponse.statusCode == 201) {
        final order = jsonDecode(orderResponse.body);
        
        // Step 3: Navigate to checkout
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderCheckoutScreen(
                orderId: order['id'],
                totalAmount: order['total'],
                orderDetails: order,
              ),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error placing order: $e')),
      );
    }
  }

  // Step 3: Payment completed in OrderCheckoutScreen
  // (Automatic redirect back after payment)

  // Step 4: Order confirmation screen
  void _showOrderConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✓ Order Confirmed!'),
        content: const Text('Your order has been placed and paid.');
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Navigate to order tracking
              _navigateToOrderTracking();
            },
            child: const Text('Track Order'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Place Order')),
      body: Center(
        child: ElevatedButton(
          onPressed: _placeOrder,
          child: const Text('Order Now'),
        ),
      ),
    );
  }
}

// ============================================
// EXAMPLE 4: Order Status in Real-Time
// ============================================

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Future<Map<String, dynamic>> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = _fetchOrderStatus();
  }

  Future<Map<String, dynamic>> _fetchOrderStatus() async {
    final response = await http.get(
      Uri.parse('http://localhost:3000/orders/${widget.orderId}'),
      headers: {'Authorization': 'Bearer $jwt'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch order');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Status')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final order = snapshot.data!;
          final status = order['status']; // PENDING, CONFIRMED, PAID, FAILED

          final statusColors = {
            'PENDING': Colors.orange,
            'CONFIRMED': Colors.blue,
            'PAID': Colors.green,
            'FAILED': Colors.red,
          };

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order ID: ${order['id']}'),
                        const SizedBox(height: 8),
                        Text('Total: €${order['total']}'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Status: '),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColors[status],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (status == 'PAID')
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Your payment was successful! Order confirmed.'),
                ),
              if (status == 'FAILED')
                ElevatedButton(
                  onPressed: () {
                    // Retry payment
                    Navigator.pop(context);
                  },
                  child: const Text('Retry Payment'),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================
// EXAMPLE 5: Backend Order Update Logic
// ============================================

// In payments.service.ts after successful payment:

async handleSuccessfulPayment(orderId: string, paymentMethod: string) {
  // Update order status to CONFIRMED
  const updatedOrder = await this.prisma.order.update({
    where: { id: orderId },
    data: {
      status: 'CONFIRMED', // Payment successful
      paidAt: new Date(),
      paymentMethod: paymentMethod, // CARD, EDINAR, PAYPAL
    },
  });

  // Optional: Send confirmation email
  await this.emailService.sendOrderConfirmation(updatedOrder.clientId, updatedOrder);

  // Optional: Notify restaurant
  await this.notificationService.notifyRestaurant(
    updatedOrder.restaurantId,
    'New order received: #${orderedOrder.id}'
  );

  return updatedOrder;
}

// ============================================
// EXAMPLE 6: Admin Dashboard Payment Analytics
// ============================================

class PaymentAnalyticsScreen extends StatefulWidget {
  @override
  State<PaymentAnalyticsScreen> createState() => _PaymentAnalyticsScreenState();
}

class _PaymentAnalyticsScreenState extends State<PaymentAnalyticsScreen> {
  Future<Map<String, dynamic>> _fetchPaymentStats() async {
    final response = await http.get(
      Uri.parse('http://localhost:3000/admin/payments/stats'),
      headers: {'Authorization': 'Bearer $adminToken'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch payment stats');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Analytics')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchPaymentStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatCard(
                'Total Revenue',
                '€${(stats['totalRevenue'] as num).toStringAsFixed(2)}',
                Icons.money,
                Colors.green,
              ),
              _buildStatCard(
                'Stripe Payments',
                '${stats['stripeCount']}',
                Icons.credit_card,
                Colors.blue,
              ),
              _buildStatCard(
                'e-Dinar Payments',
                '${stats['konnectCount']}',
                Icons.account_balance_wallet,
                Colors.amber,
              ),
              _buildStatCard(
                'PayPal Payments',
                '${stats['paypalCount']}',
                Icons.payment,
                Colors.orange,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
