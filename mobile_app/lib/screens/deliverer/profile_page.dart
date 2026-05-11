import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_service.dart';
import '../../api/auth_storage.dart';
import 'transactions.dart';

class DelivererProfilePage extends StatefulWidget {
  const DelivererProfilePage({super.key});

  @override
  State<DelivererProfilePage> createState() => _DelivererProfilePageState();
}

class _DelivererProfilePageState extends State<DelivererProfilePage> {
  Map<String, dynamic>? _authUser;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _receivedReviews = [];
  bool _loading = true;
  bool _savingSettings = false;
  String? _error;

  bool _newOffers = true;
  bool _orderUpdates = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final jwt = await getJwt();
      if (jwt == null) {
        throw Exception('Missing session token');
      }

      final results = await Future.wait([
        ApiService.get('auth/me', headers: {'Authorization': 'Bearer $jwt'}),
        ApiService.get(
          'livreur/onboarding/me',
          headers: {'Authorization': 'Bearer $jwt'},
        ),
        ApiService.get(
          'orders/deliverer/history',
          headers: {'Authorization': 'Bearer $jwt'},
        ),
        ApiService.get(
          'feedback/received/reviews?limit=5',
          headers: {'Authorization': 'Bearer $jwt'},
        ),
      ]);

      final authUser = results[0] as Map<String, dynamic>;
      final profile = results[1] as Map<String, dynamic>;
      final history = results[2] is List
          ? (results[2] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];
      final reviews = results[3] is List
          ? (results[3] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : <Map<String, dynamic>>[];

      final notifications =
          profile['notificationPreferences'] as Map<String, dynamic>?;

      if (!mounted) return;
      setState(() {
        _authUser = authUser;
        _profile = profile;
        _history = history;
        _receivedReviews = reviews;
        _newOffers = notifications?['newOffers'] != false;
        _orderUpdates = notifications?['orderUpdates'] != false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load profile: $e';
        _loading = false;
      });
    }
  }

  String _monthYear(dynamic value) {
    if (value == null) return 'Jan 2024';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return 'Jan 2024';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.year}';
  }

  String _valueOf(String key, {String fallback = '-'}) {
    final value = _profile?[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isNotEmpty ? text : fallback;
  }

  double _rating() {
    final value = _profile?['avgRating'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 4.8;
  }

  String _payoutMethodLabel() {
    final method = _profile?['payoutMethod']?.toString();
    if (method == null || method.isEmpty) return 'Not set';
    switch (method) {
      case 'BANK_TRANSFER':
        return 'Bank Transfer';
      case 'PAYPAL':
        return 'PayPal';
      default:
        return method;
    }
  }

  String _payoutDetailsLabel() {
    final details = _profile?['payoutDetails'];
    if (details == null) return 'Not set';
    if (details is Map) {
      // Check if PayPal
      final paypalEmail = details['paypalEmail']?.toString() ?? '';
      if (paypalEmail.isNotEmpty) {
        return paypalEmail;
      }
      // Bank transfer
      final accountHolder = details['accountHolder']?.toString() ?? '';
      final bankName = details['bankName']?.toString() ?? '';
      final iban = details['iban']?.toString() ?? '';
      final maskedIban = iban.length >= 4
          ? '•••• ${iban.substring(iban.length - 4)}'
          : '••••';
      if (accountHolder.isNotEmpty) {
        return '$accountHolder\n$bankName · $maskedIban';
      }
      return bankName.isNotEmpty ? '$bankName · $maskedIban' : maskedIban;
    }
    final text = details.toString().trim();
    return text.isEmpty ? 'Not set' : text;
  }

  Widget _buildTopCard() {
    final name = _valueOf('fullName', fallback: 'Deliverer');
    final since = _monthYear(
      _profile?['submittedAt'] ?? _profile?['termsAcceptedAt'],
    );
    final deliveryCount = _history.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E0D7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5F3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 42,
              color: Color(0xFF26A69A),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Delivery Partner since $since',
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    color: Color(0xFF5E6D66),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 24,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _rating().toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF151515),
                      ),
                    ),
                    Text(
                      ' ($deliveryCount deliveries)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5E6D66),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    Widget? action,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E0D7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                ),
              ),
              const Spacer(),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF141414),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFCFBF8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4DDCF)),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 15, color: Color(0xFF171717)),
          ),
        ),
      ],
    );
  }

  void _showAllReviewsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reviews, color: Color(0xFF26A69A), size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'All Reviews',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Reviews list
              Flexible(
                child: _receivedReviews.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No reviews yet.',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: _receivedReviews.map((review) {
                            final rating = review['rating']?.toString() ?? '0';
                            final comment = (review['comment'] ?? '').toString();
                            final reviewer = (review['reviewerName'] ??
                                    review['reviewerEmail'] ??
                                    'Anonymous')
                                .toString();
                            final date = review['createdAt'] != null
                                ? DateTime.tryParse(review['createdAt'].toString())
                                : null;
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCFBF8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE4DDCF)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: Color(0xFFF59E0B), size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        rating,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                      const Spacer(),
                                      Text(
                                        reviewer,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (date != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${date.day}/${date.month}/${date.year}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                    ),
                                  ],
                                  if (comment.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      comment,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
              ),
              // Footer with count
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, size: 16, color: Colors.amber.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '${_receivedReviews.length} review${_receivedReviews.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reviewsSection() {
    if (_receivedReviews.isEmpty) {
      return const Text(
        'No reviews yet.',
        style: TextStyle(color: Color(0xFF6B7280)),
      );
    }

    final previewReviews = _receivedReviews.take(2).toList();

    return Column(
      children: [
        ...previewReviews.map((review) {
          final rating = review['rating']?.toString() ?? '0';
          final comment = (review['comment'] ?? '').toString();
          final reviewer =
              (review['reviewerName'] ?? review['reviewerEmail'] ?? '')
                  .toString();
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFBF8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4DDCF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      rating,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      reviewer,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    comment,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          );
        }),
        if (_receivedReviews.length > 2) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAllReviewsDialog,
              icon: const Icon(Icons.open_in_full, size: 18),
              label: Text('View all ${_receivedReviews.length} reviews'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF26A69A),
                side: const BorderSide(color: Color(0xFF26A69A)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openProfileDialog() async {
    final currentEmail = _authUser?['email']?.toString() ?? '';
    final emailController = TextEditingController(text: currentEmail);
    final nameController = TextEditingController(
      text: _valueOf('fullName', fallback: ''),
    );
    final phoneController = TextEditingController(
      text: _valueOf('phone', fallback: ''),
    );
    final vehicleController = TextEditingController(
      text: _valueOf('vehicleType', fallback: ''),
    );
    final zoneController = TextEditingController(
      text: _valueOf('zone', fallback: ''),
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            InputDecoration fieldDecoration(String label) => InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              isDense: true,
            );

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: fieldDecoration('Email'),
                      ),
                      if ((_authUser?['pendingEmail']?.toString().isNotEmpty ??
                          false)) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Pending verification: ${_authUser?['pendingEmail']}',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: fieldDecoration('Full Name'),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneController,
                        decoration: fieldDecoration('Phone'),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: vehicleController,
                        decoration: fieldDecoration('Vehicle Type'),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: zoneController,
                        decoration: fieldDecoration('Zone'),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  final newEmail = emailController.text.trim();
                                  if (newEmail.isEmpty ||
                                      !newEmail.contains('@')) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Enter a valid email address.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  setLocalState(() => saving = true);
                                  try {
                                    await ApiService.patch(
                                      'livreur/onboarding/me/profile',
                                      {
                                        'fullName': nameController.text.trim(),
                                        'phone': phoneController.text.trim(),
                                        'vehicleType': vehicleController.text
                                            .trim(),
                                        'zone': zoneController.text.trim(),
                                      },
                                    );

                                    var emailChangeRequested = false;
                                    if (newEmail.toLowerCase() !=
                                        currentEmail.toLowerCase()) {
                                      await ApiService.post(
                                        'auth/request-email-change',
                                        {'email': newEmail},
                                      );
                                      emailChangeRequested = true;
                                    }

                                    if (emailChangeRequested && mounted) {
                                      setState(() {
                                        _authUser = {
                                          ...?_authUser,
                                          'pendingEmail': newEmail,
                                        };
                                      });
                                    }

                                    if (!mounted) return;
                                    Navigator.of(dialogContext).pop();
                                    await _loadProfile();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          emailChangeRequested
                                              ? 'Profile updated. Verification email sent for your new address.'
                                              : 'Profile updated',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    setLocalState(() => saving = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Profile update failed: $e',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16807A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openPaymentDialog() async {
    // Default to BANK_TRANSFER if null or invalid value
    final validMethods = ['BANK_TRANSFER', 'PAYPAL'];
    final rawMethod = _profile?['payoutMethod']?.toString();
    String? selectedMethod = validMethods.contains(rawMethod) ? rawMethod : 'BANK_TRANSFER';
    final accountHolderController = TextEditingController();
    final bankNameController = TextEditingController();
    final ibanController = TextEditingController();
    final paypalEmailController = TextEditingController();

    // Parse existing payout details if available
    final existingDetails = _profile?['payoutDetails'];
    if (existingDetails is Map) {
      accountHolderController.text = existingDetails['accountHolder']?.toString() ?? '';
      bankNameController.text = existingDetails['bankName']?.toString() ?? '';
      ibanController.text = existingDetails['iban']?.toString() ?? '';
      paypalEmailController.text = existingDetails['paypalEmail']?.toString() ?? '';
    } else if (existingDetails is String && existingDetails.isNotEmpty) {
      accountHolderController.text = existingDetails;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('Payment Info'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'BANK_TRANSFER',
                          child: Text('Bank Transfer'),
                        ),
                        DropdownMenuItem(
                          value: 'PAYPAL',
                          child: Text('PayPal'),
                        ),
                      ],
                      onChanged: (value) =>
                          setLocalState(() => selectedMethod = value),
                    ),
                    const SizedBox(height: 16),
                    if (selectedMethod == 'BANK_TRANSFER') ...[
                      TextField(
                        controller: accountHolderController,
                        decoration: const InputDecoration(
                          labelText: 'Account Holder Name',
                          hintText: 'Full name on account',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bankNameController,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name',
                          hintText: 'e.g. Attijari Bank',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ibanController,
                        decoration: const InputDecoration(
                          labelText: 'IBAN / Account Number',
                          hintText: 'TN59 1234 5678 9012 3456 7890 1234',
                        ),
                        keyboardType: TextInputType.text,
                      ),
                    ],
                    if (selectedMethod == 'PAYPAL') ...[
                      TextField(
                        controller: paypalEmailController,
                        decoration: const InputDecoration(
                          labelText: 'PayPal Email',
                          hintText: 'email@example.com',
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          // Validate fields
                          if (selectedMethod == 'BANK_TRANSFER') {
                            if (accountHolderController.text.trim().isEmpty ||
                                ibanController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please fill account holder name and IBAN.'),
                                ),
                              );
                              return;
                            }
                          } else if (selectedMethod == 'PAYPAL') {
                            if (paypalEmailController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please fill PayPal email.'),
                                ),
                              );
                              return;
                            }
                          }

                          setLocalState(() => saving = true);
                          try {
                            final paymentDetails = selectedMethod == 'PAYPAL'
                                ? {'paypalEmail': paypalEmailController.text.trim()}
                                : {
                                    'accountHolder': accountHolderController.text.trim(),
                                    'bankName': bankNameController.text.trim(),
                                    'iban': ibanController.text.trim().replaceAll(' ', ''),
                                  };
                            await ApiService.patch(
                              'livreur/onboarding/me/payment',
                              {
                                'payoutMethod': selectedMethod,
                                'payoutDetails': paymentDetails,
                              },
                            );
                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                            await _loadProfile();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Payment info updated'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setLocalState(() => saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Payment update failed: $e'),
                              ),
                            );
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveNotifications() async {
    setState(() => _savingSettings = true);
    try {
      await ApiService.patch('livreur/onboarding/notifications', {
        'newOffers': _newOffers,
        'orderUpdates': _orderUpdates,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save notifications: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Future<void> _openChangePasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final passwordRegex = RegExp(
      r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
    );

    bool isValidPassword(String value) => passwordRegex.hasMatch(value);

    String extractBackendMessage(dynamic error) {
      final str = error.toString();
      final match = RegExp(r'\{.*\}').firstMatch(str);
      if (match != null) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(match.group(0)!));
          if (map['message'] is String) return map['message'];
          if (map['message'] is List && map['message'].isNotEmpty) {
            return map['message'][0].toString();
          }
          return map['error']?.toString() ?? str;
        } catch (_) {}
      }
      return str;
    }

    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                      ),
                    ),
                    TextField(
                      controller: newController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                      ),
                    ),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMsg!,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final currPw = currentController.text.trim();
                          final newPw = newController.text.trim();
                          final confPw = confirmController.text.trim();

                          if (currPw.isEmpty) {
                            setLocalState(
                              () => errorMsg = 'Current password is required.',
                            );
                            return;
                          }
                          if (newPw.isEmpty || confPw.isEmpty) {
                            setLocalState(
                              () => errorMsg =
                                  'Fill in new password and confirmation.',
                            );
                            return;
                          }
                          if (newPw != confPw) {
                            setLocalState(
                              () => errorMsg = 'Passwords do not match.',
                            );
                            return;
                          }
                          if (!isValidPassword(newPw)) {
                            setLocalState(
                              () => errorMsg =
                                  'Password must be at least 8 characters and include 1 uppercase, 1 lowercase, 1 number, and 1 special character.',
                            );
                            return;
                          }

                          setLocalState(() => saving = true);
                          try {
                            await ApiService.patch('auth/change-password', {
                              'oldPassword': currPw,
                              'newPassword': newPw,
                            });
                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password changed!'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setLocalState(() => saving = false);
                            final errMsg = extractBackendMessage(e);
                            if (errMsg.contains(
                              'Current password is incorrect',
                            )) {
                              setLocalState(() {
                                errorMsg =
                                    'Your current password is incorrect.';
                              });
                            } else {
                              setLocalState(() => errorMsg = errMsg);
                            }
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('Delete account?'),
          content: const Text(
            'This will permanently delete your deliverer account and related data.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _savingSettings = true);
    try {
      final jwt = await getJwt();
      if (jwt == null) throw Exception('Missing session token');

      await ApiService.delete(
        'livreur/onboarding/me',
        headers: {'Authorization': 'Bearer $jwt'},
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt');

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/signin/deliverer', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();

    // Revoke device token before logout (best-effort)
    final token = prefs.getString('fcmRegisteredToken');
    if (token != null && token.isNotEmpty) {
      try {
        final jwt = await getJwt();
        if (jwt != null && jwt.isNotEmpty) {
          await ApiService.delete(
            'notifications/me/device-tokens?token=$token',
            headers: {'Authorization': 'Bearer $jwt'},
          );
        }
      } catch (_) {
        // Best-effort token revocation; don't block logout if it fails
      }
    }

    await prefs.remove('jwt');
    await prefs.remove('fcmRegisteredToken');
    await prefs.remove('fcmRegisteredPlatform');
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/signin/deliverer', (route) => false);
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        const Text(
          'My Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 16),
        _buildTopCard(),
        const SizedBox(height: 18),
        _sectionCard(
          title: 'Profile Info',
          action: TextButton.icon(
            onPressed: _openProfileDialog,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit Profile'),
          ),
          children: [
            _infoField('Email', _authUser?['email']?.toString() ?? '-'),
            if ((_authUser?['pendingEmail']?.toString().isNotEmpty ??
                false)) ...[
              const SizedBox(height: 16),
              _infoField(
                'Pending Email',
                _authUser?['pendingEmail']?.toString() ?? '-',
              ),
            ],
            const SizedBox(height: 16),
            _infoField('Phone', _valueOf('phone')),
            const SizedBox(height: 16),
            _infoField('Vehicle Type', _valueOf('vehicleType')),
            const SizedBox(height: 16),
            _infoField('Zone', _valueOf('zone')),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Payment Info',
          action: TextButton.icon(
            onPressed: _openPaymentDialog,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit Payment'),
          ),
          children: [
            _infoField('Payment Method', _payoutMethodLabel()),
            const SizedBox(height: 16),
            _infoField('Payment Details', _payoutDetailsLabel()),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(title: 'Recent Reviews', children: [_reviewsSection()]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DelivererTransactionsPage(),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('View All Transactions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF28C76F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Settings',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('New offers'),
              subtitle: const Text(
                'Get notified when new delivery requests appear',
              ),
              value: _newOffers,
              onChanged: _savingSettings
                  ? null
                  : (value) async {
                      setState(() => _newOffers = value);
                      await _saveNotifications();
                    },
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Order updates'),
              subtitle: const Text('Receive delivery status updates'),
              value: _orderUpdates,
              onChanged: _savingSettings
                  ? null
                  : (value) async {
                      setState(() => _orderUpdates = value);
                      await _saveNotifications();
                    },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Account',
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _savingSettings ? null : _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openChangePasswordDialog,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Change Password'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _savingSettings ? null : _deleteAccount,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Delete Account',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFF0CACA)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F5F1),
      child: RefreshIndicator(
        onRefresh: _loadProfile,
        color: const Color(0xFF26A69A),
        child: _loading
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 160),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              )
            : _buildContent(),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) {
      text = text.substring(0, 16);
    }
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i != text.length - 1) {
        buffer.write(' ');
      }
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll('/', '');
    if (text.length > 4) {
      text = text.substring(0, 4);
    }
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && i != text.length - 1) {
        buffer.write('/');
      }
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
