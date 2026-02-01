import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================
// PERMISSION SERVICE
// ============================================
// Centralized permission checking for admins

class PermissionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache permissions (avoid repeated queries)
  Map<String, dynamic>? _cachedPermissions;
  DateTime? _cacheTime;

  // ============================================
  // GET USER PERMISSIONS
  // ============================================

  Future<Map<String, dynamic>> getPermissions() async {
    // Return cached if less than 5 minutes old
    if (_cachedPermissions != null &&
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inMinutes < 5) {
      return _cachedPermissions!;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return _emptyPermissions();
      }

      final role = await _supabase
          .from('user_roles')
          .select('''
      is_admin,
      can_manage_products,
       can_manage_orders,     
      is_agent,
      can_manage_withdraw,
      can_suspend_users,
      can_suspend_shops
    ''')
          .eq('user_id', user.id)
          .maybeSingle();

      if (role == null) {
        return _emptyPermissions();
      }

      _cachedPermissions = {
        'is_admin': role['is_admin'] == true,
        'can_manage_products': role['can_manage_products'] == true,
        'can_manage_orders': role['can_manage_orders'] == true, // 👈 ADD
        'is_agent': role['is_agent'] == true,
        'can_manage_withdraw': role['can_manage_withdraw'] == true,
        'can_suspend_users': role['can_suspend_users'] == true,
        'can_suspend_shops': role['can_suspend_shops'] == true,
      };

      _cacheTime = DateTime.now();

      return _cachedPermissions!;
    } catch (e) {
      print('Error getting permissions: $e');
      return _emptyPermissions();
    }
  }

  Map<String, dynamic> _emptyPermissions() {
    return {
      'is_admin': false,
      'can_manage_products': false,
      'can_manage_orders': false, // 👈 ADD
      'is_agent': false,
      'can_manage_withdraw': false,
      'can_suspend_users': false,
      'can_suspend_shops': false,
    };
  }

  // ============================================
  // QUICK PERMISSION CHECKS
  // ============================================

  /// Check if user is an active admin (master switch)
  Future<bool> isAdmin() async {
    final perms = await getPermissions();
    return perms['is_admin'] == true;
  }

  /// Check if user can approve/reject products
  Future<bool> canManageProducts() async {
    final perms = await getPermissions();
    return perms['is_admin'] == true && perms['can_manage_products'] == true;
  }

  /// Check if user can handle wallet deposits
  Future<bool> isAgent() async {
    final perms = await getPermissions();
    return perms['is_admin'] == true && perms['is_agent'] == true;
  }

  /// Check if user can suspend/unsuspend users
  Future<bool> canSuspendUsers() async {
    final perms = await getPermissions();
    return perms['is_admin'] == true && perms['can_suspend_users'] == true;
  }

  /// Check if user can suspend/unsuspend shops
  Future<bool> canSuspendShops() async {
    final perms = await getPermissions();
    return perms['is_admin'] == true && perms['can_suspend_shops'] == true;
  }

  /// Check if user can manage withdrawals
  Future<bool> canManageWithdraw() async {
    final perms = await getPermissions();
    return perms['is_admin'] == true && perms['can_manage_withdraw'] == true;
  }

  // ============================================
  // SUSPENSION ACTIONS
  // ============================================

  /// Suspend a user account
  Future<bool> suspendUser({
    required String userId,
    required String reason,
  }) async {
    if (!await canSuspendUsers()) {
      print('Permission denied: cannot suspend users');
      return false;
    }

    try {
      final admin = _supabase.auth.currentUser;
      if (admin == null) return false;

      await _supabase
          .from('profiles')
          .update({
            'is_suspended': true,
            'suspended_at': DateTime.now().toIso8601String(),
            'suspended_by': admin.id,
            'suspension_reason': reason,
          })
          .eq('id', userId);

      return true;
    } catch (e) {
      print('Error suspending user: $e');
      return false;
    }
  }

  /// Unsuspend a user account
  Future<bool> unsuspendUser(String userId) async {
    if (!await canSuspendUsers()) {
      print('Permission denied:  cannot unsuspend users');
      return false;
    }

    try {
      await _supabase
          .from('profiles')
          .update({
            'is_suspended': false,
            'suspended_at': null,
            'suspended_by': null,
            'suspension_reason': null,
          })
          .eq('id', userId);

      return true;
    } catch (e) {
      print('Error unsuspending user: $e');
      return false;
    }
  }

  /// Suspend a shop
  Future<bool> suspendShop({
    required String shopId,
    required String reason,
  }) async {
    if (!await canSuspendShops()) {
      print('Permission denied:  cannot suspend shops');
      return false;
    }

    try {
      final admin = _supabase.auth.currentUser;
      if (admin == null) return false;

      await _supabase
          .from('shops')
          .update({
            'is_suspended': true,
            'suspended_at': DateTime.now().toIso8601String(),
            'suspended_by': admin.id,
            'suspension_reason': reason,
          })
          .eq('id', shopId);

      return true;
    } catch (e) {
      print('Error suspending shop: $e');
      return false;
    }
  }

  /// Unsuspend a shop
  Future<bool> unsuspendShop(String shopId) async {
    if (!await canSuspendShops()) {
      print('Permission denied: cannot unsuspend shops');
      return false;
    }

    try {
      await _supabase
          .from('shops')
          .update({
            'is_suspended': false,
            'suspended_at': null,
            'suspended_by': null,
            'suspension_reason': null,
          })
          .eq('id', shopId);

      return true;
    } catch (e) {
      print('Error unsuspending shop: $e');
      return false;
    }
  }

  /// Clear cached permissions (call after changing roles)
  void clearCache() {
    _cachedPermissions = null;
    _cacheTime = null;
  }
}
