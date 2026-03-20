import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../widgets/main_scaffold.dart';
import 'restaurant_details.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
  String collectionMethod = 'pickup';
  String? deliveryAddress;
  String? phoneNumber;
  String paymentMethod = 'card';

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
    final name = restProfile?['restaurantName'] ?? '';
    final desc = offer['description'] ?? '';
    final address =
        (restProfile?['address'] ?? offer['address'] ?? 'Address unavailable')
            .toString(); // or offer['address']
    final rating = restProfile?['avgRating'] ?? 4.5;
    final discounted = (offer['discountedPrice'] as num?)?.toDouble() ?? 0.0;
    final original = (offer['originalPrice'] as num?)?.toDouble() ?? 0.0;
    final pickup = offer['pickupTime'] ?? '';
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
                    Row(
                      children: [
                        // Eco & distance badges
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(0xFFEAF9F4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.eco,
                                      size: 21,
                                      color: Color(0xFF3D9176),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Eco-Friendly',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF3D9176),
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Reducing food waste',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF5EDF7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(
                                      Icons.place_outlined,
                                      size: 21,
                                      color: Color(0xFF9A65A6),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Distance',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF9A65A6),
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '0.5 km', // TODO: Dynamically calculate using user and restaurant addresses
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (isAnonymous)
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Color(0xFF3D9176),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              fontStyle: FontStyle
                                  .italic, // make it stand out as anonymous
                            ),
                          )
                        else
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                final restaurantUserId =
                                    offer['restaurant']?['id'];
                                if (restaurantUserId == null ||
                                    restaurantUserId.isEmpty) {
                                  print('No valid restaurant user ID found!');
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
                              child: Tooltip(
                                message: "See restaurant details",
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        color: Color(0xFF3D9176),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: Color(0xFF3D9176),
                                    ),
                                  ],
                                ),
                              ),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFEAF9F4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                color: Color(0xFF3D9176),
                                size: 19,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Pickup Time',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3D9176),
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                pickup,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFF5EDF7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.place_outlined,
                                color: Color(0xFF9A65A6),
                                size: 19,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Distance',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF9A65A6),
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '0.5 km',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ],
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
                              pickup: pickup,
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
      required VoidCallback onTap,
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
        return StatefulBuilder(
          builder: (dialogContext, setState) {
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

                      // --- Delivery Option Card (always visible)
                      collectionOption(
                        selected: selectedMethod == "delivery",
                        onTap: () {
                          setState(() {
                            selectedMethod = "delivery";
                            errorText = null; // clear error
                          });
                        },
                        highlightColor: Color(0xFF9A65A6),
                        icon: Icons.local_shipping,
                        title: "Home Delivery",
                        subtitle:
                            "+€${deliveryFee.toStringAsFixed(2)} - Delivered to your door",
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
                                    color: Color(
                                      0xFF3D9176,
                                    ), // matches your screenshot!
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
                                padding: EdgeInsets.symmetric(vertical: 13),
                                textStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.5,
                                ),
                              ),
                              onPressed: () {
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
                                Navigator.of(context).pop();
                                showPaymentDialog(
                                  collectionMethod: selectedMethod,
                                  deliveryAddress: addressController.text,
                                  phoneNumber: phoneController.text,
                                  deliveryFee: selectedMethod == "delivery"
                                      ? deliveryFee
                                      : 0,
                                  discounted: discounted,
                                  subtotal: subtotal,
                                  total:
                                      subtotal +
                                      (selectedMethod == "delivery"
                                          ? deliveryFee
                                          : 0),
                                  offer: widget.offer,
                                  pickup: pickup,
                                  address: address,
                                );
                              },
                              child: Text('Continue to Payment'),
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

  void showPaymentDialog({
    required String collectionMethod,
    String? deliveryAddress,
    String? phoneNumber,
    required double deliveryFee,
    required double discounted,
    required double subtotal,
    required double total,
    required dynamic offer,
    required String pickup,
    required String address,
  }) {
    String selectedPayment = 'card';

    Widget paymentOption({
      required bool selected,
      required VoidCallback onTap,
      required IconData icon,
      required String label,
      required Color color,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: 11),
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? color : Color(0xFFE5E7EB),
              width: selected ? 2 : 1.2,
            ),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: color.withOpacity(0.13),
                  blurRadius: 3,
                  spreadRadius: 0,
                ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? color : Colors.grey[500], size: 26),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? color : Colors.grey[400],
                size: 22,
              ),
            ],
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(19),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22.0,
                  vertical: 23,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Payment",
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
                          "Choose your payment method and complete your order",
                          style: TextStyle(
                            fontSize: 14.5,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      SizedBox(height: 15),

                      // Summary Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: Color(0xFFF6F6F8),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _summaryRow(
                              'Item',
                              '€${subtotal.toStringAsFixed(2)}',
                            ),
                            _summaryRow('Quantity', '$quantity'),
                            if (deliveryFee > 0)
                              _summaryRow(
                                'Delivery fee',
                                '€${deliveryFee.toStringAsFixed(2)}',
                              ),
                            _summaryRow(
                              'Collection',
                              collectionMethod == 'pickup'
                                  ? 'On-site Pickup'
                                  : 'Home Delivery',
                            ),
                            Divider(height: 17),
                            _summaryRow(
                              'Total',
                              '€${total.toStringAsFixed(2)}',
                              true,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),

                      // "Payment Method"
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Payment Method",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      paymentOption(
                        selected: selectedPayment == 'card',
                        onTap: () => setState(() => selectedPayment = 'card'),
                        icon: Icons.credit_card,
                        label: "Credit / Debit Card",
                        color: Color(0xFF3D9176),
                      ),
                      paymentOption(
                        selected: selectedPayment == 'd17',
                        onTap: () => setState(() => selectedPayment = 'd17'),
                        icon: Icons.account_balance_wallet_outlined,
                        label: "D17",
                        color: Color(0xFF9A65A6),
                      ),
                      paymentOption(
                        selected: selectedPayment == 'cash',
                        onTap: () => setState(() => selectedPayment = 'cash'),
                        icon: Icons.payments_outlined,
                        label: "Cash (pay at pickup/delivery)",
                        color: Color(0xFF607274),
                      ),
                      SizedBox(height: 11),

                      // Order info (pickup/delivery details)
                      if (collectionMethod == 'pickup') ...[
                        _infoRow('Pickup:', pickup),
                        _infoRow('Location:', address),
                      ],
                      if (collectionMethod == 'delivery') ...[
                        _infoRow('Delivery:', deliveryAddress ?? ''),
                        _infoRow('Phone:', phoneNumber ?? ''),
                      ],

                      SizedBox(height: 18),

                      // Button row
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
                                  fontSize: 16,
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('Back'),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF3D9176),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 13),
                                textStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              onPressed: () async {
                                Navigator.of(context).pop();
                                String orderCode = await _submitReservation(
                                  collectionMethod: collectionMethod,
                                  deliveryAddress: deliveryAddress,
                                  phoneNumber: phoneNumber,
                                  discounted: discounted,
                                  deliveryFee: deliveryFee,
                                  subtotal: subtotal,
                                  total: total,
                                  quantity: quantity,
                                  paymentMethod: selectedPayment,
                                  offer: offer,
                                );
                                if (collectionMethod == "pickup") {
                                  showPickupQRDialog(
                                    qrCode: orderCode,
                                    pickupTime: pickup,
                                    restaurantName:
                                        offer['restaurant']?['restaurantProfile']?['restaurantName'] ??
                                        "",
                                  );
                                }
                              },

                              child: Text('Pay €${total.toStringAsFixed(2)}'),
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

  void showPickupQRDialog({
    required String qrCode,
    required String pickupTime,
    required String restaurantName,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 26.0,
              vertical: 29.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Your Pickup QR Code",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.5),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  "Show this code to collect your order",
                  style: TextStyle(fontSize: 14.2, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFF6F6F8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 18, horizontal: 28),
                  child: Column(
                    children: [
                      // The QR image:
                      QrImageView(
                        data:
                            qrCode, // order reference, ID, or whatever backend provides
                        size: 120,
                        backgroundColor: Colors.white,
                      ),
                      SizedBox(height: 8),
                      Text(
                        qrCode, // human copy of the code
                        style: TextStyle(
                          letterSpacing: 2.2,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.2,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 15),
                _infoRow("Pickup:", pickupTime),
                _infoRow("Restaurant:", restaurantName),
                SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3D9176),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 13),
                      textStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text("Go Back"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> _submitReservation({
    required String collectionMethod,
    String? deliveryAddress,
    String? phoneNumber,
    required double deliveryFee,
    required double subtotal,
    required double total,
    required int quantity,
    required String paymentMethod,
    required dynamic offer,
    required double discounted,
  }) async {
    try {
      // Build paymentDetails (empty for cash, add reference/tx for real card/D17).
      Map<String, dynamic>? paymentDetails;
      if (paymentMethod == "card") {
        paymentDetails = {
          // You'd set these after integrating with a card gateway
          "provider": "stripe",
          //"transactionId": "ch_123",
          "status": "pending",
        };
      } else if (paymentMethod == "d17") {
        paymentDetails = {
          // You'd set these after integrating with D17
          "provider": "d17",
          //"transactionId": ...
          "status": "pending",
        };
      }

      // If you have a logged-in client user, add clientId or handle on backend.
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('clientId');
      final data = {
        // "clientId": clientId, // Only include if required and non-null string!
        "restaurantId": offer['restaurant']['id'],
        "items": {"offerId": offer['id'], "quantity": quantity},

        "total": (discounted * quantity).toDouble(), // ensure double type!
        "collectionMethod": collectionMethod.toUpperCase(),
        "deliveryAddress": deliveryAddress,
        "deliveryPhone": phoneNumber,
        "deliveryFee": deliveryFee,
        "paymentMethod": paymentMethod.toUpperCase(),
        "paymentDetails": paymentDetails,
      };

      final token = prefs.getString('jwt');

      final response = await http.post(
        Uri.parse('http://localhost:3000/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final order = decoded['order'];
        final qrCode = order['reference'] ?? '';
        showPickupQRDialog(
          qrCode: qrCode,
          pickupTime: order['pickupTime'] ?? '',
          restaurantName: order['restaurantName'] ?? '',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Reservation successful!")));
        return qrCode;
      } else {
        throw Exception('Reservation failed: ${response.body}');
      }
      // If needed, pop or redirect:
      // Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      // Show error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Reservation failed: $e")));
      return Future.error(e);
    }
  }

  // Helpers to render summary/info

  Widget paymentOption({
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    Color? color,
  }) {
    color ??= Color(0xFF3D9176);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 11),
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? color : Color(0xFFE5E7EB),
            width: selected ? 2 : 1.2,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: color.withOpacity(0.13),
                blurRadius: 3,
                spreadRadius: 0,
              ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? color : Colors.grey[500], size: 26),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? color : Colors.grey[400],
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment:
          CrossAxisAlignment.start, // handles long multiline addresses
      children: [
        Text(left, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Flexible(
          child: Text(
            right,
            style: TextStyle(
              fontWeight: strong ? FontWeight.bold : FontWeight.normal,
              color: Color(0xFF445566),
              fontSize: 15,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    ),
  );
}
