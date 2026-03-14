import './api_service.dart';
import '../models/client_profile.dart';
import '../models/client_order.dart';

class ProfileService {
  // Returns a strongly typed ClientProfile object
  static Future<ClientProfile> getProfile(String jwt) async {
    final json = await ApiService.get(
      'users/me',
      headers: {'Authorization': 'Bearer $jwt'},
    );
    // The API returns the user's profile in json['clientProfile']
    // Add a field in your ClientProfile model for email if needed
    return ClientProfile.fromJson({
      ...?json['clientProfile'],
      // If you want email, join from root:
      'email': json['email'], // If ClientProfile has email field
      'joinedAt':
          json['clientProfile']?['joinedAt'] ?? '', // or handle date separately
    });
  }

  // Returns a typed list of ClientOrder objects
  static Future<List<ClientOrder>> getOrders(String jwt) async {
    final result = await ApiService.get(
      'users/me/orders',
      headers: {'Authorization': 'Bearer $jwt'},
    );
    if (result is List) {
      return result
          .map((order) => ClientOrder.fromJson(order as Map<String, dynamic>))
          .toList();
    }
    // Defensive fallback
    return [];
  }

  static Future<void> updateProfile(
    String jwt, {
    String? fullName,
    String? phone,
    String? defaultAddress,
  }) async {
    await ApiService.patch(
      'users/me/profile',
      {
        if (fullName != null) 'fullName': fullName,
        if (phone != null) 'phone': phone,
        if (defaultAddress != null) 'defaultAddress': defaultAddress,
      },
      headers: {'Authorization': 'Bearer $jwt'},
    );
  }

  static Future<void> updatePreferences(
    String jwt, {
    List<String>? cuisinePreferences,
    List<String>? dietaryRestrictions,
  }) async {
    print('ProfileService.updatePreferences CALLED');
    await ApiService.patch(
      'users/me/preferences',
      {
        if (cuisinePreferences != null)
          'cuisinePreferences': cuisinePreferences,
        if (dietaryRestrictions != null)
          'dietaryRestrictions': dietaryRestrictions,
      },
      headers: {'Authorization': 'Bearer $jwt'},
    );
  }

  static Future<void> updateNotifications(
    String jwt,
    Map<String, bool> notificationSettings,
  ) async {
    await ApiService.patch(
      'users/me/notifications',
      notificationSettings,
      headers: {'Authorization': 'Bearer $jwt'},
    );
  }

  static Future<void> changePassword(
    String jwt,
    String oldPassword,
    String newPassword,
  ) async {
    await ApiService.post(
      'users/me/change-password',
      {'oldPassword': oldPassword, 'newPassword': newPassword},
      headers: {'Authorization': 'Bearer $jwt'},
    );
  }

  static Future<void> deleteAccount(String jwt) async {
    await ApiService.delete(
      'users/me',
      headers: {'Authorization': 'Bearer $jwt'},
    );
  }
}
