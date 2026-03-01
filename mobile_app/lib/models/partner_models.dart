// Offer Model
class Offer {
  final String id;
  final String description;
  final double originalPrice;
  final double discountedPrice;
  final String pickupTime;
  final int quantity;
  final String status; // active, paused, sold_out
  final String visibility; // identified, anonymous
  final bool deliveryAvailable;

  Offer({
    required this.id,
    required this.description,
    required this.originalPrice,
    required this.discountedPrice,
    required this.pickupTime,
    required this.quantity,
    required this.status,
    required this.visibility,
    required this.deliveryAvailable,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['id'],
      description: json['description'],
      originalPrice: json['originalPrice'],
      discountedPrice: json['discountedPrice'],
      pickupTime: json['pickupTime'],
      quantity: json['quantity'],
      status: json['status'],
      visibility: json['visibility'],
      deliveryAvailable: json['deliveryAvailable'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'originalPrice': originalPrice,
      'discountedPrice': discountedPrice,
      'pickupTime': pickupTime,
      'quantity': quantity,
      'status': status,
      'visibility': visibility,
      'deliveryAvailable': deliveryAvailable,
    };
  }
}

// Order Model
class Order {
  final String id;
  final String customer;
  final int quantity;
  final String status; // pending, collected
  final String time;
  final String deliveryMethod; // pickup, delivery

  Order({
    required this.id,
    required this.customer,
    required this.quantity,
    required this.status,
    required this.time,
    required this.deliveryMethod,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      customer: json['customer'],
      quantity: json['quantity'],
      status: json['status'],
      time: json['time'],
      deliveryMethod: json['deliveryMethod'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer': customer,
      'quantity': quantity,
      'status': status,
      'time': time,
      'deliveryMethod': deliveryMethod,
    };
  }
}

// Restaurant Model
class Restaurant {
  final String name;
  final String address;
  final String phone;
  final String email;
  final int trustScore;
  final bool documentsVerified;

  Restaurant({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.trustScore,
    required this.documentsVerified,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      name: json['name'],
      address: json['address'],
      phone: json['phone'],
      email: json['email'],
      trustScore: json['trustScore'],
      documentsVerified: json['documentsVerified'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'trustScore': trustScore,
      'documentsVerified': documentsVerified,
    };
  }
}

// Stats Model
class DashboardStats {
  final double totalSales;
  final int mealsSaved;
  final double avgRating;
  final int activeOffers;

  DashboardStats({
    required this.totalSales,
    required this.mealsSaved,
    required this.avgRating,
    required this.activeOffers,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalSales: json['totalSales'],
      mealsSaved: json['mealsSaved'],
      avgRating: json['avgRating'],
      activeOffers: json['activeOffers'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalSales': totalSales,
      'mealsSaved': mealsSaved,
      'avgRating': avgRating,
      'activeOffers': activeOffers,
    };
  }
}
