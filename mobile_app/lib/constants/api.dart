const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
<<<<<<< HEAD
  defaultValue: 'http://192.168.61.154:3000/',
=======
  defaultValue: 'http://192.168.46.51:3000/',
>>>>>>> 18e96f867249be3dc473e4db2f6328544757fa0f
);

String apiUrl(String path) {
  final normalizedBase = apiBaseUrl.endsWith('/') ? apiBaseUrl : '$apiBaseUrl/';
  final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
  return '$normalizedBase$normalizedPath';
}
