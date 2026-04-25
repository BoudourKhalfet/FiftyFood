import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../constants/api.dart';
import 'package:http_parser/http_parser.dart';
import '../models/deliverer_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map data, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$apiBaseUrl$endpoint');
    final isAuthEndpoint = endpoint.startsWith('auth/');
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt');
    final defaultHeaders = {
      'Content-Type': 'application/json',
      if (!isAuthEndpoint && jwt != null) 'Authorization': 'Bearer $jwt',
    };
    final mergedHeaders = {...defaultHeaders, ...?headers};

    print('POST $url\n  Headers: $mergedHeaders\n  Body: $data');
    try {
      final res = await http
          .post(url, headers: mergedHeaders, body: jsonEncode(data))
          .timeout(
            Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Request timeout after 30 seconds');
            },
          );
      print('POST RESPONSE: ${res.statusCode} ${res.body}');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (res.body.trim().isEmpty) {
          return <String, dynamic>{};
        }
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        print('POST ERROR: ${res.statusCode} ${res.body}');
        try {
          return jsonDecode(res.body) as Map<String, dynamic>;
        } catch (e) {
          throw Exception("HTTP ${res.statusCode}: ${res.body}");
        }
      }
    } catch (e) {
      print('POST Exception: $e');
      rethrow;
    }
  }

  static Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$apiBaseUrl$endpoint');
    final res = await http.get(url, headers: headers);
    print('RAW RESPONSE: ${res.statusCode} ${res.body}');
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    } else {
      // Capture code/message for custom handling above
      try {
        final err = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception('[${err['code']}] ${err['message']}');
      } catch (e) {
        print('GET ERROR: ${res.statusCode} ${res.body}');
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }
    }
  }

  static Future<List<dynamic>> getList(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$apiBaseUrl$endpoint');
    final res = await http.get(url, headers: headers);

    print('RAW RESPONSE LIST: ${res.statusCode} ${res.body}');

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as List<dynamic>;
    } else {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map data, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$apiBaseUrl$endpoint');

    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt');
    final defaultHeaders = {
      'Content-Type': 'application/json',
      if (jwt != null) 'Authorization': 'Bearer $jwt',
    };
    final mergedHeaders = {...defaultHeaders, ...?headers};

    final res = await http.patch(
      url,
      headers: mergedHeaders,
      body: jsonEncode(data),
    );

    print('RAW RESPONSE PATCH: ${res.statusCode} ${res.body}');
    print('PATCH to $url');
    print('Request headers: ${mergedHeaders.toString()}');
    print('Request body: $data');

    final decoded = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(decoded['message'] ?? 'HTTP ${res.statusCode}');
    }

    return decoded;
  }

  static Future<Map<String, dynamic>> uploadFile(
    String endpoint,
    String fieldName,
    String filePath, {
    Map<String, String>? headers,
    String? path,
    Uint8List? bytes,
    String? fileName,
  }) async {
    final url = Uri.parse('$apiBaseUrl$endpoint');
    var request = http.MultipartRequest('POST', url);
    if (headers != null) request.headers.addAll(headers);

    if (bytes != null && fileName != null) {
      // Guess content type based on file extension
      String? contentType;
      if (fileName.toLowerCase().endsWith('.jpg') ||
          fileName.toLowerCase().endsWith('.jpeg')) {
        contentType = "image/jpeg";
      } else if (fileName.toLowerCase().endsWith('.png')) {
        contentType = "image/png";
      } else if (fileName.toLowerCase().endsWith('.pdf')) {
        contentType = "application/pdf";
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: fileName,
          contentType: contentType != null
              ? MediaType.parse(contentType)
              : null,
        ),
      );
    } else if (filePath.isNotEmpty && fileName != null) {
      String? contentType;
      if (fileName.toLowerCase().endsWith('.jpg') ||
          fileName.toLowerCase().endsWith('.jpeg')) {
        contentType = "image/jpeg";
      } else if (fileName.toLowerCase().endsWith('.png')) {
        contentType = "image/png";
      } else if (fileName.toLowerCase().endsWith('.pdf')) {
        contentType = "application/pdf";
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          fieldName,
          filePath,
          filename: fileName,
          contentType: contentType != null
              ? MediaType.parse(contentType)
              : null,
        ),
      );
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$apiBaseUrl$endpoint');
    final res = await http.delete(url, headers: headers);
    print('RAW RESPONSE DELETE: ${res.statusCode} ${res.body}');
    if (res.body.isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<DelivererProfile> getDelivererProfile(String token) async {
    final res = await ApiService.get(
      'livreur/onboarding/me',
      headers: {'Authorization': 'Bearer $token'},
    );
    return DelivererProfile.fromJson(res as Map<String, dynamic>);
  }
}
