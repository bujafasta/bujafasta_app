import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/services/shop_cache_service.dart';

Future<void> openMyShop(BuildContext context) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  // 1️⃣ NOT LOGGED IN → login first
  if (user == null) {
    Navigator.pushNamed(context, '/login', arguments: {"redirect": "my_shop"});
    return;
  }

  // =================================================
  // 2️⃣ FAST PATH → CHECK CACHE FIRST ⚡
  // =================================================
  final hasShopCached = await ShopCacheService.hasShop();

  if (hasShopCached) {
    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
      arguments: {'openShop': true},
    );
    return;
  }

  // =================================================
  // 3️⃣ FALLBACK → CHECK SUPABASE ONCE 🌐
  // =================================================
  final shop = await client
      .from('shops')
      .select('id')
      .eq('owner_id', user.id)
      .maybeSingle();

  // ❌ No shop → go create shop
  if (shop == null) {
    if (!context.mounted) return;
    Navigator.pushNamed(context, '/create-shop');
    return;
  }

  // ✅ Shop exists → CACHE IT FOREVER
  await ShopCacheService.setHasShop(true);

  // 🚀 Navigate exactly like before
  if (!context.mounted) return;
  Navigator.pushNamedAndRemoveUntil(
    context,
    '/home',
    (route) => false,
    arguments: {'openShop': true},
  );
}
