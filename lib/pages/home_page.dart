import 'package:flutter/material.dart';
import 'package:bujafasta_app/models/product.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/pages/notifications/notifications_page.dart';
import 'package:bujafasta_app/pages/messages/chat_list_page.dart';
import 'package:bujafasta_app/pages/product/product_details_page.dart';
import 'package:bujafasta_app/widgets/complete_profile_banner.dart';
import 'package:bujafasta_app/state/profile_completion_state.dart';
import 'package:bujafasta_app/state/seller_pending_order_state.dart';
import 'package:bujafasta_app/widgets/seller_pending_order_banner.dart';
import 'package:bujafasta_app/models/home_banner.dart';
import 'dart:async';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:bujafasta_app/pages/category/category_products_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bujafasta_app/state/auth_state.dart';
import 'package:bujafasta_app/widgets/login_required_banner.dart';
import 'package:bujafasta_app/widgets/sold_overlay.dart';

enum HomeTab { all, dresses, women, shoes, men }

class HomePage extends StatefulWidget {
  final List<Product> products;
  const HomePage({required this.products, super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 🚫 Products that must NEVER be shown again (this session)
  final Set<int> _removedProductIds = {};

  void _loadMoreItems() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    // ⏳ Small delay to feel natural (like TikTok / Instagram)
    await Future.delayed(const Duration(milliseconds: 400));

    setState(() {
      _currentMax = (_currentMax + _pageSize).clamp(0, _items.length);
      _isLoadingMore = false;
    });
  }

  Widget _withRefresh(Widget child) {
    return RefreshIndicator(
      color: Colors.grey,
      strokeWidth: 2,
      onRefresh: _refreshHome,
      child: child,
    );
  }

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

  Widget _buildFixedHeader() {
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        children: [
          // 🖼️ BANNER IMAGES
          if (_loadingBanners || _banners.isEmpty)
            const SizedBox.shrink()
          else
            PageView.builder(
              controller: _bannerController,
              itemCount: _banners.length,
              itemBuilder: (context, index) {
                final banner = _banners[index];

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (banner.productId == null) return;

                    final product = _items
                        .where(
                          (p) =>
                              p.id == banner.productId &&
                              !p.isDeleted &&
                              !_removedProductIds.contains(p.id),
                        )
                        .toList();

                    if (product.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Product not available')),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailsPage(
                          product: product.first,
                          shopId: product.first.shopId!,
                          sellerId: product.first.ownerId!,
                        ),
                      ),
                    );
                  },
                  child: cachedImage(
                    banner.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                );
              },
            ),

