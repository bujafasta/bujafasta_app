import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

// ============================================
// PIN SERVICE (USER-LEVEL PIN)
// ============================================

class PinService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // HASH PIN
  // ============================================

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  // ============================================
  // CHECK IF PIN IS SET (FROM PROFILES)
  // ============================================

  Future<bool> isPinSet() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final profile = await _supabase
          .from('profiles')
          .select('pin_set')
          .eq('id', user.id)
          .maybeSingle();

      return profile?['pin_set'] == true;
    } catch (e) {
      print('Error checking PIN: $e');
      return false;
    }
  }

  // ============================================
  // CREATE / SET PIN (ONCE)
  // ============================================

  Future<bool> setPin({required String pin}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // Validate PIN
      if (pin.length != 4 || !RegExp(r'^[0-9]{4}$').hasMatch(pin)) {
        throw Exception('PIN must be exactly 4 digits');
      }

      final pinHash = _hashPin(pin);

      await _supabase.from('profiles').update({
        'pin_hash': pinHash,
        'pin_set': true,
        'failed_pin_attempts': 0,
        'locked_until': null,
        'pin_set_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      return true;
    } catch (e) {
      print('Error setting PIN: $e');
      return false;
    }
  }

  // ============================================
  // VERIFY PIN (FROM PROFILES)
  // ============================================

  Future<Map<String, dynamic>> verifyPin({required String pin}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'User not logged in'};
      }

      final profile = await _supabase
          .from('profiles')
          .select('pin_hash, failed_pin_attempts, locked_until')
          .eq('id', user.id)
          .single();

      final storedHash = profile['pin_hash'];
      final failedAttempts = profile['failed_pin_attempts'] ?? 0;
      final lockedUntil = profile['locked_until'];

      // 🔒 Check lock
      if (lockedUntil != null) {
        final lockTime = DateTime.parse(lockedUntil);
        if (DateTime.now().isBefore(lockTime)) {
          final minutesLeft =
              lockTime.difference(DateTime.now()).inMinutes;
          return {
            'success': false,
            'message': 'Account locked. Try again in $minutesLeft minutes.',
            'locked': true,
          };
        }
      }

      final enteredHash = _hashPin(pin);

      // ✅ PIN CORRECT
      if (enteredHash == storedHash) {
        await _supabase.from('profiles').update({
          'failed_pin_attempts': 0,
          'locked_until': null,
        }).eq('id', user.id);

        return {'success': true};
      }

      // ❌ PIN WRONG
      final newFailedAttempts = failedAttempts + 1;

      if (newFailedAttempts >= 5) {
        final lockUntil =
            DateTime.now().add(const Duration(minutes: 30));

        await _supabase.from('profiles').update({
          'failed_pin_attempts': newFailedAttempts,
          'locked_until': lockUntil.toIso8601String(),
        }).eq('id', user.id);

        return {
          'success': false,
          'locked': true,
          'message': 'Too many attempts. Account locked for 30 minutes.',
        };
      }

      await _supabase.from('profiles').update({
        'failed_pin_attempts': newFailedAttempts,
      }).eq('id', user.id);

      return {
        'success': false,
        'attemptsLeft': 5 - newFailedAttempts,
        'message': 'Wrong PIN',
      };
    } catch (e) {
      print('Error verifying PIN: $e');
      return {'success': false, 'message': 'PIN verification failed'};
    }
  }

  // ============================================
  // RESET PIN
  // ============================================

  Future<bool> resetPin({required String newPin}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      if (!RegExp(r'^[0-9]{4}$').hasMatch(newPin)) {
        throw Exception('Invalid PIN');
      }

      final pinHash = _hashPin(newPin);

      await _supabase.from('profiles').update({
        'pin_hash': pinHash,
        'failed_pin_attempts': 0,
        'locked_until': null,
      }).eq('id', user.id);

      return true;
    } catch (e) {
      print('Error resetting PIN: $e');
      return false;
    }
  }
}
