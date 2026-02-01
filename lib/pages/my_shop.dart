import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bujafasta_app/models/product.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/pages/seller/seller_orders_page.dart';
import 'package:bujafasta_app/pages/seller/shop_wallet_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:bujafasta_app/pages/add_item_page.dart';
import 'package:bujafasta_app/pages/seller/shop_settings_page.dart';
import 'package:bujafasta_app/pages/wallet/pin_verify_screen.dart';
import 'package:bujafasta_app/state/seller_pending_order_state.dart';
import 'package:bujafasta_app/widgets/seller_pending_order_banner.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

void debugLog(String message) {
  debugPrint('🟡 [DEBUG] $message');
}

class MyShopPage extends StatefulWidget {
  final List<Product>? products;
  final String? shopId; // 👈 ADD THIS

  /// 🔒 If true → user can ONLY view (buyer mode)
  final bool readOnly;

  const MyShopPage({
    this.products,
    this.readOnly = false,
    this.shopId, // 👈 ADD THIS
    super.key,
  });

  @override
  State<MyShopPage> createState() => _MyShopPageState();
}

class _MyShopPageState extends State<MyShopPage> {
  RealtimeChannel? _shopProductsChannel;

  // LOCAL UI STATE
  String shopName = 'My Shop';
  String shopBio = '';
  Uint8List? shopAvatar;
  String? shopAvatarUrl;
  String _shopAvatarCacheKey = '';
  bool isShopVerified = false; // 👈 NEW (same idea as chat list)
  bool isUnderReview = false;
  bool _isUploadingAvatar = false; // loading ring
  bool _avatarUploadFailed = false; // red ring
  String? _avatarErrorMessage; // short error text
  bool _checkingPin = false;
  bool _productActionLoading = false;

  // SUPABASE CLIENT
  final supabase = Supabase.instance.client;

  // PRODUCTS
  List<Product> shopProducts = [];

  @override
  void initState() {
    super.initState();

    _loadShop();
    _subscribeToShopRealtime();

    _loadProducts().then((_) {
      _subscribeToShopProducts();
    });

    // 🔔 SELLER PENDING ORDERS
    _checkSellerPendingOrders();
    sellerPendingOrderNotifier.addListener(_onSellerPendingOrderChanged);
  }

  RealtimeChannel? _shopChannel;

  void _onSellerPendingOrderChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _checkSellerPendingOrders() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final res = await supabase
        .from('orders')
        .select('id')
        .eq('seller_id', user.id)
        .eq('status', 'pending')
        .limit(1);

