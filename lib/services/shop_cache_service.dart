import 'package:shared_preferences/shared_preferences.dart';

class ShopCacheService {
  // 🔑 KEY used to store shop status
  static const String _hasShopKey = 'has_shop';

  /// ✅ Save that the user HAS a shop
  static Future<void> setHasShop(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasShopKey, value);
  }

  /// 🔍 Check if cached user HAS a shop
  static Future<bool> hasShop() async {
    final prefs = await SharedPreferences.getInstance();

    // If nothing is saved yet → default is false
    return prefs.getBool(_hasShopKey) ?? false;
  }

  /// 🧹 Clear cache (use on logout)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasShopKey);
  }
}
