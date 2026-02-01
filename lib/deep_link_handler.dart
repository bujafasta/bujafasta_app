// lib/deep_link_handler.dart
import 'dart:async';
import 'package:flutter/material.dart'; // <-- Required for MaterialPageRoute
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/screens/auth/reset_password_page.dart';

class DeepLinkHandler {
  final GlobalKey<NavigatorState> navigatorKey;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri?>? _sub;

  DeepLinkHandler({required this.navigatorKey});

  Future<void> init() async {
    // Cold start
    await _handleInitialUri();

    // Warm links (app already running)
    _sub = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (e) => debugPrint("app_links stream error: $e"),
    );
  }

  Future<void> _handleInitialUri() async {
    try {
      final Uri? initial = await _appLinks.getInitialLink(); // ✅ CORRECT METHOD
      if (initial != null) _handleUri(initial);
    } catch (e) {
      debugPrint("getInitialLink failed: $e");
    }
  }

  Future<void> _handleUri(Uri uri) async {
    debugPrint("Deep link received: $uri");

    // 🔥 1. HANDLE PASSWORD RESET DEEP LINK
    // Example redirect: bujafasta://reset-callback
    // 🔥 1. HANDLE PASSWORD RESET DEEP LINK
    if (uri.host == "reset-callback") {
      debugPrint("Reset link detected: $uri");

      try {
        // Create recovery session
        final res = await Supabase.instance.client.auth.getSessionFromUrl(uri);
        debugPrint("Recovery session: $res");
      } catch (e) {
        debugPrint("getSessionFromUrl failed for reset: $e");
        // continue anyway, user may still enter new password
      }

      // 👉 Open ResetPasswordPage (DO NOT redirect to home)
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
      );

      return; // stop here
    }

    // 🔥 GOOGLE SIGN-IN COMPLETION
    if (uri.host == "login-callback" ||
        uri.queryParameters["type"] == "provider") {
      debugPrint("Google OAuth callback: $uri");

      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
        _onSignInSuccess();
      } catch (e) {
        debugPrint("OAuth session error: $e");
      }
      return;
    }

    // 🔥 2. HANDLE EMAIL CONFIRMATION DEEP LINK
    // Supabase sends ?type=signup for verification links
    if (uri.queryParameters["type"] == "signup") {
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);

        _onSignInSuccess();
        return;
      } catch (e) {
        debugPrint("Email confirmation error: $e");
      }
    }

    debugPrint("Deep link did not match known routes.");
  }

  void _onSignInSuccess() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (r) => false,
      );
      return;
    }

    final profile = await client
        .from('profiles')
        .select('is_complete')
        .eq('id', user.id)
        .maybeSingle();

    // 🔥 If profile incomplete → force them to complete it
    if (profile == null || profile['is_complete'] == false) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/complete-profile',
        (r) => false,
      );
      return;
    }

    // Otherwise, go home
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (r) => false);
  }

  void dispose() {
    _sub?.cancel();
  }
}
