import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/models/product.dart';
import 'package:bujafasta_app/services/permission_service.dart';
import 'package:bujafasta_app/pages/admin/user_moderation_page.dart';
import 'package:bujafasta_app/pages/admin/shop_moderation_page.dart';
import 'package:bujafasta_app/pages/messages/chat_list_page.dart';
import 'package:bujafasta_app/pages/admin/orders_management_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final supabase = Supabase.instance.client;
  final PermissionService _permissionService = PermissionService();
  final TextEditingController _bujafastaWithdrawController =
      TextEditingController();

  bool _withdrawingBujafasta = false;

  Map<String, dynamic>? _appMoney;
  bool _loadingAppMoney = false;

  // Permission flags
  bool _canManageProducts = false;
  bool _canSuspendUsers = false;
  bool _canSuspendShops = false;
  bool _isAgent = false;
  bool _canManageWithdraw = false;
  bool _isLoadingPermissions = true;
  bool _canManageOrders = false; // 👈 NEW (ADMIN ORDERS)

  // Current selected role
  String _selectedRole =
      'products'; // Default:  products, deposits, users, shops

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  void _showBujafastaWithdrawDialog() {
    _bujafastaWithdrawController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text('Withdraw from BujaFasta Wallet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter amount to withdraw',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bujafastaWithdrawController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (BIF)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _withdrawingBujafasta
                  ? null
                  : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _withdrawingBujafasta
                  ? null
                  : _confirmBujafastaWithdraw,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              child: _withdrawingBujafasta
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Withdraw'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmBujafastaWithdraw() async {
    final text = _bujafastaWithdrawController.text.trim();
    final amount = num.tryParse(text);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid amount')));
      return;
    }

    setState(() {
      _withdrawingBujafasta = true;
    });

    try {
      await supabase.rpc(
        'admin_withdraw_bujafasta_wallet',
        params: {
          'p_amount': amount,
          'p_description': 'Admin withdrawal from BujaFasta wallet',
        },
      );

      if (!mounted) return;

      Navigator.pop(context);

      await _loadAppMoney(); // refresh balances

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Withdrawal successful')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Withdraw failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _withdrawingBujafasta = false;
        });
      }
    }
  }

  // ============================================
  // LOAD USER PERMISSIONS
  // ============================================

  Future<void> _loadAppMoney() async {
    setState(() {
      _loadingAppMoney = true;
    });

    try {
      final res = await supabase.rpc('get_app_money_overview');

      setState(() {
        _appMoney = Map<String, dynamic>.from(res);
      });
    } catch (e) {
      debugPrint('❌ Failed to load app money: $e');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load app money: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingAppMoney = false;
        });
      }
    }
  }

  Future<void> _loadPermissions() async {
    setState(() {
      _isLoadingPermissions = true;
    });

    final perms = await _permissionService.getPermissions();

    setState(() {
      _canManageProducts = perms['can_manage_products'] == true;
      _canSuspendUsers = perms['can_suspend_users'] == true;
      _canSuspendShops = perms['can_suspend_shops'] == true;
      _isAgent = perms['is_agent'] == true;
      _canManageWithdraw = perms['can_manage_withdraw'] == true;
      _isLoadingPermissions = false;
      _canManageOrders = perms['can_manage_orders'] == true; // 👈 ADD THIS TOO

      // Auto-select first available role
      if (_canManageProducts) {
        _selectedRole = 'products';
      } else if (_canManageOrders) {
        _selectedRole = 'orders';
      } else if (_canManageWithdraw) {
        _selectedRole = 'withdraw';
      } else if (_isAgent) {
        _selectedRole = 'deposits';
      } else if (_canSuspendUsers) {
        _selectedRole = 'users';
      } else if (_canSuspendShops) {
        _selectedRole = 'shops';
      }
    });
  }

  // ============================================
  // GET AVAILABLE ROLES
  // ============================================

  List<Map<String, dynamic>> _getAvailableRoles() {
    final roles = <Map<String, dynamic>>[];

    if (_canManageProducts) {
      roles.add({
        'id': 'products',
        'title': 'Product',
        'icon': Icons.inventory_2_outlined,
        'color': Colors.blue,
      });
    }

    if (_canManageOrders) {
      roles.add({
        'id': 'orders',
        'title': 'Orders',
        'icon': Icons.receipt_long_outlined,
        'color': Colors.teal,
      });
    }

    if (_isAgent) {
      roles.add({
        'id': 'deposits',
        'title': 'Payment',
        'icon': Icons.account_balance_wallet_outlined,
        'color': Colors.green,
      });
    }

    if (_canManageWithdraw) {
      roles.add({
        'id': 'withdraw',
        'title': 'Withdraw',
        'icon': Icons.payments_outlined,
        'color': Colors.deepOrange,
      });
    }

    if (_canSuspendUsers) {
      roles.add({
        'id': 'users',
        'title': 'Users',
        'icon': Icons.people_outline,
        'color': Colors.orange,
      });
    }

    if (_canSuspendShops) {
      roles.add({
        'id': 'shops',
        'title': 'Shops',
        'icon': Icons.storefront_outlined,
        'color': Colors.purple,
      });
    }

    roles.add({
      'id': 'app_money',
      'title': 'App Money',
      'icon': Icons.account_balance_outlined,
      'color': Colors.indigo,
    });

    return roles;
  }

  // ============================================
  // BUILD ROLE SELECTOR (Horizontal Scroll)
  // ============================================

  Widget _buildRoleSelector() {
    final roles = _getAvailableRoles();

    if (roles.isEmpty) {
      return const SizedBox.shrink();
    }

    if (roles.length == 1) {
      // Only one role, no need for selector
      return const SizedBox.shrink();
    }

    return Container(
      height: 64,
      margin: const EdgeInsets.only(top: 6, bottom: 8),

      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: roles.length,
        itemBuilder: (context, index) {
          final role = roles[index];
          final isSelected = _selectedRole == role['id'];

          return GestureDetector(
            onTap: () {
              if (role['id'] == 'orders') {
                // 👉 OPEN ORDERS PAGE
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OrdersManagementPage(),
                  ),
                );
                return;
              }

              setState(() {
                _selectedRole = role['id'];
              });

              if (role['id'] == 'app_money') {
                _loadAppMoney();
              }
            },

            child: Container(
              width: 72,
              margin: const EdgeInsets.only(right: 10),

              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [role['color'].withOpacity(0.8), role['color']],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? role['color'] : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: role['color'].withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    role['icon'],
                    size: 22,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role['title'],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // BUILD CURRENT ROLE CONTENT
  // ============================================

  Widget _buildRoleContent() {
    switch (_selectedRole) {
      case 'products':
        return _buildProductManagement();
      case 'deposits':
        return _buildDepositVerification();
      case 'withdraw':
        return _buildWithdrawVerification();
      case 'users':
        return _buildUserModeration();
      case 'shops':
        return _buildShopModeration();
      case 'app_money':
        return _buildAppMoney();
      default:
        return _buildNoPermission();
    }
  }

  // ============================================
  // PRODUCT MANAGEMENT TAB
  // ============================================

  Widget _buildProductManagement() {
    if (!_canManageProducts) {
      return _buildNoPermission();
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.pending_outlined), text: "Pending"),
              Tab(icon: Icon(Icons.check_circle_outline), text: "Approved"),
              Tab(icon: Icon(Icons.cancel_outlined), text: "Rejected"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildProductTab("pending"),
                _buildProductTab("approved"),
                _buildProductTab("rejected"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTab(String status) {
    return FutureBuilder<List<Product>>(
      future: _fetchProducts(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error:  ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final items = snapshot.data!;
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No $status products',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) => _buildProductCard(items[i]),
          ),
        );
      },
    );
  }

  Future<List<Product>> _fetchProducts(String status) async {
    try {
      final res = await supabase
          .from('products')
          .select('''
      id, owner_id, name, price, category, subcategory, subcategory2,
      condition, size, details, image_urls, status, reject_reason, stock,
      shops!inner (
        id,
        shop_name,
        owner_id,
        is_under_review,
        is_suspended,
        profiles (
          first_name,
          last_name,
          phone
        )
      )
    ''')
          .eq('status', status)
          .eq('shops.is_under_review', false)
          .eq('shops.is_suspended', false)
          .order('created_at', ascending: false);

      return (res as List)
          .map((p) => Product.fromMap(Map<String, dynamic>.from(p)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching products:  $e');
      return [];
    }
  }

  Widget _buildProductCard(Product product) {
    return InkWell(
      onTap: () => _showProductDetails(product.raw),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: product.imageUrl != null
                ? Image.network(
                    product.imageUrl!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_outlined, size: 30),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_outlined, size: 30),
                  ),
          ),
          title: Text(
            product.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text("Price: ${product.price} BIF"),
              if (product.category != null)
                Text(
                  "Category: ${product.category}",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              if (product.rejectReason != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Reason: ${product.rejectReason}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product.status != 'approved')
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  tooltip: 'Approve',
                  onPressed: () => _approveProduct(product),
                ),
              if (product.status != 'rejected')
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  tooltip: 'Reject',
                  onPressed: () => _rejectProduct(product),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approveProduct(Product product) async {
    try {
      await supabase
          .from('products')
          .update({'status': 'approved', 'reject_reason': null})
          .eq('id', product.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Approved:  ${product.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
      setState(() {});
    } catch (e) {
      debugPrint('Error approving:  $e');
    }
  }

  Future<void> _rejectProduct(Product product) async {
    await HapticFeedback.mediumImpact();
    final controller = TextEditingController();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Reject Product? ",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product: ${product.name}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Rejection Reason",
                hintText: "e.g., Inappropriate content.. .",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    if (accepted != true) return;

    final reason = controller.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await supabase
          .from('products')
          .update({'status': 'rejected', 'reject_reason': reason})
          .eq('id', product.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Rejected: ${product.name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {});
    } catch (e) {
      debugPrint('Error rejecting: $e');
    }
  }

  // ============================================
  // ORDERS MANAGEMENT TAB
  // ============================================

  // ============================================
  // DEPOSIT VERIFICATION TAB
  // ============================================

  Widget _buildDepositVerification() {
    // If not an agent, block access
    if (!_isAgent) {
      return _buildNoPermission();
    }

    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.account_balance_wallet_outlined),
        label: const Text('Open Payment Verification Inbox'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          // NAVIGATE to ChatListPage in agent mode
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ChatListPage(agentDepositMode: true),
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // USER WITHDRAWAL TAB
  // ============================================

  Widget _buildWithdrawVerification() {
    if (!_canManageWithdraw) {
      return _buildNoPermission();
    }

    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.payments_outlined),
        label: const Text('Open Withdraw Verification Inbox'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ChatListPage(agentWithdrawMode: true),
            ),
          );
        },
      ),
    );
  }

  // ============================================
  // USER MODERATION TAB
  // ============================================

  Widget _buildUserModeration() {
    if (!_canSuspendUsers) {
      return _buildNoPermission();
    }

    return const UserModerationPage();
  }

  // ============================================
  // SHOP MODERATION TAB
  // ============================================

  Widget _buildShopModeration() {
    if (!_canSuspendShops) {
      return _buildNoPermission();
    }
    return const ShopModerationPage();
  }

  // ============================================
  // APP MONEY TAB
  // ============================================

  Widget _buildAppMoney() {
    if (_loadingAppMoney) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_appMoney == null) {
      return Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Load App Money'),
          onPressed: _loadAppMoney,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAppMoney,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _moneyCard(
            title: 'Users Locked Balance',
            amount: _appMoney!['users_locked'],
            icon: Icons.lock_outline,
            color: Colors.orange,
          ),
          _moneyCard(
            title: 'Users Available Balance',
            amount: _appMoney!['users_available'],
            icon: Icons.account_balance_wallet_outlined,
            color: Colors.green,
          ),
          _moneyCard(
            title: 'Shops Wallet Balance',
            amount: _appMoney!['shops_balance'],
            icon: Icons.storefront_outlined,
            color: Colors.blue,
          ),
          _moneyCard(
            title: 'Escrow Wallet Balance',
            amount: _appMoney!['escrow_balance'],
            icon: Icons.security_outlined,
            color: Colors.deepPurple,
          ),
          GestureDetector(
            onTap: _showBujafastaWithdrawDialog,
            child: _moneyCard(
              title: 'BujaFasta Wallet Balance',
              amount: _appMoney!['bujafasta_balance'],
              icon: Icons.account_balance_outlined,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyCard({
    required String title,
    required num amount,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${amount.toStringAsFixed(2)} BIF',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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

  // ============================================
  // NO PERMISSION VIEW
  // ============================================

  Widget _buildNoPermission() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            'No Permission',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have access to this section',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPermissions) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final availableRoles = _getAvailableRoles();

    if (availableRoles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Admin Panel")),
        body: _buildNoPermission(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Your Permissions',
            onPressed: _showPermissionsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildRoleSelector(),
          Expanded(child: _buildRoleContent()),
        ],
      ),
    );
  }

  void _openImagePreview(
    BuildContext context,
    List<dynamic> imageUrls,
    int initialIndex,
  ) {
    final PageController controller = PageController(initialPage: initialIndex);

    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                PageView.builder(
                  controller: controller,
                  itemCount: imageUrls.length,
                  itemBuilder: (_, index) {
                    return Center(
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Image.network(
                          imageUrls[index],
                          fit: BoxFit.contain,
                          loadingBuilder: (c, child, progress) {
                            if (progress == null) return child;
                            return const CircularProgressIndicator(
                              color: Colors.white,
                            );
                          },
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 80,
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
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProductDetails(Map<String, dynamic> raw) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, controller) {
            final shop = raw['shops'];
            final owner = shop?['profiles'];

            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: controller,
                children: [
                  // drag handle
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

                  // PRODUCT NAME
                  Text(
                    raw['name'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // IMAGES
                  if (raw['image_urls'] != null &&
                      (raw['image_urls'] as List).isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: raw['image_urls'].length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GestureDetector(
                              onTap: () => _openImagePreview(
                                context,
                                raw['image_urls'],
                                i,
                              ),

                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  raw['image_urls'][i],
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const Divider(height: 32),

                  _info('Price', '${raw['price']} BIF'),
                  _info('Stock', raw['stock']),
                  _info('Condition', raw['condition']),
                  _info('Category', raw['category']),
                  if (raw['subcategory'] != null)
                    _info('Subcategory', raw['subcategory']),
                  if (raw['subcategory2'] != null)
                    _info('Subcategory 2', raw['subcategory2']),
                  if (raw['subcategory3'] != null)
                    _info('Subcategory 3', raw['subcategory3']),
                  _info('Details', raw['details']),

                  const Divider(height: 32),

                  // SHOP INFO
                  Text(
                    'Shop Information',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  _info('Shop name', shop?['shop_name']),
                  _info(
                    'Owner name',
                    '${owner?['first_name'] ?? ''} ${owner?['last_name'] ?? ''}',
                  ),
                  _info('Owner phone', owner?['phone']),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _info(String label, dynamic value) {
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

  void _showPermissionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Permissions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPermissionBadge('Manage Products', _canManageProducts),
            const SizedBox(height: 8),
            _buildPermissionBadge('Payment Agent', _isAgent),
            const SizedBox(height: 8),
            _buildPermissionBadge('Suspend Users', _canSuspendUsers),
            const SizedBox(height: 8),
            _buildPermissionBadge('Suspend Shops', _canSuspendShops),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBadge(String label, bool hasPermission) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: hasPermission ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPermission ? Colors.green : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasPermission ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: hasPermission ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: hasPermission
                  ? Colors.green.shade700
                  : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
