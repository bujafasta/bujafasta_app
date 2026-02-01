import 'package:flutter/material.dart';
import 'package:bujafasta_app/services/wallet_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final WalletService _walletService = WalletService();

  final NumberFormat bifFormat = NumberFormat("#,##0", "fr_FR");
  bool _hasPendingDeposit = false;
  bool _hasPendingWithdraw = false;

  double totalBalance = 0.0;
  double lockedBalance = 0.0;
  double availableBalance = 0.0;

  List<Map<String, dynamic>> transactions = [];

  bool isLoading = true;
  String userName = 'Loading...';
  String userPhone = '';
  String userCountryCode = '';
  String? walletId; // 👈 used for support

  // Add money state
  File? _selectedScreenshotFile;
  String? _previewImagePath;
  RealtimeChannel? _depositChannel;
  RealtimeChannel? _withdrawChannel;
  RealtimeChannel? _walletChannel;

  @override
  void initState() {
    super.initState();
    _loadWalletData(); // load wallet directly
  }

  // --- PIN setup/check/verify/your wallet code (unchanged) ...

  Future<void> _loadWalletData() async {
    setState(() {
      isLoading = true;
    });

    final balances = await _walletService.getWalletBalances(role: 'buyer');
    final fetchedTransactions = await _walletService.getTransactions(
      role: 'buyer',
      limit: 20,
    );

    // --- NEW: Check if there is any pending deposit_request ---
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    bool pending = false;
    if (user != null) {
      final pendingDeposit = await supabase
          .from('deposit_requests')
          .select('id')
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .maybeSingle();
      pending = pendingDeposit != null;
    }

    bool pendingWithdraw = false;
    if (user != null) {
      final withdraw = await supabase
          .from('withdraw_requests')
          .select('id')
          .eq('user_id', user.id)
          .eq('status', 'pending')
          .maybeSingle();

      pendingWithdraw = withdraw != null;
    }

    // --------------------------------------------------------

    await _loadUserInfo();
    setState(() {
      totalBalance = balances['balance']!;
      lockedBalance = balances['locked']!;
      availableBalance = totalBalance - lockedBalance;

      transactions = fetchedTransactions;
      isLoading = false;
      _hasPendingDeposit = pending;
      _hasPendingWithdraw = pendingWithdraw;
    });

    _startDepositRealtime(); // 👈 ADD THIS LINE
    _startWithdrawRealtime();
    _startWalletRealtime();
  }

  Future<void> _loadUserInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final wallet = await supabase
          .from('wallets')
          .select('wallet_id, owner_name, owner_phone, country_code')
          .eq('user_id', user.id)
          .eq('role', 'buyer')
          .maybeSingle();
      if (wallet != null) {
        setState(() {
          userName = (wallet['owner_name'] ?? '').toString();
          userPhone = (wallet['owner_phone'] ?? '').toString();
          userCountryCode = (wallet['country_code'] ?? '').toString();
          walletId = wallet['wallet_id']?.toString(); // 👈 ADD THIS
          if (userName.isEmpty) {
            userName = user.email ?? 'User';
          }
        });
      }
    } catch (e) {
      print('Error loading wallet info: $e');
    }
  }

  void _startDepositRealtime() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Prevent duplicate listeners
    _depositChannel?.unsubscribe();

    _depositChannel = supabase.channel('deposit-lock-${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'deposit_requests',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (payload) {
          final newRow = payload.newRecord;
          if (newRow == null) return;

          final status = newRow['status'];

          if (!mounted) return;

          setState(() {
            _hasPendingDeposit = status == 'pending';
          });
        },
      )
      ..subscribe();
  }

  void _startWithdrawRealtime() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Prevent duplicate listeners
    _withdrawChannel?.unsubscribe();

    _withdrawChannel = supabase.channel('withdraw-lock-${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'withdraw_requests',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          if (row == null) return;

          final status = row['status'];

          if (!mounted) return;

          setState(() {
            _hasPendingWithdraw = status == 'pending';
          });
        },
      )
      ..subscribe();
  }

  void _startWalletRealtime() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Prevent duplicate listeners
    _walletChannel?.unsubscribe();

    _walletChannel = supabase.channel('wallet-live-${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'wallets',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (payload) {
          final newRow = payload.newRecord;
          if (newRow == null) return;

          // IMPORTANT: only buyer wallet
          if (newRow['role'] != 'buyer') return;

          if (!mounted) return;

          final double balance = double.parse(newRow['balance'].toString());
          final double locked = double.parse(
            newRow['locked_balance'].toString(),
          );

          setState(() {
            totalBalance = balance;
            lockedBalance = locked;
            availableBalance = balance - locked;
          });
        },
      )
      ..subscribe();
  }

  // ============================================
  // ADD MONEY DIALOG (LIGHTBOX)
  // ============================================

  void _showAddMoneyDialog(BuildContext parentContext) {
    final TextEditingController amountController = TextEditingController();
    File? pickedFile;
    String? previewImagePath;
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        const officialBujaFastaNumber = "8085";
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> _pickScreenshot() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
                allowMultiple: false,
              );
              if (result != null && result.files.isNotEmpty) {
                pickedFile = File(result.files.single.path!);
                previewImagePath = result.files.single.path;
                setModalState(() {});
              }
            }

            Future<void> _submitDeposit() async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (pickedFile == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Screenshot required!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              setModalState(() {
                submitting = true;
              });

              try {
                final supabase = Supabase.instance.client;
                final user = supabase.auth.currentUser;
                if (user == null) {
                  throw Exception('User not logged in');
                }

                // 1️⃣ Read file bytes
                final Uint8List imageBytes = await pickedFile!.readAsBytes();

                // 2️⃣ Compress image (optional but you already use flutter_image_compress)
                final Uint8List? compressedBytes =
                    await FlutterImageCompress.compressWithList(
                      imageBytes,
                      quality: 70,
                    );

                if (compressedBytes == null) {
                  throw Exception('Image compression failed');
                }

                // 3️⃣ Generate unique filename
                final fileName =
                    'deposit_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

                // 4️⃣ Upload to Supabase Storage
                await supabase.storage
                    .from('deposit_screenshots')
                    .uploadBinary(
                      fileName,
                      compressedBytes,
                      fileOptions: const FileOptions(
                        contentType: 'image/jpeg',
                        upsert: false,
                      ),
                    );

                // 5️⃣ Get public URL
                final screenshotUrl = supabase.storage
                    .from('deposit_screenshots')
                    .getPublicUrl(fileName);

                // 6️⃣ Insert deposit request
                await supabase.from('deposit_requests').insert({
                  'user_id': user.id,
                  'amount': amount,
                  'status': 'pending',

                  'screenshot_url': screenshotUrl,
                  'phone_number': userPhone,
                  'user_name': userName,
                });

                // Find or create a 'deposit' conversation for the user
                final conversation = await supabase
                    .from('conversations')
                    .select()
                    .eq('buyer_id', user.id)
                    .eq('seller_id', '74d7bd17-01a4-4185-bb73-dea9e7276917')
                    .maybeSingle();

                String conversationId;
                if (conversation == null) {
                  // No open deposit chat, create one:
                  final bujaAgentId =
                      '74d7bd17-01a4-4185-bb73-dea9e7276917'; // <-- your agent/support UUID
                  final convoRow = await supabase
                      .from('conversations')
                      .insert({
                        'buyer_id': user.id,
                        'seller_id': bujaAgentId,
                        'type': 'deposit',
                        'title': 'Support',
                        'last_message':
                            'Depositor started new deposit verification',
                        'last_message_at': DateTime.now().toIso8601String(),
                      })
                      .select()
                      .single();
                  conversationId = convoRow['id'];
                } else {
                  conversationId = conversation['id'];
                }

                // Add a system message to notify the agent
                await supabase.from('messages').insert({
                  'conversation_id': conversationId,
                  'sender_id': user.id,
                  'body': json.encode({
                    'user_name': userName,
                    'user_phone': userPhone,
                    'country_code': userCountryCode,
                    'amount': amount.toStringAsFixed(0),
                    'screenshot_url': screenshotUrl,
                  }),
                  'context': 'deposit_request',
                  'status': 'sent',
                });

                // Close modal and navigate to chat room
                if (mounted) {
                  Navigator.of(context).pop(); // close modal

                  // Use a short delay to allow modal to close before navigating
                  await Future.delayed(const Duration(milliseconds: 100));
                  Navigator.pushNamed(
                    parentContext,
                    "/chat_room",
                    arguments: {'chatId': conversationId},
                  );

                  return; // Prevents code after this block from running again after navigation
                }
              } catch (e) {
                print('Deposit upload error: $e');

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to submit deposit'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setModalState(() {
                  submitting = false;
                });
              }
            }

            // This makes the content scrollable, with a fixed button!
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Grabber
                    Container(
                      width: 60,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      margin: const EdgeInsets.only(top: 10, bottom: 18),
                    ),
                    // This is the scrollable content
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.wallet,
                                  color: Color(0xFFFFAA05),
                                  size: 32,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Deposit via BujaFasta',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFFAA05),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(
                                    Icons.close,
                                    color: Colors.grey.shade700,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Card(
                              color: Color(0xFFFFF3E0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              margin: const EdgeInsets.only(top: 8, bottom: 14),
                              child: ListTile(
                                leading: Icon(
                                  Icons.phone,
                                  color: Color(0xFFFFAA05),
                                ),
                                title: const Text(
                                  "Send your deposit to:",
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  officialBujaFastaNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Color(0xFFFFAA05),
                                    letterSpacing: 2,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.copy,
                                    color: Color(0xFFFFAA05),
                                  ),
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      const ClipboardData(
                                        text: officialBujaFastaNumber,
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Number copied!'),
                                        duration: Duration(milliseconds: 700),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            TextFormField(
                              initialValue: userName,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Your Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              initialValue:
                                  '${userCountryCode.isNotEmpty ? userCountryCode + ' ' : ''}$userPhone',
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Your Phone',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Amount Deposited (BIF)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.money,
                                  color: Color(0xFFFFAA05),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (pickedFile == null)
                              OutlinedButton.icon(
                                onPressed: _pickScreenshot,
                                icon: Icon(
                                  Icons.upload_file,
                                  color: Color(0xFFFFAA05),
                                ),
                                label: Text(
                                  'Upload Payment Screenshot',
                                  style: TextStyle(color: Color(0xFFFFAA05)),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Color(0xFFFFAA05),
                                  side: BorderSide(color: Color(0xFFFFAA05)),
                                  minimumSize: const Size.fromHeight(44),
                                ),
                              ),
                            if (pickedFile != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: 12.0,
                                  top: 0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        // Show full screen preview
                                        showDialog(
                                          context: context,
                                          builder: (_) => Dialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              child: Stack(
                                                children: [
                                                  Image.file(
                                                    pickedFile!,
                                                    fit: BoxFit.contain,
                                                  ),
                                                  Positioned(
                                                    top: 8,
                                                    right: 8,
                                                    child: IconButton(
                                                      icon: Icon(
                                                        Icons.close,
                                                        color: Colors.black,
                                                      ),
                                                      onPressed: () =>
                                                          Navigator.of(
                                                            context,
                                                          ).pop(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 68,
                                        height: 68,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFFAA05),
                                            width: 2,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Image.file(
                                          pickedFile!,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Screenshot added",
                                            style: TextStyle(
                                              color: Color(0xFFFFAA05),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Row(
                                            children: [
                                              TextButton.icon(
                                                onPressed: _pickScreenshot,
                                                icon: Icon(
                                                  Icons.refresh,
                                                  color: Color(0xFFFFAA05),
                                                ),
                                                label: const Text("Change"),
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Color(
                                                    0xFFFFAA05,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                      ),
                                                ),
                                              ),
                                              TextButton.icon(
                                                onPressed: () {
                                                  pickedFile = null;
                                                  previewImagePath = null;
                                                  setModalState(() {});
                                                },
                                                icon: Icon(
                                                  Icons.delete,
                                                  color: Colors.red.shade400,
                                                ),
                                                label: const Text("Remove"),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            "Tap thumbnail to preview",
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // --- Fixed Bottom Button ---
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: submitting ? null : _submitDeposit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFAA05),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 3,
                          ),
                          child: submitting
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Send for Verification',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showWithdrawDialog(BuildContext parentContext) {
    final TextEditingController amountController = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> _submitWithdraw() async {
              final amount = double.tryParse(amountController.text);

              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (amount > availableBalance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Amount exceeds available balance'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setModalState(() => submitting = true);

              try {
                final supabase = Supabase.instance.client;
                final user = supabase.auth.currentUser;
                if (user == null) throw Exception('Not logged in');

                // 1️⃣ CALL BACKEND FUNCTION (SOURCE OF TRUTH)
                final res = await supabase.rpc(
                  'request_withdraw',
                  params: {'p_amount': amount},
                );

                // rpc returns the withdraw_id
                final withdrawId = res.toString();

                // 2️⃣ FIND OR CREATE SAME SUPPORT CHAT
                final convo = await supabase
                    .from('conversations')
                    .select()
                    .eq('buyer_id', user.id)
                    .eq('seller_id', '74d7bd17-01a4-4185-bb73-dea9e7276917')
                    .maybeSingle();

                String conversationId;

                if (convo == null) {
                  final newConvo = await supabase
                      .from('conversations')
                      .insert({
                        'buyer_id': user.id,
                        'seller_id': '74d7bd17-01a4-4185-bb73-dea9e7276917',
                        'type': 'deposit',
                        'title': 'Support',
                        'last_message_at': DateTime.now().toIso8601String(),
                      })
                      .select()
                      .single();

                  conversationId = newConvo['id'];
                } else {
                  conversationId = convo['id'];
                }

                // 3️⃣ SEND WITHDRAW MESSAGE (JSON - FIXED)
                await supabase.from('messages').insert({
                  'conversation_id': conversationId,
                  'sender_id': user.id,
                  'body': json.encode({
                    'withdrawal_id': withdrawId.toString(), // ✅ ALWAYS STRING
                    'user_name': userName,
                    'phone_number': userPhone,
                    'country_code': userCountryCode, // ✅ ADD THIS
                    'amount': amount.toStringAsFixed(0),
                  }),
                  'context': 'withdraw_request',
                  'status': 'sent',
                });

                Navigator.pop(context);
                await Future.delayed(const Duration(milliseconds: 100));

                Navigator.pushNamed(
                  parentContext,
                  "/chat_room",
                  arguments: {'chatId': conversationId},
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Withdraw failed: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setModalState(() => submitting = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Withdraw Funds',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (BIF)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitting ? null : _submitWithdraw,
                      child: submitting
                          ? const CircularProgressIndicator()
                          : const Text('Send Withdraw Request'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ========================== UI BELOW THIS UNCHANGED ==========================

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(title: const Text('My Wallet'), centerTitle: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWalletData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade700, Colors.blue.shade900],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (userPhone.isNotEmpty)
                                      Text(
                                        '${userCountryCode.isNotEmpty ? userCountryCode + ' ' : ''}$userPhone',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // ✅ HEADER 3 DOTS MENU (CORRECT PLACE)
                              PopupMenuButton<String>(
                                enabled: walletId != null, // ✅ IMPORTANT
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.white,
                                ),
                                onSelected: (value) async {
                                  if (value != 'copy_wallet') return;

                                  if (walletId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Wallet ID not ready yet',
                                        ),
                                        duration: Duration(milliseconds: 800),
                                      ),
                                    );
                                    return;
                                  }

                                  await Clipboard.setData(
                                    ClipboardData(text: walletId!),
                                  );

                                  if (!mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Wallet ID copied'),
                                      duration: Duration(milliseconds: 800),
                                    ),
                                  );
                                },

                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'copy_wallet',
                                    child: Text('Copy Wallet ID'),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          Divider(color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 20),
                          const Text(
                            'Available Balance',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${bifFormat.format(availableBalance)} BIF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Locked Balance: ${bifFormat.format(lockedBalance)} BIF',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Total Balance: ${bifFormat.format(totalBalance)} BIF',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 20),
                          Row(
                            children: [
                              // ADD MONEY
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _hasPendingDeposit
                                      ? () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text(
                                                "Deposit Pending",
                                              ),
                                              content: const Text(
                                                "You already have a deposit under review.",
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text("OK"),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      : () => _showAddMoneyDialog(context),
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.blue,
                                  ),
                                  label: const Text(
                                    'Add Money',
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // WITHDRAW
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      (_hasPendingWithdraw ||
                                          availableBalance <= 0)
                                      ? null
                                      : () => _showWithdrawDialog(context),

                                  icon: const Icon(
                                    Icons.arrow_upward,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Withdraw',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Show under review banner if deposit is pending
                    if (_hasPendingDeposit)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 8,
                          bottom: 6,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange.shade100),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Colors.orange,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'A deposit is under review.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_hasPendingWithdraw)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 4,
                          bottom: 6,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade100),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.hourglass_top,
                                color: Colors.red,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'A withdrawal request is under review.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

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
                            '${transactions.length} total',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    transactions.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No transactions yet',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: transactions.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (context, index) {
                              final transaction = transactions[index];
                              final isCredit = transaction['type'] == 'credit';
                              final amount = double.parse(
                                transaction['amount'].toString(),
                              );
                              final description = transaction['description'];
                              final createdAt = DateTime.parse(
                                transaction['created_at'],
                              );
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isCredit
                                        ? Colors.green.shade50
                                        : Colors.red.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCredit
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: isCredit ? Colors.green : Colors.red,
                                  ),
                                ),
                                title: Text(
                                  description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}: ${createdAt.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                trailing: Text(
                                  '${isCredit ? '+' : '-'}${bifFormat.format(amount)} BIF',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isCredit ? Colors.green : Colors.red,
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

  @override
  void dispose() {
    _depositChannel?.unsubscribe();
    _withdrawChannel?.unsubscribe();
    _walletChannel?.unsubscribe();
    super.dispose();
  }
}
