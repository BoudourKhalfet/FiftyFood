import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../widgets/main_scaffold.dart';
import '../../api/api_service.dart';
import 'offer_details.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/client_profile_service.dart';

class _GeoPoint {
  final double lat;
  final double lng;

  const _GeoPoint(this.lat, this.lng);
}

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
  double? _clientLatitude;
  double? _clientLongitude;
  final Map<String, String> _distanceTextOverrides = {};
  final Map<String, _GeoPoint?> _geoCache = {};
  bool _resolvingDistanceFallbacks = false;

  String _offerKey(Map<String, dynamic> offer) {
    return (offer['id'] ?? offer['reference'] ?? offer['photoUrl'] ?? '')
        .toString();
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = (lat2 - lat1) * (3.141592653589793 / 180.0);
    final dLon = (lon2 - lon1) * (3.141592653589793 / 180.0);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1 * (3.141592653589793 / 180.0)) *
            cos(lat2 * (3.141592653589793 / 180.0)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double? _distanceKmForOffer(Map<String, dynamic> offer) {
    for (final key in const [
      'distanceKm',
      'distance',
      'distanceToRestaurantKm',
    ]) {
      final parsed = _asDouble(offer[key]);
      if (parsed != null && parsed >= 0) {
        return parsed;
      }
    }

    final profile = offer['restaurant']?['restaurantProfile'];
    final restaurantLat = _asDouble(profile?['latitude']);
    final restaurantLng = _asDouble(profile?['longitude']);

    if (_clientLatitude == null ||
        _clientLongitude == null ||
        restaurantLat == null ||
        restaurantLng == null) {
      return null;
    }

    return _distanceKm(
      _clientLatitude!,
      _clientLongitude!,
      restaurantLat,
      restaurantLng,
    );
  }

  String _distanceTextForOffer(Map<String, dynamic> offer) {
    final override = _distanceTextOverrides[_offerKey(offer)];
    if (override != null) return override;

    final km = _distanceKmForOffer(offer);
    if (km == null) return 'Distance unavailable';
    return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
  }

  Future<_GeoPoint?> _geocodeAddress(String address) async {
    final query = address.trim().toLowerCase();
    if (query.isEmpty) return null;
    if (_geoCache.containsKey(query)) return _geoCache[query];

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${Uri.encodeComponent(query)}',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'FiftyFood-Mobile/1.0'},
      );

      if (response.statusCode != 200) {
        _geoCache[query] = null;
        return null;
      }

      final rows = jsonDecode(response.body);
      if (rows is! List || rows.isEmpty) {
        _geoCache[query] = null;
        return null;
      }

      final lat = double.tryParse(rows.first['lat']?.toString() ?? '');
      final lng = double.tryParse(rows.first['lon']?.toString() ?? '');
      if (lat == null || lng == null) {
        _geoCache[query] = null;
        return null;
      }

      final point = _GeoPoint(lat, lng);
      _geoCache[query] = point;
      return point;
    } catch (_) {
      _geoCache[query] = null;
      return null;
    }
  }

  Future<void> _resolveDistanceFallbacks() async {
    if (_resolvingDistanceFallbacks || offers.isEmpty) return;
    _resolvingDistanceFallbacks = true;

    try {
      double? clientLat = _clientLatitude;
      double? clientLng = _clientLongitude;
      String clientAddress = '';

      if (clientLat == null || clientLng == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final jwt = prefs.getString('jwt');
          if (jwt != null) {
            final profile = await ProfileService.getProfile(jwt);
            clientLat = profile.lastLatitude;
            clientLng = profile.lastLongitude;
            clientAddress = profile.defaultAddress;
          }
        } catch (_) {
          // Keep fallback best-effort.
        }
      }

      _GeoPoint? clientPoint;
      if (clientLat != null && clientLng != null) {
        clientPoint = _GeoPoint(clientLat, clientLng);
      } else if (clientAddress.trim().isNotEmpty) {
        clientPoint = await _geocodeAddress(clientAddress);
      }

      if (clientPoint == null) return;

      final nextOverrides = Map<String, String>.from(_distanceTextOverrides);

      for (final raw in offers) {
        final offer = Map<String, dynamic>.from(raw as Map);
        final key = _offerKey(offer);
        if (nextOverrides.containsKey(key)) continue;

        final precomputed = _distanceKmForOffer(offer);
        if (precomputed != null && precomputed >= 0) {
          nextOverrides[key] =
              '${precomputed.toStringAsFixed(precomputed >= 10 ? 0 : 1)} km';
          continue;
        }

        final profile = offer['restaurant']?['restaurantProfile'];
        final restaurantLat = _asDouble(profile?['latitude']);
        final restaurantLng = _asDouble(profile?['longitude']);

        _GeoPoint? restaurantPoint;
        if (restaurantLat != null && restaurantLng != null) {
          restaurantPoint = _GeoPoint(restaurantLat, restaurantLng);
        } else {
          final restaurantAddress =
              (profile?['address'] ?? offer['address'] ?? '').toString();
          if (restaurantAddress.trim().isNotEmpty) {
            restaurantPoint = await _geocodeAddress(restaurantAddress);
          }
        }

        if (restaurantPoint == null) continue;

        final km = _distanceKm(
          clientPoint.lat,
          clientPoint.lng,
          restaurantPoint.lat,
          restaurantPoint.lng,
        );
        nextOverrides[key] = '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
      }

      if (!mounted) return;
      setState(() {
        _distanceTextOverrides
          ..clear()
          ..addAll(nextOverrides);
      });
    } finally {
      _resolvingDistanceFallbacks = false;
    }
  }

  String _pickupTimeTextForOffer(Map<String, dynamic> offer) {
    final pickupTime = (offer['pickupTime'] ?? '').toString().trim();
    if (pickupTime.isNotEmpty) return pickupTime;

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
      final serviceEnabled =
          await location.serviceEnabled() || await location.requestService();
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

      if (mounted) {
        setState(() {
          _clientLatitude = current.latitude;
          _clientLongitude = current.longitude;
        });
      }

      await ApiService.patch('users/me/location', {
        'latitude': current.latitude,
        'longitude': current.longitude,
      });

      await _resolveDistanceFallbacks();
    } catch (_) {
      // Keep location sync best-effort; ignore failures here.
      await _resolveDistanceFallbacks();
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
      await _resolveDistanceFallbacks();
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
                final offerMap = Map<String, dynamic>.from(offer as Map);
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
                final pickupTime = _pickupTimeTextForOffer(offerMap);
                final distance = _distanceTextForOffer(offerMap);

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OfferDetails(
                          offer: {
                            ...offerMap,
                            '_pickupTimeText': pickupTime,
                            '_distanceText': distance,
                          },
                        ),
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
