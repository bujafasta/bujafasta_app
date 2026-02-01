import 'package:flutter/material.dart';
import 'package:bujafasta_app/models/product.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/pages/messages/chat_room_page.dart';
import 'package:bujafasta_app/pages/product/buy_now_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bujafasta_app/screens/shop/my_shop_public_page.dart';
import 'package:bujafasta_app/widgets/sold_overlay.dart';

class ProductDetailsPage extends StatefulWidget {
  final int? productId;
  final Product? product;
  final int? offerId;
  // ✅ ADD THESE
  final String shopId;
  final String sellerId;

  const ProductDetailsPage({
    super.key,
    this.productId,
    this.product,
    this.offerId,
    required this.shopId,
    required this.sellerId,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

Widget cachedImage(
  String url, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  return CachedNetworkImage(
    imageUrl: url,
    fit: fit,
    width: width,
    height: height,
    placeholder: (context, _) => Container(color: Colors.grey[200]),
    errorWidget: (context, _, __) => Container(
      color: Colors.grey[200],
      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
    ),
  );
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  static const Color kAccent = Color(0xFFF57C00); // deep orange

  void _showSoldOutNotice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This item is sold out', style: TextStyle(fontSize: 14)),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openShopPage() {
    // safety: if no shop id, do nothing
    if (shopId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyShopPublicPage(shopId: shopId, sellerId: sellerId),
      ),
    );
  }

  void _subscribeToProductRealtime() {
    if (product == null || product!.id == null) return;

    final productId = product!.id!.toString();

    _productChannel = Supabase.instance.client
        .channel('product-$productId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'products',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: productId,
          ),
          callback: (payload) {
            final newRow = payload.newRecord;

            if (!mounted) return;

            setState(() {
              product = Product.fromMap(newRow);
            });
          },
        )
        .subscribe();
  }

  RealtimeChannel? _productChannel;

  bool _showFullDescription = false;
  String formatPrice(num price) {
    final str = price.toStringAsFixed(0);
    final buffer = StringBuffer();

    for (int i = 0; i < str.length; i++) {
      final positionFromEnd = str.length - i;
      buffer.write(str[i]);

      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }

    return '${buffer.toString()} BIF';
  }

  num parsePrice(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value;
    }

    if (value is String) {
      return num.tryParse(value) ?? 0;
    }

