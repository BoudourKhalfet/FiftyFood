import 'package:flutter/material.dart';
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
  String _selectedOfferStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchOffers();
  }

  Future<void> fetchOffers() async {
    await _fetchOffers();
  }

  Future<void> _fetchOffers() async {
    setState(() {
      _offersLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) {
        setState(() {
          _offers = [];
          _offersLoading = false;
        });
        return;
      }

      final result = await ApiService.getList(
        'offers/my',
        headers: {'Authorization': 'Bearer $jwt'},
      );

      setState(() {
        _offers = List<Map<String, dynamic>>.from(result);
        _offersLoading = false;
      });
    } catch (_) {
      setState(() {
        _offers = [];
        _offersLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filteredOffers() {
    if (_selectedOfferStatusFilter == 'ALL') return _offers;

    return _offers.where((offer) {
      final status = (offer['status'] ?? 'ACTIVE').toString().toUpperCase();
      return status == _selectedOfferStatusFilter;
    }).toList();
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _discountPct(Map<String, dynamic> offer) {
    final original = _asDouble(offer['originalPrice']);
    final discounted = _asDouble(offer['discountedPrice']);
    if (original <= 0) return 0;
    return (((original - discounted) / original) * 100).round();
  }

  String? _validatePickupTimeWindow(String pickupTime) {
    final parts = pickupTime.split('-').map((s) => s.trim()).toList();
    if (parts.length != 2) {
      return 'Invalid pickup time format.';
    }

    final startParts = parts[0].split(':');
    final endParts = parts[1].split(':');
    if (startParts.length != 2 || endParts.length != 2) {
      return 'Invalid pickup time format.';
    }

    final startHour = int.tryParse(startParts[0]);
    final startMinute = int.tryParse(startParts[1]);
    final endHour = int.tryParse(endParts[0]);
    final endMinute = int.tryParse(endParts[1]);

    if (startHour == null ||
        startMinute == null ||
        endHour == null ||
        endMinute == null) {
      return 'Invalid pickup time format.';
    }

    final now = DateTime.now();
    DateTime start = DateTime(
      now.year,
      now.month,
      now.day,
      startHour,
      startMinute,
    );
    DateTime end = DateTime(now.year, now.month, now.day, endHour, endMinute);

    if (start.isAtSameMomentAs(end)) {
      return 'Pickup start time must be different from end time.';
    }

    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    if (!start.isAfter(now)) {
      start = start.add(const Duration(days: 1));
      end = end.add(const Duration(days: 1));
    }

    if (!start.isAfter(now) || !end.isAfter(now)) {
      return 'Pickup start and end times must be after now.';
    }

    return null;
  }

  Future<void> _showEditOfferDialog(Map<String, dynamic> offer) async {
    final descriptionController = TextEditingController(
      text: (offer['description'] ?? '').toString(),
    );
    String selectedPickupTime = (offer['pickupTime'] ?? '').toString();

    final List<String> basePickupOptions = [
      '11:00 - 12:00',
      '12:00 - 13:00',
      '13:00 - 14:00',
      '17:00 - 18:00',
      '18:00 - 19:00',
      '19:00 - 20:00',
      '20:00 - 21:00',
      'Custom...',
    ];

    final originalPriceController = TextEditingController(
      text: (_asDouble(offer['originalPrice'])).toStringAsFixed(2),
    );
    final discountedPriceController = TextEditingController(
      text: (_asDouble(offer['discountedPrice'])).toStringAsFixed(2),
    );
    final quantityController = TextEditingController(
      text: (offer['quantity'] ?? 1).toString(),
    );

    String? dialogError;
    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
            InputDecoration fieldDecoration(String label, IconData icon) {
              return InputDecoration(
                labelText: label,
                prefixIcon: Icon(
                  icon,
                  size: 18,
                  color: const Color(0xFF6B7280),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF1F9D7A),
                    width: 1.4,
                  ),
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5F0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_note_rounded,
                              color: Color(0xFF1F9D7A),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Edit Offer',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: saving
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        maxLines: 2,
                        decoration: fieldDecoration(
                          'Description',
                          Icons.short_text_rounded,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedPickupTime.isEmpty
                            ? null
                            : selectedPickupTime,
                        decoration: fieldDecoration(
                          'Pickup Time',
                          Icons.schedule_rounded,
                        ),
                        items: (() {
                          final options = List<String>.from(basePickupOptions);
                          if (selectedPickupTime.isNotEmpty &&
                              !options.contains(selectedPickupTime)) {
                            options.insert(0, selectedPickupTime);
                          }
                          return options
                              .map(
                                (v) => DropdownMenuItem<String>(
                                  value: v,
                                  child: Text(v),
                                ),
                              )
                              .toList();
                        })(),
                        onChanged: (value) async {
                          if (value == null) return;
                          if (value == 'Custom...') {
                            final from = await showTimePicker(
                              context: dialogContext,
                              initialTime: TimeOfDay.now(),
                              helpText: 'Pickup From',
                            );
                            if (from == null) return;

                            final to = await showTimePicker(
                              context: dialogContext,
                              initialTime: from.replacing(
                                hour: (from.hour + 1) % 24,
                              ),
                              helpText: 'Pickup To',
                            );
                            if (to == null) return;

                            final now = DateTime.now();
                            final fromDateTime = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              from.hour,
                              from.minute,
                            );
                            final toDateTime = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              to.hour,
                              to.minute,
                            );

                            if (fromDateTime.isAtSameMomentAs(toDateTime)) {
                              setDialogState(() {
                                dialogError =
                                    'Pickup start time must be different from end time.';
                              });
                              return;
                            }

                            DateTime adjustedFrom = fromDateTime;
                            DateTime adjustedTo = toDateTime;
                            if (!adjustedTo.isAfter(adjustedFrom)) {
                              adjustedTo = adjustedTo.add(
                                const Duration(days: 1),
                              );
                            }

                            if (!adjustedFrom.isAfter(now)) {
                              adjustedFrom = adjustedFrom.add(
                                const Duration(days: 1),
                              );
                              adjustedTo = adjustedTo.add(
                                const Duration(days: 1),
                              );
                            }

                            if (!adjustedFrom.isAfter(now) ||
                                !adjustedTo.isAfter(now)) {
                              setDialogState(() {
                                dialogError =
                                    'Pickup start and end times must be after now.';
                              });
                              return;
                            }

                            String twoDigits(int n) =>
                                n.toString().padLeft(2, '0');
                            final custom =
                                '${twoDigits(from.hour)}:${twoDigits(from.minute)} - ${twoDigits(to.hour)}:${twoDigits(to.minute)}';

                            setDialogState(() {
                              selectedPickupTime = custom;
                            });
                          } else {
                            setDialogState(() {
                              selectedPickupTime = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: originalPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: fieldDecoration(
                          'Original Price',
                          Icons.payments_outlined,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: discountedPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: fieldDecoration(
                          'Discounted Price',
                          Icons.local_offer_outlined,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: fieldDecoration(
                          'Quantity',
                          Icons.inventory_2_outlined,
                        ),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Color(0xFFB91C1C),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dialogError!,
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                foregroundColor: const Color(0xFF4B5563),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final description = descriptionController
                                          .text
                                          .trim();
                                      final pickupTime = selectedPickupTime
                                          .trim();
                                      final originalPrice = double.tryParse(
                                        originalPriceController.text.trim(),
                                      );
                                      final discountedPrice = double.tryParse(
                                        discountedPriceController.text.trim(),
                                      );
                                      final quantity = int.tryParse(
                                        quantityController.text.trim(),
                                      );

                                      if (description.isEmpty ||
                                          pickupTime.isEmpty ||
                                          originalPrice == null ||
                                          discountedPrice == null ||
                                          quantity == null) {
                                        setDialogState(() {
                                          dialogError =
                                              'Please fill all fields correctly.';
                                        });
                                        return;
                                      }

                                      if (discountedPrice > originalPrice) {
                                        setDialogState(() {
                                          dialogError =
                                              'Discounted price must be <= original price.';
                                        });
                                        return;
                                      }

                                      final pickupTimeError =
                                          _validatePickupTimeWindow(pickupTime);
                                      if (pickupTimeError != null) {
                                        setDialogState(() {
                                          dialogError = pickupTimeError;
                                        });
                                        return;
                                      }

                                      setDialogState(() {
                                        saving = true;
                                        dialogError = null;
                                      });

                                      try {
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        final jwt = prefs.getString('jwt');
                                        if (jwt == null) {
                                          setDialogState(() {
                                            dialogError =
                                                'Missing session token.';
                                            saving = false;
                                          });
                                          return;
                                        }

                                        await ApiService.patch(
                                          'offers/${offer['id']}',
                                          {
                                            'description': description,
                                            'pickupTime': pickupTime,
                                            'originalPrice': originalPrice,
                                            'discountedPrice': discountedPrice,
                                            'quantity': quantity,
                                          },
                                          headers: {
                                            'Authorization': 'Bearer $jwt',
                                          },
                                        );

                                        if (!mounted) return;
                                        Navigator.of(dialogContext).pop();
                                        await _fetchOffers();
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Offer updated successfully.',
                                            ),
                                            backgroundColor: Color(0xFF1F9D7A),
                                          ),
                                        );
                                      } catch (_) {
                                        setDialogState(() {
                                          dialogError =
                                              'Update failed. Please try again.';
                                          saving = false;
                                        });
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: const Color(0xFFE8F5F0),
                                foregroundColor: const Color(0xFF1F9D7A),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF1F9D7A),
                                      ),
                                    )
                                  : const Text(
                                      'Save',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
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
    } finally {
      descriptionController.dispose();
      originalPriceController.dispose();
      discountedPriceController.dispose();
      quantityController.dispose();
    }
  }

  Future<void> _toggleVisibility(Map<String, dynamic> offer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) return;

      await ApiService.patch(
        'offers/${offer['id']}/visibility',
        {},
        headers: {'Authorization': 'Bearer $jwt'},
      );

      await _fetchOffers();
    } catch (_) {}
  }

  Future<void> _deleteOffer(Map<String, dynamic> offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Offer'),
        content: const Text('Are you sure you want to delete this offer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt');
      if (jwt == null) return;

      await ApiService.delete(
        'offers/${offer['id']}',
        headers: {'Authorization': 'Bearer $jwt'},
      );

      await _fetchOffers();
    } catch (_) {}
  }

  Widget _buildStatusFilterChip(String label, String value) {
    final isSelected = _selectedOfferStatusFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedOfferStatusFilter = value;
        });
      },
      selectedColor: const Color(0xFFE8F5F0),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF1F9D7A) : const Color(0xFF6B7280),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF1F9D7A) : const Color(0xFFE5E7EB),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusFilterChip('All', 'ALL'),
              _buildStatusFilterChip('Active', 'ACTIVE'),
              _buildStatusFilterChip('Paused', 'PAUSED'),
              _buildStatusFilterChip('Expired', 'EXPIRED'),
            ],
          ),
          const SizedBox(height: 14),
          if (_offersLoading)
            const Center(child: CircularProgressIndicator())
          else if (_filteredOffers().isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No offers found.')),
            )
          else
            ..._filteredOffers().map((offer) {
              final status = (offer['status'] ?? 'ACTIVE')
                  .toString()
                  .toUpperCase();
              final visibility = (offer['visibility'] ?? 'IDENTIFIED')
                  .toString()
                  .toUpperCase();
              final imageUrl = (offer['photoUrl'] ?? '').toString();
              final description = (offer['description'] ?? '').toString();
              final discounted = _asDouble(offer['discountedPrice']);
              final original = _asDouble(offer['originalPrice']);
              final quantity = (offer['quantity'] ?? 0).toString();
              final pickupTime = (offer['pickupTime'] ?? '').toString();
              final discount = _discountPct(offer);

              Color statusColor;
              switch (status) {
                case 'ACTIVE':
                  statusColor = const Color(0xFF10B981);
                  break;
                case 'PAUSED':
                  statusColor = const Color(0xFFF59E0B);
                  break;
                case 'EXPIRED':
                  statusColor = const Color(0xFFEF4444);
                  break;
                default:
                  statusColor = const Color(0xFF6B7280);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) =>
                                      Container(
                                        height: 150,
                                        color: const Color(0xFFEFEFEF),
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ),
                                )
                              : Container(
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
                        if (discount > 0)
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
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
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
                            description,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 2,
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
                                      text: '€${discounted.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Color(0xFF1F9D7A),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' €${original.toStringAsFixed(2)}',
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
                                '$quantity left',
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 12,
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
                              Expanded(
                                child: Text(
                                  pickupTime,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _showEditOfferDialog(offer),
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF10B981),
                                    side: const BorderSide(
                                      color: Color(0xFF10B981),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _toggleVisibility(offer),
                                icon: Icon(
                                  visibility == 'ANONYMOUS'
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFF10B981),
                                ),
                                style: IconButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFF10B981),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _deleteOffer(offer),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFEF4444),
                                ),
                                style: IconButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFEF4444),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
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
              );
            }),
        ],
      ),
    );
  }
}
