const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.46.51:3000/',
);

String apiUrl(String path) {
  final normalizedBase = apiBaseUrl.endsWith('/') ? apiBaseUrl : '$apiBaseUrl/';
  final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
  return '$normalizedBase$normalizedPath';
}
