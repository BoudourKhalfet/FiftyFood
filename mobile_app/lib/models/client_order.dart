class ClientOrder {
  final String id;
  final String status;
  final String deliveryMethod;
  final String restaurantName;
  final String mealName;
  final String timeSlot;
  final String date;
  final double price;
  final String reference;
  final bool delivered;
  final bool qr;
  final String imageUrl;
  final String deliveryAddress;
  final int quantity;
  final String partnerLabel;
  final double delivererRating;
  final String delivererName;
  final String delivererVehicle;
  final String clientLocation;
  final String delivererLocation;
  final String restaurantAddress;
  final String delivererPhone;

  ClientOrder({
    required this.id,
    required this.status,
    required this.deliveryMethod,
    required this.restaurantName,
    required this.mealName,
    required this.timeSlot,
    required this.date,
    required this.price,
    required this.reference,
    required this.delivered,
    required this.qr,
    required this.imageUrl,
    required this.deliveryAddress,
    required this.quantity,
    required this.partnerLabel,
    required this.delivererRating,
    required this.delivererName,
    required this.delivererVehicle,
    required this.clientLocation,
    required this.delivererLocation,
    required this.restaurantAddress,
    required this.delivererPhone,
  });

  factory ClientOrder.fromJson(Map<String, dynamic> json) {
    return ClientOrder(
      id: json['id'] ?? '',
      status: json['status'] ?? '',
      deliveryMethod: json['collectionMethod'] ?? '',
      restaurantName: json['restaurantName'] ?? '',
      mealName: json['mealName'] ?? '',
      timeSlot: json['timeSlot'] ?? '',
      date: json['date'] ?? json['createdAt']?.substring(0, 10) ?? '',
      price: (json['price'] ?? json['total'] ?? 0).toDouble(),
      reference: json['reference'] ?? json['id'] ?? '',
      delivered: json['delivered'] ?? false,
      qr: json['qr'] ?? false,
      imageUrl: json['imageUrl'] ?? '',
      deliveryAddress: json['deliveryAddress'] ?? '',
      quantity: json['quantity'] ?? 1,
      partnerLabel: json['partnerLabel'] ?? '',
      delivererRating: (json['delivererRating'] ?? 0).toDouble(),
      delivererName: json['delivererName'] ?? '',
      delivererVehicle: json['delivererVehicle'] ?? '',
      clientLocation: json['clientLocation'] ?? '',
      delivererLocation: json['delivererLocation'] ?? '',
      restaurantAddress: json['restaurantAddress'] ?? '',
      delivererPhone: json['delivererPhone'] ?? '',
    );
  }
}
