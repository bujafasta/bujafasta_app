import 'package:shared_preferences/shared_preferences.dart';

class PinCacheService {
  static const String _pinSetKey = 'pin_set_cached';

  /// Save PIN status locally
  static Future<void> setPinSet(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pinSetKey, value);
  }

  /// Read PIN status locally
  static Future<bool?> getPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinSetKey);
  }

  /// Clear cache (logout, reset PIN, etc.)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinSetKey);
  }
}
