// lib/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

final supabase = Supabase.instance.client;

class AuthService {
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? username,
  }) async {
    // 1) Create the auth user
    final res = await supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'bujafasta://login-callback',
      data: {'username': username},
    );

    // 2) If user created, create a profiles row (INSERT). Use upsert to be safe.
    final user = res.user;
    if (user != null) {
      final profile = {
        'id': user.id,
        'first_name': null,
        'last_name': null,
        'phone': null,
        'avatar_url': null,
        'is_complete': false,
      };

      try {
        await supabase.from('profiles').upsert(profile);
      } catch (e) {
        debugPrint('profiles upsert error: $e');
      }
    }

    return res;
  }

  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}
