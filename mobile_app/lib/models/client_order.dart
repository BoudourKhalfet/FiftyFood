class ClientOrder {
  final String id;
  final String status;
  final String deliveryMethod; // e.g. 'Delivery', 'Pickup'
  final String restaurant;
  final String mealName;
  final String time;
  final String date;
  final double price;
  final bool delivered;
  final bool qr;
  final String image;

  ClientOrder({
    required this.id,
    required this.status,
    required this.deliveryMethod,
    required this.restaurant,
    required this.mealName,
    required this.time,
    required this.date,
    required this.price,
    required this.delivered,
    required this.qr,
    required this.image,
  });

  factory ClientOrder.fromJson(Map<String, dynamic> json) {
    return ClientOrder(
      id: json['id'],
      status: json['status'],
      deliveryMethod:
          json['deliveryMethod'], // or map from enum/field in backend
      restaurant: json['restaurant'] ?? '',
      mealName: json['mealName'] ?? '',
      time: json['time'] ?? '', // Postprocess as needed
      date: json['date'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      delivered: (json['status'] ?? '') == 'DELIVERED',
      qr: json['qr'] ?? false,
      image: json['image'] ?? '',
    );
  }
}