    sellerPendingOrderNotifier.value = res.isNotEmpty;
  }

  Future<void> _runProductAction({
    required BuildContext context,
    required int productId,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    setState(() => _productActionLoading = true);

    try {
      await action();

      // ⏳ Wait a moment for realtime update to arrive
      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to complete action. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _productActionLoading = false);
      }
    }
  }

  Future<void> _subscribeToShopRealtime() async {
    if (widget.readOnly) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final shop = await supabase
        .from('shops')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (shop == null) return;

    final shopId = shop['id'];

    _shopChannel = supabase.channel('shop-$shopId');

    _shopChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'shops',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: shopId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;

            setState(() {
              isUnderReview = newRow['is_under_review'] == true;
              isShopVerified = newRow['is_verified'] == true;
            });
          },
        )
        .subscribe();
  }

  // ---------------------------
  // LOAD SHOP DATA
  // ---------------------------
  Future<void> _loadShop() async {
    final query = supabase.from('shops').select();

    // 🛡 SAFETY CHECK FOR BUYER MODE
    if (widget.readOnly) {
      if (widget.shopId == null) return; // 👈 VERY IMPORTANT

      final shop = await query
          .eq('id', widget.shopId!) // 👈 ! tells Dart: "I am 100% sure"
          .maybeSingle();

      if (shop != null) {
        setState(() {
          shopName = shop['shop_name'] ?? 'Shop';
          shopBio = shop['description'] ?? '';
          shopAvatarUrl = shop['shop_avatar_url'];
          isShopVerified = shop['is_verified'] == true;
          isUnderReview = shop['is_under_review'] == true;
        });
      }
      return;
    }

    // 👇 SELLER MODE
    final shop = await query
        .eq('owner_id', supabase.auth.currentUser!.id)
        .maybeSingle();

    if (shop != null) {
      setState(() {
        shopName = shop['shop_name'] ?? 'Shop';
        shopBio = shop['description'] ?? '';
        shopAvatarUrl = shop['shop_avatar_url'];
        isShopVerified = shop['is_verified'] == true;
        isUnderReview = shop['is_under_review'] == true;
      });
    }
  }

  // ---------------------------
  // LOAD REAL PRODUCTS
  // ---------------------------
  Future<void> _loadProducts() async {
    String? resolvedShopId;

    if (widget.readOnly) {
      resolvedShopId = widget.shopId;
    } else {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final shop = await supabase
          .from('shops')
          .select('id')
          .eq('owner_id', user.id)
          .maybeSingle();

      if (shop == null) return;
      resolvedShopId = shop['id'];
    }

    if (resolvedShopId == null) return;

    // 👇 IMPORTANT: use dynamic to avoid builder-type conflict
    dynamic query = supabase
        .from('products')
        .select()
        .eq('shop_id', resolvedShopId)
        .eq('status', 'approved');

    // 🔒 Buyer mode → hide hidden products
    if (widget.readOnly) {
      query = query.eq('is_hidden', false);
    }

    // ⬇️ ORDER ALWAYS LAST
    query = query.order('created_at', ascending: false);

    final List res = await query;

    setState(() {
      shopProducts = res.map<Product>((p) => Product.fromMap(p)).toList();
    });
  }

  // NOW paste the subscription function UNDER this line:
  void _subscribeToShopProducts() async {
    if (widget.readOnly) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final shop = await supabase
        .from('shops')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (shop == null) return;
    final String shopId = shop['id'].toString();

    _shopProductsChannel = supabase.channel('shop-products-$shopId');

    _shopProductsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final oldRecord = payload.oldRecord;

            // Only handle products that belong to this shop
            final String? payloadShopId =
                (payload.eventType == PostgresChangeEvent.delete)
                ? oldRecord['shop_id']?.toString()
                : newRecord['shop_id']?.toString();

            if (payloadShopId != shopId) return;

            setState(() {
              if (payload.eventType == PostgresChangeEvent.insert) {
                shopProducts.insert(0, Product.fromMap(newRecord));
              } else if (payload.eventType == PostgresChangeEvent.update) {
                final id = newRecord['id'];
                final index = shopProducts.indexWhere((p) => p.id == id);
                if (index != -1) {
                  shopProducts[index] = Product.fromMap(newRecord);
                }
              } else if (payload.eventType == PostgresChangeEvent.delete) {
                final id = oldRecord['id'];
                shopProducts.removeWhere((p) => p.id == id);
              }
            });
          },
        ) // <-- THIS CLOSING PAREN IS REQUIRED
        .subscribe(); // THEN THIS RUNS
  }

  // ---------------------------
  // SAVE SHOP NAME + BIO
  // ---------------------------
  Future<void> _saveShopToSupabase(
    Uint8List? avatarBytes, {
    bool removeAvatar = false,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    String? avatarUrl = shopAvatarUrl;

    // 🧹 REMOVE AVATAR
    if (removeAvatar) {
      avatarUrl = null;
    }
    // 📤 UPLOAD NEW AVATAR
    else if (avatarBytes != null) {
      avatarUrl = await _uploadShopAvatar(avatarBytes);
    }

    await supabase
        .from('shops')
        .update({
          'shop_name': shopName,
          'description': shopBio,
          'shop_avatar_url': avatarUrl,
        })
        .eq('owner_id', user.id);

    setState(() {
      shopAvatarUrl = avatarUrl;
      _shopAvatarCacheKey = DateTime.now().millisecondsSinceEpoch.toString();
    });
  }

  Future<String?> _uploadShopAvatar(Uint8List bytes) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // ✅ FORCE ALL IMAGES TO PNG (same as Profile)
    final path = '${user.id}/shop_$timestamp.png';

    await supabase.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/png',
          ),
        );

    return supabase.storage.from('avatars').getPublicUrl(path);
  }

  @override
  void dispose() {
    sellerPendingOrderNotifier.removeListener(_onSellerPendingOrderChanged);

    _shopProductsChannel?.unsubscribe();
    _shopChannel?.unsubscribe();
    super.dispose();
  }

  void _shareShop() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final shop = await supabase
        .from('shops')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (shop == null) return;

    final shopId = shop['id'];

    final link = 'https://bujafasta.app/shop/$shopId';

    await Share.share(link, subject: 'Check out my shop on Bujafasta');
  }

  // ---------------------------
  // UI STARTS HERE
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,

          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,

            // ➕ LEFT BUTTON
            leading: widget.readOnly
                ? null
                : IconButton(
                    icon: const Icon(Icons.add, size: 28),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddItemPage(onPost: (_) {}),
                        ),
                      );
                    },
                  ),

            // 🔴 CENTER INFO (ONLY WHEN UNDER REVIEW)
            title: isUnderReview
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Shop under review',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : null,

            centerTitle: true,

            // ☰ RIGHT BUTTON
            actions: widget.readOnly
                ? []
                : [
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu, size: 28),
                        onPressed: () {
                          Scaffold.of(context).openEndDrawer();
                        },
                      ),
                    ),
                  ],
          ),

          // ✅ RIGHT → LEFT SLIDE PAGE
          endDrawer: widget.readOnly ? null : _buildShopDrawer(),
          body: SafeArea(
            bottom: true,
            child: RefreshIndicator(
              color: const Color(0xFFFFAA07), // orange
              onRefresh: () async {
                await _loadShop();
                await _loadProducts();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // IMPORTANT
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildShopHeader(context),
                    const SizedBox(height: 20),
                    _buildProductsSection(context),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 🔔 SELLER HAS PENDING ORDER
        if (sellerPendingOrderNotifier.value)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: const SellerPendingOrderBanner(),
          ),

        // 🔒 GLOBAL BLOCKING LOADER
        if (_productActionLoading)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFFFAA07),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------
  // SHOP HEADER CARD
  // ---------------------------
  Widget _buildShopHeader(BuildContext context) {
    // ✅ CLEAN BIO BEFORE DISPLAY (MUST BE HERE)
    final safeBio = shopBio.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return Column(
      children: [
        // SHOP ICON (FLAT, NO CARD)
        GestureDetector(
          onTap: widget.readOnly ? null : _openEditAndSetState,

          child: Stack(
            alignment: Alignment.center,
            children: [
              // 🔄 PROGRESS RING
              if (_isUploadingAvatar || _avatarUploadFailed)
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _avatarUploadFailed ? Colors.red : Colors.orange,
                    ),
                  ),
                ),

              // 🖼️ AVATAR
              Container(
                padding: const EdgeInsets.all(1), // 👈 VERY TINY BORDER
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.grey.shade200,
                  child: shopAvatar != null
                      ? ClipOval(
                          child: Image.memory(
                            shopAvatar!,
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                          ),
                        )
                      : (shopAvatarUrl != null && shopAvatarUrl!.isNotEmpty)
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl:
                                '$shopAvatarUrl?cache=$_shopAvatarCacheKey',
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,

                            placeholder: (context, url) => shimmerBox(
                              width: 84,
                              height: 84,
                              radius: BorderRadius.circular(42),
                            ),

                            errorWidget: (context, url, error) => Icon(
                              Icons.storefront_outlined,
                              size: 40,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.storefront_outlined,
                          size: 40,
                          color: Colors.grey.shade600,
                        ),
                ),
              ),

              if (_avatarErrorMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  _avatarErrorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 12),

        // SHOP NAME + EDIT
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                shopName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ✅ VERIFIED BADGE (same as chat list)
            if (isShopVerified)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Image.asset(
                  'assets/verified_tick.png',
                  height: 16,
                  width: 16,
                ),
              ),
          ],
        ),

        const SizedBox(height: 6),

        const SizedBox(height: 10),

        if (!widget.readOnly)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _openEditAndSetState,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Edit'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _shareShop,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Share'),
              ),
            ],
          ),

        // SHOP BIO (VERTICALLY SAFE)
        Text(
          safeBio.isEmpty ? 'Tell buyers about you' : safeBio,
          textAlign: TextAlign.center,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildShopDrawer() {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Balance'),
              onTap: _checkingPin
                  ? null
                  : () async {
                      Navigator.pop(context);
                      setState(() => _checkingPin = true);

                      try {
                        final user = supabase.auth.currentUser;
                        if (user == null) return;

                        // 🔐 Always ask for PIN (fast, offline-friendly)
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PinVerifyScreen(
                              onPinVerified: () {
                                Navigator.pop(context);

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ShopWalletPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Unable to open wallet. Please check your connection.',
                            ),
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _checkingPin = false);
                        }
                      }
                    },
            ),

            const Divider(),

            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Business tools',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.shopping_bag_outlined),
              title: const Text('Orders'),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SellerOrdersPage()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShopSettingsPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // EDIT SHOP DIALOG (FIXED)
  // ---------------------------
  Future<void> _openEditAndSetState() async {
    final result = await _showEditShopBottomSheet();
    if (result == null) return;

    final Uint8List? bytes = result['imageBytes'];
    final bool removeAvatar = result['removeAvatar'] == true;

    final String newName = result['name'];
    final String newBio = result['bio'];

    // Update UI instantly
    setState(() {
      shopName = newName;
      shopBio = newBio;

      if (removeAvatar) {
        shopAvatar = null;
      } else if (bytes != null) {
        shopAvatar = bytes;
      }
    });

    // Upload to server
    // Start loading UI
    setState(() {
      _isUploadingAvatar = true;
      _avatarUploadFailed = false;
      _avatarErrorMessage = null;
    });

    // Upload to server
    final previousAvatar = shopAvatarUrl;
    await _saveShopToSupabase(bytes, removeAvatar: removeAvatar);

    // If upload failed (avatarUrl unchanged or null)
    if (bytes != null && shopAvatarUrl == previousAvatar) {
      setState(() {
        _avatarUploadFailed = true;
        _avatarErrorMessage = 'Upload failed. Please try again';
      });
    } else {
      setState(() {
        _avatarErrorMessage = null;
      });
    }

    // Stop loading UI
    setState(() {
      _isUploadingAvatar = false;
    });

    // IMPORTANT: reload from DB so profile updates instantly
    await _loadShop();

    // Remove temp memory image
    setState(() {
      shopAvatar = null;
      if (removeAvatar) {
        shopAvatarUrl = null;
      }
    });
  }

  Future<Map<String, dynamic>?> _showEditShopBottomSheet() {
    final nameCtrl = TextEditingController(text: shopName);
    final bioCtrl = TextEditingController(text: shopBio);

    Uint8List? localImage = shopAvatar;
    final String? existingImageUrl = shopAvatarUrl;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true, // 👈 VERY IMPORTANT
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setLocalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Edit Shop',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),

                    const SizedBox(height: 16),

                    GestureDetector(
                      onTap: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          withData: true,
                        );
                        if (result != null &&
                            result.files.single.bytes != null) {
                          setLocalState(() {
                            localImage = result.files.single.bytes;
                          });
                        }
                      },
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: Colors.grey.shade300,
                        child: localImage != null
                            ? ClipOval(
                                child: Image.memory(
                                  localImage!,
                                  width: 76,
                                  height: 76,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : (existingImageUrl != null &&
                                  existingImageUrl.isNotEmpty)
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl:
                                      '$existingImageUrl?cache=$_shopAvatarCacheKey',
                                  width: 76,
                                  height: 76,
                                  fit: BoxFit.cover,

                                  placeholder: (context, url) => shimmerBox(
                                    width: 76,
                                    height: 76,
                                    radius: BorderRadius.circular(38),
                                  ),

                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.storefront_outlined),
                                ),
                              )
                            : const Icon(Icons.storefront_outlined, size: 36),
                      ),
                    ),

                    TextButton(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          withData: true,
                        );
                        if (result != null &&
                            result.files.single.bytes != null) {
                          setLocalState(() {
                            localImage = result.files.single.bytes;
                          });
                        }
                      },

                      child: const Text("Change image"),
                    ),
                    // 🗑 REMOVE IMAGE (ONLY IF EXISTS)
                    if (localImage != null ||
                        (existingImageUrl != null &&
                            existingImageUrl.isNotEmpty))
                      TextButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Remove image?'),
                              content: const Text(
                                'Your shop profile image will be permanently removed.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Remove',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );

                          // ❌ User cancelled
                          if (confirm != true) return;

                          // ✅ User confirmed
                          setLocalState(() {
                            localImage = null;
                          });

                          Navigator.pop(context, {
                            "name": nameCtrl.text,
                            "bio": bioCtrl.text,
                            "imageBytes": null,
                            "removeAvatar": true,
                          });
                        },
                        child: const Text(
                          "Remove image",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),

                    TextField(
                      controller: nameCtrl,
                      maxLength: 30,
                      decoration: InputDecoration(
                        labelText: 'Shop name',
                        counterText: '${nameCtrl.text.length}/30',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setLocalState(() {}),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: bioCtrl,
                      maxLines: 4,
                      inputFormatters: [
                        BioLimiterFormatter(maxChars: 100, maxLines: 4),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        alignLabelWithHint: true,
                        counterText: '${bioCtrl.text.length}/100',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => setLocalState(() {}),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFAA07),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context, {
                              "name": nameCtrl.text,
                              "bio": bioCtrl.text,
                              "imageBytes": localImage,
                            });
                          },
                          child: const Text("Save"),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ---------------------------
  // PRODUCT GRID

  Widget _buildEmptyShopState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min, // 👈 prevents taking full height
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),

          Image.asset(
            'assets/empty.png',
            width: 130, // 👈 smaller
            height: 130,
            fit: BoxFit.contain,
          ),

          const SizedBox(height: 14),

          Text(
            'Your shop is empty',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 4),

          Text(
            'Add your first product to start selling',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _showProductActions(BuildContext context, Product product) {
    final rootContext = Navigator.of(context, rootNavigator: true).context;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),

              // ─── MARK SOLD ───
              ListTile(
                leading: Icon(
                  Icons.checkroom,
                  color: product.isSold
                      ? const Color(0xFFFFAA07)
                      : Colors.black,
                ),
                title: Text(product.isSold ? 'Mark available' : 'Mark sold'),
                onTap: () async {
                  Navigator.pop(context);

                  if (!product.isSold && product.isHidden) {
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Unhide this item before marking it as sold.',
                        ),
                      ),
                    );
                    return;
                  }

                  final productId = product.id;
                  if (productId == null) return;

                  await _runProductAction(
                    context: rootContext,
                    productId: productId,
                    successMessage: product.isSold
                        ? 'Product marked available'
                        : 'Product marked sold',
                    action: () {
                      return supabase
                          .from('products')
                          .update({'is_sold': !product.isSold})
                          .eq('id', productId);
                    },
                  );
                },
              ),

              // ─── EDIT ───
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _openEditProductPanel(context, product);
                },
              ),

              // ─── HIDE ───
              ListTile(
                leading: const Icon(Icons.visibility_off),
                title: Text(product.isHidden ? 'Unhide' : 'Hide'),
                onTap: () async {
                  Navigator.pop(context);

                  final productId = product.id;
                  if (productId == null) return;

                  await _runProductAction(
                    context: rootContext,
                    productId: productId,
                    successMessage: product.isHidden
                        ? 'Product is now visible'
                        : 'Product hidden',
                    action: () {
                      return supabase
                          .from('products')
                          .update({'is_hidden': !product.isHidden})
                          .eq('id', productId);
                    },
                  );
                },
              ),

              // ─── DELETE ───
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.pop(context);

                  final productId = product.id;
                  if (productId == null) return;

                  await _runProductAction(
                    context: rootContext,
                    productId: productId,
                    successMessage: 'Product deleted',
                    action: () {
                      return supabase
                          .from('products')
                          .update({'is_deleted': true})
                          .eq('id', productId);
                    },
                  );
                },
              ),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------
  Widget _buildProductsSection(BuildContext context) {
    // ✅ If shop has NO products → show empty state
    if (shopProducts.isEmpty) {
      return _buildEmptyShopState();
    }

    // ✅ FILTER OUT DELETED PRODUCTS (SOFT DELETE)
    final visibleProducts = shopProducts.where((p) {
      if (p.isDeleted) return false;

      // 🔒 Buyer must not see hidden products
      if (widget.readOnly && p.isHidden) return false;

      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Products',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const crossAxisCount = 3;
            final itemWidth = constraints.maxWidth / crossAxisCount;
            final itemHeight = itemWidth * 1.15;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleProducts.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: itemWidth / itemHeight,
              ),
              itemBuilder: (context, index) {
                final p = visibleProducts[index];
                return _ProductCardSimple(
                  product: p,
                  productIndex: index,
                  allProducts: visibleProducts,
                  readOnly: widget.readOnly, // 👈 PASS IT DOWN
                  onLongPressAction: widget.readOnly
                      ? (_) {} // 🚫 buyer does nothing
                      : (product) {
                          _showProductActions(context, product);
                        },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------
// PRODUCT CARD WIDGET
// ---------------------------
class _ProductCardSimple extends StatelessWidget {
  final Product product;
  final int productIndex;
  final List<Product> allProducts;
  final void Function(Product product) onLongPressAction;
  final bool readOnly; // 👈 ADD THIS

  const _ProductCardSimple({
    required this.product,
    required this.productIndex,
    required this.allProducts,
    required this.onLongPressAction,
    required this.readOnly, // 👈 ADD THIS
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, // 👈 THIS IS THE FIX
              onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    opaque: false,
                    pageBuilder: (_, __, ___) {
                      return FullscreenImageViewer(
                        products: allProducts,
                        initialProductIndex: productIndex,
                        initialImageIndex: 0,
                        onProductAction: readOnly
                            ? (_) {} // buyer
                            : (product) {
                                onLongPressAction(product);
                              },
                      );
                    },
                  ),
                );
              },

              // 👇 ADD THIS BLOCK
              onLongPress: () {
                onLongPressAction(product);
              },

              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 🖼 PRODUCT IMAGE
                  if (product.imageUrls.isNotEmpty) ...[
                    CachedNetworkImage(
                      imageUrl: product.imageUrls.first,
                      fit: BoxFit.cover,
                      width: double.infinity,

                      placeholder: (context, url) => shimmerBox(
                        width: double.infinity,
                        height: double.infinity,
                      ),

                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade300,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],

                  // 🟡 UNDER REVIEW BADGE (VERY SMALL)
                  // 🟡 UNDER REVIEW
                  if (product.status == 'pending')
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Under review',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                  // 🔴 REJECTED
                  if (product.status == 'rejected')
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Rejected',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // 🌑 DARK OVERLAY WHEN SOLD OR HIDDEN
                  if (product.isSold || product.isHidden)
                    Container(color: Colors.black.withOpacity(0.7)),

                  // 🏷 SOLD ICON
                  if (product.isSold)
                    const Center(
                      child: Icon(
                        Icons.checkroom,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),

                  // 👁️ HIDDEN ICON
                  if (product.isHidden)
                    const Center(
                      child: Icon(
                        Icons.visibility_off,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _openEditProductPanel(BuildContext context, Product product) {
  final nameCtrl = TextEditingController(text: product.name);
  final priceCtrl = TextEditingController(text: product.price);
  final stockCtrl = TextEditingController(text: product.stock.toString());
  final detailsCtrl = TextEditingController(text: product.details ?? '');

  String condition = product.condition;
  List<String> sizes = List.from(product.sizes);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── HEADER ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit product',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ─── NAME ───
              TextField(controller: nameCtrl, decoration: _editInput('Name')),

              const SizedBox(height: 12),

              // ─── PRICE ───
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: _editInput('Price'),
              ),

              const SizedBox(height: 12),

              // ─── STOCK ───
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: _editInput('Stock'),
              ),

              const SizedBox(height: 12),

              // ─── CONDITION ───
              DropdownButtonFormField<String>(
                value: condition,
                items: const [
                  DropdownMenuItem(value: 'New', child: Text('New')),
                  DropdownMenuItem(value: 'Like new', child: Text('Like new')),
                ],
                onChanged: (v) {
                  if (v != null) condition = v;
                },
                decoration: _editInput('Condition'),
              ),

              const SizedBox(height: 12),

              // ─── DETAILS ───
              TextField(
                controller: detailsCtrl,
                maxLines: 3,
                decoration: _editInput('Details'),
              ),

              const SizedBox(height: 20),

              // ─── SAVE BUTTON ───
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAA07),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final int? productId = product.id;

                    if (productId == null) {
                      // product not yet synced, just close safely
                      Navigator.pop(context);
                      return;
                    }

                    await Supabase.instance.client
                        .from('products')
                        .update({
                          'name': nameCtrl.text,
                          'price': priceCtrl.text,
                          'stock':
                              int.tryParse(stockCtrl.text) ?? product.stock,
                          'condition': condition,
                          'details': detailsCtrl.text,
                          'sizes': sizes,
                        })
                        .eq('id', productId);

                    if (!context.mounted) return;

                    Navigator.pop(context);
                  },

                  child: const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class BioLimiterFormatter extends TextInputFormatter {
  final int maxChars;
  final int maxLines;

  BioLimiterFormatter({required this.maxChars, required this.maxLines});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // ❌ Block character overflow
    if (newValue.text.length > maxChars) {
      return oldValue;
    }

    // ❌ Block line overflow
    final lineCount = '\n'.allMatches(newValue.text).length + 1;
    if (lineCount > maxLines) {
      return oldValue;
    }

    return newValue;
  }
}

class FullscreenImageViewer extends StatefulWidget {
  final List<Product> products;
  final int initialProductIndex;
  final int initialImageIndex;
  final void Function(Product product) onProductAction;

  const FullscreenImageViewer({
    super.key,
    required this.products,
    required this.initialProductIndex,
    required this.initialImageIndex,
    required this.onProductAction,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late PageController _productController;
  late PageController _imageController;

  int currentProductIndex = 0;
  int currentImageIndex = 0;
  bool _isSoldOutUI = false; // UI ONLY (no backend yet)
  bool _showMoreInfo = false; // controls "... more"
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();

    currentProductIndex = widget.initialProductIndex;
    currentImageIndex = widget.initialImageIndex;

    _productController = PageController(
      initialPage: widget.initialProductIndex,
    );

    _imageController = PageController(initialPage: widget.initialImageIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🔼🔽 PRODUCT SCROLL (VERTICAL)
          PageView.builder(
            controller: _productController,
            scrollDirection: Axis.vertical,
            itemCount: widget.products.length,
            onPageChanged: (pIndex) {
              setState(() {
                currentProductIndex = pIndex;
                currentImageIndex = 0;

                // Reset image controller for new product
                _imageController.dispose();
                _imageController = PageController(initialPage: 0);
              });
            },
            itemBuilder: (context, productIndex) {
              final product = widget.products[productIndex];

              return PageView.builder(
                controller: _imageController,
                itemCount: product.imageUrls.length,
                onPageChanged: (i) {
                  setState(() => currentImageIndex = i);
                },
                itemBuilder: (context, imageIndex) {
                  final imageUrl = product.imageUrls[imageIndex];

                  return Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () async {
                        final product = widget.products[currentProductIndex];
                        HapticFeedback.mediumImpact();

                        setState(() => _actionLoading = true);

                        await Future.microtask(() async {
                          widget.onProductAction(product);
                        });

                        if (mounted) {
                          setState(() => _actionLoading = false);
                        }
                      },

                      child: InteractiveViewer(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,

                              placeholder: (context, url) => Center(
                                child: shimmerBox(
                                  width: 220,
                                  height: 220,
                                  radius: BorderRadius.circular(12),
                                ),
                              ),

                              errorWidget: (context, url, error) => const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // 🔝 TOP ACTION BAR (CLOSE + SOLD + MENU)
          Positioned(
            top: 36,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ❌ CLOSE
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),

                Row(
                  children: [
                    const SizedBox(width: 6),

                    // ⋮ MORE OPTIONS
                    GestureDetector(
                      onTap: () async {
                        final product = widget.products[currentProductIndex];
                        HapticFeedback.mediumImpact();

                        setState(() => _actionLoading = true);

                        await Future.microtask(() async {
                          widget.onProductAction(product);
                        });

                        if (mounted) {
                          setState(() => _actionLoading = false);
                        }
                      },

                      child: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 🏷️ PRODUCT INFO (TIKTOK STYLE – TAP ANYWHERE)
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.1, // ~80%
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showMoreInfo = !_showMoreInfo;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🏷️ PRODUCT NAME
                    Text(
                      widget.products[currentProductIndex].name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // 💰 PRICE (ALWAYS VISIBLE)
                    Text(
                      '${widget.products[currentProductIndex].price} BIF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // 🔽 EXTRA INFO
                    if (_showMoreInfo) ...[
                      const SizedBox(height: 4),

                      // 📏 SIZES (ONLY IF AVAILABLE)
                      if (widget.products[currentProductIndex].sizes.isNotEmpty)
                        Text(
                          'Sizes: ${widget.products[currentProductIndex].sizes.join(', ')}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),

                      // 📦 STOCK (ONLY IF > 0)
                      if (widget.products[currentProductIndex].stock > 0)
                        Text(
                          'Stock: ${widget.products[currentProductIndex].stock}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),

                      // 📝 DETAILS (LAST)
                      if (widget.products[currentProductIndex].details !=
                              null &&
                          widget
                              .products[currentProductIndex]
                              .details!
                              .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            widget.products[currentProductIndex].details!,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ),
                    ],

                    // … MORE / LESS INDICATOR
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _showMoreInfo ? 'less' : '... more',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ● ○ ○ IMAGE DOTS
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.products[currentProductIndex].imageUrls.length,
                (index) {
                  final bool isActive = index == currentImageIndex;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 10 : 6,
                    height: isActive ? 10 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                  );
                },
              ),
            ),
          ),
          if (_actionLoading)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: Colors.black.withOpacity(0.55),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

InputDecoration _editInput(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.grey.shade100,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

Widget shimmerBox({double? width, double? height, BorderRadius? radius}) {
  return Shimmer.fromColors(
    baseColor: Colors.grey.shade300,
    highlightColor: Colors.grey.shade100,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: radius ?? BorderRadius.circular(8),
      ),
    ),
  );
}
