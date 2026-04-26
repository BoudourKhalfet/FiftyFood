import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import '../../widgets/main_scaffold.dart';
import 'restaurant_details.dart';
import 'my_orders.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../checkout/order_checkout_screen.dart';
import '../../widgets/payment_method_selector.dart';
import '../../constants/api.dart';
import '../../api/client_profile_service.dart';
import '../../models/client_profile.dart';
import 'package:location/location.dart';

Uint8List? decodeImg(String imgUrl) {
  // Remove data prefix if needed
  if (imgUrl.startsWith('data:image')) {
    final base64Data = imgUrl.split(',').last;
    return base64Decode(base64Data);
  }
  try {
    return base64Decode(imgUrl);
  } catch (_) {
    return null;
  }
}

class OfferDetails extends StatefulWidget {
  final dynamic offer;
  const OfferDetails({required this.offer, super.key});

  @override
  State<OfferDetails> createState() => _OfferDetailsPageState();
}

class _OfferDetailsPageState extends State<OfferDetails> {
  int quantity = 1;
  bool _isCreatingOrder = false;
  String collectionMethod = 'pickup';
  String? deliveryAddress;
  String? phoneNumber;
  String paymentMethod = 'card';
  String selectedPayment = 'card'; // ✅ FIXED: Added as class-level variable
  ClientProfile? _clientProfile;
  double? _currentLatitude;
  double? _currentLongitude;

  @override
  void initState() {
    super.initState();
    _loadClientProfile();
    _loadCurrentLocation();
  }

