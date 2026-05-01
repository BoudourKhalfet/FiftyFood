import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_links/app_links.dart';
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
  
  // Deep link handling for PayPal
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  bool _isWaitingForPayPal = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _selectedMethod = widget.initialMethod;
    _initDeepLinks();
    _checkForPendingPayment();
  }
  
  void _initDeepLinks() {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      print('Deep link error: $err');
    });
  }
  
  void _handleDeepLink(Uri uri) async {
    print('Checkout received deep link: $uri');
    final host = uri.host;
    final orderId = uri.queryParameters['orderId'];
    
    if (orderId != widget.orderId) return; // Not our order
    
    if (host == 'payment-success') {
      _verifyPayPalPayment();
    } else if (host == 'payment-error') {
      setState(() {
        _isWaitingForPayPal = false;
        _isProcessing = false;
        _error = 'Payment was cancelled or failed.';
      });
    }
  }
  
  Future<void> _checkForPendingPayment() async {
    // Check if we were redirected back from PayPal
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(uri);
      }
    } catch (e) {
      print('Error checking initial link: $e');
    }
  }
  
  Future<void> _verifyPayPalPayment() async {
    setState(() {
      _isWaitingForPayPal = false;
      _isProcessing = true;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final paypalOrderId = prefs.getString('pendingPayPalOrderId');
      
      if (paypalOrderId != null) {
        final capture = await PaymentService.capturePayPalPayment(
          paypalOrderId: paypalOrderId,
          orderId: widget.orderId,
        );
        
        if (capture['success'] == true || capture['status'] == 'COMPLETED') {
          await prefs.remove('pendingPayPalOrderId');
          await prefs.remove('pendingOrderId');
          _showPaymentSuccess();
        } else {
          setState(() {
            _isProcessing = false;
            _error = 'Payment verification failed.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'Error: $e';
      });
    }
  }
  
  void _showPaymentSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('Payment Successful!'),
        content: const Text('Your order has been confirmed.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(true); // Return to previous screen with success
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3D9176)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
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

  /// Show dialog when returning from PayPal
  void _showPayPalReturnDialog(String paypalOrderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.payment, color: Color(0xFF0070BA)),
              SizedBox(width: 8),
              Text('PayPal'),
            ],
          ),
          content: const Text(
            'Did you complete the payment in PayPal?',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('No, Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _capturePayPalAndShowResult(paypalOrderId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0070BA),
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Verify Payment'),
            ),
          ],
        );
      },
    );
  }

  /// Capture PayPal and show result
  Future<void> _capturePayPalAndShowResult(String paypalOrderId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Verifying payment...'),
          ],
        ),
      ),
    );

    try {
      final capture = await PaymentService.capturePayPalPayment(
        paypalOrderId: paypalOrderId,
        orderId: widget.orderId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (capture['isSuccessful'] == true) {
        _showPaymentSuccessDialog('PayPal');
      } else if (capture['needsApproval'] == true) {
        _showPaymentErrorDialog('Payment not yet approved. Please complete payment in PayPal first.');
      } else {
        _showPaymentErrorDialog('PayPal payment could not be completed.');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      final errorText = e.toString();
      if (errorText.contains('Unauthorized') || errorText.contains('session expired')) {
        _showSessionExpiredDialog();
      } else {
        _showPaymentErrorDialog('Payment verification failed: $errorText');
      }
    }
  }

  /// Handle PayPal Payment with deep links
  Future<void> _processPayPalPayment() async {
    try {
      final paymentData = await PaymentService.createPayPalPayment(
        orderId: widget.orderId,
        returnUrl: 'fiftyfood://payment-success?orderId=${widget.orderId}',
        cancelUrl: 'fiftyfood://payment-error?orderId=${widget.orderId}',
      );

      final approvalUrl = paymentData['approvalUrl'];
      final paypalOrderId = paymentData['paypalOrderId'];

      // Store order info for when we return from PayPal
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pendingOrderId', widget.orderId);
      await prefs.setString('pendingPayPalOrderId', paypalOrderId);

      if (!mounted) return;

      // Show waiting state - deep link will handle the return
      setState(() {
        _isWaitingForPayPal = true;
      });

      // Open PayPal in browser
      await PaymentService.openPaymentUrl(approvalUrl);

      // The deep link handler will automatically process the result when user returns
    } catch (e) {
      setState(() {
        _isWaitingForPayPal = false;
      });
      rethrow;
    }
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

  /// Show Session Expired Dialog
  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text(
          'Your login session has expired. Please sign in again to complete your payment.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Clear JWT and redirect to login
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('jwt');
              if (!mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/signin',
                (route) => false,
              );
            },
            child: const Text('Sign In Again'),
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
      body: Stack(
        children: [
          SingleChildScrollView(
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
      // Waiting for PayPal overlay
      if (_isWaitingForPayPal)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text(
                      'Complete payment in PayPal...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'ll return here automatically',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isWaitingForPayPal = false;
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
