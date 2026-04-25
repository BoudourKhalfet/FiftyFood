import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants/api.dart';
import '../../api/auth_storage.dart';

class RestaurantDetailsPage extends StatefulWidget {
  final String restaurantId;

  const RestaurantDetailsPage({required this.restaurantId, Key? key})
    : super(key: key);

  @override
  State<RestaurantDetailsPage> createState() => _RestaurantDetailsPageState();
}

class _RestaurantDetailsPageState extends State<RestaurantDetailsPage> {
  late Future<Map<String, dynamic>> _dataFuture;
  final TextEditingController _reviewController = TextEditingController();
  int _selectedRating = 0;
  bool _submittingReview = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = fetchRestaurantData(widget.restaurantId);
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic raw) {
    final parsed = DateTime.tryParse((raw ?? '').toString());
    if (parsed == null) return '';
    final dd = parsed.day.toString().padLeft(2, '0');
    final mm = parsed.month.toString().padLeft(2, '0');
    final yy = (parsed.year % 100).toString().padLeft(2, '0');
    return '$dd/$mm/$yy';
  }

  String _formatEstablishmentType(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return 'Not specified';
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> _submitRestaurantReview() async {
    if (_selectedRating < 1 || _selectedRating > 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a rating.')));
      return;
    }

    final token = await getJwt();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in as client to submit a review.'),
        ),
      );
      return;
    }

    setState(() => _submittingReview = true);
    try {
      final url = Uri.parse(apiUrl('feedback/reviews/restaurant'));
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'restaurantId': widget.restaurantId,
          'rating': _selectedRating,
          'comment': _reviewController.text.trim(),
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        setState(() {
          _selectedRating = 0;
          _reviewController.clear();
          _dataFuture = fetchRestaurantData(widget.restaurantId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully.')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit review.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to submit review.')));
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  Future<Map<String, dynamic>> fetchRestaurantData(String id) async {
    final url = Uri.parse(apiUrl('api/restaurants/$id'));
    final response = await http.get(url); // Add headers if needed (auth etc)
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load restaurant data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No data.'));
          }

          final data = snapshot.data!;
          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top bar
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(right: 17),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.notifications_none_outlined,
                                color: Color(0xFF3D9176),
                              ),
                              SizedBox(width: 13),
                              Icon(Icons.menu, color: Color(0xFF232323)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Cover Photo
                    if (data['coverUrl'] != null &&
                        data['coverUrl'].toString().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          data['coverUrl'],
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18.0,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name with stars/rating only
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  data['restaurantName'] ??
                                      data['name'] ??
                                      'Restaurant',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 24,
                                    color: Color(0xFF232323),
                                  ),
                                ),
                              ),
                              // Show average rating (stars) if available
                              if (data['avgRating'] != null ||
                                  data['rating'] != null)
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAFBE3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 13,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        (data['avgRating'] ??
                                                data['rating'] ??
                                                4.5)
                                            .toString(),
                                        style: const TextStyle(
                                          color: Color(0xFF44AA45),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(
                                        Icons.star,
                                        color: Color(0xFFFFB400),
                                        size: 17,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1.2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.storefront_outlined,
                                  color: Color(0xFF3D9176),
                                  size: 19,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Type: ${_formatEstablishmentType(data['establishmentType'])}',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF232323),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Address & phone row card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 1.5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF3D9176),
                                  size: 21,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    data['address'] ?? "",
                                    style: const TextStyle(
                                      color: Color(0xFF232323),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (data['phone'] != null)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.phone,
                                        color: Color(0xFF3D9176),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        data['phone'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF737373),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Leave a Rating (unchanged)
                          Container(
                            padding: const EdgeInsets.all(13),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1.2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Leave a Rating',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final starButtons = List.generate(5, (
                                      index,
                                    ) {
                                      final star = index + 1;
                                      return IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        iconSize: 22,
                                        splashRadius: 18,
                                        onPressed: () {
                                          setState(() {
                                            _selectedRating = star;
                                          });
                                        },
                                        icon: Icon(
                                          star <= _selectedRating
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber[600],
                                        ),
                                      );
                                    });

                                    if (constraints.maxWidth < 390) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('Your rating:'),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Wrap(
                                                  spacing: 2,
                                                  runSpacing: 2,
                                                  children: starButtons,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '$_selectedRating/5',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    }

                                    return Row(
                                      children: [
                                        const Text('Your rating:'),
                                        const SizedBox(width: 8),
                                        Wrap(spacing: 2, children: starButtons),
                                        const SizedBox(width: 8),
                                        Text(
                                          '$_selectedRating/5',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 9),
                                TextField(
                                  controller: _reviewController,
                                  minLines: 2,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    hintText:
                                        'Share your experience (optional)...',
                                    hintStyle: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFB6B6B6),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 9),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3D9176),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 11,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: _submittingReview
                                        ? null
                                        : _submitRestaurantReview,
                                    child: _submittingReview
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Submit Review',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Reviews list
                          const Text(
                            'Reviews',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 9),
                          ...(data['reviews'] as List<dynamic>? ?? [])
                              .map(
                                (review) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFA1D5BD),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: Color(0xFF357A59),
                                          size: 23,
                                        ),
                                      ),
                                      const SizedBox(width: 13),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  (review['user'] ??
                                                      review['userName'] ??
                                                      ''),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: Color(0xFF3D9176),
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  _formatDate(
                                                    review['date'] ??
                                                        review['createdAt'],
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: List.generate(
                                                review['rating'] ?? 0,
                                                (i) => Icon(
                                                  Icons.star,
                                                  color: Colors.amber[600],
                                                  size: 17,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              review['comment'] ??
                                                  review['text'] ??
                                                  "",
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                color: Color(0xFF374151),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