          // 🔝 HEADER (SEARCH + TABS)
          Positioned(
            left: 16,
            right: 16,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔍 SEARCH + ICONS
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            onTap: () {
                              setState(() {
                                _isSearchMode = true;
                              });
                            },
                            controller: _searchController,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Search products...',
                              prefixIcon: Icon(Icons.search, size: 18),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ChatListPage(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 📂 TABS
                  Row(
                    children: [
                      _topMenuItem(
                        'All',
                        active: _activeTab == HomeTab.all,
                        light: true,
                        onTap: () {
                          _tabsPageController.animateToPage(
                            HomeTab.all.index,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        },
                      ),
                      _topMenuItem(
                        'Dresses',
                        active: _activeTab == HomeTab.dresses,
                        light: true,
                        onTap: () {
                          _tabsPageController.animateToPage(
                            HomeTab.dresses.index,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        },
                      ),
                      _topMenuItem(
                        'Women',
                        active: _activeTab == HomeTab.women,
                        light: true,
                        onTap: () {
                          _tabsPageController.animateToPage(
                            HomeTab.women.index,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        },
                      ),
                      _topMenuItem(
                        'Shoes',
                        active: _activeTab == HomeTab.shoes,
                        light: true,
                        onTap: () {
                          _tabsPageController.animateToPage(
                            HomeTab.shoes.index,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        },
                      ),
                      _topMenuItem(
                        'Men',
                        active: _activeTab == HomeTab.men,
                        light: true,
                        onTap: () {
                          _tabsPageController.animateToPage(
                            HomeTab.men.index,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return PageView(
      controller: _tabsPageController,
      onPageChanged: (index) {
        setState(() {
          _activeTab = HomeTab.values[index];
        });
      },
      children: [
        _withRefresh(_buildHomeContent()),
        _withRefresh(_buildDressesContent()),
        _withRefresh(_buildWomenContent()),
        _withRefresh(_buildShoesContent()),
        _withRefresh(_buildMenContent()),
      ],
    );
  }

  HomeTab _activeTab = HomeTab.all;

  // 🔍 SEARCH STATE
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchMode = false; // 👈 controls white search screen
  bool _isSearching = false; // 👈 later for loading results
  bool _hasSearched = false; // 👈 ADD THIS LINE
  Timer? _searchDebounce;
  final PageController _tabsPageController = PageController();

  List<Product> _searchResults = [];

  void _onSearchChanged(String value) {
    // Cancel previous timer
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }

    if (value.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }

    // Start new timer (300ms)
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchProducts(value);
    });
  }

  final List<WomenCategory> _womenCategories = [
    WomenCategory(title: 'Tops', image: 'assets/tops_for_women.jpg'),
    WomenCategory(title: 'Bottoms', image: 'assets/bottoms_for_women.jpg'),
    WomenCategory(title: 'Dresses', image: 'assets/dresses.jpg'),
    WomenCategory(title: 'Handbags', image: 'assets/handbags_for_women.jpg'),
    WomenCategory(
      title: 'Complete Sets',
      image: 'assets/complete_sets_for_women.jpg',
    ),
    WomenCategory(title: 'Shoes', image: 'assets/heels_for_women.jpg'),
    WomenCategory(title: 'Jewelry', image: 'assets/necklace_for_women.jpg'),
    WomenCategory(
      title: 'Accessories',
      image: 'assets/accessories_for_women.jpg',
    ),
    WomenCategory(title: 'Suits', image: 'assets/trouser_suit_for_women.jpg'),
    WomenCategory(title: 'Underwear', image: 'assets/underwear_for_women.jpg'),
    WomenCategory(
      title: 'Head & Hair',
      image: 'assets/head_and_hair_accessories_for_women.jpg',
    ),
    WomenCategory(title: 'Watches', image: 'assets/watches_for_women.jpg'),
  ];

  final List<WomenCategory> _menCategories = [
    WomenCategory(title: 'Tops', image: 'assets/tops_for_men.jpg'),
    WomenCategory(title: 'Bottoms', image: 'assets/bottoms_for_men.jpg'),
    WomenCategory(title: 'Shoes', image: 'assets/shoes_for_men.jpg'),
    WomenCategory(title: 'Suits', image: 'assets/suits_for_men.jpg'),
    WomenCategory(
      title: 'Complete Sets',
      image: 'assets/complete_sets_for_men.jpg',
    ),
    WomenCategory(title: 'Watches', image: 'assets/watches_for_men.jpg'),
    WomenCategory(
      title: 'Accessories',
      image: 'assets/accessories_for_men.jpg',
    ),
    WomenCategory(title: 'Jewelry', image: 'assets/jewelry_for_men.jpg'),
    WomenCategory(title: 'Underwear', image: 'assets/underwear_for_men.jpg'),
  ];

  void _autoSlideBanner() {
    if (!mounted) return;

    // 🚨 If banners not ready, don't slide
    if (_banners.isEmpty) {
      Future.delayed(const Duration(seconds: 5), _autoSlideBanner);
      return;
    }

    _currentBanner = (_currentBanner + 1) % _banners.length;

    _bannerController.animateToPage(
      _currentBanner,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );

    Future.delayed(const Duration(seconds: 5), _autoSlideBanner);
  }

  final PageController _bannerController = PageController(
    viewportFraction: 1.0,
  );

  int _currentBanner = 0;

  List<HomeBanner> _banners = [];
  bool _loadingBanners = true;
  List<Map<String, dynamic>> _superDeals = [];
  bool _loadingSuperDeals = true;

  RealtimeChannel? _productsChannel;

  List<Product> _items = [];
  bool _loading = true;
  int _unreadCount = 0;
  // 🧠 Lazy loading state
  final int _pageSize = 20; // how many items per load
  int _currentMax = 20; // how many items are visible
  bool _isLoadingMore = false;

  Future<void> _loadUnreadNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final res = await Supabase.instance.client
        .from('notifications')
        .select('id')
        .eq('user_id', user.id)
        .eq('is_read', false);

    setState(() {
      _unreadCount = res.length;
    });
  }

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHomeBanners(); // 👈 ADD THIS
    _loadSuperDeals();

    Future.delayed(const Duration(seconds: 5), _autoSlideBanner);

    _loadProducts().then((_) {
      _subscribeToProducts();
    });

    _loadUnreadNotifications();

    // 🔔 LISTEN TO GLOBAL PROFILE STATE
    profileCompleteNotifier.addListener(_onProfileCompletionChanged);
    // 🔔 LISTEN TO LOGIN / LOGOUT STATE
    isLoggedInNotifier.addListener(_onAuthChanged);
  }

  void _onProfileCompletionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onAuthChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadSuperDeals() async {
    final client = Supabase.instance.client;

    try {
      final res = await client
          .from('super_deals')
          .select('product_id, image_url, price')
          .eq('is_active', true);

      setState(() {
        _superDeals = List<Map<String, dynamic>>.from(res);
        _loadingSuperDeals = false;
      });
    } catch (e) {
      _loadingSuperDeals = false;
    }
  }

  Future<void> _loadHomeBanners() async {
    final client = Supabase.instance.client;

    try {
      final res = await client
          .from('home_banners')
          .select('id, image_url, product_id')
          .eq('is_active', true)
          .order('position', ascending: true);

      setState(() {
        _banners = res.map<HomeBanner>((e) => HomeBanner.fromMap(e)).toList();
        _loadingBanners = false;
      });

      // 🔥 START SLIDER ONLY AFTER DATA EXISTS
      if (_banners.isNotEmpty) {
        Future.delayed(const Duration(seconds: 5), _autoSlideBanner);
      }
    } catch (e) {
      _loadingBanners = false;
    }
  }

  Future<void> _loadProducts() async {
    final client = Supabase.instance.client;

    try {
      final response = await client
          .from('products')
          .select()
          .eq('status', 'approved')
          .eq('is_hidden', false) // 👈 ADD THIS
          .eq('is_deleted', false); // ✅ ADD THIS

      // Convert safely
      _items = response
          .map<Product>((item) => Product.fromMap(item))
          .where((p) => p.id != null && !_removedProductIds.contains(p.id))
          .toList();

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        // Only show error if nothing is loaded
        if (_items.isEmpty) {
          _error = 'offline';
        }
        _loading = false;
      });
    }
  }

  // 🔄 PULL TO REFRESH (RELOAD EVERYTHING)
  Future<void> _refreshHome() async {
    _currentMax = _pageSize;
    _isLoadingMore = false;

    setState(() {
      _loading = true;
      _loadingBanners = true;
      _loadingSuperDeals = true;
      _error = null;
    });

    try {
      await Future.wait([
        _loadProducts(),
        _loadHomeBanners(),
        _loadSuperDeals(),
      ]);
    } catch (_) {
      // silent fail, UI already handles error
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true; // 👈 ADD THIS
      _searchResults.clear();
    });

    final client = Supabase.instance.client;

    try {
      final res = await client.rpc(
        'search_products_fast',
        params: {'p_query': query},
      );

      // 🔑 Extract ONLY IDs from search
      final List<int> foundIds = (res as List)
          .map<int>((e) => e['id'] as int)
          .toList();

      // 🔑 FILTER HOME PRODUCTS (FULL DATA)
      setState(() {
        _searchResults = _items
            .where(
              (p) =>
                  p.id != null &&
                  foundIds.contains(p.id) &&
                  !p.isHidden &&
                  !p.isDeleted && // ✅ ADD THIS
                  !_removedProductIds.contains(p.id), // ✅ THIS WAS MISSING
            )
            .toList();

        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _subscribeToProducts() {
    final client = Supabase.instance.client;

    _productsChannel = client.channel('products-all');

    _productsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final oldRecord = payload.oldRecord;

            setState(() {
              if (payload.eventType == PostgresChangeEvent.insert) {
                final bool isApproved = newRecord['status'] == 'approved';
                final bool isHidden = newRecord['is_hidden'] == true;
                final bool isDeleted = newRecord['is_deleted'] == true;

                if (isApproved && !isHidden && !isDeleted) {
                  _items.insert(0, Product.fromMap(newRecord));
                }
              } else if (payload.eventType == PostgresChangeEvent.update) {
                final id = newRecord['id'];
                final index = _items.indexWhere((p) => p.id == id);

                final bool isApproved = newRecord['status'] == 'approved';
                final bool isHidden = newRecord['is_hidden'] == true;
                final bool isDeleted = newRecord['is_deleted'] == true; // ✅ ADD

                if (isApproved && !isHidden && !isDeleted) {
                  // ✅ Visible product
                  if (index != -1) {
                    _items[index] = Product.fromMap(newRecord);
                  } else {
                    _items.insert(0, Product.fromMap(newRecord));
                  }
                } else {
                  // ❌ Hidden OR not approved → remove forever
                  if (index != -1) {
                    final removed = _items[index];
                    if (removed.id != null) {
                      _removedProductIds.add(removed.id!);
                    }
                    _items.removeAt(index);
                  }
                }
              } else if (payload.eventType == PostgresChangeEvent.delete) {
                final id = oldRecord['id'];
                if (id != null) {
                  _removedProductIds.add(id);
                }
                _items.removeWhere((p) => p.id == id);
              }
            });
          },
        )
        .subscribe();
  }

  Widget _buildBlankCategory(String title) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  List<Product> _dressesItems() {
    return _items
        .where(
          (p) =>
              p.subcategory2 != null && p.subcategory2 == 'Dresses & Jumpsuits',
        )
        .toList();
  }

  List<Product> _shoesItems() {
    return _items
        .where(
          (p) => p.subcategory2 != null && p.subcategory2 == 'Shoes for men',
        )
        .toList();
  }

  List<Product> _womenItems() {
    return _items
        .where((p) => (p.subcategory ?? '').toLowerCase() == 'women')
        .toList();
  }

  List<Product> _menItems() {
    return _items
        .where((p) => (p.subcategory ?? '').toLowerCase() == 'men')
        .toList();
  }

  Widget _buildHomeContent() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // 👇 when user scrolls near the bottom
        if (notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 300 &&
            !_isLoadingMore &&
            _currentMax < _items.length) {
          _loadMoreItems();
        }
        return false; // allow normal scrolling
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 90),
        child: Column(
          children: [
            // 🟨 PROMO STRIP (FREE PICKUP + FRESH SALES)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // 🔸 FREE PICKUP
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Color(0xFFFFE0B2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.storefront_outlined,
                              color: Color(0xFFF57C00),
                              size: 20,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Free Pickup',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 🔸 FRESH SALES
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.auto_awesome_outlined,
                              color: Color(0xFFF57C00),
                              size: 20,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Fresh Sales',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ⚡ SUPER DEALS LABEL
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: const [
                  Icon(Icons.flash_on, size: 14, color: Color(0xFFF57C00)),
                  SizedBox(width: 4),
                  Text(
                    'Super Deals',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // 🧃 SUPER DEALS LIST
            SizedBox(
              height: 160,
              child: _loadingSuperDeals
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      itemCount: _superDeals.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final deal = _superDeals[index];

                        final int productId = deal['product_id'];
                        final String imageUrl = deal['image_url'];
                        final num price = deal['price'];

                        return GestureDetector(
                          onTap: () {
                            final product = _items
                                .where(
                                  (p) =>
                                      p.id == productId &&
                                      !p.isDeleted &&
                                      !_removedProductIds.contains(p.id),
                                )
                                .toList();

                            if (product.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Product not available'),
                                ),
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailsPage(
                                  product: product.first,
                                  shopId: product.first.shopId!,
                                  sellerId: product.first.ownerId!,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 110,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(10),
                                    ),
                                    child: cachedImage(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    formatPrice(price),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF57C00),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),
            Padding(
              // 🔽 REDUCE SIDE PADDING (THIS WAS THE MAIN PROBLEM)
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: _items.isEmpty
                  ? const Center(child: Text('No products found'))
                  : Builder(
                      builder: (context) {
                        final visibleItems = _items.take(_currentMax).toList();

                        return Column(
                          children: [
                            MasonryGridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 8,
                              itemCount: visibleItems.length,
                              itemBuilder: (context, index) {
                                final item = visibleItems[index];
                                return _buildMasonryItem(item, index);
                              },
                            ),

                            // 🔄 LOADING MORE INDICATOR
                            if (_isLoadingMore)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDressesContent() {
    final dresses = _dressesItems();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 90),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: dresses.isEmpty
            ? const Center(
                child: Text(
                  'No dresses found',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : MasonryGridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 8,
                itemCount: dresses.length,
                itemBuilder: (context, index) {
                  final item = dresses[index];
                  return _buildMasonryItem(item, index);
                },
              ),
      ),
    );
  }

  Widget _buildShoesContent() {
    final shoes = _shoesItems();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 90),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: shoes.isEmpty
            ? const Center(
                child: Text(
                  'No shoes found',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : MasonryGridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 8,
                itemCount: shoes.length,
                itemBuilder: (context, index) {
                  final item = shoes[index];
                  return _buildMasonryItem(item, index);
                },
              ),
      ),
    );
  }

  Widget _buildWomenContent() {
    final womenProducts = _womenItems();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👩 WOMEN CATEGORIES (TOP)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _womenCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (context, index) {
                final item = _womenCategories[index];

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryProductsPage(
                          title: item.title,
                          subcategory: 'women',
                          subcategory2: item.title,
                          allProducts: _items,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(
                        child: Image.asset(
                          item.image,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 🧾 WOMEN PRODUCTS (HOME STYLE)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: womenProducts.isEmpty
                ? const Center(
                    child: Text(
                      'No women products found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : MasonryGridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,

                    // SAME AS HOME
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 8,

                    itemCount: womenProducts.length,
                    itemBuilder: (context, index) {
                      final item = womenProducts[index];
                      return _buildMasonryItem(item, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenContent() {
    final menProducts = _menItems();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 👨 MEN CATEGORIES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _menCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemBuilder: (context, index) {
                final item = _menCategories[index];

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryProductsPage(
                          title: item.title,
                          subcategory: 'men',
                          subcategory2: item.title,
                          allProducts: _items,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(
                        child: Image.asset(
                          item.image,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // 🧾 MEN PRODUCTS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: menProducts.isEmpty
                ? const Center(
                    child: Text(
                      'No men products found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : MasonryGridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 8,
                    itemCount: menProducts.length,
                    itemBuilder: (context, index) {
                      final item = menProducts[index];
                      return _buildMasonryItem(item, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔍 SEARCH MODE (BLANK SCREEN)
    if (_isSearchMode) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // 🔙 BACK + SEARCH BAR
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // 🔙 BACK BUTTON
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() {
                          _isSearchMode = false;
                          _searchController.clear();
                          _searchResults.clear();
                          _hasSearched = false; // 👈 RESET
                        });
                      },
                    ),

                    const SizedBox(width: 8),

                    // 🔍 SEARCH BAR
                    Expanded(
                      child: Center(
                        child: Container(
                          height: 42, // ✅ SAME AS HOME
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            textInputAction: TextInputAction.search,

                            // 🔴 LIVE SEARCH
                            onChanged: _onSearchChanged,

                            // ⌨️ KEYBOARD SEARCH STILL WORKS
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                _searchProducts(value);
                              }
                            },

                            style: const TextStyle(
                              fontSize: 13, // ✅ SMALL TEXT
                            ),

                            decoration: const InputDecoration(
                              hintText: 'Search products…',
                              hintStyle: TextStyle(
                                fontSize: 12, // ✅ SMALLER HINT
                                color: Colors.grey,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                size: 18,
                                color: Colors.grey,
                              ),
                              border: InputBorder.none,
                              isDense: true, // ✅ IMPORTANT (reduces height)
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 🧼 EMPTY BODY (INTENTIONALLY BLANK)
              Expanded(
                child: Column(
                  children: [
                    // 🔄 FIXED-HEIGHT LOADING ROW (NO JUMP)
                    AnimatedOpacity(
                      opacity: _isSearching ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: SizedBox(
                        height: 32, // 👈 FIXED HEIGHT = NO UI JUMP
                        child: Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 📄 RESULTS AREA (STABLE)
                    Expanded(
                      child: !_hasSearched
                          ? const SizedBox.shrink()
                          : _searchResults.isEmpty && !_isSearching
                          ? const Center(
                              child: Text(
                                'No products found',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = _searchResults[index];
                                return _buildSearchResultRow(item);
                              },
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

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.wifi_off, size: 40, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No internet connection',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'Please check your connection and try again',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final recentItems = _isSearching
        ? <Product>[]
        : (_searchResults.isNotEmpty ? _searchResults : _items);

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 260,
              pinned: false,
              floating: false,
              snap: false,
              automaticallyImplyLeading: false,
              backgroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(background: _buildFixedHeader()),
            ),
          ];
        },
        body: Stack(
          children: [
            _buildTabContent(),

            // 🔔 BOTTOM BANNERS
            ValueListenableBuilder<bool>(
              valueListenable: sellerPendingOrderNotifier,
              builder: (context, hasPendingOrder, _) {
                if (hasPendingOrder) {
                  return const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SellerPendingOrderBanner(),
                  );
                }

                return ValueListenableBuilder<bool>(
                  valueListenable: isLoggedInNotifier,
                  builder: (context, isLoggedIn, _) {
                    if (!isLoggedIn) {
                      return const Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LoginRequiredBanner(),
                      );
                    }

                    return ValueListenableBuilder<bool>(
                      valueListenable: profileCompleteNotifier,
                      builder: (context, isProfileComplete, _) {
                        if (!isProfileComplete) {
                          return const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: CompleteProfileBanner(),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItemCard(Product item) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsPage(
              product: item,

              // ✅ ADD THESE
              shopId: item.shopId!,
              sellerId: item.ownerId!,
            ),
          ),
        );
      },

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[200],
              ),
              child: item.imageUrls.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: item.imageUrls.length == 1
                          ? cachedImage(
                              item.imageUrls.first,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : PageView.builder(
                              itemCount: item.imageUrls.length,
                              physics: const BouncingScrollPhysics(),
                              itemBuilder: (context, index) {
                                return cachedImage(
                                  item.imageUrls[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                );
                              },
                            ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          Text(
            formatPrice(num.parse(item.price)),
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMasonryItem(Product item, int index) {
    const List<double> heightPresets = [180, 220, 260];
    final double imageHeight = heightPresets[index % heightPresets.length];

    return InkWell(
      onTap: () {
        Navigator.push(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.imageUrls.isNotEmpty
                      ? cachedImage(item.imageUrls.first, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),

                  // 🔴 SOLD OVERLAY
                  if (item.isSold) const SoldOverlay(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            formatPrice(num.parse(item.price)),
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultRow(Product item) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsPage(
              product: item, // ✅ SAME AS HOME
              shopId: item.shopId!, // ✅ REQUIRED
              sellerId: item.ownerId!, // ✅ REQUIRED
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // 🖼️ SMALL CIRCULAR IMAGE
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[200],
              child: item.imageUrls.isNotEmpty
                  ? ClipOval(
                      child: cachedImage(
                        item.imageUrls.first,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.image, size: 16, color: Colors.grey),
            ),

            const SizedBox(width: 12),

            // 📝 NAME + PRICE
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatPrice(num.parse(item.price)),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),

            // ➡️ CHEVRON
            const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget cachedImage(
    String url, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    final image = CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, _) => Container(color: Colors.grey[200]),
      errorWidget: (context, _, __) => Container(
        color: Colors.grey[200],
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
        ),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius, child: image);
    }

    return image;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose(); // 👈 VERY IMPORTANT
    profileCompleteNotifier.removeListener(_onProfileCompletionChanged);
    isLoggedInNotifier.removeListener(_onAuthChanged);
    _productsChannel?.unsubscribe();
    _bannerController.dispose();
    _tabsPageController.dispose();

    super.dispose();
  }
}

class WomenCategory {
  final String title;
  final String image;

  WomenCategory({required this.title, required this.image});
}

Widget _topMenuItem(
  String text, {
  required bool active,
  required bool light,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          color: light
              ? (active ? Colors.white : Colors.white70)
              : (active ? Colors.black : Colors.grey[600]),
        ),
      ),
    ),
  );
}
