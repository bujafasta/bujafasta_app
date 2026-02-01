import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:bujafasta_app/pages/wallet/pin_verify_screen.dart';

class ShopWalletPage extends StatefulWidget {
  const ShopWalletPage({super.key});

  @override
  State<ShopWalletPage> createState() => _ShopWalletPageState();
}

class _ShopWalletPageState extends State<ShopWalletPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  num balance = 0;
  String shopName = '';
  String shopWalletId = '';
  double transferFeePercent = 0;
  List<Map<String, dynamic>> transactions = [];
  bool loadingTransactions = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // 1️⃣ Load shop wallet
    final wallet = await supabase
        .from('wallets')
        .select('wallet_id, balance')
        .eq('user_id', user.id)
        .eq('role', 'seller')
        .single();

    // 2️⃣ Load shop name
    final shop = await supabase
        .from('shops')
        .select('shop_name')
        .eq('owner_id', user.id)
        .single();

    // 3️⃣ Load internal transfer fee
    final feeRow = await supabase
        .from('app_fees')
        .select('fee_percent')
        .eq('key', 'internal_transfer_fee')
        .eq('is_active', true)
        .single();

    // 4️⃣ Load shop wallet transactions
    final txs = await supabase
        .from('wallet_transactions')
        .select('type, amount, description, created_at')
        .eq('wallet_id', wallet['wallet_id'])
        .order('created_at', ascending: false)
        .limit(20);

    setState(() {
      balance = wallet['balance'];
      shopWalletId = wallet['wallet_id'];
      shopName = shop['shop_name'];
      transferFeePercent = (feeRow['fee_percent'] as num?)?.toDouble() ?? 0;
      transactions = List<Map<String, dynamic>>.from(txs);
      loading = false;
      loadingTransactions = false;
    });
  }

  // ===============================
  // SHOP → PERSONAL TRANSFER
  // ===============================
  void _showTransferDialog() {
    final amountController = TextEditingController();
    bool submitting = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> _submitTransfer() async {
              final user = supabase.auth.currentUser;
              if (user == null) return;

              final amount = int.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Invalid amount')));
                return;
              }

              // 🔐 STEP 1: ASK FOR PIN AGAIN
              final bool? pinVerified = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => PinVerifyScreen(
                    onPinVerified: () {
                      Navigator.pop(context, true); // 👈 return success
                    },
                  ),
                ),
              );

              // ❌ PIN cancelled or failed
              if (pinVerified != true) {
                return;
              }

              // 🔒 STEP 2: PIN OK → PROCEED WITH TRANSFER
              setModalState(() => submitting = true);

              try {
                final result = await supabase.rpc(
                  'transfer_shop_to_personal',
                  params: {'p_amount': amount},
                );

                if (result['status'] == 'insufficient_balance') {
                  setModalState(() {
                    errorMessage =
                        'You cannot transfer this amount.\nMaximum allowed: ${result['max_withdrawable']} BIF';
                  });
                  return;
                }

                if (result['status'] == 'ok') {
                  Navigator.pop(context); // close bottom sheet

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Transferred ${result['net_amount']} BIF (Fee ${result['fee']} BIF)',
                      ),
                    ),
                  );

                  await _loadWallet();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transfer failed. Please try again.'),
                  ),
                );
              } finally {
                setModalState(() => submitting = false);
              }
            }

            return Stack(
              children: [
                // =========================
                // MAIN BOTTOM SHEET CONTENT
                // =========================
                Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    top: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Transfer to Personal Wallet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Money will be moved from your shop wallet',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount (BIF)',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'An internal fee of ${transferFeePercent.toStringAsFixed(2)}% applies.\n'
                          'You cannot transfer your full balance — the system will calculate the maximum allowed amount.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: submitting ? null : _submitTransfer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9800),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Confirm Transfer',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                // =========================
                // BLOCKING LOADING OVERLAY
                // =========================
                if (submitting)
                  Positioned.fill(
                    child: AbsorbPointer(
                      absorbing: true,
                      child: Container(
                        color: Colors.black.withOpacity(0.35),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFFF9800),
                                  ),
                                ),
                                SizedBox(height: 14),
                                Text(
                                  'Please wait…',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Processing secure transfer',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop Wallet'), centerTitle: true),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWallet,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // ===============================
                    // SHOP WALLET CARD
                    // ===============================
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              const Icon(Icons.store, color: Colors.white),
                              const SizedBox(width: 10),
                              const Text(
                                'Shop Balance',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white,
                                ),
                                onSelected: (value) async {
                                  if (value == 'copy_wallet_id') {
                                    await Clipboard.setData(
                                      ClipboardData(text: shopWalletId),
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Shop Wallet ID copied'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'copy_wallet_id',
                                    child: Text('Copy Wallet ID'),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Shop name
                          Text(
                            shopName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Wallet label
                          const Text(
                            'Shop Wallet Balance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Balance value
                          Text(
                            '${NumberFormat("#,##0").format(balance)} BIF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Transfer button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _showTransferDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Move to Personal Wallet',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ===============================
                    // INFO NOTE (CLEAN UX)
                    // ===============================
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: Text(
                        'Transfers include an internal fee of '
                        '${transferFeePercent.toStringAsFixed(2)}%. '
                        'If you attempt to transfer your full balance, '
                        'the system will block it and show the maximum allowed amount.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Transactions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${transactions.length}',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                    if (loadingTransactions)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      )
                    else if (transactions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No transactions yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final tx = transactions[index];
                          final amount = NumberFormat(
                            "#,##0",
                          ).format(tx['amount']);
                          final isDebit = tx['amount'] < 0;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isDebit
                                  ? Colors.red.shade50
                                  : Colors.green.shade50,
                              child: Icon(
                                isDebit
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: isDebit ? Colors.red : Colors.green,
                              ),
                            ),
                            title: Text(
                              tx['description'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              DateFormat(
                                'dd MMM yyyy • HH:mm',
                              ).format(DateTime.parse(tx['created_at'])),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Text(
                              '${isDebit ? '-' : '+'}$amount BIF',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDebit ? Colors.red : Colors.green,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
