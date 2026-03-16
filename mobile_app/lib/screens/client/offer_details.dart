import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../widgets/main_scaffold.dart';
import 'restaurant_details.dart';

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
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              final restaurantUserId =
                                  offer['restaurant']?['id'];
                              print(
                                'Tapped restaurant with userId=$restaurantUserId',
                              );
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
                                    name,
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
                            // TODO: Reserve logic
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
}
