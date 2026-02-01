import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/state/seller_pending_order_state.dart';
import 'package:bujafasta_app/state/auth_state.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _decideWhereToGo();
  }

  Future<void> _decideWhereToGo() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    // 🔐 UPDATE GLOBAL LOGIN STATE
    if (user == null) {
      isLoggedInNotifier.value = false;
    } else {
      isLoggedInNotifier.value = true;
    }

    // 👇 START SELLER PENDING ORDER WATCHER IF LOGGED IN
    if (user != null) {
      await startSellerPendingOrderWatcher();
    }

    if (!mounted) return;

    // ✅ Open app freely
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset(
          'assets/bujafastalogo.png',
          width: 120,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
