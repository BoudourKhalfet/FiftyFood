import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../../l10n/app_localizations.dart';
import 'offers_tab.dart';
import 'orders_tab.dart';
import 'stats_tab.dart';
import 'profile_tab.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../constants/api.dart';

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
    isExpanded: true,
    value: value.isEmpty ? null : value,
    decoration: InputDecoration(
      isDense: true,
      hintText: 'Select time',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
    ),
    items: options.map((v) {
      final past = isPast(v);
      return DropdownMenuItem<String>(
        value: v,
        enabled: !past || v == value,
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
  String? _uploadedOfferImageUrl;
  bool _uploadingOfferImage = false;
  String? _offerImageUploadError;
  DateTime? _pickupDate;
  List<String> _selectedCategories = [];
  final List<String> _categories = [
    'BAKERY',
    'CAFE',
    'GRILL',
    'FAST_FOOD',
    'VEGETARIAN',
    'HALAL',
    'SEAFOOD',
    'SUSHI',
    'PIZZA',
    'BURGER',
    'BBQ',
    'HEALTHY',
    'DESSERT',
    'STREET_FOOD',
    'SANDWICHES',
    'SALAD',
    'PASTA',
    'BREAKFAST',
    'FINE_DINING',
    'BRUNCH',
  ];

  final Map<String, String> _categoryLabels = {
    'BAKERY': 'Bakery',
    'CAFE': 'Cafe',
    'GRILL': 'Grill',
    'FAST_FOOD': 'Fast Food',
    'VEGETARIAN': 'Vegetarian',
    'HALAL': 'Halal',
    'SEAFOOD': 'Seafood',
    'SUSHI': 'Sushi',
    'PIZZA': 'Pizza',
    'BURGER': 'Burger',
    'BBQ': 'BBQ',
    'HEALTHY': 'Healthy',
    'DESSERT': 'Dessert',
    'STREET_FOOD': 'Street Food',
    'SANDWICHES': 'Sandwiches',
    'SALAD': 'Salad',
    'PASTA': 'Pasta',
    'BREAKFAST': 'Breakfast',
    'FINE_DINING': 'Fine Dining',
    'BRUNCH': 'Brunch',
  };

  Future<void> _pickAndUploadOfferImage(
    void Function(void Function()) modalSetState,
  ) async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      String extension = picked.name.split('.').last.toLowerCase();
      MediaType? mediaType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mediaType = MediaType('image', 'jpeg');
          break;
        case 'png':
          mediaType = MediaType('image', 'png');
          break;
        case 'gif':
          mediaType = MediaType('image', 'gif');
          break;
        case 'bmp':
          mediaType = MediaType('image', 'bmp');
          break;
        case 'webp':
          mediaType = MediaType('image', 'webp');
          break;
        default:
          mediaType = MediaType('application', 'octet-stream');
      }

      modalSetState(() {
        _uploadingOfferImage = true;
        _offerImageUploadError = null;
        _uploadedOfferImageUrl = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');

      final uri = Uri.parse(apiUrl('offers/upload-photo'));
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $jwt';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: picked.name,
          contentType: mediaType,
        ),
      );

      final streamedResponse = await request.send();
      final respStr = await streamedResponse.stream.bytesToString();
      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        final data = jsonDecode(respStr);
        modalSetState(() {
          _uploadedOfferImageUrl = data['url'];
          _offerImageUploadError = null;
        });

        // Auto-generate description using Gemini
        await _generateDescriptionForImage(data['url'], modalSetState);
      } else {
        modalSetState(() {
          _offerImageUploadError = 'Failed to upload img: $respStr';
          _uploadedOfferImageUrl = null;
        });
      }
    } catch (e) {
      modalSetState(
        () => _offerImageUploadError = 'Image picker/upload error: $e',
      );
    } finally {
      modalSetState(() {
        _uploadingOfferImage = false;
      });
    }
  }

  Future<void> _generateDescriptionForImage(
    String imageUrl,
    void Function(void Function()) modalSetState,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');

      // Get current language code
      final locale = Localizations.localeOf(context);
      final languageCode = locale.languageCode;

      final response = await http.post(
        Uri.parse(apiUrl('offers/generate-description')),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'imageUrl': imageUrl, 'language': languageCode}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final description = data['description'] as String?;

        if (description != null && description.isNotEmpty) {
          modalSetState(() {
            _descriptionController.text = description;
            _offerDescription = description;
          });
        }
      } else {
        print('Failed to generate description: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('Error generating description: $e');
      // Don't show error to user - description generation is optional
    }
  }

  int _activeTab = 0; // 0: offers, 1: orders, 2: stats, 3: profile

  // New Offer Form
  late TextEditingController _descriptionController;
  String _offerDescription = '';
  String _originalPrice = '';
  String _discountedPrice = '';
  String _quantity = '';
  String _pickupTime = '';
  String _visibility = 'IDENTIFIED';

  // Image Upload

  bool _aiVerifying = false;
  Map<String, dynamic>? _aiResult;

  // QR Scanner
  Map<String, dynamic>? _qrResult;
  bool _qrValidating = false;

  // Restaurant Dashboard Stats
  double _totalSales = 0.0;
  int _mealsSaved = 0;
  double _avgRating = 0.0;
  int _activeOffers = 0;
  bool _loadingStats = true;

  Map<String, dynamic> _restaurantInfo = {
    'name': 'Restaurant Name',
    'email': '',
  };

  // For badge on Orders in side menu
  final List<Map<String, dynamic>> _orders = [];
  final GlobalKey<PartnerOffersTabState> _offersTabKey =
      GlobalKey<PartnerOffersTabState>();

  // Timer for real-time stats refresh
  Timer? _statsRefreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchRestaurantProfile();
    _fetchRestaurantStats();

    // Refresh stats every 30 seconds for real-time updates
    _statsRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchRestaurantStats();
    });
  }

  @override
  void dispose() {
    _statsRefreshTimer?.cancel();
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

  Future<void> _fetchRestaurantStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) return;

      final response = await ApiService.get(
        'restaurant/onboarding/stats',
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (mounted) {
        setState(() {
          _totalSales = (response['totalSales'] ?? 0).toDouble();
          _mealsSaved = response['mealsSaved'] ?? 0;
          _avgRating = (response['avgRating'] ?? 0).toDouble();
          _activeOffers = response['activeOffers'] ?? 0;
          _loadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching restaurant stats: $e');
      if (mounted) {
        setState(() {
          _loadingStats = false;
        });
      }
    }
  }

  static const bool _autoCloseQrDialogOnSuccess = true;
  static const Duration _qrSuccessAutoCloseDelay = Duration(milliseconds: 900);

  Future<void> _validateQrToken(
    String token, {
    BuildContext? dialogContext,
    bool autoCloseOnSuccess = false,
  }) async {
    setState(() {
      _qrValidating = true;
      _qrResult = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      final response = await ApiService.post(
        'orders/qr/validate',
        {'token': token.trim()},
        headers: {if (jwt != null) 'Authorization': 'Bearer $jwt'},
      );

      if (!mounted) return;
      final success = response['success'] == true;
      final message = (response['message'] ?? 'QR validation completed')
          .toString();

      setState(() {
        _qrResult = {'success': success, 'message': message};
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF10B981),
          ),
        );

        if (autoCloseOnSuccess && dialogContext != null) {
          Future.delayed(_qrSuccessAutoCloseDelay, () {
            if (!mounted) return;
            try {
              if (Navigator.of(dialogContext).canPop()) {
                _qrResult = null;
                Navigator.of(dialogContext).pop();
              }
            } catch (_) {
              // Dialog might already be closed.
            }
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _qrResult = {
          'success': false,
          'message': e.toString().replaceFirst('Exception: ', ''),
        };
      });
    } finally {
      if (mounted) {
        setState(() {
          _qrValidating = false;
        });
      }
    }
  }

  Future<void> _scanQrWithCamera(BuildContext dialogContext) async {
    bool consumed = false;

    final scannedToken = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Scan QR Code'),
        content: SizedBox(
          width: 320,
          height: 320,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: MobileScanner(
              onDetect: (capture) {
                if (consumed) return;
                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;
                final value = barcodes.first.rawValue;
                if (value == null || value.trim().isEmpty) return;
                consumed = true;
                Navigator.of(dialogContext).pop(value.trim());
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (scannedToken == null || scannedToken.isEmpty) return;

    await _validateQrToken(
      scannedToken,
      dialogContext: dialogContext,
      autoCloseOnSuccess: _autoCloseQrDialogOnSuccess,
    );
  }

  void _showQrScannerDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Validate Customer QR Code'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scan the customer\'s QR code',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _qrValidating
                      ? null
                      : () => _scanQrWithCamera(dialogContext),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan with Camera'),
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
              _qrResult = null;
              Navigator.pop(dialogContext);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
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
              fontSize: 13,
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
                      // Logo & Portal header
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
                            Text(
                              _restaurantInfo['name'] ?? "",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              _restaurantInfo['email'] ?? "",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 14),
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
                      _buildDrawerItem(
                        icon: Icons.inventory_2,
                        label: 'My Offers',
                        index: 0,
                      ),
                      const SizedBox(height: 5),
                      _buildDrawerItem(
                        icon: Icons.grid_view_rounded,
                        label: 'Orders',
                        index: 1,
                        badgeCount: _orders.length,
                      ),
                      const SizedBox(height: 5),
                      _buildDrawerItem(
                        icon: Icons.bar_chart_rounded,
                        label: 'Statistics',
                        index: 2,
                      ),
                      const SizedBox(height: 5),
                      _buildDrawerItem(
                        icon: Icons.person_outline,
                        label: 'Profile',
                        index: 3,
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          // Celebration mode code (To DO)
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 21),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  void _showCreateOfferDialog() {
    _descriptionController = TextEditingController();

    setState(() {
      _offerDescription = '';
      _originalPrice = '';
      _discountedPrice = '';
      _quantity = '';
      _pickupTime = '';
      _visibility = 'IDENTIFIED';
      _uploadedOfferImageUrl = null;
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
                maxWidth: 375,
                maxHeight: MediaQuery.of(context).size.height * 0.94,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Center(
                      child: Text(
                        AppLocalizations.of(context)!.btnCreateOffer,
                        style: const TextStyle(
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

                    if (_uploadedOfferImageUrl == null)
                      GestureDetector(
                        onTap: _uploadingOfferImage
                            ? null
                            : () async {
                                // Always clear error before starting new upload!
                                modalSetState(() {
                                  _offerImageUploadError = null;
                                  _uploadedOfferImageUrl = null;
                                });
                                try {
                                  await _pickAndUploadOfferImage(modalSetState);
                                } catch (e) {
                                  modalSetState(() {
                                    _offerImageUploadError =
                                        'Image picker/upload error: $e';
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
                          child: _uploadingOfferImage
                              ? const Center(child: CircularProgressIndicator())
                              : const Center(
                                  child: Icon(
                                    Icons.add_a_photo,
                                    size: 48,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                        ),
                      )
                    else
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              _uploadedOfferImageUrl!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                modalSetState(() {
                                  _uploadedOfferImageUrl = null;
                                  _descriptionController.clear();
                                  _offerDescription = '';
                                  _offerImageUploadError = null;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_offerImageUploadError != null &&
                        _uploadedOfferImageUrl == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Text(
                          _offerImageUploadError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
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
                    Text(
                      AppLocalizations.of(context)!.labelDescription,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descriptionController,
                      onChanged: (v) => _offerDescription = v,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.hintDescription,
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

                    // CATEGORY SECTION
                    Text(
                      AppLocalizations.of(context)!.labelCategories,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),

                    MultiSelectDialogField(
                      items: _categories
                          .map(
                            (cat) => MultiSelectItem(
                              cat,
                              _categoryLabels[cat] ?? cat,
                            ),
                          )
                          .toList(),
                      title: Text(
                        AppLocalizations.of(context)!.labelCategories,
                      ),
                      selectedColor: Color(0xFF1F9D7A),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Color(0xFF9CA3AF), width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      buttonIcon: const Icon(
                        Icons.category,
                        color: Color(0xFF1F9D7A),
                      ),
                      buttonText: Text(
                        AppLocalizations.of(context)!.btnSelectCategories,
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 13,
                        ),
                      ),
                      onConfirm: (results) {
                        modalSetState(() {
                          _selectedCategories = results.cast<String>();
                        });
                      },
                      initialValue: _selectedCategories,
                    ),
                    const SizedBox(height: 12),
                    // Prices Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.labelOriginalPrice,
                                style: const TextStyle(
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
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.labelDiscountedPrice,
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
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.labelQuantity,
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
                                  isDense: true,
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
                        SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pickup Time'),
                              SizedBox(height: 6),
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
                      'IDENTIFIED',
                      'Identified Restaurant',
                      'Your restaurant name and branding will be visible',
                      modalSetState,
                    ),
                    const SizedBox(height: 8),
                    _buildVisibilityOptionDialog(
                      'ANONYMOUS',
                      'Anonymous',
                      'Only price, quantity, pickup time and distance shown',
                      modalSetState,
                    ),
                    const SizedBox(height: 18),

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
                            onPressed: _uploadedOfferImageUrl != null
                                ? () async {
                                    // Validate form fields.
                                    if (_offerDescription.trim().isEmpty ||
                                        _originalPrice.isEmpty ||
                                        _discountedPrice.isEmpty ||
                                        _quantity.isEmpty ||
                                        _pickupTime.isEmpty ||
                                        _selectedCategories.isEmpty) {
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

                                      final now = DateTime.now();
                                      final pickupHour = int.parse(
                                        _pickupTime.split(":")[0],
                                      );
                                      final pickupMinute = int.parse(
                                        _pickupTime
                                            .split(":")[1]
                                            .split('-')[0]
                                            .trim(),
                                      );
                                      DateTime candidate = DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                        pickupHour,
                                        pickupMinute,
                                      );
                                      if (candidate.isBefore(now)) {
                                        candidate = candidate.add(
                                          Duration(days: 1),
                                        );
                                      }

                                      final response = await ApiService.post(
                                        'offers',
                                        {
                                          'description': _offerDescription
                                              .trim(),
                                          'originalPrice': double.parse(
                                            _originalPrice,
                                          ),
                                          'discountedPrice': double.parse(
                                            _discountedPrice,
                                          ),
                                          'quantity': int.parse(_quantity),
                                          'pickupTime': _pickupTime,
                                          'pickupDateTime': candidate
                                              .toIso8601String(),
                                          'categories': _selectedCategories,
                                          'visibility': _visibility,

                                          'photoUrl': _uploadedOfferImageUrl,
                                        },
                                        headers: {
                                          'Authorization': 'Bearer $jwt',
                                        },
                                      );
                                      print('Offer POST response: $response');
                                      _offersTabKey.currentState?.fetchOffers();

                                      Navigator.of(ctx).pop();
                                      setState(() {
                                        _aiResult = null;
                                        _offerDescription = '';
                                        _originalPrice = '';
                                        _discountedPrice = '';
                                        _quantity = '';
                                        _pickupTime = '';
                                        _visibility = 'IDENTIFIED';
                                      });

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
                                        _descriptionController.clear();
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

  Widget _buildStatsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;

        if (constraints.maxWidth < 600) {
          crossAxisCount = 2;
        } else if (constraints.maxWidth < 1000) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 4;
        }

        return GridView(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.9,
          ),
          children: [
            _buildStatCard(
              title: "Total Sales",
              value: _loadingStats ? "-" : _totalSales.toStringAsFixed(2),
              icon: Icons.euro,
              iconColor: const Color(0xFF1F9D7A),
              iconBg: const Color(0xFFE8F5F1),
            ),
            _buildStatCard(
              title: "Meals Saved",
              value: _loadingStats ? "-" : _mealsSaved.toString(),
              icon: Icons.eco,
              iconColor: const Color(0xFF2ECC71),
              iconBg: const Color(0xFFE9F8EF),
            ),
            _buildStatCard(
              title: "Avg Rating",
              value: _loadingStats ? "-" : _avgRating.toStringAsFixed(1),
              icon: Icons.star_border,
              iconColor: const Color(0xFFFFA000),
              iconBg: const Color(0xFFFFF4E5),
            ),
            _buildStatCard(
              title: "Active Offers",
              value: _loadingStats ? "-" : _activeOffers.toString(),
              icon: Icons.trending_up,
              iconColor: const Color(0xFFFF7043),
              iconBg: const Color(0xFFFFEDE8),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: null,
        centerTitle: false,
        leading: Builder(
          builder: (context) => IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu, color: Color(0xFF1A1A1A)),
          ),
        ),
      ),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
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
              const SizedBox(height: 18),
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
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showCreateOfferDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('New Offer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F9D7A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildStatsSection(),
              const SizedBox(height: 26),
              // Tabs bar
              Row(
                children: [
                  _buildTabButton(0, 'Offers'),
                  _buildTabButton(1, 'Orders'),
                  _buildTabButton(2, 'Stats'),
                  _buildTabButton(3, 'Profile'),
                ],
              ),
              const SizedBox(height: 16),

              Builder(
                builder: (context) {
                  switch (_activeTab) {
                    case 0:
                      return PartnerOffersTab(key: _offersTabKey);
                    case 1:
                      return PartnerOrdersTab();
                    case 2:
                      return PartnerStatsTab();
                    case 3:
                      return PartnerProfileTab();
                    default:
                      return SizedBox();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
