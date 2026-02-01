import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShopModerationPage extends StatefulWidget {
  const ShopModerationPage({super.key});

  @override
  State<ShopModerationPage> createState() => _ShopModerationPageState();
}

class _ShopModerationPageState extends State<ShopModerationPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;
  String _searchQuery = '';
  int _totalShops = 0;
  int _suspendedShops = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadShopStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showShopDetails(Map<String, dynamic> shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: controller,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),

                  // Shop name
                  Text(
                    shop['shop_name'] ?? 'Unknown shop',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (shop['shop_avatar_url'] != null &&
                      shop['shop_avatar_url'].toString().isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          shop['shop_avatar_url'],
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_not_supported,
                            size: 60,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 👤 OWNER AVATAR  ✅ PASTE THIS HERE
                  if (shop['owner_avatar_url'] != null &&
                      shop['owner_avatar_url'].toString().isNotEmpty)
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'Owner',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          CircleAvatar(
                            radius: 36,
                            backgroundImage: NetworkImage(
                              shop['owner_avatar_url'],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  const SizedBox(height: 8),

                  _infoRow('Shop ID', shop['id']),
                  _infoRow('Owner ID', shop['owner_id']),
                  const Divider(height: 24),

                  // 👤 OWNER DETAILS
                  Text(
                    'Owner Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  _infoRow(
                    'Owner name',
                    '${shop['owner_first_name'] ?? ''} ${shop['owner_last_name'] ?? ''}',
                  ),
                  _infoRow('Phone', shop['owner_phone']),
                  _infoRow('Country code', shop['owner_country_code']),
                  _infoRow('Email', shop['owner_email']),
                  _infoRow('Role', shop['owner_role']),

                  _boolRow('PIN set', shop['owner_pin_set']),

                  _infoRow('Description', shop['description']),
                  _infoRow('Address', shop['address']),
                  _infoRow('Sell type', shop['sell_type']),
                  _infoRow('Province ID', shop['province_id']),
                  _infoRow('Quartier ID', shop['quartier_id']),
                  _infoRow('Created at', shop['created_at']),

                  const Divider(height: 32),

                  _boolRow('Under review', shop['is_under_review']),
                  _boolRow('Suspended', shop['is_suspended']),
                  _boolRow('Verified', shop['is_verified']),
                  _boolRow('Vacation mode', shop['is_vacation']),

                  if (shop['is_suspended'] == true) ...[
                    const Divider(height: 32),
                    _infoRow('Suspension reason', shop['suspension_reason']),
                    _infoRow('Suspended at', shop['suspended_at']),
                    _infoRow('Suspended by', shop['suspended_by']),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(value.toString(), style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _boolRow(String label, bool? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            value == true ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: value == true ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Future<void> _loadShopStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final result = await supabase.rpc('get_shop_moderation_stats').single();
      setState(() {
        _totalShops = (result['total_shops'] ?? 0) as int;
        _suspendedShops = (result['suspended_shops'] ?? 0) as int;
        _isLoadingStats = false;
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchShops({required String mode}) async {
    try {
      // 🟢 ACTIVE SHOPS
      if (mode == 'active') {
        final result = await supabase.rpc(
          'search_active_shops',
          params: {'search_term': _searchQuery.isEmpty ? null : _searchQuery},
        );
        return List<Map<String, dynamic>>.from(result);
      }

      // 🟡 UNDER REVIEW SHOPS
      if (mode == 'under_review') {
        final result = await supabase.rpc(
          'search_under_review_shops',
          params: {'search_term': _searchQuery.isEmpty ? null : _searchQuery},
        );
        return List<Map<String, dynamic>>.from(result);
      }

      // 🔴 SUSPENDED SHOPS
      if (mode == 'suspended') {
        final result = await supabase.rpc(
          'search_suspended_shops',
          params: {'search_term': _searchQuery.isEmpty ? null : _searchQuery},
        );
        return List<Map<String, dynamic>>.from(result);
      }

      // 👇 SAFETY NET (this fixes the error)
      return [];
    } catch (e) {
      debugPrint('Error fetching shops: $e');
      return [];
    }
  }

  Future<void> _suspendShop(Map<String, dynamic> shop) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Suspend Shop',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shop: ${shop['shop_name']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Suspension Reason',
                hintText: 'e.g., Fraud, repeated policy violation...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final reason = controller.text.trim();
    if (reason.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide a suspension reason'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    try {
      final result = await supabase.rpc(
        'suspend_shop_action',
        params: {'target_shop_id': shop['id'], 'reason': reason},
      );
      if (mounted && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Shop suspended!'),
            backgroundColor: Colors.red,
          ),
        );
        _loadShopStats();
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error suspending shop: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unsuspendShop(Map<String, dynamic> shop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsuspend Shop'),
        content: Text(
          'Are you sure you want to unsuspend ${shop['shop_name']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unsuspend'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await supabase.rpc(
        'unsuspend_shop_action',
        params: {'target_shop_id': shop['id']},
      );
      if (mounted && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Shop unsuspended!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadShopStats();
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error unsuspending shop: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveShop(Map<String, dynamic> shop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Shop'),
        content: Text('Approve "${shop['shop_name']}" and make it active?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await supabase
          .from('shops')
          .update({'is_under_review': false})
          .eq('id', shop['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Shop approved and now active'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadShopStats();
      setState(() {});
    } catch (e) {
      debugPrint('Error approving shop: $e');
    }
  }

  Future<void> _rejectShop(Map<String, dynamic> shop) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Shop', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject "${shop['shop_name']}"?'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rejection reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await supabase.rpc(
      'suspend_shop_action',
      params: {
        'target_shop_id': shop['id'],
        'reason': controller.text.trim().isEmpty
            ? 'Rejected during review'
            : controller.text.trim(),
      },
    );

    _loadShopStats();
    setState(() {});
  }

  Widget _buildShopCard(Map<String, dynamic> shop) {
    final isSuspended = shop['is_suspended'] == true;
    final isUnderReview = shop['is_under_review'] == true;

    final shopName = shop['shop_name'] ?? 'Unknown Shop';
    final address = shop['address'] ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 6),

      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showShopDetails(shop),
        child: ListTile(
          dense: true, // 🔥 forces compact layout
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),

          leading: Icon(
            Icons.storefront_outlined,
            color: isSuspended ? Colors.red : Colors.green,
            size: 28,
          ),

          title: Row(
            children: [
              Expanded(
                child: Text(
                  shopName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),

              // 🔴 SUSPENDED BADGE
              if (isSuspended)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'SUSPENDED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),

              // 🟡 UNDER REVIEW BADGE  ✅ PASTE THIS HERE
              if (isUnderReview)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'UNDER REVIEW',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
            ],
          ),

          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👤 OWNER NAME
              if (shop['owner_first_name'] != null)
                Text(
                  '👤 ${shop['owner_first_name']} ${shop['owner_last_name'] ?? ''}',
                  style: const TextStyle(fontSize: 13),
                ),

              // 🔐 PIN STATUS
              if (shop['owner_pin_set'] != null)
                Text(
                  shop['owner_pin_set'] == true
                      ? '🔐 PIN set'
                      : '⚠️ PIN not set',
                  style: TextStyle(
                    fontSize: 12,
                    color: shop['owner_pin_set'] == true
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),

              if (address.isNotEmpty) Text('📍 $address'),

              if (isSuspended && shop['suspension_reason'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '⚠️ ${shop['suspension_reason']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),

          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'approve':
                  _approveShop(shop);
                  break;
                case 'reject':
                  _rejectShop(shop);
                  break;
                case 'suspend':
                  _suspendShop(shop);
                  break;
                case 'unsuspend':
                  _unsuspendShop(shop);
                  break;
              }
            },

            itemBuilder: (context) => [
              if (isUnderReview)
                const PopupMenuItem(
                  value: 'approve',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text('Approve Shop'),
                    ],
                  ),
                ),
              if (isUnderReview)
                const PopupMenuItem(
                  value: 'reject',
                  child: Row(
                    children: [
                      Icon(Icons.close, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Reject Shop'),
                    ],
                  ),
                ),
              if (!isSuspended && !isUnderReview)
                const PopupMenuItem(
                  value: 'suspend',
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Suspend Shop'),
                    ],
                  ),
                ),
              if (isSuspended)
                const PopupMenuItem(
                  value: 'unsuspend',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text('Unsuspend Shop'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShopTab(String mode) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: SizedBox(
            height: 38, // 🔥 fixed compact height
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search shop…',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),

        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchShops(mode: mode),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(child: Text('Error: ${snapshot.error}'));
              final shops = snapshot.data!;
              if (shops.isEmpty) {
                return Center(
                  child: Text(
                    mode == 'suspended'
                        ? 'No suspended shops'
                        : mode == 'under_review'
                        ? 'No shops under review'
                        : 'No active shops',
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  await _loadShopStats();
                  setState(() {});
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: shops.length,
                  itemBuilder: (_, i) => _buildShopCard(shops[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stats Header
        // 🔢 SMALL STATS BAR (COMPACT)
        Container(
          margin: const EdgeInsets.only(top: 6, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _isLoadingStats
              ? const SizedBox(
                  height: 24,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 🏪 TOTAL SHOPS
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront,
                          size: 18,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_totalShops',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Shops',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),

                    // 🔴 SUSPENDED SHOPS
                    Row(
                      children: [
                        const Icon(Icons.block, size: 18, color: Colors.red),
                        const SizedBox(width: 6),
                        Text(
                          '$_suspendedShops',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Suspended',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
        ),

        // Tabs
        SizedBox(
          height: 36, // 🔥 force compact height
          child: TabBar(
            controller: _tabController,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.storefront_outlined, size: 14),
                text: 'Active',
              ),
              Tab(icon: Icon(Icons.hourglass_top, size: 14), text: 'Review'),
              Tab(icon: Icon(Icons.block, size: 14), text: 'Suspended'),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildShopTab('active'), // Active shops
              _buildShopTab('under_review'), // 🟡 Under Review
              _buildShopTab('suspended'), // Suspended shops
            ],
          ),
        ),
      ],
    );
  }
}
