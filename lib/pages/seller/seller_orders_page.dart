import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/pages/seller/seller_orders_history_page.dart';
import 'package:flutter/services.dart';
import 'package:bujafasta_app/state/seller_pending_order_state.dart';

class SellerOrdersPage extends StatefulWidget {
  const SellerOrdersPage({super.key});

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage> {
  static const Color kAccent = Color(0xFFF57C00);

  String _buyerCancelCountdown(String createdAt) {
    final created = DateTime.parse(createdAt);
    final cancelAllowedAt = created.add(const Duration(hours: 1));
    final now = DateTime.now();

    if (now.isAfter(cancelAllowedAt)) {
      return 'Buyer can cancel this order anytime';
    }

    final remaining = cancelAllowedAt.difference(now);
    final minutes = remaining.inMinutes;

    return 'Buyer may cancel in $minutes min';
  }

  final supabase = Supabase.instance.client;

  bool loading = true;
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    _loadPendingOrders();
  }

  String _deliveryLabel(String? type) {
    switch (type) {
      case 'delivery':
        return 'Delivered by Buja Fasta';
      case 'pickup':
        return 'Pickup at Buja Fasta point';
      case 'seller_pickup':
        return 'Pickup at your shop';
      default:
        return 'Order type unknown';
    }
  }

  Future<void> _loadPendingOrders() async {
    setState(() => loading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        orders = [];
        return;
      }

      final res = await supabase
          .from('orders')
          .select('''
  id,
  subtotal,
  quantity,
  size,
  condition,
  delivery_type,
  destination_address,
  destination_label,
  created_at,
  status,

  products(
    name,
    image_urls,
    subcategory
  ),

  profiles:profiles!orders_buyer_id_fkey!left(
    first_name,
    last_name
  ),

  destination_quartier:quartiers!orders_destination_quartier_id_fkey!left(
    name
  )
''')
          .eq('seller_id', user.id)
          .inFilter('status', [
            'pending',
            'accepted',
            'on_the_way',
            'ready_to_pickup',
          ])
          .order('created_at', ascending: false);

      orders = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      // 🔴 THIS IS WHY IT WAS STUCK
      debugPrint('LOAD ORDERS ERROR: $e');
      orders = [];
    } finally {
      // ✅ ALWAYS executed
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      await supabase.rpc(
        'seller_accept_order',
        params: {'p_order_id': orderId},
      );

      // 🔔 FORCE GLOBAL STATE UPDATE (LIKE PROFILE COMPLETE)
      await refreshSellerPendingOrders();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order accepted')));

      _loadPendingOrders(); // refresh local list
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    try {
      await supabase.rpc(
        'seller_reject_order',
        params: {'p_order_id': orderId},
      );

      // 🔔 FORCE GLOBAL STATE UPDATE (LIKE PROFILE COMPLETE)
      await refreshSellerPendingOrders();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order rejected')));

      _loadPendingOrders(); // refresh local list
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: null, // already on Pending
                    child: const Text('Pending'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SellerOrdersHistoryPage(),
                        ),
                      );
                    },
                    child: const Text('History'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
          ? const Center(child: Text('No pending orders'))
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];

                return Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🖼 PRODUCT IMAGE
                        Builder(
                          builder: (_) {
                            final images =
                                order['products']?['image_urls']
                                    as List<dynamic>?;

                            return CircleAvatar(
                              radius: 22,
                              backgroundImage:
                                  (images != null && images.isNotEmpty)
                                  ? NetworkImage(images.first)
                                  : null,
                              child: (images == null || images.isEmpty)
                                  ? const Icon(Icons.shopping_bag)
                                  : null,
                            );
                          },
                        ),

                        const SizedBox(width: 12),

                        // 📦 PRODUCT + BUYER INFO
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product name
                              Text(
                                order['products']?['name'] ?? 'Product',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),

                              Text(
                                'Status: ${order['status']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),

                              const SizedBox(height: 6),

                              // Seller earnings (ONLY subtotal)
                              Text(
                                'You earn: ${order['subtotal']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: kAccent,
                                ),
                              ),

                              const SizedBox(height: 4),

                              // stock
                              Text(
                                'Quantity: ${order['quantity'] ?? 1}',
                                style: const TextStyle(fontSize: 12),
                              ),

                              // Size (only if selected)
                              if (order['size'] != null &&
                                  order['size'].toString().isNotEmpty)
                                Text(
                                  'Size: ${order['size']}',
                                  style: const TextStyle(fontSize: 12),
                                ),

                              // Condition
                              if (order['condition'] != null &&
                                  order['condition'].toString().isNotEmpty)
                                Text(
                                  'Condition: ${order['condition']}',
                                  style: const TextStyle(fontSize: 12),
                                ),

                              // Category
                              if (order['products']?['subcategory'] != null)
                                Text(
                                  'Category: ${order['products']['subcategory']}',
                                  style: const TextStyle(fontSize: 12),
                                ),

                              const SizedBox(height: 4),

                              // Order type (delivery / pickup)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.local_shipping,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _deliveryLabel(order['delivery_type']),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // 🚚 DELIVERY DETAILS (ONLY FOR DELIVERY)
                              if (order['delivery_type'] == 'delivery') ...[
                                const SizedBox(height: 6),

                                if (order['destination_quartier']?['name'] !=
                                    null)
                                  Text(
                                    'Quartier: ${order['destination_quartier']['name']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),

                                if (order['destination_address'] != null &&
                                    order['destination_address']
                                        .toString()
                                        .isNotEmpty)
                                  Text(
                                    'Delivery address: ${order['destination_address']}',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],

                              const SizedBox(height: 6),

                              // Buyer row (name + quartier + chat icon)
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${order['profiles']?['first_name'] ?? ''} ${order['profiles']?['last_name'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 18,
                                    color: kAccent,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              // Cancel countdown
                              // Cancel countdown (ONLY when pending)
                              if (order['status'] == 'pending')
                                Text(
                                  _buyerCancelCountdown(order['created_at']),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // ⚙ ACTIONS
                        // ⚙ ACTIONS
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Copy is always allowed
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: order['id'].toString()),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Order ID copied'),
                                  ),
                                );
                              },
                            ),

                            // ⏳ PENDING ONLY → Accept / Reject
                            if (order['status'] == 'pending') ...[
                              OutlinedButton(
                                onPressed: () => _rejectOrder(order['id']),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  minimumSize: const Size(80, 32),
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text('Reject'),
                              ),
                              const SizedBox(height: 4),
                              ElevatedButton(
                                onPressed: () => _acceptOrder(order['id']),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(80, 32),
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text('Accept'),
                              ),
                            ]
                            // ✅ ACCEPTED
                            else if (order['status'] == 'accepted') ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.4),
                                  ),
                                ),
                                child: const Text(
                                  'Accepted',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ]
                            // 🚚 ON THE WAY
                            else if (order['status'] == 'on_the_way') ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.4),
                                  ),
                                ),
                                child: const Text(
                                  'On the way',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                            ]
                            // 📦 READY TO PICKUP
                            else if (order['status'] == 'ready_to_pickup') ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.purple.withOpacity(0.4),
                                  ),
                                ),
                                child: const Text(
                                  'Ready',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
