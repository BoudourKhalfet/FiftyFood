import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RestaurantDetailsPage extends StatefulWidget {
  final String restaurantId;

  const RestaurantDetailsPage({required this.restaurantId, Key? key})
    : super(key: key);

  @override
  State<RestaurantDetailsPage> createState() => _RestaurantDetailsPageState();
}

class _RestaurantDetailsPageState extends State<RestaurantDetailsPage> {
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = fetchRestaurantData(widget.restaurantId);
  }

  Future<Map<String, dynamic>> fetchRestaurantData(String id) async {
    final url = Uri.parse('http://192.168.100.6:3000/api/restaurants/$id');
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
                                Row(
                                  children: [
                                    const Text('Your rating:'),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          Icons.star_border,
                                          color: Colors.amber[600],
                                        );
                                      }),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '0/5',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 9),
                                TextField(
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
                                    onPressed: () {},
                                    child: const Text(
                                      'Submit Review',
                                      style: TextStyle(
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
                                                  review['date'] ??
                                                      review['createdAt'] ??
                                                      "",
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