    return 0;
  }

  Future<void> _loadRelatedProductsFromBackend() async {
    final res = await Supabase.instance.client
        .from('products')
        .select()
        .eq('status', 'approved');

    final allProducts = res.map<Product>((e) => Product.fromMap(e)).toList();

    _buildRelatedProducts(allProducts);
  }

  void _buildRelatedProducts(List<Product> allProducts) {
    if (product == null) return;

    List<Product> results = [];

    // 1️⃣ Try subcategory3
    if (product!.subcategory3 != null && product!.subcategory3!.isNotEmpty) {
      results = allProducts.where((p) {
        return p.id != product!.id && p.subcategory3 == product!.subcategory3;
      }).toList();
    }

    // 2️⃣ Fallback to subcategory2
    if (results.isEmpty &&
        product!.subcategory2 != null &&
        product!.subcategory2!.isNotEmpty) {
      results = allProducts.where((p) {
        return p.id != product!.id && p.subcategory2 == product!.subcategory2;
      }).toList();
    }

    // 3️⃣ Fallback to subcategory
    if (results.isEmpty &&
        product!.subcategory != null &&
        product!.subcategory!.isNotEmpty) {
      results = allProducts.where((p) {
        return p.id != product!.id && p.subcategory == product!.subcategory;
      }).toList();
    }

    setState(() {
      _relatedProducts = results.take(8).toList(); // limit
      _loadingRelated = false;
    });
  }

  List<Product> _relatedProducts = [];
  bool _loadingRelated = true;

  Future<void> _toggleFavorite() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null || product == null) return;

    setState(() {
      loadingFavorite = true;
    });

    if (isFavorite) {
      // ❌ REMOVE FAVORITE
      await supabase
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('product_id', product!.id!);
    } else {
      // ❤️ ADD FAVORITE
      await supabase.from('favorites').insert({
        'user_id': user.id,
        'product_id': product!.id!,
      });
    }

    setState(() {
      isFavorite = !isFavorite;
      loadingFavorite = false;
    });
  }

  int selectedImageIndex = 0;
  Product? product;
  bool loadingProduct = true;
  late final String shopId;
  late final String sellerId;

  int? offerPrice;
  bool loadingOfferPrice = false;
  bool isFavorite = false;
  bool loadingFavorite = true;

  Future<void> _loadProduct() async {
    final supabase = Supabase.instance.client;

    final res = await supabase
        .from('products')
        .select('''
        id,
        name,
        price,
        details,
        image_urls,
        sizes,
        color,
        owner_id,
        shop_id
      ''')
        .eq('id', widget.productId!)
        .single();

    setState(() {
      product = Product.fromMap(res);
      loadingProduct = false;
    });

    // Load shop AFTER product is loaded
    await _loadShop();
  }

  Future<void> _loadOfferPrice() async {
    if (widget.offerId == null) return;

    setState(() {
      loadingOfferPrice = true;
    });

    final supabase = Supabase.instance.client;

    final offer = await supabase
        .from('offers')
        .select('offer_price')
        .eq('id', widget.offerId!)
        .eq('status', 'active')
        .gt('expires_at', DateTime.now().toIso8601String())
        .maybeSingle();

    setState(() {
      offerPrice = offer != null ? (offer['offer_price'] as num).toInt() : null;
      loadingOfferPrice = false;
    });
  }

  Future<void> _loadFavoriteStatus() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null || product == null) {
      setState(() {
        loadingFavorite = false;
      });
      return;
    }

    final res = await supabase
        .from('favorites')
        .select('id')
        .eq('user_id', user.id)
        .eq('product_id', product!.id!)
        .maybeSingle();

    setState(() {
      isFavorite = res != null;
      loadingFavorite = false;
    });
  }

  Future<void> openChatWithSeller() async {
    final String productImage = product!.imageUrls.isNotEmpty
        ? product!.imageUrls.first
        : '';

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    final buyerId = user.id;
    final sellerId = product!.ownerId;
    final productId = product!.id;

    if (sellerId == null || productId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Seller not found!")));
      return;
    }

    // 1️⃣ Check if conversation already exists between buyer & seller (not product-specific)
    // 1️⃣ Check if conversation already exists between buyer & seller (not product-specific)
    final existing = await supabase
        .from('conversations')
        .select()
        .eq('buyer_id', buyerId)
        .eq('seller_id', sellerId)
        .maybeSingle();

    String conversationId;

    if (existing != null) {
      // 2️⃣ Conversation exists → UPDATE product_id to current product
      conversationId = existing['id'].toString();

      await supabase
          .from('conversations')
          .update({
            'product_id': productId, // 👈 Update to latest product
            'last_message_at': DateTime.now()
                .toIso8601String(), // 👈 Bump to top
          })
          .eq('id', conversationId);
    } else {
      // 3️⃣ No conversation → Create NEW one WITH product_id
      final insert = await supabase
          .from('conversations')
          .insert({
            'buyer_id': buyerId,
            'seller_id': sellerId,
            'product_id': productId, // 👈 MUST INCLUDE THIS!
            'last_message': '',
            'last_message_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      conversationId = insert['id'].toString();
    }

    // 3️⃣ Open Chat Room
    // 3️⃣ Load shop info BEFORE opening chat
    final shopData = await supabase
        .from('shops')
        .select('shop_name, shop_avatar_url')
        .eq('owner_id', sellerId)
        .maybeSingle();

    // 4️⃣ Open Chat Room with correct shop data
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          chatId: conversationId,
          chatTitle: shopData?['shop_name'] ?? "Shop",
          chatImage: productImage,
          isCustomerCare: false,
          productId: productId.toString(), // 👈 CONVERT int to String
        ),
      ),
    );
  }

  Map<String, dynamic>? shop;
  bool loadingShop = true;
  bool _shopIsVerified = false;

  @override
  void initState() {
    super.initState();
    shopId = widget.shopId;
    sellerId = widget.sellerId;

    if (widget.product != null) {
      product = widget.product;
      loadingProduct = false;
      _loadShop();
      _loadFavoriteStatus(); // 👈 ADD THIS
      _loadRelatedProductsFromBackend();
      _subscribeToProductRealtime();
    } else if (widget.productId != null) {
      _loadProduct().then((_) {
        _loadFavoriteStatus();
        _loadRelatedProductsFromBackend();
        _subscribeToProductRealtime(); // 👈 ADD THIS
      });
    }

    _loadOfferPrice();
  }

  Future<void> _loadShop() async {
    if (product == null || product!.ownerId == null) return;

    final res = await Supabase.instance.client
        .from('shops')
        .select('shop_name, shop_avatar_url, is_verified')
        .eq('owner_id', product!.ownerId!)
        .maybeSingle();

    setState(() {
      shop = res;
      _shopIsVerified = res?['is_verified'] == true;
      loadingShop = false;
    });
  }

  Future<void> _refreshProduct() async {
    if (widget.productId != null) {
      // Reload full product from server
      setState(() {
        loadingProduct = true;
      });

      await _loadProduct();
    } else if (widget.product != null) {
      // Came from Home → refresh shop + offer only
      await _loadShop();
    }

    // Always refresh offer price
    await _loadOfferPrice();
  }

  @override
  Widget build(BuildContext context) {
    if (loadingProduct) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: Colors.grey,
                strokeWidth: 2,
                onRefresh: _refreshProduct,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔙 HEADER + SEARCH BAR
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios),
                              onPressed: () => Navigator.pop(context),
                            ),

                            Expanded(
                              child: Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const TextField(
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    prefixIcon: Icon(Icons.search),
                                    hintText: 'Search',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 🖼️ LARGE PRODUCT IMAGE
                      Container(
                        height: 300,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            product!.imageUrls.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FullScreenImageViewer(
                                            images: product!.imageUrls,
                                            initialIndex: selectedImageIndex,
                                          ),
                                        ),
                                      );
                                    },
                                    child: PageView.builder(
                                      itemCount: product!.imageUrls.length,
                                      onPageChanged: (index) {
                                        setState(() {
                                          selectedImageIndex = index;
                                        });
                                      },
                                      itemBuilder: (context, index) {
                                        return cachedImage(
                                          product!.imageUrls[index],
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 40,
                                    ),
                                  ),

                            // 🔴 SOLD OVERLAY
                            if (product!.isSold) const SoldOverlay(),
                          ],
                        ),
                      ), // ✅ THIS LINE WAS MISSING
                      // SMALL GALLERY PREVIEW
                      SizedBox(
                        height: 60,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: product!.imageUrls.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final imageUrl = product!.imageUrls[index];
                            final isSelected = index == selectedImageIndex;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedImageIndex = index;
                                });

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenImageViewer(
                                      images: product!.imageUrls,
                                      initialIndex: index,
                                    ),
                                  ),
                                );
                              },

                              child: Container(
                                width: 60,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ), // 👈 SMALL GAP
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: cachedImage(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),

                      // PRICE + MESSAGE BUTTON
                      // PRICE + MESSAGE BUTTON
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: loadingOfferPrice
                                  ? const CircularProgressIndicator()
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (offerPrice != null)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: kAccent.withOpacity(
                                                0.15,
                                              ), // 👈 soft accent background
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),

                                            child: const Text(
                                              "OFFER",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          formatPrice(
                                            offerPrice ??
                                                parsePrice(product!.price),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),

                                        const SizedBox(height: 4),

                                        Text(
                                          product!.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),

                            // 💰 NEGOTIATE PRICE BUTTON (NEW!)
                            // 💬 CHAT NOW BUTTON
                            GestureDetector(
                              onTap: () {
                                if (product!.isSold) {
                                  _showSoldOutNotice();
                                  return;
                                }
                                openChatWithSeller();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),

                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/chat_bubble.png',
                                      width: 18,
                                      height: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Chat now',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // 💬 CHAT BUTTON
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // DESCRIPTION
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product!.details ?? "No description available.",
                              maxLines: _showFullDescription ? null : 2,
                              overflow: _showFullDescription
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),

                            // READ MORE / SHOW LESS
                            if ((product!.details ?? '').length > 80)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showFullDescription =
                                        !_showFullDescription;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _showFullDescription
                                        ? "Show less"
                                        : "Read more",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // SIZE OPTIONS
                      // SIZE OPTIONS
                      if (product!.sizes.isNotEmpty && !product!.isSold)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: product!.sizes.map((size) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10, // 🔽 smaller
                                  vertical: 4, // 🔽 smaller
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    14,
                                  ), // 🔽 tighter
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  size,
                                  style: const TextStyle(
                                    fontSize: 12, // 🔽 smaller text
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                      const SizedBox(height: 15),

                      const SizedBox(height: 20),

                      // SHOP INFO (DYNAMIC)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: loadingShop
                            ? const Text("Loading shop info...")
                            : GestureDetector(
                                onTap: _openShopPage,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Colors.grey[200],
                                      child:
                                          (shop?['shop_avatar_url'] != null &&
                                              (shop!['shop_avatar_url']
                                                      as String)
                                                  .isNotEmpty)
                                          ? ClipOval(
                                              child: cachedImage(
                                                shop!['shop_avatar_url'],
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : const Icon(Icons.store, size: 24),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              shop?['shop_name'] ?? "Shop name",
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (_shopIsVerified)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 4,
                                                ),
                                                child: Image.asset(
                                                  'assets/verified_tick.png',
                                                  width: 14,
                                                  height: 14,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                      ),

                      const SizedBox(height: 25),

                      // YOU MAY ALSO LIKE
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "You may also like",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // STATIC SUGGESTED ITEMS
                      if (_loadingRelated)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_relatedProducts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "No similar items found",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      else
                        SizedBox(
                          height: 210,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _relatedProducts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final item = _relatedProducts[index];

                              return GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailsPage(
                                        product: item,
                                        shopId: item.shopId!,
                                        sellerId: item.ownerId!,
                                      ),
                                    ),
                                  );
                                },
                                child: SizedBox(
                                  width: 140,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: cachedImage(
                                          item.imageUrls.first,
                                          height: 140,
                                          width: 140,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        formatPrice(parsePrice(item.price)),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),

            // ❤️ FAVORITE + BUY BUTTON
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: loadingFavorite ? null : _toggleFavorite,
                    child: loadingFavorite
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 28,
                            color: isFavorite ? Colors.red : Colors.black,
                          ),
                  ),

                  const SizedBox(width: 20),

                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (product!.isSold || product!.isHidden) {
                          _showSoldOutNotice(); // 🔔 TOAST
                          return;
                        }

                        BuyNowHandler.start(
                          context: context,
                          productId: product!.id!,
                          offerId: widget.offerId,
                          shopId: shopId,
                          sellerId: sellerId,
                        );
                      },
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: (product!.isSold || product!.isHidden)
                              ? Colors.grey
                              : kAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            (product!.isSold || product!.isHidden)
                                ? "SOLD OUT"
                                : "BUY NOW",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _productChannel?.unsubscribe();
    super.dispose();
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    final PageController controller = PageController(initialPage: initialIndex);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: images.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.contain,
                      placeholder: (_, __) =>
                          const CircularProgressIndicator(color: Colors.white),
                      errorWidget: (_, __, ___) => const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                );
              },
            ),

            // ❌ CLOSE BUTTON
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black54,
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
