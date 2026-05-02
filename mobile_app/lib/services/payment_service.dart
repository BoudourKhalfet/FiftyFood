import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/api.dart';
import 'package:flutter/foundation.dart';
class PaymentService {

  /// Create Stripe payment intent (no order created yet)
  static Future<Map<String, dynamic>> createStripeIntent({
    required String restaurantId,
    required String offerId,
    required Map<String, dynamic> items,
    required double total,
    String? collectionMethod,
    String? deliveryAddress,
    String? deliveryPhone,
    double? deliveryFee,
    String? email,
    String? orderId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');

      if (jwt == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse(apiUrl('payments/create-intent')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({
          'restaurantId': restaurantId,
          'offerId': offerId,
          'items': items,
          'total': total,
          if (collectionMethod != null) 'collectionMethod': collectionMethod,
          if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
          if (deliveryPhone != null) 'deliveryPhone': deliveryPhone,
          if (deliveryFee != null) 'deliveryFee': deliveryFee,
          if (email != null && email.isNotEmpty) 'email': email,
          if (orderId != null) 'orderId': orderId,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to create payment intent: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Stripe payment error: $e');
    }
  }

  /// Create Stripe Checkout session (web) — no order created yet
  static Future<Map<String, dynamic>> createStripeCheckoutSession({
    required String restaurantId,
    required String offerId,
    required Map<String, dynamic> items,
    required double total,
    String? collectionMethod,
    String? deliveryAddress,
    String? deliveryPhone,
    double? deliveryFee,
    String? email,
    String? successUrl,
    String? cancelUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');

      if (jwt == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse(apiUrl('payments/stripe/checkout')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({
          'restaurantId': restaurantId,
          'offerId': offerId,
          'items': items,
          'total': total,
          if (collectionMethod != null) 'collectionMethod': collectionMethod,
          if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
          if (deliveryPhone != null) 'deliveryPhone': deliveryPhone,
          if (deliveryFee != null) 'deliveryFee': deliveryFee,
          if (email != null && email.isNotEmpty) 'email': email,
          if (successUrl != null) 'successUrl': successUrl,
          if (cancelUrl != null) 'cancelUrl': cancelUrl,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to create Stripe checkout session: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Stripe checkout error: $e');
    }
  }

  /// Confirm Stripe Checkout session (web)
  static Future<Map<String, dynamic>> confirmStripeCheckoutSession({
    required String sessionId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');

      if (jwt == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse(apiUrl('payments/stripe/checkout/$sessionId/confirm')),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to confirm Stripe checkout: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Stripe checkout confirmation error: $e');
    }
  }

  /// Create PayPal payment
  static Future<Map<String, dynamic>> createPayPalPayment({
    required String orderId,
    String? returnUrl,
    String? cancelUrl,
    double? amount,
  }) async {
    try {
      debugPrint('PayPal: Starting payment creation');
      
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');

      if (jwt == null) {
        debugPrint('PayPal: No authentication token found');
        throw Exception('No authentication token found');
      }

      final url = apiUrl('paypal/create-order');
      final requestBody = {
        'orderId': orderId,
        'returnUrl': returnUrl,
        'cancelUrl': cancelUrl,
        'amount': amount,
      };
      
      debugPrint('PayPal: Request URL: $url');
      debugPrint('PayPal: Request body: $requestBody');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('PayPal: Response status: ${response.statusCode}');
      debugPrint('PayPal: Response body: ${response.body}');

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to create PayPal payment: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('PayPal: Error occurred: $e');
      throw Exception('PayPal payment error: $e');
    }
  }

  /// Capture PayPal payment
  static Future<Map<String, dynamic>> capturePayPalPayment({
    required String paypalOrderId,
    required String orderId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');

      if (jwt == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse(apiUrl('paypal/capture-order')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({
          'paypalOrderId': paypalOrderId,
          'orderId': orderId,
        }),
      );
        if (response.statusCode == 401) {
          throw Exception('Unauthorized: your session expired. Please sign in again.');
        }


      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to capture PayPal payment: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('PayPal capture error: $e');
    }
  }

  /// Confirm Stripe payment (mobile fallback — webhook is source of truth)
  static Future<Map<String, dynamic>> confirmStripePayment({
    required String paymentIntentId,
    String? orderId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');

      if (jwt == null) {
        throw Exception('No authentication token found');
      }

      final resolvedOrderId = orderId ?? 'pending';
      final response = await http.post(
        Uri.parse(apiUrl('payments/confirm-stripe/$resolvedOrderId/$paymentIntentId')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to confirm Stripe payment: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Stripe confirmation error: $e');
    }
  }

  /// Update order status after successful payment
  static Future<Map<String, dynamic>> confirmOrderPayment({
    required String orderId,
    required String paymentMethod,
    Map<String, dynamic>? paymentDetails,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');

      if (jwt == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse(apiUrl('orders/$orderId/confirm-payment')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({
          'paymentMethod': paymentMethod,
          'paymentDetails': paymentDetails ?? {},
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to confirm order payment: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Order confirmation error: $e');
    }
  }

  /// Open URL (for Konnect and PayPal redirects)
  static Future<void> openPaymentUrl(String url) async {
  try {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );
    } else {
      throw Exception('Could not launch payment URL');
    }
  } catch (e) {
    throw Exception('URL launch error: $e');
  }
}
}
