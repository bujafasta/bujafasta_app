import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================
// WALLET SERVICE
// ============================================
// Handles all wallet operations

class WalletService {
  // Get Supabase client (connection to database)
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // GET WALLET BALANCE
  // ============================================
  // Fetches current user's wallet balance
  Future<Map<String, double>> getWalletBalances({required String role}) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final wallet = await supabase
        .from('wallets')
        .select('balance, locked_balance')
        .eq('user_id', user.id)
        .eq('role', role)
        .single();

    final balance = (wallet['balance'] as num).toDouble();
    final locked = (wallet['locked_balance'] as num).toDouble();

    return {'balance': balance, 'locked': locked};
  }

  // ============================================
  // ADD MONEY TO WALLET
  // ============================================
  // Adds money to wallet and creates transaction record
  Future<bool> addMoney({
    required String role,
    required double amount,
    required String description,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Step 1: Get current wallet
      final wallet = await _supabase
          .from('wallets')
          .select('wallet_id, balance')
          .eq('user_id', user.id)
          .eq('role', role)
          .single();

      final walletId = wallet['wallet_id'];
      final currentBalance = double.parse(wallet['balance'].toString());
      final newBalance = currentBalance + amount;

      // Step 2: Update wallet balance
      await _supabase
          .from('wallets')
          .update({'balance': newBalance})
          .eq('wallet_id', walletId);

      // Step 3: Create transaction record
      await _supabase.from('wallet_transactions').insert({
        'wallet_id': walletId,
        'type': 'credit',
        'amount': amount,
        'description': description,
        'balance_before': currentBalance,
        'balance_after': newBalance,
      });

      return true;
    } catch (e) {
      print('Error adding money: $e');
      return false;
    }
  }

  // ============================================
  // REMOVE MONEY FROM WALLET
  // ============================================
  // Removes money from wallet (for purchases)
  Future<bool> deductMoney({
    required String role,
    required double amount,
    required String description,
    int? orderId,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Step 1: Get current wallet
      final wallet = await _supabase
          .from('wallets')
          .select('wallet_id, balance')
          .eq('user_id', user.id)
          .eq('role', role)
          .single();

      final walletId = wallet['wallet_id'];
      final currentBalance = double.parse(wallet['balance'].toString());
      if (currentBalance < amount) {
        throw Exception('Insufficient funds');
      }
      final newBalance = currentBalance - amount;

      // Step 2: Update wallet balance
      await _supabase
          .from('wallets')
          .update({'balance': newBalance})
          .eq('wallet_id', walletId);

      // Step 3: Create transaction record
      await _supabase.from('wallet_transactions').insert({
        'wallet_id': walletId,
        'type': 'debit',
        'amount': amount,
        'description': description,
        'balance_before': currentBalance,
        'balance_after': newBalance,
        'order_id': orderId,
      });

      return true;
    } catch (e) {
      print('Error deducting money: $e');
      return false;
    }
  }

  // ============================================
  // GET WALLET TRANSACTIONS
  // ============================================
  // Fetches transaction history
  Future<List<Map<String, dynamic>>> getTransactions({
    required String role,
    int limit = 50,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      // Get wallet ID
      final wallet = await _supabase
          .from('wallets')
          .select('wallet_id')
          .eq('user_id', user.id)
          .eq('role', role)
          .maybeSingle();

      if (wallet == null) return [];

      // Fetch transactions
      final transactions = await _supabase
          .from('wallet_transactions')
          .select()
          .eq('wallet_id', wallet['wallet_id'])
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(transactions);
    } catch (e) {
      print('Error getting transactions: $e');
      return [];
    }
  }
}
