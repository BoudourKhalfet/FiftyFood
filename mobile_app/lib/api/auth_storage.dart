import 'package:shared_preferences/shared_preferences.dart';

Future<String?> getJwt() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('jwt');
}
