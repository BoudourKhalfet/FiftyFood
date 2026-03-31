class DelivererProfile {
  final String? fullName;
  final bool? locationConsentGiven;

  DelivererProfile({this.fullName, this.locationConsentGiven});

  factory DelivererProfile.fromJson(Map<String, dynamic> json) {
    return DelivererProfile(
      fullName: json['fullName'] as String?,
      locationConsentGiven: json['locationConsentGiven'] as bool?,
    );
  }
}
