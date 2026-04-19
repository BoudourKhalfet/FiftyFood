import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';

String shortenText(String s, {int limit = 10}) {
  if (s.length <= limit * 2) return s;
  return '${s.substring(0, limit)}...${s.substring(s.length - limit)}';
}

void showPickupQRCodeModal(
  BuildContext context, {
  required String qrData,
  required String displayCode,
  required String pickupSlot,
  required String restaurantName,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 38),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 30, 30, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  'Your Pickup QR Code',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Show this code to collect your order',
                  style: TextStyle(
                    fontSize: 15.2,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // QR and code
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 26,
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: qrData,
                        size: 105,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        displayCode,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          fontSize: 17,
                          letterSpacing: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Keep value text pinned to the right edge for consistent alignment.
                _modalInfoRow('Pickup:', pickupSlot),
                SizedBox(height: 7),
                _modalInfoRow('Restaurant:', restaurantName),
                const SizedBox(height: 16),
                Divider(height: 19, thickness: 1),
                const SizedBox(height: 2),

                // Go Back Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3D9176),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Go Back',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Close Icon
          Positioned(
            right: 9,
            top: 9,
            child: IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: Icon(Icons.close, size: 26, color: Colors.black45),
              splashRadius: 22,
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _modalInfoRow(String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 95,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontWeight: FontWeight.w400,
            color: Colors.black87,
            fontSize: 15,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

Widget universalImage(
  String imgUrl, {
  double height = 180,
  double? width,
  BoxFit fit = BoxFit.cover,
}) {
  if (imgUrl.isEmpty) {
    return Container(height: height, width: width, color: Colors.grey[200]);
  }
  if (imgUrl.startsWith('http')) {
    return Image.network(imgUrl, height: height, width: width, fit: fit);
  }
  if (imgUrl.startsWith('data:image')) {
    try {
      final bytes = base64Decode(imgUrl.split(',').last);
      return Image.memory(bytes, height: height, width: width, fit: fit);
    } catch (_) {
      return Container(height: height, width: width, color: Colors.grey[200]);
    }
  }
  // fallback, in case someone sends raw base64 (not data URI)
  try {
    final bytes = base64Decode(imgUrl);
    return Image.memory(bytes, height: height, width: width, fit: fit);
  } catch (_) {
    return Container(height: height, width: width, color: Colors.grey[200]);
  }
}

class OrderCard extends StatelessWidget {
  final String status;
  final String collectionMethod;
  final String mealName;
  final String restaurantName;
  final String timeSlot;
  final String date;
  final String imageUrl;
  final double price;
  final VoidCallback? onViewQR;
  final VoidCallback? onRateRestaurant;
  final VoidCallback? onReportRestaurant;
  final VoidCallback? onRateDeliverer;
  final VoidCallback? onReportDeliverer;
  final bool canViewQR;
  final bool canRateRestaurant;
  final bool canReportRestaurant;
  final bool canRateDeliverer;
  final bool canReportDeliverer;
  final String reference;
  final String? pickupQrToken;
  final String? pickupQrDisplay;
  final Widget? bottomButton;

  const OrderCard({
    super.key,
    required this.status,
    required this.collectionMethod,
    required this.mealName,
    required this.restaurantName,
    required this.timeSlot,
    required this.date,
    required this.imageUrl,
    required this.price,
    this.onViewQR,
    this.onRateRestaurant,
    this.onReportRestaurant,
    this.onRateDeliverer,
    this.onReportDeliverer,
    this.canViewQR = false,
    this.canRateRestaurant = false,
    this.canReportRestaurant = false,

    this.canRateDeliverer = false,
    this.canReportDeliverer = false,
    required this.reference,
    this.pickupQrToken,
    this.pickupQrDisplay,
    this.bottomButton,
  });

  // Status/label color logic
  Color getStatusColor(BuildContext context) {
    switch (status) {
      case 'READY':
        return Colors.green;
      case 'PAID':
        return Colors.teal;
      case 'PICKED_UP':
        return Colors.red;
      case 'DELIVERED':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          universalImage(
            imageUrl,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
          ),

          // Info box
          Container(
            color: Color(0xFFF7FAF9), // Soft green-tinted background
            padding: EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badges
                Row(
                  children: [
                    _Badge(
                      label: _statusLabel(status),
                      color: getStatusColor(context),
                    ),
                    SizedBox(width: 8),
                    _Badge(
                      label: _capitalize(collectionMethod),
                      color: collectionMethod == 'PICKUP'
                          ? Colors.teal[300]!
                          : Colors.deepPurple[300]!,
                    ),
                  ],
                ),

                SizedBox(height: 9),

                // Meal Name
                Text(
                  mealName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Restaurant Name
                Text(
                  restaurantName,
                  style: TextStyle(
                    color: Colors.teal,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),

                // Time & Date Row
                Row(
                  children: [
                    Icon(Icons.access_time, size: 17, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(timeSlot, style: TextStyle(fontSize: 14)),
                    SizedBox(width: 13),
                    Icon(
                      Icons.calendar_today,
                      size: 15,
                      color: Colors.grey[600],
                    ),
                    SizedBox(width: 3),
                    Text(date, style: TextStyle(fontSize: 14)),
                  ],
                ),
                SizedBox(height: 12),

                // Price and QR
                Row(
                  children: [
                    Text(
                      "€${price.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 21.5,
                        color: Colors.teal[700],
                      ),
                    ),
                    Spacer(),
                    if (canViewQR)
                      OutlinedButton.icon(
                        icon: Icon(Icons.qr_code, size: 19),
                        label: Text("View QR Code"),

                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.teal[700],
                          side: BorderSide(color: Colors.teal[700]!),
                          textStyle: TextStyle(fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 9,
                          ),
                        ),
                        onPressed: () => showPickupQRCodeModal(
                          context,
                          qrData:
                              (pickupQrToken != null &&
                                  pickupQrToken!.trim().isNotEmpty)
                              ? pickupQrToken!
                              : reference,
                          displayCode:
                              (pickupQrDisplay != null &&
                                  pickupQrDisplay!.trim().isNotEmpty)
                              ? pickupQrDisplay!
                              : reference,
                          pickupSlot: timeSlot,
                          restaurantName: restaurantName,
                        ),
                      ),
                  ],
                ),
                if (canRateRestaurant ||
                    canReportRestaurant ||
                    canRateDeliverer ||
                    canReportDeliverer)
                  Padding(
                    padding: const EdgeInsets.only(top: 14.0),
                    child: Column(
                      children: [
                        // Restaurant actions
                        Row(
                          children: [
                            if (canRateRestaurant)
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.star_border),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF199060),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                  label: Text(
                                    "Rate Restaurant",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  onPressed: onRateRestaurant,
                                ),
                              ),
                            if (canReportRestaurant)
                              Expanded(
                                child: TextButton.icon(
                                  icon: Icon(Icons.report, color: Colors.red),
                                  label: Text(
                                    "Report Restaurant",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: onReportRestaurant,
                                ),
                              ),
                          ],
                        ),
                        // Deliverer actions
                        if (collectionMethod == "DELIVERY")
                          Row(
                            children: [
                              if (canRateDeliverer)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.star_border),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF199060),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                    ),
                                    label: Text("Rate Deliverer"),
                                    onPressed: onRateDeliverer,
                                  ),
                                ),
                              if (canReportDeliverer)
                                Expanded(
                                  child: TextButton.icon(
                                    icon: Icon(Icons.report, color: Colors.red),
                                    label: Text(
                                      "Report Deliverer",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: onReportDeliverer,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                if (bottomButton != null) ...[
                  SizedBox(height: 12),
                  bottomButton!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String? str) => (str?.isEmpty ?? true)
      ? ''
      : str![0].toUpperCase() + str.substring(1).toLowerCase();

  String _statusLabel(String st) {
    switch (st) {
      case 'PENDING':
        return 'Pending';
      case 'CONFIRMED':
        return 'Confirmed';
      case 'READY':
        return 'Ready';
      case 'PICKED_UP':
        return 'Picked Up';
      case 'DELIVERED':
        return 'Delivered';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return st; // Or just return the status, capitalized or with a warning
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
