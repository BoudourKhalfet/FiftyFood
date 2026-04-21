import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/api.dart';

class PaymentService {

  /// Create Stripe payment intent
  static Future<Map<String, dynamic>> createStripeIntent({
    required String orderId,
    required double amount,
    String? email,
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
          'orderId': orderId,
          'amount': amount,
          'email': email,
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

  /// Create Stripe Checkout session (web)
  static Future<Map<String, dynamic>> createStripeCheckoutSession({
    required String orderId,
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
          'orderId': orderId,
          'email': email,
          'successUrl': successUrl,
          'cancelUrl': cancelUrl,
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
    required String orderId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          apiUrl('payments/stripe/checkout/$sessionId/confirm/$orderId'),
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to confirm Stripe checkout: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Stripe checkout confirmation error: $e');
    }
  }

  /// Create Konnect (E-Dinar) payment
  static Future<Map<String, dynamic>> createKonnectPayment({
    required String orderId,
    required String firstName,
    required String lastName,
    required String email,
    String? phone,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');

      if (jwt == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse(apiUrl('payments/konnect')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({
          'orderId': orderId,
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phone': phone,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to create Konnect payment: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Konnect payment error: $e');
    }
  }

  /// Create PayPal payment
  static Future<Map<String, dynamic>> createPayPalPayment({
    required String orderId,
    String? returnUrl,
    String? cancelUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');

      if (jwt == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse(apiUrl('paypal/create-order')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({
          'orderId': orderId,
          'returnUrl': returnUrl,
          'cancelUrl': cancelUrl,
        }),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to create PayPal payment: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('PayPal payment error: $e');
    }
  }

  /// Verify Konnect payment status
  static Future<Map<String, dynamic>> verifyKonnectPayment({
    required String paymentId,
    required String orderId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(apiUrl('payments/konnect/$paymentId/verify/$orderId')),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to verify Konnect payment: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Konnect verification error: $e');
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

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to capture PayPal payment: ${response.body}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('PayPal capture error: $e');
    }
  }

  /// Confirm Stripe payment
  static Future<Map<String, dynamic>> confirmStripePayment({
    required String orderId,
    required String paymentIntentId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');

      if (jwt == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse(
          apiUrl('payments/confirm-stripe/$orderId/$paymentIntentId'),
        ),
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

  /// Open URL (for Konnect and PayPal redirects)
  static Future<void> openPaymentUrl(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Could not launch payment URL');
      }
    } catch (e) {
      throw Exception('URL launch error: $e');
    }
  }
}
