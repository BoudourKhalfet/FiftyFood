import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/api_service.dart';

Widget buildPickupTimeDropdown({
  required String value,
  required void Function(String) onChanged,
  required BuildContext context,
}) {
  final now = TimeOfDay.now();
  final List<String> baseOptions = [
    '11:00 - 12:00',
    '12:00 - 13:00',
    '13:00 - 14:00',
    '17:00 - 18:00',
    '18:00 - 19:00',
    '19:00 - 20:00',
    '20:00 - 21:00',
    'Custom...',
  ];

  // If current value is a custom time range and not already in options, add it at the top!
  List<String> options = List.from(baseOptions);
  if (value.isNotEmpty &&
      value != 'Custom...' &&
      !baseOptions.contains(value)) {
    options = [value, ...baseOptions];
  }

  bool isPast(String slot) {
    if (slot == 'Custom...') return false;
    final endStr = slot.split('-').last.trim();
    final h = int.parse(endStr.split(':')[0]);
    final m = int.parse(endStr.split(':')[1]);
    final end = TimeOfDay(hour: h, minute: m);
    if (end.hour < now.hour) return true;
    if (end.hour == now.hour && end.minute <= now.minute) return true;
    return false;
  }

  return DropdownButtonFormField<String>(
    value: value.isEmpty ? null : value,
    decoration: InputDecoration(
      hintText: 'Select time',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
    ),
    items: options.map((v) {
      final past = isPast(v);
      return DropdownMenuItem<String>(
        value: v,
        enabled: !past || v == value, // always enable the selected custom!
        child: past && v != value
            ? Text(v, style: const TextStyle(color: Colors.grey))
            : Text(v),
      );
    }).toList(),
    onChanged: (v) async {
      if (v == 'Custom...') {
        TimeOfDay? from = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
          helpText: 'Pickup From',
        );
        if (from == null) return;
        TimeOfDay? to = await showTimePicker(
          context: context,
          initialTime: from.replacing(hour: (from.hour + 1) % 24),
          helpText: 'Pickup To',
        );
        if (to == null) return;
        String twoDigits(int n) => n.toString().padLeft(2, '0');
        final custom =
            "${twoDigits(from.hour)}:${twoDigits(from.minute)} - ${twoDigits(to.hour)}:${twoDigits(to.minute)}";
        onChanged(custom);
      } else if (v != null && (!isPast(v) || v == value)) {
        onChanged(v);
      }
    },
  );
}

class PartnerDashboardPage extends StatefulWidget {
  const PartnerDashboardPage({Key? key}) : super(key: key);

  @override
  State<PartnerDashboardPage> createState() => _PartnerDashboardPageState();
}

