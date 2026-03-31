import 'package:flutter/material.dart';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_service.dart';

class PartnerOffersTab extends StatefulWidget {
  const PartnerOffersTab({Key? key}) : super(key: key);

  @override
  State<PartnerOffersTab> createState() => PartnerOffersTabState();
}

class PartnerOffersTabState extends State<PartnerOffersTab> {
  List<Map<String, dynamic>> _offers = [];
  bool _offersLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchOffers();
  }

  Future<void> _fetchOffers() async {
    setState(() => _offersLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) {
        setState(() => _offersLoading = false);
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

  Future<void> fetchOffers() async => _fetchOffers();

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
                          child:
                              offer['photoUrl'] != null &&
                                  offer['photoUrl'].toString().isNotEmpty
                              ? Image.network(
                                  offer['photoUrl'],
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) =>
                                      Icon(Icons.broken_image),
                                )
                              : // fallback (placeholder)
                                Container(
                                  height: 150,
                                  color: const Color(0xFFEFEFEF),
                                  child: const Center(
                                    child: Icon(
                                      Icons.fastfood,
                                      color: Color(0xFF9CA3AF),
                                      size: 40,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _buildOffersTab(),
    );
  }
}
