class ClientProfile {
  final String? email;
  final String fullName;
  final String phone;
  final String defaultAddress;
  final String clientType;
  final List<String> cuisinePreferences;
  final DateTime? joinedAt;
  final Map<String, dynamic>? notificationPreferences;
  final bool? locationConsentGiven;
  final double? lastLatitude;
  final double? lastLongitude;
  final String? societyName;
  final String? fiscalNumber;

  ClientProfile({
    required this.email,
    required this.fullName,
    required this.phone,
    required this.defaultAddress,
    required this.clientType,
    required this.cuisinePreferences,
    this.joinedAt,
    this.notificationPreferences,
    required this.locationConsentGiven,
    this.lastLatitude,
    this.lastLongitude,
    this.societyName,
    this.fiscalNumber,
  });

  factory ClientProfile.fromJson(Map<String, dynamic> json) {
    return ClientProfile(
      email: json['email'],
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      defaultAddress: json['defaultAddress'] ?? '',
      clientType: json['clientType'] ?? 'NORMAL',
      cuisinePreferences: List<String>.from(json['cuisinePreferences'] ?? []),
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : null,
      notificationPreferences: json['notificationPreferences'] ?? {},
      locationConsentGiven: json['locationConsentGiven'] as bool?,
      lastLatitude: (json['lastLatitude'] as num?)?.toDouble(),
      lastLongitude: (json['lastLongitude'] as num?)?.toDouble(),
      societyName: json['societyName'],
      fiscalNumber: json['fiscalNumber'],
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
