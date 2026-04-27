import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/payment_service.dart';
import '../../widgets/payment_method_selector.dart';

class OrderCheckoutScreen extends StatefulWidget {
  final String orderId;
  final double totalAmount;
  final Map<String, dynamic> orderDetails;
  final AppPaymentMethod? initialMethod;
  final bool lockMethod;
  final String? clientSecret;

  const OrderCheckoutScreen({
    Key? key,
    required this.orderId,
    required this.totalAmount,
    required this.orderDetails,
    this.initialMethod,
    this.lockMethod = false,
    this.clientSecret,
  }) : super(key: key);

  @override
  State<OrderCheckoutScreen> createState() => _OrderCheckoutScreenState();
}

class _OrderCheckoutScreenState extends State<OrderCheckoutScreen> {
  AppPaymentMethod? _selectedMethod;
  bool _isProcessing = false;
  String? _error;
  String? _userEmail;
  String? _userFirstName;
  String? _userLastName;
  CardFieldInputDetails? _cardDetails;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _selectedMethod = widget.initialMethod;
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString('email') ?? '';
      _userFirstName = prefs.getString('firstName') ?? '';
      _userLastName = prefs.getString('lastName') ?? '';
    });
  }

  Future<void> _processPayment() async {
    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      switch (_selectedMethod) {
        case AppPaymentMethod.card:
          await _processStripePayment();
          break;
        case AppPaymentMethod.eDinar:
          await _processKonnectPayment();
          break;
        case AppPaymentMethod.paypal:
          await _processPayPalPayment();
          break;
        default:
          throw Exception('Unknown payment method');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Error: $_error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// Handle Stripe Payment
  Future<void> _processStripePayment() async {
    try {
      if (kIsWeb) {
        final origin = Uri.base.origin;
        final successUrl = '$origin/';
        final cancelUrl = '$origin/';

        final sessionData = await PaymentService.createStripeCheckoutSession(
          orderId: widget.orderId,
          email: _userEmail,
          successUrl: successUrl,
          cancelUrl: cancelUrl,
        );

        final sessionUrl = sessionData['sessionUrl'] as String?;
        final sessionId = sessionData['sessionId'] as String?;

        if (sessionUrl == null || sessionId == null) {
          throw Exception('Failed to start Stripe checkout');
        }

        await PaymentService.openPaymentUrl(sessionUrl);

        if (!mounted) return;
        _showStripeCheckoutConfirmDialog(sessionId);
        return;
      }
      // Step 1: Create payment intent on backend
      final intentData = await PaymentService.createStripeIntent(
        orderId: widget.orderId,
        amount: widget.totalAmount,
        email: _userEmail,
      );

      final clientSecret = intentData['clientSecret'] as String?;
      final publishableKey = intentData['publishableKey'] as String?;

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Missing Stripe client secret');
      }

      if (publishableKey != null && publishableKey.isNotEmpty) {
        Stripe.publishableKey = publishableKey;
        await Stripe.instance.applySettings();
      }

      if (!mounted) return;

      // Step 2: Collect card details and confirm payment
      final paymentIntentId =
          await _showStripeCardSheet(clientSecret) ??
          _paymentIntentIdFromClientSecret(clientSecret);
      if (paymentIntentId == null || paymentIntentId.isEmpty) {
        throw Exception('Payment cancelled');
      }

      // Step 3: Confirm on backend to update order status
      await PaymentService.confirmStripePayment(
        orderId: widget.orderId,
        paymentIntentId: paymentIntentId,
      );

      _showPaymentSuccessDialog('Card');
    } catch (e) {
      rethrow;
    }
  }

  void _showStripeCheckoutConfirmDialog(String sessionId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Complete Payment'),
        content: const Text(
          'After finishing Stripe checkout, tap the button below to confirm the payment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final confirmation =
                    await PaymentService.confirmStripeCheckoutSession(
                  sessionId: sessionId,
                  orderId: widget.orderId,
                );

                if (!mounted) return;
                Navigator.pop(context);

                if (confirmation['status'] == 'paid') {
                  _showPaymentSuccessDialog('Card');
                } else {
                  _showPaymentErrorDialog('Payment not completed yet.');
                }
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                _showPaymentErrorDialog(e.toString());
              }
            },
            child: const Text('I Paid'),
          ),
        ],
      ),
    );
  }

  /// Handle Konnect (E-Dinar) Payment
  Future<void> _processKonnectPayment() async {
    try {
      // Step 1: Create payment on backend
      final paymentData = await PaymentService.createKonnectPayment(
        orderId: widget.orderId,
        firstName: _userFirstName ?? 'User',
        lastName: _userLastName ?? '',
        email: _userEmail ?? 'user@example.com',
      );

      final paymentUrl = paymentData['paymentUrl'];
      final paymentId = paymentData['paymentId'];

      if (!mounted) return;

      // Step 2: Open payment URL
      await PaymentService.openPaymentUrl(paymentUrl);

      // Step 3: Verify payment after user returns
      if (!mounted) return;
      _showKonnectVerificationDialog(paymentId);
    } catch (e) {
      rethrow;
    }
  }

  /// Handle PayPal Payment
  Future<void> _processPayPalPayment() async {
    try {
      // Step 1: Create PayPal order on backend
      final paymentData = await PaymentService.createPayPalPayment(
        orderId: widget.orderId,
      );

      final approvalUrl = paymentData['approvalUrl'];
      final paypalOrderId = paymentData['paypalOrderId'];

      if (!mounted) return;

      // Step 2: Open PayPal approval URL
      await PaymentService.openPaymentUrl(approvalUrl);

      // Step 3: Let user confirm after returning from PayPal and then capture
      if (!mounted) return;
      _showPayPalCaptureDialog(paypalOrderId);
    } catch (e) {
      rethrow;
    }
  }

  void _showPayPalCaptureDialog(String paypalOrderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Complete PayPal Payment'),
        content: const Text(
          'After you finish PayPal checkout in your browser, tap the button below to confirm and capture payment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final capture = await PaymentService.capturePayPalPayment(
                  paypalOrderId: paypalOrderId,
                  orderId: widget.orderId,
                );

                if (!mounted) return;
                Navigator.pop(context);

                if (capture['isSuccessful'] == true) {
                  _showPaymentSuccessDialog('PayPal');
                } else {
                  _showPaymentErrorDialog('PayPal payment is not completed yet.');
                }
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                _showPaymentErrorDialog(e.toString());
              }
            },
            child: const Text('I Paid'),
          ),
        ],
      ),
    );
  }

  /// Show Stripe card entry and confirm
  Future<String?> _showStripeCardSheet(String clientSecret) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        bool isSubmitting = false;
        String? localError;

        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Card Payment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  CardField(
                    onCardChanged: (details) {
                      _cardDetails = details;
                    },
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      localError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (!(_cardDetails?.complete ?? false)) {
                                setStateSheet(() {
                                  localError =
                                      'Please enter complete card details.';
                                });
                                return;
                              }
                              setStateSheet(() {
                                isSubmitting = true;
                                localError = null;
                              });

                              try {
                                final intent =
                                    await Stripe.instance.confirmPayment(
                                  paymentIntentClientSecret: clientSecret,
                                  data: PaymentMethodParams.card(
                                    paymentMethodData: PaymentMethodData(),
                                  ),
                                );
                                if (!mounted) return;
                                Navigator.pop(context, intent.id);
                              } catch (e) {
                                setStateSheet(() {
                                  localError =
                                      e.toString().replaceAll('Exception: ', '');
                                  isSubmitting = false;
                                });
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Pay Now'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String? _paymentIntentIdFromClientSecret(String clientSecret) {
    final marker = '_secret_';
    final idx = clientSecret.indexOf(marker);
    if (idx <= 0) return null;
    return clientSecret.substring(0, idx);
  }

  /// Show Konnect Verification Dialog
  void _showKonnectVerificationDialog(String paymentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verifying Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Checking your payment status...',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    // Wait a moment for user to complete payment
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        final verification = await PaymentService.verifyKonnectPayment(
          paymentId: paymentId,
          orderId: widget.orderId,
        );

        if (!mounted) return;
        Navigator.pop(context); // Close verification dialog

        if (verification['isSuccessful']) {
          _showPaymentSuccessDialog('e-Dinar');
        } else {
          _showPaymentErrorDialog('Payment was not completed');
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        _showPaymentErrorDialog(e.toString());
      }
    });
  }

  /// Show Payment Success Dialog
  void _showPaymentSuccessDialog(String method) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('✓ Payment Successful'),
        content: Text('Your payment via $method was processed successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Return success
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  /// Show Payment Error Dialog
  void _showPaymentErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✗ Payment Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: const Color(0xFF1F9D7A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order ID:'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.orderId,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:'),
                      Text(
                        '€${widget.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F9D7A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (widget.lockMethod && _selectedMethod != null) ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _methodIcon(_selectedMethod!),
                      color: _methodColor(_selectedMethod!),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _methodLabel(_selectedMethod!),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !_isProcessing ? _processPayment : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F9D7A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Pay Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ] else ...[
              // Payment Method Selector
              PaymentMethodSelector(
                onMethodSelected: (method) {
                  setState(() {
                    _selectedMethod = method;
                    _error = null;
                  });
                },
                onPayNow: _processPayment,
                isLoading: _isProcessing,
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red[900]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _methodLabel(AppPaymentMethod method) {
    switch (method) {
      case AppPaymentMethod.card:
        return 'Pay with Card';
      case AppPaymentMethod.eDinar:
        return 'Pay with e-Dinar / D17';
      case AppPaymentMethod.paypal:
        return 'Pay with PayPal';
    }
  }

  IconData _methodIcon(AppPaymentMethod method) {
    switch (method) {
      case AppPaymentMethod.card:
        return Icons.credit_card;
      case AppPaymentMethod.eDinar:
        return Icons.account_balance_wallet;
      case AppPaymentMethod.paypal:
        return Icons.payment;
    }
  }

  Color _methodColor(AppPaymentMethod method) {
    switch (method) {
      case AppPaymentMethod.card:
        return Colors.blue;
      case AppPaymentMethod.eDinar:
        return const Color(0xFF1F9D7A);
      case AppPaymentMethod.paypal:
        return Colors.amber;
    }
  }
}
