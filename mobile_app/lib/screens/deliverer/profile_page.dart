import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_service.dart';
import '../../api/auth_storage.dart';

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
  List<Map<String, dynamic>> _receivedComplaints = [];
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
        ApiService.get(
          'feedback/received/complaints?limit=5',
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
      final complaints = results[4] is List
          ? (results[4] as List)
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
        _receivedComplaints = complaints;
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
    return method;
  }

  String _payoutDetailsLabel() {
    final details = _profile?['payoutDetails'];
    if (details == null) return 'Not set';
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

  Widget _reviewsSection() {
    if (_receivedReviews.isEmpty) {
      return const Text(
        'No reviews yet.',
        style: TextStyle(color: Color(0xFF6B7280)),
      );
    }

    return Column(
      children: _receivedReviews.map((review) {
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
                Text(comment),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _complaintsSection() {
    if (_receivedComplaints.isEmpty) {
      return const Text(
        'No complaints yet.',
        style: TextStyle(color: Color(0xFF6B7280)),
      );
    }

    return Column(
      children: _receivedComplaints.map((complaint) {
        final reason = (complaint['reason'] ?? '').toString();
        final description = (complaint['description'] ?? '').toString();
        final reporter =
            (complaint['complainantName'] ??
                    complaint['complainantEmail'] ??
                    '')
                .toString();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.report_gmailerrorred,
                    color: Color(0xFFDC2626),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    reporter,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(description),
              ],
            ],
          ),
        );
      }).toList(),
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
    String? selectedMethod = _profile?['payoutMethod']?.toString();
    final detailsController = TextEditingController(
      text: _profile?['payoutDetails']?.toString() ?? '',
    );

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
                          value: 'MOBILE_WALLET',
                          child: Text('Mobile Wallet'),
                        ),
                        DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                      ],
                      onChanged: (value) =>
                          setLocalState(() => selectedMethod = value),
                    ),
                    TextField(
                      controller: detailsController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Details',
                      ),
                      maxLines: 3,
                    ),
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
                          setLocalState(() => saving = true);
                          try {
                            await ApiService.patch(
                              'livreur/onboarding/me/payment',
                              {
                                'payoutMethod': selectedMethod,
                                'payoutDetails': detailsController.text.trim(),
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
    await prefs.remove('jwt');
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
        _sectionCard(
          title: 'Recent Complaints',
          children: [_complaintsSection()],
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
