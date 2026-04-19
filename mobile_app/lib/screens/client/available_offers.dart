import 'package:flutter/material.dart';
import 'dart:async';
import '../../widgets/main_scaffold.dart';
import '../../api/api_service.dart';
import 'offer_details.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:location/location.dart';

Uint8List? decodeImg(String imgUrl) {
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

class AvailableOffersPage extends StatefulWidget {
  const AvailableOffersPage({super.key});

  @override
  State<AvailableOffersPage> createState() => _AvailableOffersPageState();
}

class _AvailableOffersPageState extends State<AvailableOffersPage> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, Uint8List> _imageCache = {};
  Timer? _locationTimer;
  String _searchTerm = '';
  List<dynamic> filteredOffers = [];
  List<dynamic> offers = [];
  bool isLoading = true;
  String? error;

  void _updateFilteredOffers() {
    setState(() {
      _searchTerm = _searchController.text.trim().toLowerCase();
      filteredOffers = offers.where((offer) {
        final name =
            (offer['restaurant']?['restaurantProfile']?['restaurantName'] ?? '')
                .toString()
                .toLowerCase();
        final desc = (offer['description'] ?? '').toString().toLowerCase();
        return name.contains(_searchTerm) || desc.contains(_searchTerm);
      }).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    fetchOffers();
    _syncClientLocation();
    _locationTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _syncClientLocation();
    });
    _searchController.addListener(_updateFilteredOffers);
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _syncClientLocation() async {
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

      await ApiService.patch('users/me/location', {
        'latitude': current.latitude,
        'longitude': current.longitude,
      });
    } catch (_) {
      // Keep location sync best-effort; ignore failures here.
    }
  }

  Future<void> fetchOffers() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final data = await ApiService.getList('offers');
      setState(() {
        offers = data;
        filteredOffers = data;
        isLoading = false;
        error = null;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load offers. Try again.';
        offers = [];
        filteredOffers = [];
        isLoading = false;
      });
    }
  }

  Widget buildOfferImage(String imgUrl) {
    const height = 180.0;

    if (imgUrl.isEmpty) {
      return Container(height: height, color: Colors.grey[200]);
    }

    // NETWORK IMAGE
    if (imgUrl.startsWith('http')) {
      return Image.network(
        imgUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(height: height, color: Colors.grey[200]);
        },
        errorBuilder: (_, __, ___) =>
            Container(height: height, color: Colors.grey[200]),
      );
    }

    // BASE64 IMAGE
    if (!_imageCache.containsKey(imgUrl)) {
      final decoded = decodeImg(imgUrl);
      if (decoded != null) {
        _imageCache[imgUrl] = decoded;
      }
    }

    final bytes = _imageCache[imgUrl];

    if (bytes != null) {
      return Image.memory(
        bytes,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    return Container(height: height, color: Colors.grey[200]);
  }

  @override
  Widget build(BuildContext context) {
    const textPrimary = Color(0xFF1A1A1A);
    const textSecondary = Color(0xFF6B7280);
    const border = Color(0xFFE5E7EB);
    const accent = Color(0xFF3D9176);

    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final horizontalPadding = isSmallScreen ? 14.0 : 24.0;
    final titleFontSize = isSmallScreen ? 32.0 : 36.0;
    final searchHeight = isSmallScreen ? 34.0 : 40.0;

    return MainScaffold(
      child: RefreshIndicator(
        onRefresh: fetchOffers,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            22,
            horizontalPadding,
            24,
          ),
          children: [
            // Title with Back Arrow
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: textPrimary, size: 28),
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.only(right: 6),
                  splashRadius: 23,
                ),
                SizedBox(width: 2), // optional spacing
                Expanded(
                  child: Text(
                    'Available Offers',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: titleFontSize,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Location indicator
            // Uncomment and implement once you fetch the client location
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //   children: [
            //     Expanded(
            //       child: Text(
            //         locationString ?? 'Select your location',
            //         overflow: TextOverflow.ellipsis,
            //         maxLines: 1,
            //         style: ...
            //       ),
            //     ),
            //     TextButton(
            //       onPressed: () { /* location picker */ },
            //       child: Text('Change location'),
            //     ),
            //   ],
            // ),
            // const SizedBox(height: 16),
            // Search and filter row
            Builder(
              builder: (context) {
                return Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: searchHeight,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search restaurants or dishes.',
                            prefixIcon: Icon(
                              Icons.search,
                              size: 18,
                              color: Color(0xFF9CA3AF),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: border, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 37,
                      height: searchHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent, width: 2),
                      ),
                      child: Icon(Icons.tune, size: 18, color: accent),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Count/offers status
            if (isLoading)
              Text(
                'Loading offers...',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: isSmallScreen ? 13 : 14.8,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w400,
                ),
              )
            else if (error != null)
              Text(
                error!,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: isSmallScreen ? 13 : 14.8,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w400,
                ),
              )
            else
              Text(
                '${filteredOffers.length} offer${filteredOffers.length == 1 ? '' : 's'} available',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: isSmallScreen ? 13 : 14.8,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w400,
                ),
              ),

            const SizedBox(height: 16),

            // Empty state or loading or offers list
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if ((filteredOffers.isEmpty && error == null))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Color(0xFFF3F4F6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No offers yet',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: isSmallScreen ? 16 : 18,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Offers will appear here once restaurants publish new offers.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: isSmallScreen ? 12 : 14,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: fetchOffers,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Refresh',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...filteredOffers.map((offer) {
                final restProfile = offer['restaurant']?['restaurantProfile'];
                final imgUrl = offer['photoUrl'] ?? "";
                final desc = offer['description'] ?? "";
                final isAnonymous = offer['visibility'] == 'ANONYMOUS';
                final restName = isAnonymous
                    ? 'Anonymous'
                    : (offer['restaurant']?['restaurantProfile']?['restaurantName'] ??
                          'Restaurant');
                final rating = (restProfile?['avgRating'] ?? 4.5).toDouble();
                final discounted =
                    (offer['discountedPrice'] as num?)?.toDouble() ?? 0.0;
                final original =
                    (offer['originalPrice'] as num?)?.toDouble() ?? 0.0;
                final qty = offer['quantity'] ?? 1;
                final discountPct = (original > 0)
                    ? ((original - discounted) / original * 100).round()
                    : 0;
                final pickupTime = offer['pickupTime'] ?? '';
                final distance = "0.5 km";

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OfferDetails(offer: offer),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              child: buildOfferImage(imgUrl),
                            ),
                            if (discountPct > 0)
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '-$discountPct%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$qty left',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      restName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                desc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF646464),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    distance,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Icon(
                                    Icons.access_time,
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    pickupTime,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Text(
                                    '€${discounted.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Color(0xFF3D9176),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '€${original.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () {}, // TODO: Save food action
                                    icon: const Icon(
                                      Icons.favorite_border,
                                      color: Color(0xFF3D9176),
                                      size: 21,
                                    ),
                                    label: const Text(
                                      'Save food',
                                      style: TextStyle(
                                        color: Color(0xFF3D9176),
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF3D9176),
                                      minimumSize: const Size(10, 36),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
