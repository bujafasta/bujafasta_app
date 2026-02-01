import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/pages/admin/admin_order_details_page.dart';

class OrdersManagementPage extends StatefulWidget {
  const OrdersManagementPage({super.key});

  @override
  State<OrdersManagementPage> createState() => _OrdersManagementPageState();
}

class _OrdersManagementPageState extends State<OrdersManagementPage> {
  void _openManualRefundSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: _ManualRefundContent(
            supabase: supabase,
            deliveryLabel: _deliveryLabel,
          ),
        );
      },
    );
  }

  String _deliveryLabel(String? type) {
    switch (type) {
      case 'delivery':
        return 'Delivery by Buja Fasta';
      case 'pickup':
        return 'Pickup at Buja Fasta';
      case 'seller_pickup':
        return 'Pickup at seller shop';
      default:
        return 'Order type unknown';
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadOrders(); // 👈 load "pending" orders by default
  }

  // 👇 currently selected order status
  String _selectedStatus = 'pending';

  final supabase = Supabase.instance.client;

  bool _loading = false;
  List<Map<String, dynamic>> _orders = [];

  // 👇 all order statuses
  final List<Map<String, String>> _statuses = [
    {'id': 'pending', 'label': 'Pending'},
    {'id': 'accepted', 'label': 'Accepted'},
    {'id': 'on_the_way', 'label': 'On the way'},
    {'id': 'ready_to_pickup', 'label': 'Ready to pickup'}, // 👈 NEW TAB
    {'id': 'rejected', 'label': 'Rejected'},
    {'id': 'cancelled', 'label': 'Cancelled'},
    {'id': 'completed', 'label': 'Completed'},
    {'id': 'refunded', 'label': 'Refunded'},
  ];

  // 🎨 Status colors
  final Map<String, Color> _statusColors = {
    'pending': Colors.orange,
    'accepted': Colors.blue,
    'on_the_way': Colors.purple,
    'ready_to_pickup': Colors.deepOrange, // 👈 NEW
    'rejected': Colors.red,
    'cancelled': Colors.grey,
    'completed': Colors.green,
    'refunded': Colors.teal,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.currency_exchange),
            tooltip: 'Manual refund',
            onPressed: _openManualRefundSheet,
          ),
        ],
      ),

      body: Column(
        children: [
          // =====================================
          // HORIZONTAL STATUS TABS
          // =====================================
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _statuses.length,
              itemBuilder: (context, index) {
                final status = _statuses[index];
                final isSelected = _selectedStatus == status['id'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStatus = status['id']!;
                    });
                    _loadOrders();
                  },

                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _statusColors[status['id']]!
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? _statusColors[status['id']]!
                            : Colors.grey.shade300,
                      ),
                    ),

                    child: Center(
                      child: Text(
                        status['label']!,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // =====================================
          // CONTENT AREA (PLACEHOLDER)
          // =====================================
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                ? Center(
                    child: Text(
                      'No $_selectedStatus orders',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      final product = order['products'];

                      return Card(
                        margin: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Builder(
                                builder: (_) {
                                  final images =
                                      product?['image_urls'] as List<dynamic>?;

                                  return CircleAvatar(
                                    backgroundImage:
                                        (images != null && images.isNotEmpty)
                                        ? NetworkImage(images.first)
                                        : null,
                                    child: images == null || images.isEmpty
                                        ? const Icon(Icons.shopping_bag)
                                        : null,
                                  );
                                },
                              ),
                              title: Text(
                                product?['name'] ?? 'Product',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _deliveryLabel(order['delivery_type']),
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminOrderDetailsPage(
                                      orderId: order['id'],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);

    try {
      final res = await supabase
          .from('orders')
          .select('''
  id,
  status,
  delivery_type,
  is_delivery_confirmed,
  created_at,

  products (
    name,
    image_urls
  )
''')
          .eq('status', _selectedStatus)
          .order('created_at', ascending: false);

      _orders = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('ADMIN LOAD ORDERS ERROR: $e');
      _orders = [];
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}

class _ManualRefundContent extends StatefulWidget {
  final SupabaseClient supabase;
  final String Function(String?) deliveryLabel;

  const _ManualRefundContent({
    required this.supabase,
    required this.deliveryLabel,
  });

  @override
  State<_ManualRefundContent> createState() => _ManualRefundContentState();
}

class _ManualRefundContentState extends State<_ManualRefundContent> {
  final TextEditingController _orderIdCtrl = TextEditingController();

  bool _loading = false;
  String? _status;
  Map<String, dynamic>? _order;

  @override
  void dispose() {
    _orderIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _moveOrderMoneyToAudit() async {
    if (_order == null) return;

    setState(() => _loading = true);

    try {
      await widget.supabase.rpc(
        'move_order_money_to_audit',
        params: {'p_order_id': _order!['id']},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order money moved to audit (placeholder)'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audit move failed (expected): $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadOrder() async {
    final id = _orderIdCtrl.text.trim();
    if (id.isEmpty) return;

    setState(() {
      _loading = true;
      _order = null;
      _status = null;
    });

    try {
      final res = await widget.supabase
          .from('orders')
          .select('''
  id,
  status,
  created_at,
  delivery_type,
  pickup_day,
  is_delivery_confirmed,

  quantity,
  size,
  condition,
  subcategory,

  subtotal,
  delivery_fee,
  protection_fee,
  amount,

  origin_label,
  origin_address,
  destination_label,
  destination_address,

  products (
  name,
  image_urls
),


  buyer:profiles!orders_buyer_id_fkey (
    first_name,
    last_name,
    phone,
    email
  ),

  seller:profiles!orders_seller_id_fkey (
    first_name,
    last_name,
    phone,
    email
  ),

  shops (
    shop_name,
    sell_type,
    is_verified,
    quartier_id,
    quartiers (
      name
    )
  )
''')
          .eq('id', id)
          .maybeSingle();

      if (res == null) {
        setState(() => _status = 'Order not found');
      } else {
        setState(() {
          _order = res;
          _status = res['status'];
        });
      }
    } catch (e) {
      setState(() => _status = 'Failed to load order');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Manual order lookup',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),

              const Spacer(), // 👈 pushes "Close" to the right

              TextButton(
                onPressed: () {
                  Navigator.pop(context); // 👈 closes the sheet
                },
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _orderIdCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Paste order ID',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadOrder(),
                ),
              ),

              const SizedBox(width: 8),

              ElevatedButton(
                onPressed: _loading ? null : _loadOrder,
                child: const Text('Search'),
              ),
            ],
          ),

          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Loading...', style: TextStyle(fontSize: 12)),
            ),

          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Status: $_status',
                style: const TextStyle(fontSize: 12),
              ),
            ),

          if (_order != null) ...[
            const Divider(),

            _info('Delivery', widget.deliveryLabel(_order!['delivery_type'])),
            _info('Total', '${_order!['amount']} BIF'),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.security),
                label: const Text('Move order money to audit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _loading ? null : _moveOrderMoneyToAudit,
              ),
            ),

            const Divider(),
            const Text(
              'Order details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            _info('Order ID', _order!['id']),
            _info('Created at', _order!['created_at']),
            _info('Status', _order!['status']),
            _info(
              'Delivery confirmed',
              _order!['is_delivery_confirmed'] == true ? 'Yes' : 'No',
            ),

            const SizedBox(height: 8),
            const Text('Buyer', style: TextStyle(fontWeight: FontWeight.bold)),

            _info(
              'Name',
              '${_order!['buyer']?['first_name']} ${_order!['buyer']?['last_name']}',
            ),
            _info('Phone', _order!['buyer']?['phone']),
            _info('Email', _order!['buyer']?['email']),
            const SizedBox(height: 8),
            const Text(
              'Seller / Shop',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            _info(
              'Seller',
              '${_order!['seller']?['first_name']} ${_order!['seller']?['last_name']}',
            ),
            _info('Seller phone', _order!['seller']?['phone']),
            _info('Shop', _order!['shops']?['shop_name']),
            _info('Shop type', _order!['shops']?['sell_type']),
            _info(
              'Verified',
              _order!['shops']?['is_verified'] == true ? 'Yes' : 'No',
            ),
            _info('Shop quartier', _order!['shops']?['quartiers']?['name']),

            const SizedBox(height: 8),
            const Text(
              'Product',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            if (_order!['products']?['image_urls'] != null &&
                (_order!['products']['image_urls'] as List).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: GestureDetector(
                  onTap: () {
                    _openImagePreview(
                      context,
                      List<String>.from(_order!['products']['image_urls']),
                    );
                  },
                  child: const Text(
                    'Preview images',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),

            _info('Name', _order!['products']?['name']),
            _info('Quantity', _order!['quantity']?.toString()),
            _info('Size', _order!['size']),
            _info('Condition', _order!['condition']),
            _info('Category', _order!['subcategory']),

            const SizedBox(height: 8),
            const Text(
              'Delivery / Route',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            _info(
              'Route',
              _order!['delivery_type'] == 'delivery'
                  ? '${_order!['origin_label']} → ${_order!['destination_label']}'
                  : 'Pickup',
            ),
            _info('Origin address', _order!['origin_address']),
            _info('Destination address', _order!['destination_address']),
            _info('Pickup day', _order!['pickup_day']),

            const SizedBox(height: 8),
            const Text(
              'Payment',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            _info('Subtotal', '${_order!['subtotal']} BIF'),
            _info('Delivery fee', '${_order!['delivery_fee']} BIF'),
            _info('Protection fee', '${_order!['protection_fee']} BIF'),
            _info('Total', '${_order!['amount']} BIF'),
          ],
        ],
      ),
    );
  }

  Widget _info(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }

  void _openImagePreview(BuildContext context, List<String> images) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              // 🔄 IMAGE SCROLLER
              PageView.builder(
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    child: Center(
                      child: Image.network(
                        images[index],
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
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
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmRefund(BuildContext context, String target) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Are you sure?'),
          content: Text(
            target == 'buyer'
                ? 'This will refund the buyer. This action cannot be undone.'
                : 'This will refund the seller. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);

                // 🚫 NO LOGIC YET (INTENTIONALLY)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Refund $target (logic not implemented yet)'),
                  ),
                );
              },
              child: const Text('Yes, refund'),
            ),
          ],
        );
      },
    );
  }
}
