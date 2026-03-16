import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../constants/api.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map data, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$apiBaseUrl$endpoint');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json', ...?headers},
      body: jsonEncode(data),
    );
    // FIX: Accept any 2xx as success
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else {
      throw Exception("HTTP ${res.statusCode}: ${res.body}");
    }
  }

  static Future<dynamic> get(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$apiBaseUrl$endpoint');
    final res = await http.get(url, headers: headers);
    print('RAW RESPONSE: ${res.statusCode} ${res.body}');
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getList(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$apiBaseUrl$endpoint');
    final res = await http.get(url, headers: headers);
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map data, {
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$apiBaseUrl$endpoint');
    final res = await http.patch(
      url,
      headers: {'Content-Type': 'application/json', ...?headers},
      body: jsonEncode(data),
    );
    print('RAW RESPONSE PATCH: ${res.statusCode} ${res.body}');
    print('PATCH to $url');
    print('Request headers: ${headers.toString()}');
    print('Request body: $data');
    return jsonDecode(res.body) as Map<String, dynamic>;
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
    } else if (filePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
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
}