class _PartnerDashboardPageState extends State<PartnerDashboardPage> {
  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _restaurantInfo['name']);
    final emailController = TextEditingController(
      text: _restaurantInfo['email'],
    );
    final phoneController = TextEditingController(
      text: _restaurantInfo['phone'],
    );
    final addressController = TextEditingController(
      text: _restaurantInfo['address'],
    );
    final cityController = TextEditingController(text: _restaurantInfo['city']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Restaurant Name',
                  ),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Update profile via API
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final jwt = prefs.getString('jwt');
                  if (jwt == null) return;

                  await ApiService.patch(
                    'auth/me/profile',
                    {
                      'restaurantName': nameController.text,
                      'address': addressController.text,
                      'city': cityController.text,
                      'phone': phoneController.text,
                    },
                    headers: {'Authorization': 'Bearer $jwt'},
                  );

                  setState(() {
                    _restaurantInfo['name'] = nameController.text;
                    _restaurantInfo['email'] = emailController.text;
                    _restaurantInfo['phone'] = phoneController.text;
                    _restaurantInfo['address'] = addressController.text;
                    _restaurantInfo['city'] = cityController.text;
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated!'),
                        backgroundColor: Color(0xFF1F9D7A),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating profile: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F9D7A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  int _activeTab = 0; // 0: offers, 1: orders, 2: stats, 3: profile
  bool _showCreateOffer = false;
  bool _showQrScanner = false;
  bool _showModeFete = false;
  bool _modeFeteActive = false;
  String _modeFeteRemaining = '';
  Timer? _modeFeteTimer;
  DateTime? _modeFeteEndsAt;

  // New Offer Form
  String _offerDescription = '';
  String _originalPrice = '';
  String _discountedPrice = '';
  String _quantity = '';
  String _pickupTime = '';
  String _visibility = 'identified';
  bool _deliveryAvailable = false;

  // Image Upload
  String? _offerImagePreview;
  String? _offerImageBase64; // base64 data URL for AI verification
  bool _aiVerifying = false;
  Map<String, dynamic>? _aiResult;
  // Removed _photoTakenAt and all EXIF/photo date logic

  // Mode Fête Form
  String _modeFeteDuration = '60';
  String _modeFeteMessage = '';

  // QR Scanner
  String _qrInput = '';
  Map<String, dynamic>? _qrResult;

  // Offers Data (from backend)
  List<Map<String, dynamic>> _offers = [];
  bool _offersLoading = false;

  final Map<String, dynamic> _stats = {
    'totalSales': 0,
    'mealsSaved': 0,
    'avgRating': 0,
    'activeOffers': 0,
  };

  final List<Map<String, dynamic>> _orders = [];

  Map<String, dynamic> _restaurantInfo = {
    'name': 'Restaurant Name',
    'address': 'Address not set',
    'city': 'City not set',
    'phone': '+1 (000) 000-0000',
    'email': 'email@example.com',
    'trustScore': 0,
    'documentsVerified': false,
  };

  @override
  void initState() {
    super.initState();
    _fetchRestaurantProfile();
    _fetchOffers();
  }

  @override
  void dispose() {
    _modeFeteTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRestaurantProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) return;
      final response = await ApiService.get(
        'auth/me',
        headers: {'Authorization': 'Bearer $jwt'},
      );
      final restaurant = response['restaurantProfile'];
      if (restaurant != null && mounted) {
        setState(() {
          _restaurantInfo = {
            'name': restaurant['restaurantName'] ?? 'Restaurant Name',
            'address': restaurant['address'] ?? 'Address not set',
            'city': restaurant['city'] ?? 'City not set',
            'phone': restaurant['phone'] ?? '+1 (000) 000-0000',
            'email': response['email'] ?? 'email@example.com',
            'trustScore': _restaurantInfo['trustScore'],
            'documentsVerified': _restaurantInfo['documentsVerified'],
          };
        });
      }
    } catch (e) {
      debugPrint('Error fetching restaurant profile: $e');
    }
  }

  void _startModeFete() {
    final duration = int.parse(_modeFeteDuration);
    final endsAt = DateTime.now().add(Duration(minutes: duration));

    setState(() {
      _modeFeteActive = true;
      _modeFeteEndsAt = endsAt;
      _showModeFete = false;
      _modeFeteDuration = '60';
      _modeFeteMessage = '';
    });

    _modeFeteTimer?.cancel();
    _modeFeteTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_modeFeteActive) {
        timer.cancel();
        return;
      }

      final remaining = _modeFeteEndsAt!.difference(DateTime.now());
      if (remaining.isNegative) {
        setState(() {
          _modeFeteActive = false;
          _modeFeteRemaining = '';
        });
        timer.cancel();
      } else {
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes % 60;
        final seconds = remaining.inSeconds % 60;

        if (hours > 0) {
          _modeFeteRemaining =
              '$hours h ${minutes.toString().padLeft(2, '0')} m';
        } else {
          _modeFeteRemaining =
              '$minutes m ${seconds.toString().padLeft(2, '0')} s';
        }
        setState(() {});
      }
    });
  }

  void _endModeFete() {
    _modeFeteTimer?.cancel();
    setState(() {
      _modeFeteActive = false;
      _modeFeteRemaining = '';
    });
  }

  /// Pick a photo from camera or gallery using ImagePicker.
  Future<void> _pickOfferImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final base64Str = base64Encode(bytes);

    setState(() {
      _offerImagePreview = picked.path;
      _offerImageBase64 = base64Str; // Send plain base64, not data URL
    });
  }

  /// Fetch existing offers from the backend.
  Future<void> _fetchOffers() async {
    setState(() => _offersLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) {
        return;
      }

      final response = await ApiService.getList(
        'offers/my',
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (mounted) {
        setState(() {
          _offers = List<Map<String, dynamic>>.from(response);
          _offersLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _offersLoading = false);
    }
  }

  /// Toggle offer status between ACTIVE and PAUSED via backend.
  Future<void> _toggleOfferStatus(String offerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) return;
      await ApiService.patch(
        'offers/$offerId/status',
        {},
        headers: {'Authorization': 'Bearer $jwt'},
      );
      _fetchOffers();
    } catch (e) {
      debugPrint('Toggle status error: $e');
    }
  }

  Future<void> _createOffer() async {
    if (_offerImageBase64 == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) return;

      final response = await ApiService.post(
        'offers',
        {
          'photoUrl': _offerImageBase64!,
          'description': _offerDescription,
          'originalPrice': double.tryParse(_originalPrice) ?? 0,
          'discountedPrice': double.tryParse(_discountedPrice) ?? 0,
          'quantity': int.tryParse(_quantity) ?? 1,
          'pickupTime': _pickupTime,
          'visibility': _visibility.toUpperCase(),
          'deliveryAvailable': _deliveryAvailable,
        },
        headers: {'Authorization': 'Bearer $jwt'},
      );

      setState(() {
        _showCreateOffer = false;
        _offerImagePreview = null;
        _offerImageBase64 = null;
        _aiResult = null;
        _offerDescription = '';
        _originalPrice = '';
        _discountedPrice = '';
        _quantity = '';
        _pickupTime = '';
        _visibility = 'identified';
        _deliveryAvailable = false;
      });

      // Refresh offers list
      _fetchOffers();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Offer published successfully!'),
            backgroundColor: Color(0xFF1F9D7A),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating offer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish offer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Delete an offer via the backend.
  Future<void> _deleteOffer(String offerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) return;

      await ApiService.delete(
        'offers/$offerId',
        headers: {'Authorization': 'Bearer $jwt'},
      );

      _fetchOffers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer deleted.'),
            backgroundColor: Color(0xFF1F9D7A),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting offer: $e');
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Icon(icon, color: iconColor, size: 20)),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Offers',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        if (_offersLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF1F9D7A)),
            ),
          )
        else if (_offers.isEmpty)
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 40,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No offers yet',
                    style: TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _showCreateOfferDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Create your first offer'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1F9D7A),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _offers.length,
            itemBuilder: (context, index) {
              final offer = _offers[index];
              final status = (offer['status'] ?? 'ACTIVE')
                  .toString()
                  .toUpperCase();
              final visibility = (offer['visibility'] ?? 'IDENTIFIED')
                  .toString()
                  .toUpperCase();
              final discount =
                  offer['originalPrice'] != null && offer['originalPrice'] > 0
                  ? ((offer['originalPrice'] - offer['discountedPrice']) /
                            offer['originalPrice'] *
                            100)
                        .round()
                  : 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image with badges
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          child: offer['photoUrl'] != null
                              ? Image.memory(
                                  base64Decode(
                                    offer['photoUrl'].toString().startsWith(
                                          'data:',
                                        )
                                        ? offer['photoUrl']
                                              .toString()
                                              .split(',')
                                              .last
                                        : offer['photoUrl'].toString(),
                                  ),
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  height: 150,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEFEFEF),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.fastfood,
                                      size: 40,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ),
                        ),
                        // Visibility badge
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: visibility == 'IDENTIFIED'
                                  ? const Color(0xFF1F9D7A)
                                  : const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  visibility == 'IDENTIFIED'
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  size: 12,
                                  color: visibility == 'IDENTIFIED'
                                      ? Colors.white
                                      : const Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  visibility == 'IDENTIFIED'
                                      ? 'Identified'
                                      : 'Anonymous',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: visibility == 'IDENTIFIED'
                                        ? Colors.white
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Discount badge
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '-$discount%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        // Status badge
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: status == 'ACTIVE'
                                  ? const Color(0xFF10B981)
                                  : (status == 'SOLD_OUT'
                                        ? const Color(0xFFE5E7EB)
                                        : const Color(0xFFFFA500)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status == 'ACTIVE'
                                  ? 'Active'
                                  : (status == 'SOLD_OUT'
                                        ? 'Sold Out'
                                        : 'Paused'),
                              style: TextStyle(
                                color: status == 'ACTIVE'
                                    ? Colors.white
                                    : const Color(0xFF6B7280),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer['description'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text:
                                          '€${(offer['discountedPrice'] ?? 0).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Color(0xFF1F9D7A),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          ' €${(offer['originalPrice'] ?? 0).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        decoration: TextDecoration.lineThrough,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${offer['quantity'] ?? 0} left',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                offer['pickupTime'] ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                offer['deliveryAvailable'] == true
                                    ? Icons.local_shipping
                                    : Icons.store,
                                size: 14,
                                color: offer['deliveryAvailable'] == true
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                offer['deliveryAvailable'] == true
                                    ? 'Delivery'
                                    : 'Pickup only',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.edit, size: 14),
                                  label: const Text('Edit'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    foregroundColor: const Color(0xFF1F9D7A),
                                    side: const BorderSide(
                                      color: Color(0xFF1F9D7A),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final jwt = prefs.getString('jwt');
                                  if (jwt == null) return;
                                  try {
                                    await ApiService.patch(
                                      'offers/${offer['id']}/visibility',
                                      {},
                                      headers: {'Authorization': 'Bearer $jwt'},
                                    );
                                    _fetchOffers();
                                  } catch (e) {
                                    debugPrint('Toggle visibility error: $e');
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  foregroundColor: const Color(0xFF1F9D7A),
                                  side: const BorderSide(
                                    color: Color(0xFF1F9D7A),
                                  ),
                                ),
                                child: Icon(
                                  visibility == 'IDENTIFIED'
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => _deleteOffer(offer['id']),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  size: 14,
                                  color: Colors.red,
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
            },
          ),
      ],
    );
  }

  Widget _buildOrdersTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Orders',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _orders.length,
          itemBuilder: (context, index) {
            final order = _orders[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.qr_code,
                            size: 20,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${order['id']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${order['customer']} • ${order['quantity']} item(s)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: order['deliveryMethod'] == 'delivery'
                              ? const Color(0xFF1F9D7A).withOpacity(0.1)
                              : Colors.transparent,
                          border: Border.all(
                            color: order['deliveryMethod'] == 'delivery'
                                ? const Color(0xFF1F9D7A)
                                : const Color(0xFF9CA3AF),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              order['deliveryMethod'] == 'delivery'
                                  ? Icons.local_shipping
                                  : Icons.store,
                              size: 12,
                              color: order['deliveryMethod'] == 'delivery'
                                  ? const Color(0xFF1F9D7A)
                                  : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              order['deliveryMethod'] == 'delivery'
                                  ? 'Delivery'
                                  : 'Pickup',
                              style: TextStyle(
                                fontSize: 11,
                                color: order['deliveryMethod'] == 'delivery'
                                    ? const Color(0xFF1F9D7A)
                                    : const Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Time',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            Text(
                              order['time'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: order['status'] == 'collected'
                              ? const Color(0xFF10B981).withOpacity(0.1)
                              : const Color(0xFFFFA500).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order['status'] == 'collected'
                              ? 'Collected'
                              : 'Pending',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: order['status'] == 'collected'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFFFA500),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (order['status'] == 'pending') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text('Mark Collected'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F9D7A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance Analytics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sales This Week',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 2),
              const Text(
                'Revenue from rescued meals',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, size: 32, color: Color(0xFF9CA3AF)),
                      SizedBox(height: 8),
                      Text(
                        'Chart placeholder',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Environmental Impact',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 2),
              const Text(
                'Your contribution to reducing waste',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              _buildImpactRow('CO₂ Saved', '234 kg'),
              const SizedBox(height: 8),
              _buildImpactRow('Water Saved', '1,250 L'),
              const SizedBox(height: 8),
              _buildImpactRow('Meals Rescued', '156'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImpactRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Color(0xFF1F9D7A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Restaurant Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showEditProfileDialog,
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F9D7A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.business, size: 18, color: Color(0xFF1F9D7A)),
                  SizedBox(width: 8),
                  Text(
                    'Restaurant Information',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoField('Restaurant Name', _restaurantInfo['name']),
              const SizedBox(height: 8),
              _buildInfoField('Email', _restaurantInfo['email']),
              const SizedBox(height: 8),
              _buildInfoField('Phone', _restaurantInfo['phone']),
              const SizedBox(height: 8),
              _buildInfoField('Address', _restaurantInfo['address']),
              const SizedBox(height: 8),
              _buildInfoField('City', _restaurantInfo['city']),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.description, size: 18, color: Color(0xFF1F9D7A)),
                  SizedBox(width: 8),
                  Text(
                    'Legal Documents',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDocumentRow('Business Registration'),
              const SizedBox(height: 8),
              _buildDocumentRow('Hygiene Certificate'),
              const SizedBox(height: 8),
              _buildDocumentRow('Ownership/Rental Proof'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.star, size: 18, color: Color(0xFFFFA500)),
                  SizedBox(width: 8),
                  Text(
                    'Trust Score',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        _restaurantInfo['trustScore'].toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Excellent Standing',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Your trust score is based on document verification & ratings',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentRow(String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Verified',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A)),
            ),
          ],
        ),
        OutlinedButton(
          onPressed: () {},
          child: const Text('View'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            side: const BorderSide(color: Color(0xFF1F9D7A)),
            foregroundColor: const Color(0xFF1F9D7A),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: null, // Remove the 'FiftyFood Partner' header
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu, color: Color(0xFF1A1A1A)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isSmallScreen ? 14 : 20,
            14,
            isSmallScreen ? 14 : 20,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Text(
                'Welcome back, ${_restaurantInfo['name']} 👋',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Manage your offers and track your impact',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),

              // Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showQrScannerDialog,
                      icon: const Icon(Icons.qr_code, size: 16),
                      label: const Text('Scan QR'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1F9D7A),
                        side: const BorderSide(color: Color(0xFF1F9D7A)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showCreateOfferDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Offer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F9D7A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Stats Cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 160,
                      child: _buildStatCard(
                        'Total Sales',
                        '€${_stats['totalSales'].toStringAsFixed(0)}',
                        Icons.euro,
                        const Color(0xFF1F9D7A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: _buildStatCard(
                        'Meals Saved',
                        '${_stats['mealsSaved']}',
                        Icons.eco,
                        const Color(0xFF1F9D7A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: _buildStatCard(
                        'Avg Rating',
                        '${_stats['avgRating']}',
                        Icons.star,
                        const Color(0xFFFFA500),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: _buildStatCard(
                        'Active Offers',
                        '${_stats['activeOffers']}',
                        Icons.trending_up,
                        const Color(0xFFFF7A59),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Mode Fête Section
              if (_modeFeteActive)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEAA7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.celebration,
                        color: Color(0xFFFFA500),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mode Fête Active',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: Color(0xFFFFA500),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _modeFeteRemaining,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFFFA500),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _endModeFete,
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFFFFA500),
                        ),
                      ),
                    ],
                  ),
                ),

              // Tab Navigation
              Row(
                children: [
                  _buildTabButton(0, 'Offers'),
                  _buildTabButton(1, 'Orders'),
                  _buildTabButton(2, 'Stats'),
                  _buildTabButton(3, 'Profile'),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Content
              if (_activeTab == 0)
                _buildOffersTab()
              else if (_activeTab == 1)
                _buildOrdersTab()
              else if (_activeTab == 2)
                _buildStatsTab()
              else
                _buildProfileTab(),
            ],
          ),
        ),
      ),
      drawer: _buildDrawer(),
    );
  }

  Widget _buildTabButton(int index, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _activeTab == index
                    ? const Color(0xFF1F9D7A)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: _activeTab == index
                  ? const Color(0xFF1F9D7A)
                  : const Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo + Restaurant Portal
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              height: 120,
                              width: 120,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1F9D7A),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.eco,
                                      color: Colors.white,
                                      size: 60,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Restaurant Portal',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // My Offers - Active tab styling
                      _buildDrawerItem(
                        icon: Icons.inventory_2,
                        label: 'My Offers',
                        index: 0,
                      ),
                      const SizedBox(height: 4),

                      // Orders with badge
                      _buildDrawerItem(
                        icon: Icons.grid_view_rounded,
                        label: 'Orders',
                        index: 1,
                        badgeCount: _orders.length,
                      ),
                      const SizedBox(height: 4),

                      // Statistics
                      _buildDrawerItem(
                        icon: Icons.bar_chart_rounded,
                        label: 'Statistics',
                        index: 2,
                      ),
                      const SizedBox(height: 4),

                      // Profile
                      _buildDrawerItem(
                        icon: Icons.person_outline,
                        label: 'Profile',
                        index: 3,
                      ),
                      const SizedBox(height: 24),

                      // Celebration Mode card
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _showModeFete = true);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD1FAE5)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.eco,
                                    color: Color(0xFF1F9D7A),
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Celebration Mode',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Click here to temporarily activate Celebration Mode to publish special offers during events',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6B7280),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom items: Settings + Sign Out
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const Divider(color: Color(0xFFF3F4F6)),
                  ListTile(
                    leading: const Icon(
                      Icons.settings_outlined,
                      color: Color(0xFF6B7280),
                      size: 22,
                    ),
                    title: const Text(
                      'Settings',
                      style: TextStyle(fontSize: 14, color: Color(0xFF374151)),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.logout,
                      color: Color(0xFFEF4444),
                      size: 22,
                    ),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(fontSize: 14, color: Color(0xFFEF4444)),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required int index,
    int badgeCount = 0,
  }) {
    final bool isActive = _activeTab == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() => _activeTab = index);
          Navigator.pop(context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1F9D7A) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive ? Colors.white : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isActive ? Colors.white : const Color(0xFF6B7280),
                  ),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateOfferDialog() {
    // Reset form state
    setState(() {
      _offerImagePreview = null;
      _offerImageBase64 = null;
      _offerDescription = '';
      _originalPrice = '';
      _discountedPrice = '';
      _quantity = '';
      _pickupTime = '';
      _visibility = 'identified';
      _deliveryAvailable = false;
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) {
        String? modalError;
        return StatefulBuilder(
          builder: (modalContext, modalSetState) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 480,
                maxHeight: MediaQuery.of(context).size.height * 0.94,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Center(
                      child: Text(
                        'Create New Offer',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(
                        'List your surplus food and help reduce waste',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Image Picker Section
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Food Photo',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Required — must be taken today',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_offerImagePreview == null)
                      GestureDetector(
                        onTap: () async {
                          try {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1200,
                              maxHeight: 1200,
                              imageQuality: 85,
                            );
                            if (picked == null) return;
                            final bytes = await picked.readAsBytes();
                            final base64Str = base64Encode(bytes);
                            modalSetState(() {
                              _offerImagePreview = picked.path;
                              _offerImageBase64 = base64Str;
                              modalError = null;
                            });
                          } catch (e) {
                            modalSetState(() {
                              modalError = 'Image picker error: $e';
                            });
                          }
                        },
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF9CA3AF)),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.add_a_photo,
                              size: 48,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ),
                    if (_offerImagePreview != null && _offerImageBase64 != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(_offerImageBase64!),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),

                    // --- ERROR MESSAGE (always below image area) ---
                    if (modalError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Text(
                          modalError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 18),

                    // Description
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      onChanged: (v) => _offerDescription = v,
                      decoration: InputDecoration(
                        hintText:
                            "e.g. Surprise pasta bag, Chef's selection...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Prices Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Original Price (€)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                keyboardType: TextInputType.number,
                                onChanged: (v) => _originalPrice = v,
                                decoration: InputDecoration(
                                  hintText: '18.50',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  hintStyle: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Discounted Price (€)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                keyboardType: TextInputType.number,
                                onChanged: (v) => _discountedPrice = v,
                                decoration: InputDecoration(
                                  hintText: '6.90',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  hintStyle: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quantity & Pickup Time
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quantity',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                keyboardType: TextInputType.number,
                                onChanged: (v) => _quantity = v,
                                decoration: InputDecoration(
                                  hintText: '5',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  hintStyle: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pickup Time',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              buildPickupTimeDropdown(
                                value: _pickupTime,
                                onChanged: (slot) =>
                                    modalSetState(() => _pickupTime = slot),
                                context: ctx,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Offer Visibility
                    const Text(
                      'Offer Visibility',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildVisibilityOptionDialog(
                      'identified',
                      'Identified Restaurant',
                      'Your restaurant name and branding will be visible',
                      modalSetState,
                    ),
                    const SizedBox(height: 8),
                    _buildVisibilityOptionDialog(
                      'anonymous',
                      'Anonymous',
                      'Only price, quantity, pickup time and distance shown',
                      modalSetState,
                    ),
                    const SizedBox(height: 18),

                    // Delivery toggle
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.local_shipping,
                                size: 16,
                                color: Color(0xFF9CA3AF),
                              ),
                              SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enable Delivery',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Allow customers to order delivery',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _deliveryAvailable,
                            onChanged: (v) =>
                                modalSetState(() => _deliveryAvailable = v),
                            activeColor: const Color(0xFF1F9D7A),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Discount validation feedback (optional, as before)
                    if (_originalPrice.isNotEmpty &&
                        _discountedPrice.isNotEmpty)
                      Builder(
                        builder: (_) {
                          final orig = double.tryParse(_originalPrice) ?? 0;
                          final disc = double.tryParse(_discountedPrice) ?? 0;
                          if (orig > 0 && disc > 0 && disc < orig) {
                            final pct = ((orig - disc) / orig * 100).round();
                            if (pct < 10) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '⚠️ Discount must be at least 10%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              );
                            } else if (pct > 90) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '⚠️ Discount seems unrealistic (>90%)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '✅ $pct% discount applied',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1F9D7A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _offerImageBase64 != null
                                ? () async {
                                    // Validate form fields.
                                    if (_offerDescription.trim().isEmpty ||
                                        _originalPrice.isEmpty ||
                                        _discountedPrice.isEmpty ||
                                        _quantity.isEmpty ||
                                        _pickupTime.isEmpty) {
                                      modalSetState(() {
                                        modalError = "All fields are required!";
                                      });
                                      return;
                                    }
                                    try {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      final jwt = prefs.getString('jwt');
                                      if (jwt == null) {
                                        modalSetState(() {
                                          modalError =
                                              "You are not authenticated!";
                                        });
                                        return;
                                      }

                                      final response = await ApiService.post(
                                        'offers',
                                        {
                                          'photoUrl': _offerImageBase64!,
                                          'description': _offerDescription,
                                          'originalPrice':
                                              double.tryParse(_originalPrice) ??
                                              0,
                                          'discountedPrice':
                                              double.tryParse(
                                                _discountedPrice,
                                              ) ??
                                              0,
                                          'quantity':
                                              int.tryParse(_quantity) ?? 1,
                                          'pickupTime': _pickupTime,
                                          'visibility': _visibility
                                              .toUpperCase(),
                                          'deliveryAvailable':
                                              _deliveryAvailable,
                                        },
                                        headers: {
                                          'Authorization': 'Bearer $jwt',
                                        },
                                      );

                                      Navigator.of(ctx).pop();
                                      setState(() {
                                        _offerImagePreview = null;
                                        _offerImageBase64 = null;
                                        _aiResult = null;
                                        _offerDescription = '';
                                        _originalPrice = '';
                                        _discountedPrice = '';
                                        _quantity = '';
                                        _pickupTime = '';
                                        _visibility = 'identified';
                                        _deliveryAvailable = false;
                                      });
                                      _fetchOffers();

                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              '✅ Offer published successfully!',
                                            ),
                                            backgroundColor: Color(0xFF1F9D7A),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      modalSetState(() {
                                        modalError =
                                            'Failed to publish offer: $e';
                                      });
                                    }
                                  }
                                : null,
                            child: const Text('Publish Offer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1F9D7A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // This is the inner visibility radio option for dialog version
  Widget _buildVisibilityOptionDialog(
    String value,
    String title,
    String subtitle,
    void Function(void Function()) setSheetState,
  ) {
    return GestureDetector(
      onTap: () => setSheetState(() => _visibility = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: _visibility == value
                ? const Color(0xFF1F9D7A)
                : const Color(0xFF9CA3AF),
          ),
          borderRadius: BorderRadius.circular(8),
          color: _visibility == value
              ? const Color(0xFF1F9D7A).withOpacity(0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _visibility,
              onChanged: (v) => setSheetState(() => _visibility = v!),
              activeColor: const Color(0xFF1F9D7A),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQrScannerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Validate Customer QR Code'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter or scan the customer\'s QR code',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF9CA3AF),
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.qr_code,
                    size: 40,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) {
                  _qrInput = v;
                },
                decoration: InputDecoration(
                  hintText: 'Paste QR token here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_qrResult != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _qrResult!['success']
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _qrResult!['success']
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _qrResult!['success']
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 18,
                        color: _qrResult!['success']
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _qrResult!['message'],
                          style: TextStyle(
                            fontSize: 11,
                            color: _qrResult!['success']
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _qrInput = '';
              _qrResult = null;
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: _qrInput.isNotEmpty
                ? () {
                    setState(
                      () => _qrResult = {
                        'success': true,
                        'message': 'QR Code validated successfully!',
                      },
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F9D7A),
            ),
            child: const Text(
              'Validate',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