  Future<void> _loadClientProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) return;

      final profile = await ProfileService.getProfile(jwt);
      if (!mounted) return;
      setState(() {
        _clientProfile = profile;
      });
    } catch (_) {
      // Best-effort only; distance falls back to unavailable when no coords exist.
    }
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final location = Location();
      final serviceEnabled = await location.serviceEnabled() ||
          await location.requestService();
      if (!serviceEnabled) return;

      var permission = await location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await location.requestPermission();
      }
      if (permission != PermissionStatus.granted &&
          permission != PermissionStatus.grantedLimited) {
        return;
      }

      final current = await location.getLocation();
      if (current.latitude == null || current.longitude == null) return;

      if (!mounted) return;
      setState(() {
        _currentLatitude = current.latitude;
        _currentLongitude = current.longitude;
      });
    } catch (_) {
      // Best-effort only.
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _pickupTimeText(dynamic offer) {
    final direct = (offer['_pickupTimeText'] ?? offer['pickupTime'] ?? '')
        .toString()
        .trim();
    if (direct.isNotEmpty) return direct;

    final pickupDateTimeRaw = offer['pickupDateTime']?.toString();
    if (pickupDateTimeRaw == null || pickupDateTimeRaw.isEmpty) {
      return 'Time unavailable';
    }

    final parsed = DateTime.tryParse(pickupDateTimeRaw)?.toLocal();
    if (parsed == null) return 'Time unavailable';

    final hh = parsed.hour.toString().padLeft(2, '0');
    final mm = parsed.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _distanceText(dynamic offer, dynamic restProfile) {
    final fromList = (offer['_distanceText'] ?? '').toString().trim();
    if (fromList.isNotEmpty && fromList != 'Distance unavailable') {
      return fromList;
    }

    for (final key in const [
      'distanceKm',
      'distance',
      'distanceToRestaurantKm',
    ]) {
      final km = _asDouble(offer[key]);
      if (km != null && km >= 0) {
        return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
      }
    }

    final clientLat = _currentLatitude ?? _clientProfile?.lastLatitude;
    final clientLng = _currentLongitude ?? _clientProfile?.lastLongitude;
    final restaurantLat = _asDouble(restProfile?['latitude']);
    final restaurantLng = _asDouble(restProfile?['longitude']);

    if (clientLat != null &&
        clientLng != null &&
        restaurantLat != null &&
        restaurantLng != null) {
      const earthRadiusKm = 6371.0;
      final dLat = (restaurantLat - clientLat) * (3.141592653589793 / 180.0);
      final dLon = (restaurantLng - clientLng) * (3.141592653589793 / 180.0);
      final a =
          (sin(dLat / 2) * sin(dLat / 2)) +
          cos(clientLat * (3.141592653589793 / 180.0)) *
              cos(restaurantLat * (3.141592653589793 / 180.0)) *
              (sin(dLon / 2) * sin(dLon / 2));
      final c = 2 * atan2(sqrt(a), sqrt(1 - a));
      final km = earthRadiusKm * c;
      return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
    }

    return fromList.isNotEmpty ? fromList : 'Distance unavailable';
  }

  Future<bool> _checkDeliveryAvailable(String restaurantId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt');
    debugPrint(
      '[DELIVERY DEBUG][CLIENT] checking availability for restaurantId=$restaurantId',
    );
    try {
      if (restaurantId.trim().isEmpty) {
        debugPrint('[DELIVERY DEBUG][CLIENT] restaurantId is empty');
        return false;
      }

      final response = await http.get(
        Uri.parse(
          apiUrl('orders/can-deliver'),
        ).replace(queryParameters: {'restaurantId': restaurantId}),
        headers: {'Authorization': 'Bearer $token'},
      );

      debugPrint(
        '[DELIVERY DEBUG][CLIENT] status=${response.statusCode} body=${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['available'] == true;
      }
    } catch (e) {
      debugPrint('[DELIVERY DEBUG][CLIENT] request failed: $e');
    }
    return false;
  }

  Widget buildOfferImage(String? imgUrl) {
    if (imgUrl == null || imgUrl.isEmpty) {
      return Container(height: 190, color: Colors.grey[200]);
    }
    if (imgUrl.startsWith('http')) {
      return Image.network(
        imgUrl,
        height: 190,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            Container(height: 190, color: Colors.grey[200]),
      );
    }
    try {
      final bytes = decodeImg(imgUrl);
      return Image.memory(
        bytes ?? Uint8List(0),
        height: 190,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            Container(height: 190, color: Colors.grey[200]),
      );
    } catch (_) {
      return Container(height: 190, color: Colors.grey[200]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;

    final imgUrl = offer['photoUrl'];
    final restProfile = offer['restaurant']?['restaurantProfile'];
    final desc = offer['description'] ?? '';
    final address =
        (restProfile?['address'] ?? offer['address'] ?? 'Address unavailable')
            .toString(); // or offer['address']
    final rating = restProfile?['avgRating'] ?? 4.5;
    final discounted = (offer['discountedPrice'] as num?)?.toDouble() ?? 0.0;
    final original = (offer['originalPrice'] as num?)?.toDouble() ?? 0.0;
    final pickupDisplay = _pickupTimeText(offer);
    final distanceDisplay = _distanceText(offer, restProfile);
    final left = offer['quantity'] ?? 1;
    final save = original - discounted;
    final isAnonymous = offer['visibility'] == 'ANONYMOUS';
    final displayName = isAnonymous
        ? 'Anonymous'
        : (restProfile?['restaurantName'] ?? '');

    return MainScaffold(
      child: Column(
        children: [
          // Top bar Row (with back button, logo, and menu IF MainScaffold doesn't already provide it)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 15),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_clientProfile == null) const SizedBox.shrink(),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: buildOfferImage(imgUrl),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '-${original > 0 ? ((original - discounted) / original * 100).round() : 0}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(children: []),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: const Color(0xFF3D9176),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    fontStyle: isAnonymous
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                              ),
                              if (!isAnonymous) ...[
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: 'See restaurant details',
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      final restaurantUserId =
                                          offer['restaurant']?['id'];
                                      if (restaurantUserId == null ||
                                          restaurantUserId.isEmpty) {
                                        return;
                                      }
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => RestaurantDetailsPage(
                                            restaurantId: restaurantUserId,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.info_outline,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Details',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      minimumSize: const Size(0, 28),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      side: const BorderSide(
                                        color: Color(0xFF3D9176),
                                      ),
                                      foregroundColor: const Color(0xFF3D9176),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        Text(
                          rating.toString(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(desc, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '€${discounted.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF3D9176),
                            fontWeight: FontWeight.w800,
                            fontSize: 25,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '€${original.toStringAsFixed(2)}',
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFDEF8EA),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Text(
                            'Save €${save.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF3D9176),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFEAF9F4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 19,
                                  color: Color(0xFF3D9176),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Pickup Time',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF3D9176),
                                  ),
                                ),
                                Text(
                                  pickupDisplay,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFF5EDF7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.place_outlined,
                                  size: 19,
                                  color: Color(0xFF9A65A6),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Distance',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF9A65A6),
                                  ),
                                ),
                                Text(
                                  distanceDisplay,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.location_on,
                        color: Colors.black,
                        size: 28,
                      ),
                      title: Text(
                        'Pickup Address',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(address, style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "What's included",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      desc,
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          '$left left',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          'Quantity:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline),
                          onPressed: quantity > 1
                              ? () => setState(() => quantity--)
                              : null,
                        ),
                        Text(
                          '$quantity',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline),
                          onPressed: quantity < left
                              ? () => setState(() => quantity++)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('Total', style: TextStyle(fontSize: 15)),
                        const Spacer(),
                        Text(
                          '€${(quantity * discounted).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Color(0xFF3D9176),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF3D9176),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 13,
                            ),
                          ),
                          onPressed: () {
                            showCollectionMethodDialog(
                              discounted: discounted,
                              pickup: pickupDisplay,
                              address: address,
                            );
                          },
                          child: const Text(
                            'Reserve Now',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
        ],
      ),
    );
  }

  void showCollectionMethodDialog({
    required double discounted,
    required String pickup,
    required String address,
  }) async {
    double deliveryFee = 2.5;
    final subtotal = discounted * quantity;

    // --- Dialog-local state ---
    String selectedMethod = 'pickup';
    String? errorText;
    final addressController = TextEditingController();
    final phoneController = TextEditingController();

    // --- Helper widget for radio card ---
    Widget collectionOption({
      required bool selected,
      required void Function()? onTap,
      required Color highlightColor,
      required IconData icon,
      required String title,
      required String subtitle,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? highlightColor : Color(0xFFE5E7EB),
              width: selected ? 2 : 1.2,
            ),
            borderRadius: BorderRadius.circular(12),
            color: selected ? highlightColor.withOpacity(0.09) : Colors.white,
          ),
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 13),
          child: Row(
            children: [
              Icon(icon, color: highlightColor, size: 27),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13.2,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? highlightColor : Colors.grey,
                size: 23,
              ),
            ],
          ),
        ),
      );
    }

    await showDialog(
      context: context,
      builder: (context) {
        bool deliveryChecked = false;
        bool deliveryAvailable = true;
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            if (!deliveryChecked) {
              deliveryChecked = true;
              final restaurantId =
                  (widget.offer['restaurant']?['id'] ??
                          widget.offer['restaurantId'] ??
                          '')
                      .toString();
              _checkDeliveryAvailable(restaurantId).then((val) {
                setState(() {
                  deliveryAvailable = val;
                });
              });
            }
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(19),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22.0,
                  vertical: 22.5,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- Title & description
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Choose Collection Method",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 19.5,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      SizedBox(height: 3),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "How would you like to receive your order?",
                          style: TextStyle(
                            fontSize: 15.2,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      SizedBox(height: 18),

                      // --- Pickup Option Card
                      collectionOption(
                        selected: selectedMethod == "pickup",
                        onTap: () {
                          setState(() {
                            selectedMethod = "pickup";
                            errorText = null; // clear error
                          });
                        },
                        highlightColor: Color(0xFF3D9176),
                        icon: Icons.storefront,
                        title: "On-site Pickup",
                        subtitle: "Free - Collect from restaurant",
                      ),

                      if (!deliveryChecked) ...[
                        SizedBox(height: 14),
                        Row(
                          children: [
                            CircularProgressIndicator(strokeWidth: 2),
                            SizedBox(width: 12),
                            Text("Checking delivery availability..."),
                          ],
                        ),
                      ] else if (deliveryChecked && deliveryAvailable)
                        collectionOption(
                          selected: selectedMethod == "delivery",
                          onTap: () {
                            setState(() {
                              selectedMethod = "delivery";
                              errorText = null;
                            });
                          },
                          highlightColor: Color(0xFF9A65A6),
                          icon: Icons.local_shipping,
                          title: "Home Delivery",
                          subtitle:
                              "+€${deliveryFee.toStringAsFixed(2)} - Delivered to your door",
                        )
                      else
                        collectionOption(
                          selected: false,
                          onTap: null, // disables this card!
                          highlightColor: Colors.grey,
                          icon: Icons.local_shipping,
                          title: "Home Delivery (Unavailable)",
                          subtitle: "No deliverers available right now",
                        ),

                      // --- Delivery Fields if selected
                      if (selectedMethod == "delivery") ...[
                        SizedBox(height: 4),
                        TextField(
                          controller: addressController,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 12,
                            ),
                            labelText: "Delivery address",
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.5),
                              borderSide: BorderSide(color: Color(0xFFE6E8EB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.5),
                              borderSide: BorderSide(color: Color(0xFF3D9176)),
                            ),
                            floatingLabelStyle: TextStyle(
                              color: Color(0xFF3D9176),
                            ),
                          ),
                        ),
                        SizedBox(height: 9),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 12,
                            ),
                            labelText: "Phone number",
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.5),
                              borderSide: BorderSide(color: Color(0xFFE6E8EB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.5),
                              borderSide: BorderSide(color: Color(0xFF3D9176)),
                            ),
                            floatingLabelStyle: TextStyle(
                              color: Color(0xFF3D9176),
                            ),
                          ),
                        ),
                        SizedBox(height: 7),
                        // --- Inline Error Message
                        if (errorText != null) ...[
                          SizedBox(height: 6),
                          Text(
                            errorText!,
                            style: TextStyle(
                              color: Colors.red[600],
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],

                      SizedBox(height: 7),

                      // --- Cart/price summary box
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Color(0xFFF6F6F8),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Subtotal line
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subtotal ($quantity item${quantity == 1 ? '' : 's'})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black87,
                                    fontSize: 15.8,
                                  ),
                                ),
                                Text(
                                  '€${subtotal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    color: Colors.black87,
                                    fontSize: 15.8,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 5),
                            // Total line
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.2,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '€${(subtotal + (selectedMethod == 'delivery' ? deliveryFee : 0)).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17.5,
                                    color: Color(0xFF3D9176),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // --- Button Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Color(0xFF3D9176),
                                side: BorderSide(
                                  color: Color(0xFF3D9176),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 13),
                                textStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.5,
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('Cancel'),
                            ),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF3D9176),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 11),
                                textStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              onPressed: _isCreatingOrder
                                  ? null
                                  : () async {
                                if (selectedMethod == 'delivery' &&
                                    (addressController.text.isEmpty ||
                                        phoneController.text.isEmpty)) {
                                  setState(() {
                                    errorText =
                                        "Enter address & phone for delivery!";
                                  });
                                  return;
                                }
                                // Clear errors and proceed
                                setState(() {
                                  errorText = null;
                                });
                                // ✅ FIXED: Update the class-level selectedPayment before navigating
                                this.selectedPayment = 'card'; // or get from payment selector
                                Navigator.of(context).pop();
                                await _createOrderAndPay(
                                  {
                                    "restaurantId": widget.offer['restaurant']['id'],
                                    "offerId": widget.offer['id'].toString(),
                                    "items": {"offerId": widget.offer['id'], "quantity": quantity},

                                    "total": (discounted * quantity).toDouble(), // ensure double type!
                                    "collectionMethod": selectedMethod.toUpperCase(),
                                    "deliveryAddress": selectedMethod == 'delivery'
                                        ? addressController.text.trim()
                                        : null,
                                    "deliveryPhone": selectedMethod == 'delivery'
                                        ? phoneController.text.trim()
                                        : null,
                                    "deliveryFee": deliveryFee,
                                    "paymentMethod": "CARD",
                                    "paymentDetails": {
                                    "status": "pending",
                                    "provider": selectedPayment.toLowerCase() // ✅ Now accessible
                                    }
                                  },
                                  context,
                                );
                              },
                              child: _isCreatingOrder
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text('Confirm and Pay'),
                            ),
                          ),
                        ],
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

  Future<void> _createOrderAndPay(
    Map<String, dynamic> orderDetails,
    BuildContext context,
  ) async {
    if (_isCreatingOrder) return;
    if (mounted) {
      setState(() => _isCreatingOrder = true);
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt');
    if (token == null) {
      // Handle user not logged in
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You are not logged in.')),
      );
      if (mounted) {
        setState(() => _isCreatingOrder = false);
      }
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl('orders')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(orderDetails),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final orderId =
            (responseData['order']?['id'] ?? responseData['orderId'])
                ?.toString();
        final clientSecret = responseData['clientSecret'];
        final totalAmount =
            (orderDetails['total'] is num)
                ? (orderDetails['total'] as num).toDouble()
                : 0.0;

        if (orderId == null || orderId.isEmpty || orderId == 'null') {
          throw Exception('Order created but no order id returned by backend');
        }

        // Navigate to a success page or show a success message
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OrderCheckoutScreen(
              orderDetails: orderDetails,
              orderId: orderId,
              totalAmount: totalAmount,
              clientSecret: clientSecret,
            ),
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        // Handle error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to create order: ${errorData['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingOrder = false);
      }
    }
  }

  // Helpers to render summary/info

  Widget _summaryRow(String left, String right, [bool strong = false]) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              left,
              style: TextStyle(
                fontWeight: strong ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
              ),
            ),
            Text(
              right,
              style: TextStyle(
                fontWeight: strong ? FontWeight.bold : FontWeight.w500,
                fontSize: 15.4,
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

  Widget _infoRow(String left, String right, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3.5),
    child: Row(
      crossAxisAlignment:
          CrossAxisAlignment.start, // handles long multiline addresses
      children: [
        SizedBox(
          width: 95,
          child: Text(
            left,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        Expanded(
          child: Text(
            right,
            style: TextStyle(
              fontWeight: strong ? FontWeight.bold : FontWeight.normal,
              color: Color(0xFF445566),
              fontSize: 15,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}