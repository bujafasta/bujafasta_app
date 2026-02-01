import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_room_page.dart';

class ChatPreview {
  final String id;
  final String title;
  final String? image;
  final String lastMessage;
  final DateTime lastAt;
  final int unreadCount;
  final bool isCustomerCare;
  final String? productId;
  final String? context; // 👈 ADD THIS for message type
  final bool isVerified; // 👈 Add this field

  ChatPreview({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.lastAt,
    this.image,
    this.unreadCount = 0,
    this.isCustomerCare = false,
    this.productId,
    this.context, // 👈 ADD THIS
    this.isVerified = false, // 👈 Default to false
  });
}

class ChatListPage extends StatefulWidget {
  final bool agentDepositMode;
  final bool agentWithdrawMode; // 👈 ADD THIS

  const ChatListPage({
    super.key,
    this.agentDepositMode = false,
    this.agentWithdrawMode = false, // 👈 ADD THIS
  });

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _confirmingDeposit = false;

  List<ChatPreview> chats = [];
  bool loading = true;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _conversationsChannel;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _messagesChannel?.unsubscribe();
    _conversationsChannel?.unsubscribe();
    super.dispose();
  }

  // 🔄 Subscribe to real-time updates
  void _subscribeToUpdates() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // Listen to new messages
    _messagesChannel = supabase
        .channel('chat_list_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            _loadChats(); // Reload when new message arrives
          },
        )
        .subscribe();

    // Listen to conversation updates
    _conversationsChannel = supabase
        .channel('chat_list_conversations')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            _loadChats(); // Reload when conversation updates
          },
        )
        .subscribe();
  }

  Future<void> _continueDepositFlow(String phone) async {
    final supabase = Supabase.instance.client;

    // 1️⃣ Validate phone
    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Phone number is required')));
      return;
    }

    // 2️⃣ Find user by phone
    final profile = await supabase
        .from('profiles')
        .select('id, first_name, last_name, phone')
        .eq('phone', phone)
        .maybeSingle();

    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user found with this phone number')),
      );
      return;
    }

    // 3️⃣ Close bottom sheet
    if (!mounted) return;
    Navigator.pop(context);

    // Reset amount input
    _amountController.clear();

    // 4️⃣ SHOW STRONG (NON-DISMISSIBLE) UI
    showDialog(
      context: context,
      barrierDismissible: false, // 🚫 cannot close by tapping outside
      builder: (_) {
        return AlertDialog(
          title: const Text('Confirm Deposit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👤 USER INFO
              Text(
                'Name:',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Phone:',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                profile['phone'],
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 16),

              // 💰 AMOUNT INPUT
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Deposit amount',
                  hintText: 'Enter amount',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            // ❌ CANCEL
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),

            // ✅ CONFIRM (UI ONLY)
            ElevatedButton(
              onPressed: _confirmingDeposit
                  ? null
                  : () async {
                      final amountText = _amountController.text.trim();

                      if (amountText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Deposit amount is required'),
                          ),
                        );
                        return;
                      }

                      final amount = num.tryParse(amountText);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid deposit amount'),
                          ),
                        );
                        return;
                      }

                      setState(() {
                        _confirmingDeposit = true;
                      });

                      try {
                        final supabase = Supabase.instance.client;

                        // 🔥 CALL BACKEND FUNCTION
                        await supabase.rpc(
                          'admin_deposit_wallet',
                          params: {
                            'p_user_id': profile['id'], // 👈 IMPORTANT
                            'p_amount': amount,
                            'p_description': 'Manual admin deposit',
                          },
                        );

                        if (!mounted) return;

                        Navigator.pop(context); // close dialog

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Deposit successful')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Deposit failed: $e')),
                        );
                      } finally {
                        if (mounted) {
                          setState(() {
                            _confirmingDeposit = false;
                          });
                        }
                      }
                    },
              child: _confirmingDeposit
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirm deposit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadChats() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    List<dynamic> convos;

    // 👤 Show only deposit chats if agentDepositMode is true (agent Payment Verification)
    if (widget.agentDepositMode) {
      // 🟢 Deposit verification inbox
      convos = await supabase
          .from('conversations')
          .select()
          .eq('type', 'deposit')
          .order('last_message_at', ascending: false);
    } else if (widget.agentWithdrawMode) {
      // 🟠 Withdraw verification inbox
      convos = await supabase
          .from('conversations')
          .select()
          .eq('type', 'withdraw')
          .order('last_message_at', ascending: false);
    } else {
      // 🔵 Normal user chats
      convos = await supabase
          .from('conversations')
          .select()
          .or('buyer_id.eq.${user.id},seller_id.eq.${user.id}')
          .order('last_message_at', ascending: false);
    }

    List<ChatPreview> list = [];

    for (final c in convos) {
      final convoId = c['id'];
      final sellerId = c['seller_id'];
      final buyerId = c['buyer_id'];
      final bool iAmSeller = user.id == sellerId;

      String title = 'User';
      String? image;
      bool isVerified = false; // Track verification status

      if (widget.agentDepositMode && c['type'] == 'deposit') {
        // Agents: always show buyer profile for deposit chats!
        final profile = await supabase
            .from('profiles')
            .select('first_name, last_name, avatar_url')
            .eq('id', buyerId)
            .maybeSingle();

        if (profile != null) {
          final first = profile['first_name'] ?? '';
          final last = profile['last_name'] ?? '';
          title = ('$first $last').trim().isEmpty ? 'Buyer' : '$first $last';
          image = profile['avatar_url'];
        }
      } else if (iAmSeller) {
        // Regular seller view: show buyer
        final profile = await supabase
            .from('profiles')
            .select('first_name, last_name, avatar_url')
            .eq('id', buyerId)
            .maybeSingle();

        if (profile != null) {
          final first = profile['first_name'] ?? '';
          final last = profile['last_name'] ?? '';
          title = ('$first $last').trim().isEmpty ? 'Buyer' : '$first $last';
          image = profile['avatar_url'];
        }
      } else {
        // Regular buyer view: show shop
        final shop = await supabase
            .from('shops')
            .select('shop_name, shop_avatar_url, is_verified')
            .eq('owner_id', sellerId)
            .maybeSingle();

        if (shop != null) {
          title = shop['shop_name'] ?? 'Shop';
          image = shop['shop_avatar_url'];
          isVerified = shop['is_verified'] == true; // Update verification flag
        }
      }

      // Count unread messages using the STATUS field
      final unread = await supabase
          .from('messages')
          .select('id')
          .eq('conversation_id', convoId)
          .eq('recipient_id', user.id)
          .neq('status', 'read');

      // Get last message details
      final lastMsg = await supabase
          .from('messages')
          .select('context, deleted_by, body')
          .eq('conversation_id', convoId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final lastMsgContext = lastMsg?['context'];
      final deletedBy = lastMsg?['deleted_by'];
      final isDeletedByMe = deletedBy == user.id;

      // Format last message based on its context
      String displayLastMessage = c['last_message'] ?? '';
      if (isDeletedByMe) {
        displayLastMessage = 'You deleted this message';
      } else if (lastMsgContext == 'image') {
        displayLastMessage = '📷 Photo';
      } else if (lastMsgContext == 'audio') {
        displayLastMessage = '🎤 Voice message';
      }

      list.add(
        ChatPreview(
          id: convoId,
          title: title,
          image: image,
          lastMessage: displayLastMessage,
          lastAt: DateTime.parse(c['last_message_at'] ?? c['created_at']),
          unreadCount: unread.length,
          isCustomerCare: false,
          productId: c['product_id']?.toString(),
          context: lastMsgContext,
          isVerified: isVerified, // 👈 Include this
        ),
      );
    }

    // ...existing code...

    setState(() {
      chats = list;
      loading = false;
    });
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return DateFormat.Hm().format(dt);
    } else if (now.difference(dt).inDays == 1) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yy').format(dt);
    }
  }

  void _openChat(ChatPreview chat) async {
    // Navigate to chat
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          chatId: chat.id,
          chatTitle: chat.title,
          chatImage: chat.image,
          isCustomerCare: chat.isCustomerCare,
        ),
      ),
    );

    // Reload chats when returning (to update unread counts)
    _loadChats();
  }

  Widget _chatTile(ChatPreview chat) {
    return ListTile(
      onTap: () => _openChat(chat),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: (chat.image != null && chat.image!.isNotEmpty)
                ? NetworkImage(chat.image!)
                : null,
            backgroundColor: Colors.grey[200],
            child: (chat.image == null || chat.image!.isEmpty)
                ? const Icon(Icons.person)
                : null,
          ),
        ],
      ),
      title: Row(
        children: [
          Text(
            chat.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: chat.unreadCount > 0
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          if (chat.isCustomerCare || chat.isVerified)
            Padding(
              padding: const EdgeInsets.only(left: 6.0), // Add a slight gap
              child: Image.asset(
                'assets/verified_tick.png', // Reference to the PNG icon
                height: 14,
                width: 14,
              ),
            ),
        ],
      ),
      subtitle: Text(
        chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: chat.unreadCount > 0 ? Colors.black87 : Colors.grey,
          fontWeight: chat.unreadCount > 0
              ? FontWeight.w500
              : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(chat.lastAt),
            style: TextStyle(
              fontSize: 12,
              color: chat.unreadCount > 0 ? Colors.green : Colors.grey,
              fontWeight: chat.unreadCount > 0
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${chat.unreadCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openAddDepositSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // allows keyboard push-up
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Title
              const Text(
                'Add Deposit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              // 📞 Phone input
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Enter phone number',
                  hintText: 'eg: 61234567',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              // 🔘 Continue button (no logic yet)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final phone = _phoneController.text.trim();

                    _continueDepositFlow(phone);
                  },

                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        actions: [
          // ➕ ADD DEPOSIT ICON (AGENT ONLY)
          if (widget.agentDepositMode == true)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add deposit',
              onPressed: _openAddDepositSheet,
            ),

          // 🔄 Refresh button (always visible)
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadChats),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : chats.isEmpty
          ? const Center(child: Text("No conversations yet"))
          : RefreshIndicator(
              onRefresh: _loadChats,
              child: ListView.separated(
                itemBuilder: (_, i) => _chatTile(chats[i]),
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemCount: chats.length,
              ),
            ),
    );
  }
}
