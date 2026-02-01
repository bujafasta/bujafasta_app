import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart'; // 👈 ADD THIS
import 'package:flutter_image_compress/flutter_image_compress.dart'; // 👈 ADD THIS
import 'dart:convert';
import 'package:bujafasta_app/models/product.dart';
import 'package:bujafasta_app/pages/product/product_details_page.dart';

class ChatRoomPage extends StatefulWidget {
  final String chatId;
  final String? chatTitle;
  final String? chatImage;
  final bool isCustomerCare;
  final String? productId;

  // ✅ ADD THESE
  final String? phone;
  final String? countryCode;

  ChatRoomPage({
    super.key,
    required this.chatId,
    this.chatTitle,
    this.chatImage,
    this.isCustomerCare = false,
    this.productId,
    this.phone,
    this.countryCode,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
  final bool _shopIsVerified = false; // Track whether the shop is verified.
}

/// simple message model for UI-only chat
class Msg {
  final String id;
  final String clientId;
  final String text;
  final String from;
  final DateTime at;
  final String status;
  final bool isPending;
  final String? context;
  final bool isDeletedByMe; // 👈 ADD THIS

  // reply support
  final int? replyToId;
  final String? replyToText;
  final String? replyToFrom;
  final String? replyToContext;

  Msg({
    required this.id,
    required this.clientId,
    required this.text,
    this.isDeletedByMe = false,
    required this.from,
    required this.at,
    required this.status,
    required this.isPending,
    this.context, // 👈 ADD THIS
    this.replyToId,
    this.replyToText,
    this.replyToFrom,
    this.replyToContext,
  });
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  // 🎤 voice recording
  final AudioRecorder _recorder = AudioRecorder();

  // Chat title and image resolution
  String? _resolvedChatTitle;
  String? _resolvedChatImage;

  // 📦 PRODUCT PREVIEW DATA
  Map<String, dynamic>? product; // Stores product details from database
  String? shopId;
  String? sellerId;

  bool loadingProduct = false; // Shows if we're still loading product data
  // 💰 SELLER STATUS (NEW!)
  bool isSeller = false; // TRUE if current user is the seller
  bool loadingSellerStatus = true; // TRUE while checking seller status

  // 🎤 voice recording
  bool _isRecording = false;
  bool _isPaused = false; // 👈 ADD THIS
  int _recordingSeconds = 0; // 👈 ADD THIS
  Timer? _recordingTimer; // 👈 ADD THIS

  String? _recordedPath;
  final AudioPlayer _soundPlayer = AudioPlayer();

  bool _realtimeReady = false;

  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  bool _otherIsRecording = false; // 👈 ADD THIS

  bool _isOnline = true;
  bool _shopIsVerified = false;
  bool _retryRunning = false; // 🔒 mutex (prevents double retry)

  bool _otherIsTyping = false;
  Timer? _typingTimer;
  RealtimeChannel? _typingChannel;

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  // 🔁 reply state
  Msg? _replyToMessage;

  List<Msg> messages = [];
  final Map<String, GlobalKey> _messageKeys = {};

  RealtimeChannel? _messagesChannel;

  void _handleOfferBuy(Msg m) async {
    final supabase = Supabase.instance.client;

    // 1️⃣ Get active offer for this conversation
    final offer = await supabase
        .from('offers')
        .select('id, product_id')
        .eq('conversation_id', widget.chatId)
        .eq('buyer_id', supabase.auth.currentUser!.id)
        .eq('status', 'active')
        .gt('expires_at', DateTime.now().toIso8601String())
        .maybeSingle();

    if (offer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Offer expired or not valid")),
      );
      return;
    }

    // 2️⃣ Navigate to product page WITH offerId
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsPage(
          productId: offer['product_id'],
          offerId: offer['id'],
          shopId: shopId!,
          sellerId: sellerId!,
        ),
      ),
    );
  }

  void _clearReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  // 👇 ADD THESE NEW METHODS
  Future<void> _playStartRecordSound() async {
    try {
      await _soundPlayer.play(AssetSource('start_record.aac')); // 👈 FIXED
    } catch (e) {
      print('Error playing start sound:  $e');
    }
  }

  Future<void> _loadChatHeader() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      // Get conversation participants
      final convo = await supabase
          .from('conversations')
          .select('buyer_id, seller_id')
          .eq('id', widget.chatId)
          .single();

      final buyerId = convo['buyer_id'];
      final sellerId = convo['seller_id'];

      final bool iAmSeller = currentUser.id == sellerId;

      if (iAmSeller) {
        // 👤 Seller should see BUYER
        final profile = await supabase
            .from('profiles')
            .select('first_name, last_name, avatar_url')
            .eq('id', buyerId)
            .maybeSingle();

        setState(() {
          final first = profile?['first_name'] ?? '';
          final last = profile?['last_name'] ?? '';
          _resolvedChatTitle = ('$first $last').trim().isEmpty
              ? 'Buyer'
              : '$first $last';
          _resolvedChatImage = profile?['avatar_url'];
          _shopIsVerified = false;
        });
      } else {
        // 🏪 Buyer should see SHOP
        final shop = await supabase
            .from('shops')
            .select('shop_name, shop_avatar_url, is_verified')
            .eq('owner_id', sellerId)
            .maybeSingle();

        setState(() {
          _resolvedChatTitle = shop?['shop_name'] ?? 'Shop';
          _resolvedChatImage = shop?['shop_avatar_url'];
          _shopIsVerified = shop?['is_verified'] == true;
        });
      }
    } catch (e) {
      setState(() {
        _resolvedChatTitle = 'Chat';
        _resolvedChatImage = null;
        _shopIsVerified = false;
      });
    }
  }

  Future<void> _playEndRecordSound() async {
    try {
      await _soundPlayer.play(AssetSource('end_record.aac')); // 👈 FIXED
    } catch (e) {
      print('Error playing end sound:  $e');
    }
  }

  Future<void> _playCancelRecordSound() async {
    try {
      await _soundPlayer.play(AssetSource('cancel_record.aac'));
    } catch (e) {
      print('Error playing cancel sound:  $e');
    }
  }

  Future<void> _setTyping(bool value) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('typing_status').upsert({
      'conversation_id': widget.chatId,
      'user_id': user.id,
      'is_typing': value,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _setRecording(bool value) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase.from('typing_status').upsert({
      'conversation_id': widget.chatId,
      'user_id': user.id,
      'is_recording': value,
      'is_typing': false, // Turn off typing when recording
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // 🔁 fetch replied message for receiver (realtime JOIN fix)
  Future<Map<String, dynamic>?> _fetchReplyMessage(int replyId) async {
    final supabase = Supabase.instance.client;

    final res = await supabase
        .from('messages')
        .select('id, body, sender_id, context') // 👈 ADD context
        .eq('id', replyId)
        .maybeSingle();

    return res;
  }

  Future<void> _syncLatestMessages() async {
    final supabase = Supabase.instance.client;

    if (messages.isEmpty) return;

    final lastTime = messages.last.at.toIso8601String();

    final res = await supabase
        .from('messages')
        .select()
        .eq('conversation_id', widget.chatId)
        .gt('created_at', lastTime)
        .order('created_at', ascending: true);

    if (res.isEmpty) return;

    setState(() {
      for (final m in res) {
        final clientId = m['client_id'] ?? m['id'].toString();
        final exists = messages.any((msg) => msg.clientId == clientId);

        if (!exists) {
          messages.add(
            Msg(
              id: m['id'].toString(),
              clientId: clientId,
              text: m['body'] ?? '',
              from:
                  m['sender_id'] ==
                      Supabase.instance.client.auth.currentUser?.id
                  ? 'me'
                  : 'other',
              at: DateTime.parse(m['created_at']),
              status: m['status'] ?? 'sent',
              isPending: false,
              context: m['context'],
              isDeletedByMe: false, // 👈 ADD THIS LINE
            ),
          );
        }
      }

      messages.sort((a, b) => a.at.compareTo(b.at));
    });

    _scrollToBottom();
  }

  Future<void> _sendPendingMessage(Msg m) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final convo = await supabase
          .from('conversations')
          .select('buyer_id, seller_id')
          .eq('id', widget.chatId)
          .single();

      final buyerId = convo['buyer_id'];
      final sellerId = convo['seller_id'];
      final recipientId = user.id == buyerId ? sellerId : buyerId;

      final res = await supabase
          .from('messages')
          .insert({
            'client_id': m.clientId,
            'conversation_id': widget.chatId,
            'sender_id': user.id,
            'recipient_id': recipientId,
            'body': m.text,
            'context': m.context ?? 'text', // 👈 ADD THIS
            'status': 'sent',
          })
          .select()
          .single();

      setState(() {
        final index = messages.indexWhere((x) => x.clientId == m.clientId);

        if (index != -1) {
          final old = messages[index];

          messages[index] = Msg(
            id: res['id'].toString(),
            clientId: m.clientId,
            text: m.text,
            from: 'me',
            at: DateTime.parse(res['created_at']),
            status: 'sent',
            isPending: false,
            context: res['context'], // 👈 ADD THIS
            isDeletedByMe: false, // 👈 ADD THIS LINE
            replyToId: old.replyToId,
            replyToText: old.replyToText,
            replyToFrom: old.replyToFrom,
            replyToContext: old.replyToContext, // 👈 ADD THIS
          );

          messages.sort((a, b) => a.at.compareTo(b.at));
        }
      });
    } catch (e) {
      // stays pending
    }
  }

  Future<void> _retryPendingMessagesSafely() async {
    if (_retryRunning) return;
    _retryRunning = true;

    try {
      final pending = messages.where((m) => m.isPending).toList()
        ..sort((a, b) => a.at.compareTo(b.at));

      for (final m in pending) {
        await _sendPendingMessage(m);
      }
    } finally {
      _retryRunning = false;
    }
  }

  Future<void> _loadMessages() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final res = await supabase
        .from('messages')
        .select('''
      *,
      reply_to_message:  reply_to_message_id (
        id,
        body,
        sender_id,
        context
      )
    ''') // 👈 ADD context HERE
        .eq('conversation_id', widget.chatId)
        .order('created_at', ascending: true);

    messages = res.map<Msg>((m) {
      final isDeletedByMe = m['deleted_by'] == user.id; // 👈 NEW LINE

      return Msg(
        id: m['id'].toString(),
        clientId: m['client_id'] ?? m['id'].toString(),
        text: m['body'] ?? '',
        from: m['sender_id'] == user.id ? 'me' : 'other',
        at: DateTime.parse(m['created_at']),
        status: m['status'] ?? 'sent',
        isPending: false,
        context: m['context'],
        isDeletedByMe: isDeletedByMe, // 👈 NEW LINE
        replyToId: m['reply_to_message_id'],
        replyToText: m['reply_to_message']?['body'],
        replyToFrom: m['reply_to_message']?['sender_id'] == user.id
            ? 'You'
            : 'Other',
        replyToContext: m['reply_to_message']?['context'],
      );
    }).toList();

    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Mark messages as delivered
    for (final m in messages) {
      if (m.from == 'other' && m.status == 'sent') {
        Supabase.instance.client
            .from('messages')
            .update({'status': 'delivered'})
            .eq('id', m.id);
      }
    }
  }

  void _listenToConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final hasInternet = results.any((r) => r != ConnectivityResult.none);

      if (hasInternet && !_isOnline) {
        _isOnline = true;
        await _retryPendingMessagesSafely();
      } else if (!hasInternet) {
        _isOnline = false;
      }
    });
  }

  void _subscribeToTyping() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    _typingChannel = supabase
        .channel('typing_${widget.chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'typing_status',
          callback: (payload) {
            final data = payload.newRecord;

            if (data['conversation_id'] != widget.chatId) return;
            if (data['user_id'] == user?.id) return;

            setState(() {
              _otherIsTyping = data['is_typing'] == true;
              _otherIsRecording = data['is_recording'] == true; // 👈 ADD THIS
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          },
        )
        .subscribe();
  }

  void _subscribeToMessages() {
    final supabase = Supabase.instance.client;

    _messagesChannel = supabase
        .channel('messages_${widget.chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            if (payload.eventType.toString() == 'UPDATE') {
              final updated = payload.newRecord;

              if (updated['conversation_id'].toString() != widget.chatId) {
                return;
              }

              final updatedId = updated['id'].toString();
              final updatedClientId = updated['client_id'] ?? updatedId;

              int index = messages.indexWhere(
                (m) => m.clientId == updatedClientId,
              );

              if (index == -1) {
                index = messages.indexWhere((m) => m.id == updatedId);
              }

              if (index != -1) {
                setState(() {
                  final old = messages[index];

                  messages[index] = Msg(
                    id: old.id,
                    clientId: old.clientId,
                    text: updated['body'] ?? old.text,
                    from: old.from,
                    at: old.at,
                    status: updated['status'] ?? old.status,
                    isPending: false,
                    context: updated['context'] ?? old.context, // 👈 ADD THIS
                    isDeletedByMe: old.isDeletedByMe, // 👈 ADD THIS
                    replyToId: old.replyToId,
                    replyToText: old.replyToText,
                    replyToFrom: old.replyToFrom,
                    replyToContext: old.replyToContext, // 👈 ADD THIS
                  );
                });
              }

              return;
            }

            final m = payload.newRecord;

            if (m['conversation_id'].toString() != widget.chatId) return;

            final user = supabase.auth.currentUser;

            if (m['sender_id'] != user?.id && m['status'] == 'sent') {
              Supabase.instance.client
                  .from('messages')
                  .update({'status': 'delivered'})
                  .eq('id', m['id']);
            }

            // ignore my own optimistic inserts
            if (m['sender_id'] == user?.id) {
              final incomingClientId = m['client_id'];

              final index = messages.indexWhere(
                (msg) => msg.clientId == incomingClientId,
              );

              if (index != -1) {
                setState(() {
                  final old = messages[index];

                  messages[index] = Msg(
                    id: m['id'].toString(),
                    clientId: old.clientId,
                    text: old.text,
                    from: 'me',
                    at: DateTime.parse(m['created_at']),
                    status: m['status'] ?? old.status,
                    isPending: false,
                    context: m['context'] ?? old.context, // 👈 ADD THIS
                    isDeletedByMe: old.isDeletedByMe, // 👈 ADD THIS
                    replyToId: old.replyToId,
                    replyToText: old.replyToText,
                    replyToFrom: old.replyToFrom,
                    replyToContext: old.replyToContext, // 👈 ADD THIS
                  );

                  messages.sort((a, b) => a.at.compareTo(b.at));
                });
              }

              return;
            }

            final incomingClientId = m['client_id'] ?? m['id'].toString();

            if (m['sender_id'] ==
                Supabase.instance.client.auth.currentUser?.id) {
              final index = messages.indexWhere(
                (msg) => msg.clientId == incomingClientId,
              );

              if (index != -1) {
                setState(() {
                  final old = messages[index];

                  messages[index] = Msg(
                    id: old.id,
                    clientId: old.clientId,
                    text: old.text,
                    from: 'me',
                    at: old.at,
                    status: m['status'] ?? old.status,
                    isPending: false,
                    context: m['context'] ?? old.context, // 👈 ADD THIS
                    isDeletedByMe: old.isDeletedByMe, // 👈 ADD THIS
                    replyToId: old.replyToId,
                    replyToText: old.replyToText,
                    replyToFrom: old.replyToFrom,
                    replyToContext: old.replyToContext, // 👈 ADD THIS
                  );
                });
              }

              return;
            }

            final exists = messages.any(
              (msg) => msg.clientId == incomingClientId,
            );

            if (exists) return;

            final replyId = m['reply_to_message_id'];

            String? replyText;
            String? replyFrom;
            String? replyContext; // 👈 ADD THIS

            if (replyId != null) {
              final reply = await _fetchReplyMessage(replyId);

              if (reply != null) {
                replyText = reply['body'];
                replyContext = reply['context']; // 👈 ADD THIS
                replyFrom =
                    reply['sender_id'] ==
                        Supabase.instance.client.auth.currentUser?.id
                    ? 'You'
                    : 'Other';
              }
            }

            setState(() {
              messages.add(
                Msg(
                  id: m['id'].toString(),
                  clientId: m['client_id'] ?? m['id'].toString(),
                  text: m['body'] ?? '',
                  from: 'other',
                  at: DateTime.parse(m['created_at']),
                  status: m['status'] ?? 'sent',
                  isPending: false,
                  context: m['context'], // 👈 ADD THIS
                  isDeletedByMe: false, // 👈 ADD THIS
                  replyToId: replyId,
                  replyToText: replyText,
                  replyToFrom: replyFrom,
                  replyToContext:
                      replyContext, // 👈 ADD THIS (it's already extracted above)
                ),
              );
            });

            _markAsRead();
            _scrollToBottom();
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            if (_realtimeReady) {
              _syncLatestMessages();
            }
            _realtimeReady = true;
          }
        });
  }

  @override
  void initState() {
    super.initState();
    debugPrint('💬 ChatRoomPage opened for chatId=${widget.chatId}');
    _loadChatHeader(); // 👈 ADD THIS LINE
    _loadMessages().then((_) {
      _markAsRead();
    });

    _subscribeToMessages();
    _subscribeToTyping();
    _listenToConnectivity();
    _loadProductDetails(); // 👈 ADD THIS LINE - Load product when chat opens
    _checkSellerStatus(); // 👈 ADD THIS LINE - Check if user is seller
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    _messagesChannel?.unsubscribe();
    _typingChannel?.unsubscribe();
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    _recorder.dispose();
    _soundPlayer.dispose(); // 👈 ADD THIS
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;

      final position = _scroll.position.maxScrollExtent;

      _scroll.animateTo(
        position,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  // 📦 LOAD PRODUCT DETAILS FROM SUPABASE
  // 📦 LOAD PRODUCT DETAILS FROM SUPABASE
  Future<void> _loadProductDetails() async {
    final supabase = Supabase.instance.client;
    String? productIdToFetch = widget.productId;

    // 🔄 If no productId was passed, fetch it from the conversation
    if (productIdToFetch == null) {
      try {
        final convo = await supabase
            .from('conversations')
            .select('product_id')
            .eq('id', widget.chatId)
            .maybeSingle();

        if (convo != null && convo['product_id'] != null) {
          productIdToFetch = convo['product_id'].toString();
        } else {
          // No product linked to this conversation
          return;
        }
      } catch (e) {
        print('Error fetching conversation product_id: $e');
        return;
      }
    }

    // Show loading state
    setState(() {
      loadingProduct = true;
    });

    try {
      // Fetch product details from Supabase
      final res = await supabase
          .from('products')
          .select('id, name, price, image_urls, shop_id')
          .eq('id', productIdToFetch!)
          .single();

      // fetch shop info
      final shop = await supabase
          .from('shops')
          .select('id, owner_id')
          .eq('id', res['shop_id'])
          .single();

      // Store the product data
      setState(() {
        product = res;
        shopId = shop['id'];
        sellerId = shop['owner_id'];
        loadingProduct = false;
      });
    } catch (e) {
      // If something goes wrong, stop loading
      setState(() {
        loadingProduct = false;
      });
      print('Error loading product: $e');
    }
  }

  // 💰 CHECK IF CURRENT USER IS THE SELLER
  Future<void> _checkSellerStatus() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        isSeller = false;
        loadingSellerStatus = false;
      });
      return;
    }

    try {
      // Fetch conversation to check seller_id
      final convo = await supabase
          .from('conversations')
          .select('seller_id')
          .eq('id', widget.chatId)
          .single();

      // Check if current user is the seller
      setState(() {
        isSeller = (convo['seller_id'] == user.id);
        loadingSellerStatus = false;
      });
    } catch (e) {
      print('Error checking seller status: $e');
      setState(() {
        isSeller = false;
        loadingSellerStatus = false;
      });
    }
  }

  // 💰 SHOW MAKE OFFER MODAL (SELLER ONLY)
  void _showMakeOfferModal() {
    // Controller for offer price input
    final TextEditingController offerController = TextEditingController();

    // Error message state
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows keyboard to push modal up
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          // Allows setState inside modal
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(
                  context,
                ).viewInsets.bottom, // Keyboard padding
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === HEADER ===
                    Row(
                      children: [
                        const Icon(
                          Icons.local_offer,
                          color: Colors.orange,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Make Special Offer',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // === CURRENT PRICE (READ-ONLY) ===
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Price: ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            '${product!['price']} BIF',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // === OFFER PRICE INPUT ===
                    const Text(
                      'Your Offer Price',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: offerController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter offer price',
                        suffixText: 'BIF',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorText: errorMessage, // Shows validation errors
                      ),
                      onChanged: (_) {
                        // Clear error when user types
                        setModalState(() {
                          errorMessage = null;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // === VALIDATION HINT ===
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Offer must be less than current price',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // === SUBMIT BUTTON ===
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Validate input
                          final offerText = offerController.text.trim();

                          if (offerText.isEmpty) {
                            setModalState(() {
                              errorMessage = 'Please enter an offer price';
                            });
                            return;
                          }

                          final offerPrice = double.tryParse(offerText);

                          if (offerPrice == null) {
                            setModalState(() {
                              errorMessage = 'Please enter a valid number';
                            });
                            return;
                          }

                          final currentPrice = double.parse(
                            product!['price'].toString(),
                          );

                          if (offerPrice >= currentPrice) {
                            setModalState(() {
                              errorMessage =
                                  'Offer must be less than ${currentPrice.toStringAsFixed(0)} BIF';
                            });
                            return;
                          }

                          if (offerPrice <= 0) {
                            setModalState(() {
                              errorMessage = 'Offer must be greater than 0';
                            });
                            return;
                          }

                          // All validations passed - show confirmation
                          Navigator.pop(context); // Close input modal
                          _showOfferConfirmation(
                            offerPrice,
                          ); // Show confirmation
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ⚠️ SHOW CONFIRMATION BEFORE CREATING OFFER
  void _showOfferConfirmation(double offerPrice) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              const Text('Confirm Offer'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You are creating a private offer for this buyer only.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'This buyer will be able to purchase this product at the price you set.',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Original Price:'),
                        Text(
                          '${product!['price']} BIF',
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Offer Price: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${offerPrice.toStringAsFixed(0)} BIF',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Expires in 24 hours',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close confirmation
                _createOffer(offerPrice); // Actually create the offer!
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text(
                'Confirm Offer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // 💾 CREATE OFFER IN SUPABASE DATABASE
  // 💾 CREATE OFFER IN SUPABASE DATABASE
  Future<void> _createOffer(double offerPrice) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to make an offer'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get conversation details (buyer_id)
      final convo = await supabase
          .from('conversations')
          .select('buyer_id, seller_id')
          .eq('id', widget.chatId)
          .single();

      final buyerId = convo['buyer_id'];
      final sellerId = convo['seller_id'];

      // Create offer in database
      final offerResult = await supabase
          .from('offers')
          .insert({
            'product_id': int.parse(product!['id'].toString()),
            'conversation_id': widget.chatId,
            'buyer_id': buyerId,
            'seller_id': sellerId,
            'offer_price': offerPrice,
            'expires_at': DateTime.now()
                .add(const Duration(hours: 24))
                .toIso8601String(),
            'status': 'active',
          })
          .select()
          .single();

      // 📨 SEND SYSTEM MESSAGE WITH OFFER DETAILS
      final offerMessage =
          '''
🎉 Special Offer! 

Product: ${product!['name']}
Original Price: ${product!['price']} BIF
Offer Price: ${offerPrice.toStringAsFixed(0)} BIF

⏰ Expires in 24 hours
''';

      final clientId = DateTime.now().millisecondsSinceEpoch.toString();

      // Insert offer message
      await supabase.from('messages').insert({
        'client_id': clientId,
        'conversation_id': widget.chatId,
        'sender_id': sellerId, // Seller is sending the offer
        'recipient_id': buyerId, // Buyer receives the offer
        'body': offerMessage,
        'context': 'offer', // 👈 NEW context type
        'status': 'sent',
      });

      // Update conversation last message
      await supabase
          .from('conversations')
          .update({
            'last_message': 'Special offer sent',
            'last_message_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.chatId);

      // Close loading
      if (mounted) Navigator.pop(context);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Offer sent!  ${offerPrice.toStringAsFixed(0)} BIF'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Scroll to bottom to show new offer message
      _scrollToBottom();
    } catch (e) {
      // Close loading
      if (mounted) Navigator.pop(context);

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create offer:  $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      // 🎵 Play start sound
      await _playStartRecordSound(); // 👈 ADD THIS

      final dir = await getTemporaryDirectory();

      _recordedPath =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(const RecordConfig(), path: _recordedPath!);

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingSeconds = 0;
      });

      _startRecordingTimer();
      await _setRecording(true);
    }
  }

  Future<void> _stopRecordingAndSend() async {
    _recordingTimer?.cancel();
    await _setRecording(false);

    // 🎵 Play end sound
    await _playEndRecordSound(); // 👈 ADD THIS

    final path = await _recorder.stop();

    if (path == null) {
      return;
    }

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordingSeconds = 0;
    });

    await _sendVoiceMessage(path);
  }

  Future<void> _cancelRecording() async {
    // 🎵 Play cancel sound
    await _playCancelRecordSound(); // 👈 ADD THIS

    await _recorder.stop();
    _recordingTimer?.cancel();
    await _setRecording(false);

    // Delete the recorded file
    if (_recordedPath != null) {
      final file = File(_recordedPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordingSeconds = 0;
      _recordedPath = null;
    });
  }

  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingSeconds++;
      });
    });
  }

  Future<void> _pauseRecording() async {
    await _recorder.pause();
    _recordingTimer?.cancel();
    setState(() {
      _isPaused = true;
    });
  }

  Future<void> _resumeRecording() async {
    await _recorder.resume();
    _startRecordingTimer();
    setState(() {
      _isPaused = false;
    });
  }

  Future<void> _pickAndSendImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      await _sendImageMessage(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatRecordingTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _sendVoiceMessage(String filePath) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    // 👇 CREATE CLIENT ID FOR OPTIMISTIC UI
    final clientId = DateTime.now().millisecondsSinceEpoch.toString();

    // 👇 ADD OPTIMISTIC MESSAGE IMMEDIATELY
    final tempMsg = Msg(
      id: clientId,
      clientId: clientId,
      text: 'Sending voice message... ', // Placeholder text
      from: 'me',
      at: DateTime.now(),
      status: 'sent',
      isPending: true,
      context: 'audio',
      isDeletedByMe: false, // 👈 ADD THIS LINE
    );

    setState(() {
      messages.add(tempMsg);
    });

    // 👇 SCROLL TO SHOW NEW MESSAGE
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        // Remove optimistic message on failure
        setState(() {
          messages.removeWhere((m) => m.clientId == clientId);
        });

        return;
      }

      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      final bytes = await file.readAsBytes();

      // Upload to storage
      await supabase.storage
          .from('voice_messages')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'audio/m4a',
              upsert: false,
            ),
          );

      // Get public URL
      final audioUrl = supabase.storage
          .from('voice_messages')
          .getPublicUrl(fileName);

      // Get conversation details
      final convo = await supabase
          .from('conversations')
          .select('buyer_id, seller_id')
          .eq('id', widget.chatId)
          .single();

      final recipientId = user.id == convo['buyer_id']
          ? convo['seller_id']
          : convo['buyer_id'];

      // Insert message with client_id
      final messageResult = await supabase
          .from('messages')
          .insert({
            'client_id': clientId, // 👈 ADD THIS
            'conversation_id': widget.chatId,
            'sender_id': user.id,
            'recipient_id': recipientId,
            'body': audioUrl,
            'context': 'audio',
            'status': 'sent',
          })
          .select()
          .single();

      // 👇 UPDATE OPTIMISTIC MESSAGE WITH REAL DATA
      setState(() {
        final index = messages.indexWhere((m) => m.clientId == clientId);
        if (index != -1) {
          messages[index] = Msg(
            id: messageResult['id'].toString(),
            clientId: clientId,
            text: audioUrl, // Real audio URL
            from: 'me',
            at: DateTime.parse(messageResult['created_at']),
            status: messageResult['status'],
            isPending: false,
            context: 'audio',
            isDeletedByMe: false, // 👈 ADD THIS LINE
          );
        }
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice message sent! '),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // 👇 REMOVE OPTIMISTIC MESSAGE ON ERROR
      setState(() {
        messages.removeWhere((m) => m.clientId == clientId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send voice message:  $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _sendImageMessage(File imageFile) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final clientId = DateTime.now().millisecondsSinceEpoch.toString();

    // Show optimistic message
    final tempMsg = Msg(
      id: clientId,
      clientId: clientId,
      text: 'Sending image...',
      from: 'me',
      at: DateTime.now(),
      status: 'sent',
      isPending: true,
      context: 'image',
      isDeletedByMe: false, // 👈 ADD THIS LINE
    );

    setState(() {
      messages.add(tempMsg);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      // Compress image
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (compressedBytes == null) {
        throw Exception('Image compression failed');
      }

      // Upload to storage
      final fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage
          .from('images_message')
          .uploadBinary(
            fileName,
            compressedBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      // Get public URL
      final imageUrl = supabase.storage
          .from('images_message')
          .getPublicUrl(fileName);

      // Get conversation details
      final convo = await supabase
          .from('conversations')
          .select('buyer_id, seller_id')
          .eq('id', widget.chatId)
          .single();

      final recipientId = user.id == convo['buyer_id']
          ? convo['seller_id']
          : convo['buyer_id'];

      // Insert message
      final messageResult = await supabase
          .from('messages')
          .insert({
            'client_id': clientId,
            'conversation_id': widget.chatId,
            'sender_id': user.id,
            'recipient_id': recipientId,
            'body': imageUrl,
            'context': 'image',
            'status': 'sent',
          })
          .select()
          .single();

      // Update optimistic message
      setState(() {
        final index = messages.indexWhere((m) => m.clientId == clientId);
        if (index != -1) {
          messages[index] = Msg(
            id: messageResult['id'].toString(),
            clientId: clientId,
            text: imageUrl,
            from: 'me',
            at: DateTime.parse(messageResult['created_at']),
            status: messageResult['status'],
            isPending: false,
            context: 'image',
            isDeletedByMe: false, // 👈 ADD THIS LINE
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image sent! '),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() {
        messages.removeWhere((m) => m.clientId == clientId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final clientId = DateTime.now().millisecondsSinceEpoch.toString();

    final replyId = _replyToMessage?.id;
    final replyText = _replyToMessage?.text;
    final replyFrom = _replyToMessage?.from == 'me' ? 'You' : 'Other';

    final tempMsg = Msg(
      id: clientId,
      clientId: clientId,
      text: text,
      from: 'me',
      at: DateTime.now(),
      status: 'sent',
      isPending: true,
      context: 'text',
      isDeletedByMe: false, // 👈 ADD THIS LINE
      replyToId: replyId != null ? int.tryParse(replyId) : null,
      replyToText: replyText,
      replyToFrom: replyFrom,
      replyToContext: _replyToMessage?.context, // 👈 ADD THIS
    );

    setState(() {
      messages.add(tempMsg);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    _controller.clear();
    _clearReply();
    await _setTyping(false);

    final convo = await supabase
        .from('conversations')
        .select('buyer_id, seller_id')
        .eq('id', widget.chatId)
        .single();

    final buyerId = convo['buyer_id'];
    final sellerId = convo['seller_id'];
    final recipientId = user.id == buyerId ? sellerId : buyerId;

    try {
      final res = await supabase
          .from('messages')
          .insert({
            'client_id': clientId,
            'conversation_id': widget.chatId,
            'sender_id': user.id,
            'recipient_id': recipientId,
            'body': text,
            'context': 'text',
            'status': 'sent',
            'reply_to_message_id': replyId,
          })
          .select()
          .single();

      // 🔔 SEND PUSH NOTIFICATION (TEXT MESSAGE ONLY)

      // ✅ STEP 1: CHECK SESSION (VERY IMPORTANT)
      final session = supabase.auth.currentSession;

      if (session == null) {
        debugPrint('❌ NO SESSION — push notification NOT sent');
        return;
      }

      debugPrint('✅ SESSION EXISTS — calling notify_chat_message');

      // ✅ STEP 2: CALL EDGE FUNCTION
      final messageId = res['id'];

      if (messageId != null) {
        await supabase.functions.invoke(
          'notify_chat_message',
          body: {'message_id': messageId},
        );
      }

      setState(() {
        final index = messages.indexWhere((m) => m.clientId == clientId);
        if (index != -1) {
          final old = messages[index];

          messages[index] = Msg(
            id: res['id'].toString(),
            clientId: clientId,
            text: res['body'],
            from: 'me',
            at: DateTime.parse(res['created_at']),
            status: res['status'],
            isPending: false,
            context: res['context'],
            isDeletedByMe: false, // 👈 ADD THIS LINE
            replyToId: replyId != null ? int.tryParse(replyId) : null,
            replyToText: replyText,
            replyToFrom: replyFrom,
            replyToContext:
                old.replyToContext, // 👈 ADD THIS - preserve from old message
          );
        }
      });
    } catch (e) {
      // stays pending
    }

    await supabase
        .from('conversations')
        .update({
          'last_message': text,
          'last_message_at': DateTime.now().toIso8601String(),
        })
        .eq('id', widget.chatId);
  }

  Future<void> _markAsRead() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase
        .from('messages')
        .update({'status': 'read'})
        .eq('conversation_id', widget.chatId)
        .eq('recipient_id', user.id);

    setState(() {
      for (int i = 0; i < messages.length; i++) {
        if (messages[i].from == 'other') {
          final old = messages[i];

          messages[i] = Msg(
            id: old.id,
            clientId: old.clientId,
            text: old.text,
            from: old.from,
            at: old.at,
            status: 'read',
            isPending: false,
            context: old.context, // 👈 ADD THIS
            isDeletedByMe:
                old.isDeletedByMe, // 👈 ADD THIS LINE (preserve old value)
            replyToId: old.replyToId,
            replyToText: old.replyToText,
            replyToFrom: old.replyToFrom,
            replyToContext: old.replyToContext, // 👈 ADD THIS
          );
        }
      }
    });
  }

  Future<void> _deleteMessageForMe(Msg m) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Update database
      await supabase
          .from('messages')
          .update({'deleted_by': user.id})
          .eq('id', m.id);

      // Update UI
      setState(() {
        final index = messages.indexWhere((msg) => msg.clientId == m.clientId);
        if (index != -1) {
          final old = messages[index];
          messages[index] = Msg(
            id: old.id,
            clientId: old.clientId,
            text: old.text,
            from: old.from,
            at: old.at,
            status: old.status,
            isPending: false,
            context: old.context,
            isDeletedByMe: true, // 👈 Mark as deleted
            replyToId: old.replyToId,
            replyToText: old.replyToText,
            replyToFrom: old.replyToFrom,
            replyToContext: old.replyToContext,
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete:  $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _statusIcon(Msg m, Color color) {
    if (m.isPending) {
      return Icon(Icons.access_time, size: 14, color: color);
    }

    switch (m.status) {
      case 'read':
        return const Icon(Icons.done_all, size: 16, color: Colors.blue);
      case 'delivered':
        return Icon(Icons.done_all, size: 16, color: color);
      case 'sent':
      default:
        return Icon(Icons.check, size: 16, color: color);
    }
  }

  void _showMessageActions(BuildContext context, Msg m) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyToMessage = m;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: m.text));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete for me',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessageForMe(m); // 👈 CHANGED - Just call the function
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBubble(Msg m) {
    final isMe = m.from == 'me';
    final key = _messageKeys.putIfAbsent(m.id, () => GlobalKey());

    // 🎵 Check if this is an audio message
    final isAudioMessage = m.context == 'audio';

    return SizedBox(
      key: key,
      width: double.infinity,
      child: Dismissible(
        key: ValueKey(m.clientId),
        direction: isMe
            ? DismissDirection.endToStart
            : DismissDirection.startToEnd,
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.18,
          DismissDirection.endToStart: 0.18,
        },
        movementDuration: const Duration(milliseconds: 120),
        confirmDismiss: (_) async {
          setState(() {
            _replyToMessage = m;
          });
          return false;
        },
        background: Container(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: const Icon(Icons.reply, color: Colors.grey),
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () {
              _showMessageActions(context, m);
            },
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: isMe ? Colors.green.shade600 : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isMe ? 12 : 4),
                  topRight: Radius.circular(isMe ? 4 : 12),
                  bottomLeft: const Radius.circular(12),
                  bottomRight: const Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Reply preview
                  if (m.replyToId != null)
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(12),
                            duration: const Duration(seconds: 4),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${m.replyToFrom ?? 'Unknown'}:',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  m.replyToText ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const Divider(
                                  color: Colors.white24,
                                  height: 16,
                                ),
                                const Text(
                                  'Reply:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  m.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.white.withOpacity(0.15)
                              : Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            // 🖼️ Show image thumbnail if replying to image
                            if (m.replyToContext == 'image')
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    m.replyToText ?? '',
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, _) =>
                                        const Icon(
                                          Icons.broken_image,
                                          size: 40,
                                        ),
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.replyToFrom ?? '',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isMe
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    m.replyToContext == 'image'
                                        ? '📷 Photo'
                                        : (m.replyToContext == 'audio'
                                              ? '🎤 Voice message'
                                              : (m.replyToText ?? '')),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // OFFER LABEL
                  if (m.context == 'offer')
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "OFFER",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),

                  // 🎵 Audio message player
                  // 🗑️ Check if deleted FIRST
                  if (m.isDeletedByMe)
                    Text(
                      'You deleted this message',
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  // 🎵 Audio message player
                  else if (isAudioMessage)
                    _AudioPlayerWidget(
                      audioUrl: m.text,
                      isMe: isMe,
                      isPending: m.isPending,
                    )
                  // 🖼️ Image message
                  // 🖼️ Image message
                  else if (m.context == 'image')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: m.isPending
                              ? Container(
                                  width: 200,
                                  height: 200,
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => Scaffold(
                                          backgroundColor: Colors.black,
                                          appBar: AppBar(
                                            backgroundColor: Colors.black,
                                            iconTheme: const IconThemeData(
                                              color: Colors.white,
                                            ),
                                          ),
                                          body: Center(
                                            child: InteractiveViewer(
                                              child: Image.network(m.text),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Image.network(
                                    m.text,
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Container(
                                            width: 200,
                                            height: 200,
                                            color: Colors.grey.shade300,
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 200,
                                        height: 200,
                                        color: Colors.grey.shade300,
                                        child: const Icon(
                                          Icons.broken_image,
                                          size: 50,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                        if (m.isPending)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Uploading..  .',
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                      ],
                    )
                  // 💰 OFFER MESSAGE (NEW!)
                  else if (m.context == 'offer')
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.shade200,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.local_offer,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Special Offer',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            m.text,
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 13,
                            ),
                          ),

                          // ✅ BUY BUTTON — BUYER ONLY
                          if (!isSeller) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  _handleOfferBuy(m);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                child: const Text("Buy at offer price"),
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  // 💵 Deposit Request Message Special Widget
                  else if (m.context == 'deposit_request')
                    _DepositRequestBubble(
                      message: m,
                      conversationId: widget.chatId,
                    )
                  // 💸 Withdraw Request Message Special Widget
                  else if (m.context == 'withdraw_request')
                    _WithdrawRequestBubble(
                      message: m,
                      conversationId: widget.chatId,
                    )
                  // 📝 Text message
                  else
                    Text(
                      m.text,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                      ),
                    ),

                  const SizedBox(height: 6),
                  // Timestamp and status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat.Hm().format(m.at),
                        style: TextStyle(
                          fontSize: 11,
                          color: (isMe ? Colors.white : Colors.black87)
                              .withOpacity(0.85),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        _statusIcon(m, Colors.white.withOpacity(0.8)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _appBarTitle() {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.grey[200],
          backgroundImage: (_resolvedChatImage?.isNotEmpty ?? false)
              ? NetworkImage(_resolvedChatImage!)
              : null,
          child: (_resolvedChatImage == null || _resolvedChatImage!.isEmpty)
              ? const Icon(Icons.store, color: Colors.grey)
              : null,
        ),
        const SizedBox(
          width: 8,
        ), // Add spacing between the avatar and the title
        Row(
          children: [
            Text(
              _resolvedChatTitle ?? widget.chatTitle ?? 'Chat',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (_shopIsVerified) // Only show the Verified tick icon if shop is verified
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Image.asset(
                  'assets/verified_tick.png', // Replace with the verified tick PNG
                  height: 16,
                  width: 16,
                ),
              ),
          ],
        ),
      ],
    );
  }

  // 📦 BUILD PRODUCT PREVIEW CARD
  Widget _buildProductCard() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // === PRODUCT INFO ROW ===
          Row(
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    (product!['image_urls'] != null &&
                        (product!['image_urls'] as List).isNotEmpty)
                    ? Image.network(
                        (product!['image_urls'] as List).first,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, _) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported),
                      ),
              ),

              const SizedBox(width: 12),

              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product!['name'] ?? 'Product',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product!['price'] ?? 0} BIF',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // === BUTTONS ROW ===
          Row(
            children: [
              // View Product Button (EVERYONE sees this)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // TODO: Navigate to product page
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('View Product clicked')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'View Product',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Make Offer Button (SELLER ONLY!)
              if (isSeller) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _showMakeOfferModal(); // 👈 We'll create this next!
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Make Offer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8, // 👈 Safe spacing (default is 16)
        title: _appBarTitle(),
      ),
      body: Column(
        children: [
          // 📦 PRODUCT PREVIEW CARD (shows above messages)
          if (product != null) _buildProductCard(),

          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount:
                        messages.length +
                        (_otherIsTyping ? 1 : 0) +
                        (_otherIsRecording ? 1 : 0), // 👈 UPDATED
                    itemBuilder: (_, i) {
                      // 🎙️ Recording indicator (show first)
                      if (_otherIsRecording && i == messages.length) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            top: 4,
                            bottom: 8,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Lottie.asset(
                                    'assets/recording.json', // 👈 Your recording animation
                                    height: 30,
                                    width: 30,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Recording voice message...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      // 📝 Typing indicator
                      if (_otherIsTyping &&
                          i == messages.length + (_otherIsRecording ? 1 : 0)) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            top: 4,
                            bottom: 8,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Lottie.asset(
                              'assets/typing.json',
                              height: 40,
                            ),
                          ),
                        );
                      }

                      return _buildBubble(messages[i]);
                    },
                  ),
                ),
              ],
            ),
          ),
          // 🎙️ RECORDING MODE
          if (_isRecording)
            _RecordingModeWidget(
              recordingTime: _formatRecordingTime(_recordingSeconds),
              isPaused: _isPaused,
              onPause: _pauseRecording,
              onResume: _resumeRecording,
              onDelete: _cancelRecording,
              onSend: _stopRecordingAndSend,
            )
          else ...[
            // Reply preview (only show when NOT recording)
            if (_replyToMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(width: 4, height: 40, color: Colors.green),
                    const SizedBox(width: 8),
                    // 🖼️ Show image thumbnail if replying to image
                    if (_replyToMessage!.context == 'image')
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            _replyToMessage!.text,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, _) =>
                                const Icon(Icons.broken_image, size: 40),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _replyToMessage!.from == 'me' ? 'You' : 'Replying',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _replyToMessage!.context == 'image'
                                ? '📷 Photo'
                                : (_replyToMessage!.context == 'audio'
                                      ? '🎤 Voice message'
                                      : _replyToMessage!.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearReply,
                    ),
                  ],
                ),
              ),
            // Normal typing bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          builder: (_) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(
                                    Icons.image,
                                    color: Colors.blue,
                                  ),
                                  title: const Text('Send Image'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickAndSendImage();
                                  },
                                ),
                                // Camera option removed
                              ],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: (_) {
                          setState(() {});
                          _setTyping(true);
                          _typingTimer?.cancel();
                          _typingTimer = Timer(const Duration(seconds: 2), () {
                            _setTyping(false);
                          });
                        },
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration.collapsed(
                          hintText: 'Message...',
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTapUp: (_) {
                        if (_controller.text.isNotEmpty) {
                          _sendMessage();
                          return;
                        }
                        _startRecording();
                      },
                      child: Icon(
                        _controller.text.isNotEmpty ? Icons.send : Icons.mic,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// 🎙️ Recording Mode Widget
class _RecordingModeWidget extends StatelessWidget {
  final String recordingTime;
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onDelete;
  final VoidCallback onSend;

  const _RecordingModeWidget({
    required this.recordingTime,
    required this.isPaused,
    required this.onPause,
    required this.onResume,
    required this.onDelete,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border(top: BorderSide(color: Colors.red.shade200, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Delete button
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete, color: Colors.red, size: 28),
            ),

            const SizedBox(width: 8),

            // Animation + Timer
            Expanded(
              child: Row(
                children: [
                  Lottie.asset(
                    'assets/recording_mode.json',
                    height: 40,
                    width: 40,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    recordingTime,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Pause/Resume button
            IconButton(
              onPressed: isPaused ? onResume : onPause,
              icon: Icon(
                isPaused ? Icons.play_arrow : Icons.pause,
                color: Colors.red.shade700,
                size: 28,
              ),
            ),

            const SizedBox(width: 8),

            // Send button
            Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: onSend,
                icon: const Icon(Icons.send, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🎵 Audio Player Widget with Play/Pause, Progress Bar, and Timer
class _AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isMe;
  final bool isPending;

  const _AudioPlayerWidget({
    required this.audioUrl,
    required this.isMe,
    required this.isPending,
  });

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    // Listen to player state changes
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    // Listen to duration changes
    _player.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
        });
      }
    });

    // Listen to position changes
    _player.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    // Listen to completion
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _togglePlayPause() async {
    if (widget.isPending) return;

    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        if (_position == Duration.zero) {
          setState(() => _isLoading = true);
          await _player.play(UrlSource(widget.audioUrl));
          setState(() => _isLoading = false);
        } else {
          await _player.resume();
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to play audio'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause Button
          Container(
            decoration: BoxDecoration(
              color: widget.isMe
                  ? Colors.white.withOpacity(0.2)
                  : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          widget.isMe ? Colors.white : Colors.black87,
                        ),
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: widget.isMe ? Colors.white : Colors.black87,
                    ),
              onPressed: widget.isPending ? null : _togglePlayPause,
            ),
          ),

          const SizedBox(width: 8),

          // Progress Bar & Time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress Bar
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: widget.isMe ? Colors.white : Colors.green,
                    inactiveTrackColor: widget.isMe
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.shade400,
                    thumbColor: widget.isMe ? Colors.white : Colors.green,
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (value) async {
                      final newPosition = Duration(
                        milliseconds: (value * _duration.inMilliseconds)
                            .round(),
                      );
                      await _player.seek(newPosition);
                    },
                  ),
                ),

                // Time Display
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: Text(
                    widget.isPending
                        ? 'Uploading...'
                        : '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isMe ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Waveform Icon
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.graphic_eq,
              size: 20,
              color: widget.isMe ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

// small verified widget used inside chat room as well:

// small verified widget used inside chat room as well:

class _DepositRequestBubble extends StatefulWidget {
  final Msg message;
  final String conversationId;

  const _DepositRequestBubble({
    required this.message,
    required this.conversationId,
  });

  @override
  State<_DepositRequestBubble> createState() => _DepositRequestBubbleState();
}

class _DepositRequestBubbleState extends State<_DepositRequestBubble> {
  bool confirming = false;
  bool confirmed = false;
  bool rejected = false;
  bool isAgent = false;
  bool isDepositJson = false;
  Map<String, dynamic> deposit = {};

  @override
  void initState() {
    super.initState();
    _extractDeposit();
    _checkAgentPermission();
    if (isDepositJson) {
      _checkDepositStatus();
    }
  }

  void _extractDeposit() {
    // Try to parse JSON body
    try {
      final bodyJson = widget.message.text;
      deposit = json.decode(bodyJson);
      isDepositJson =
          deposit is Map<String, dynamic> && deposit['user_name'] != null;
    } catch (_) {
      deposit = {};
      isDepositJson = false;
    }
  }

  Future<void> _checkAgentPermission() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final roles = await supabase
        .from('user_roles')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (roles != null &&
        roles['is_agent'] == true &&
        roles['is_admin'] == true) {
      setState(() {
        isAgent = true;
      });
    }
  }

  Future<void> _checkDepositStatus() async {
    final supabase = Supabase.instance.client;
    if (!isDepositJson) return;

    final depositReq = await supabase
        .from('deposit_requests')
        .select('status')
        .eq('user_name', deposit['user_name'])
        .eq('amount', int.parse(deposit['amount'].toString()))
        .eq('screenshot_url', deposit['screenshot_url'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (depositReq == null) return;

    setState(() {
      confirmed = depositReq['status'] == 'approved';
      rejected = depositReq['status'] == 'rejected';
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a friendly message for old, non-JSON deposit requests
    if (!isDepositJson) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "This is an old deposit request.\nIt cannot be confirmed or rejected in this app version.",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        border: Border.all(color: Colors.orange, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📝 Deposit Request',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Name: ${deposit['user_name'] ?? '-'}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            'Phone: ${deposit['country_code'] ?? ''} ${deposit['user_phone'] ?? '-'}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            'Amount: ${deposit['amount'] ?? '-'} BIF',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (deposit['screenshot_url'] != null &&
              (deposit['screenshot_url'] as String).isNotEmpty)
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.black87,
                      child: InteractiveViewer(
                        child: Image.network(deposit['screenshot_url']),
                      ),
                    ),
                  );
                },
                child: Image.network(deposit['screenshot_url'], height: 180),
              ),
            ),
          const SizedBox(height: 10),
          if (isAgent && !confirmed && !rejected)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: confirming
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      'Accept Deposit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                    onPressed: confirming ? null : _showConfirmAcceptDialog,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: confirming
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cancel, color: Colors.white),
                    label: const Text(
                      'Reject Deposit',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                    ),
                    onPressed: confirming ? null : _showConfirmRejectDialog,
                  ),
                ),
              ],
            ),
          if (confirmed)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Deposit Confirmed ✔️',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (rejected)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Deposit Rejected ✖️',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showConfirmAcceptDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Accept Deposit"),
        content: const Text("Are you sure you want to accept this deposit?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmDeposit();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Accept"),
          ),
        ],
      ),
    );
  }

  void _showConfirmRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reject Deposit"),
        content: const Text("Are you sure you want to reject this deposit?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _rejectDeposit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text("Reject"),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeposit() async {
    setState(() {
      confirming = true;
    });

    final supabase = Supabase.instance.client;

    // 🧠 SAFETY CHECK
    if (!isDepositJson || deposit.isEmpty) {
      _showNotSupportedWarning();
      setState(() {
        confirming = false;
      });
      return;
    }

    try {
      // 1️⃣ Find the deposit_request ID (TEMP MATCH — SAME AS BEFORE)
      final depositReq = await supabase
          .from('deposit_requests')
          .select('id')
          .eq('user_name', deposit['user_name'])
          .eq('amount', int.parse(deposit['amount'].toString()))
          .eq('screenshot_url', deposit['screenshot_url'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (depositReq == null) {
        setState(() {
          confirming = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No deposit request found!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 2️⃣ CALL BACKEND (THIS IS THE ONLY MONEY ACTION)
      await supabase.rpc(
        'confirm_deposit',
        params: {'deposit_request_id': depositReq['id']},
      );

      // 3️⃣ UI ONLY (NO MONEY HERE)
      setState(() {
        confirmed = true;
        confirming = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deposit Confirmed!')));
    } catch (e) {
      setState(() {
        confirming = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to confirm deposit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectDeposit() async {
    setState(() {
      confirming = true;
    });

    final supabase = Supabase.instance.client;

    // 🧠 SAFETY CHECK
    if (!isDepositJson || deposit.isEmpty) {
      _showNotSupportedWarning();
      setState(() {
        confirming = false;
      });
      return;
    }

    try {
      // 1️⃣ Find deposit_request ID (TEMP MATCH)
      final depositReq = await supabase
          .from('deposit_requests')
          .select('id')
          .eq('user_name', deposit['user_name'])
          .eq('amount', int.parse(deposit['amount'].toString()))
          .eq('screenshot_url', deposit['screenshot_url'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (depositReq == null) {
        setState(() {
          confirming = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No deposit request found!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 2️⃣ CALL BACKEND (SAFE)
      await supabase.rpc(
        'reject_deposit',
        params: {'deposit_request_id': depositReq['id']},
      );

      // 3️⃣ UI ONLY
      setState(() {
        rejected = true;
        confirming = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deposit Rejected')));
    } catch (e) {
      setState(() {
        confirming = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject deposit: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showNotSupportedWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "This is an old deposit message that can't be processed.",
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class _WithdrawRequestBubble extends StatefulWidget {
  final Msg message;
  final String conversationId;

  const _WithdrawRequestBubble({
    required this.message,
    required this.conversationId,
  });

  @override
  State<_WithdrawRequestBubble> createState() => _WithdrawRequestBubbleState();
}

class _WithdrawRequestBubbleState extends State<_WithdrawRequestBubble> {
  bool isWithdrawJson = false;
  bool isAdmin = false;
  bool loadingStatus = true;
  bool approved = false;
  bool rejected = false;

  Map<String, dynamic> withdraw = {};
  String? withdrawalId;

  @override
  void initState() {
    super.initState();
    _extractWithdraw();
    _checkAdminPermission();
    if (withdrawalId != null) {
      _loadWithdrawStatus();
    }
  }

  // 1️⃣ Parse JSON safely
  void _extractWithdraw() {
    try {
      withdraw = json.decode(widget.message.text);

      withdrawalId = withdraw['withdrawal_id']?.toString();

      isWithdrawJson =
          withdraw is Map<String, dynamic> &&
          withdrawalId != null &&
          withdraw['user_name'] != null &&
          withdraw['amount'] != null &&
          withdraw['phone_number'] != null;
    } catch (_) {
      withdraw = {};
      isWithdrawJson = false;
    }
  }

  // 2️⃣ Check if current user is ADMIN + AGENT
  Future<void> _checkAdminPermission() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    final roles = await supabase
        .from('user_roles')
        .select('is_admin, is_agent')
        .eq('user_id', user.id)
        .maybeSingle();

    if (roles != null &&
        roles['is_admin'] == true &&
        roles['is_agent'] == true) {
      setState(() {
        isAdmin = true;
      });
    }
  }

  // 3️⃣ Load withdraw status using withdrawal_id (CORRECT WAY)
  Future<void> _loadWithdrawStatus() async {
    final supabase = Supabase.instance.client;

    final req = await supabase
        .from('withdraw_requests')
        .select('status')
        .eq('id', withdrawalId!)
        .maybeSingle();

    if (req == null) return;

    setState(() {
      approved = req['status'] == 'approved';
      rejected = req['status'] == 'rejected';
      loadingStatus = false;
    });
  }

  void _showConfirmAcceptWithdraw() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Accept Withdraw"),
        content: const Text(
          "Are you sure you want to accept this withdraw?\n\nThis action will release money to the user.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              await _approveWithdraw();
            },
            child: const Text("Accept"),
          ),
        ],
      ),
    );
  }

  void _showConfirmRejectWithdraw() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reject Withdraw"),
        content: const Text(
          "Are you sure you want to reject this withdraw?\n\nThe locked funds will be released back.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _rejectWithdraw();
            },
            child: const Text("Reject"),
          ),
        ],
      ),
    );
  }

  Future<void> _approveWithdraw() async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.rpc(
        'approve_withdraw',
        params: {'p_withdraw_id': withdrawalId},
      );

      setState(() {
        approved = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Withdraw Approved')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to approve withdraw: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectWithdraw() async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.rpc(
        'reject_withdraw',
        params: {'p_withdraw_id': withdrawalId},
      );

      setState(() {
        rejected = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Withdraw Rejected')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject withdraw: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fallback for old messages
    if (!isWithdrawJson) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red),
        ),
        child: const Text(
          'This is an old withdraw request.\nIt cannot be processed.',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💸 Withdraw Request',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 10),

          Text('Name: ${withdraw['user_name']}'),
          Text(
            'Phone: ${(withdraw['country_code'] ?? '')} ${withdraw['phone_number']}',
          ),
          Text(
            'Amount: ${withdraw['amount']} BIF',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          if (approved)
            const Text(
              'Withdraw Approved ✔️',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),

          if (rejected)
            const Text(
              'Withdraw Rejected ✖️',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),

          if (isAdmin && !approved && !rejected)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      'Accept Withdraw',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                    ),
                    onPressed: _showConfirmAcceptWithdraw,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    label: const Text(
                      'Reject Withdraw',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                    ),
                    onPressed: _showConfirmRejectWithdraw,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
