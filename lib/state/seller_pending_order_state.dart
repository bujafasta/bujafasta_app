import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final ValueNotifier<bool> sellerPendingOrderNotifier = ValueNotifier<bool>(
  false,
);

RealtimeChannel? _sellerOrdersChannel;

/// Call this ONCE when app starts (after login)
Future<void> startSellerPendingOrderWatcher() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  if (user == null) return;

  // 1️⃣ Initial check
  await _refreshSellerPendingOrders();

  // 2️⃣ Realtime listener
  _sellerOrdersChannel = client.channel('seller-orders-${user.id}');

  _sellerOrdersChannel!
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'seller_id',
          value: user.id,
        ),
        callback: (_) async {
          await _refreshSellerPendingOrders();
        },
      )
      .subscribe();
}

/// 🔔 PUBLIC helper — can be called from anywhere (accept / reject / confirm)
Future<void> refreshSellerPendingOrders() async {
  await _refreshSellerPendingOrders();
}

/// Checks DB and updates notifier
Future<void> _refreshSellerPendingOrders() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  if (user == null) return;

  final res = await client
      .from('orders')
      .select('id')
      .eq('seller_id', user.id)
      .eq('status', 'pending')
      .limit(1);

  sellerPendingOrderNotifier.value = res.isNotEmpty;
}

/// Cleanup on logout
Future<void> stopSellerPendingOrderWatcher() async {
  await _sellerOrdersChannel?.unsubscribe();
  _sellerOrdersChannel = null;
  sellerPendingOrderNotifier.value = false;
}
