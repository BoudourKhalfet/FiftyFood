class ClientProfile {
  final String? email;
  final String fullName;
  final String phone;
  final String defaultAddress;
  final List<String> cuisinePreferences;
  final List<String> dietaryRestrictions;
  final DateTime? joinedAt;
  final Map<String, dynamic>? notificationPreferences;

  ClientProfile({
    required this.email,
    required this.fullName,
    required this.phone,
    required this.defaultAddress,
    required this.cuisinePreferences,
    required this.dietaryRestrictions,
    this.joinedAt,
    this.notificationPreferences,
  });

  factory ClientProfile.fromJson(Map<String, dynamic> json) {
    return ClientProfile(
      email: json['email'],
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      defaultAddress: json['defaultAddress'] ?? '',
      cuisinePreferences: List<String>.from(json['cuisinePreferences'] ?? []),
      dietaryRestrictions: List<String>.from(json['dietaryRestrictions'] ?? []),
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : null,
      notificationPreferences: json['notificationPreferences'] ?? {},
    );
  }
}

class ClientUser {
  final String id;
  final String email;
  final ClientProfile clientProfile;

  ClientUser({
    required this.id,
    required this.email,
    required this.clientProfile,
  });

  factory ClientUser.fromJson(Map<String, dynamic> json) {
    return ClientUser(
      id: json['id'],
      email: json['email'],
      clientProfile: ClientProfile.fromJson(json['clientProfile'] ?? {}),
    );
  }
}
