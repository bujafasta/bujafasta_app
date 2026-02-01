import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';


class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  final supabase = Supabase.instance.client;
  // 🎨 Status colors (GLOBAL & CONSISTENT)
  static const Color kSellerConfirmedBlue = Color(
    0xFF2196F3,
  ); // Material Blue 500
  static const Color kDeliveryConfirmedGreen = Color(0xFF4CAF50); // Green 500

  bool _canCancelOrder(Map<String, dynamic> order) {
    if (order['status'] != 'pending') return false;

    final createdAt = DateTime.parse(order['created_at']);
    final now = DateTime.now();

    return now.isAfter(createdAt.add(const Duration(hours: 1)));
  }

  String _pendingStatusMessage(Map<String, dynamic> order) {
    if (order['status'] != 'pending') return '';

    if (_canCancelOrder(order)) {
      return 'You can keep waiting for the seller to confirm your order or cancel it';
    }

    return 'Waiting for seller to confirm your order';
  }

  String _sellerConfirmedMessage() {
    return 'Seller has confirmed your order. '
        'Please wait for Buja Fasta to confirm your delivery.';
  }

  String _deliveryConfirmedMessage() {
    return 'Buja Fasta has confirmed your delivery. '
        'Please confirm when you receive delivery.';
  }

  bool loadingOrders = true;
  bool loadingDetails = false;

  List<Map<String, dynamic>> orders = [];
  Map<String, dynamic>? selectedOrder;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  // 🔄 LOAD ORDERS ONCE
  Future<void> _loadOrders() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final res = await supabase
        .from('orders')
        .select('''
  id,
  amount,
  status,
  is_delivery_confirmed,
  delivery_type,
  shops (
    sell_type
  ),
  products (
    name,
    image_urls
  )
''')
        .eq('buyer_id', user.id)
        .order('created_at', ascending: false);

    setState(() {
      orders = List<Map<String, dynamic>>.from(res);
      loadingOrders = false;
    });
  }

  // 🔄 LOAD DETAILS ONLY
  Future<void> _loadOrderDetails(String orderId) async {
    setState(() {
      loadingDetails = true;
    });

    final res = await supabase
        .from('orders')
        .select('''
      id,
      amount,
      status,
      is_delivery_confirmed,
      created_at,
      quantity,
      subtotal,
      size,
      condition,
      subcategory,

      delivery_type,
      delivery_fee,
      protection_fee,

      origin_label,
origin_address,
destination_label,
destination_address,
pickup_day,


      products (
        name,
        image_urls
      ),

      shops (
  shop_name,
  is_verified,
  sell_type,
  quartier_id,
  quartiers ( name )
)

    ''')
        .eq('id', orderId)
        .maybeSingle();

    setState(() {
      selectedOrder = res;
      loadingDetails = false;
    });
  }

  // ✅ CONFIRM RECEIVED
  Future<void> _confirmReceived() async {
    await supabase.rpc(
      'buyer_confirm_order',
      params: {'p_order_id': selectedOrder!['id']},
    );

    _loadOrderDetails(selectedOrder!['id']);
  }

  // ❌ CANCEL ORDER
  Future<void> _cancelOrder() async {
    await supabase.rpc(
      'buyer_cancel_order',
      params: {'p_order_id': selectedOrder!['id']},
    );

    _loadOrderDetails(selectedOrder!['id']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        leading: selectedOrder != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    selectedOrder = null;
                  });
                },
              )
            : null,

        actions: selectedOrder != null
            ? [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'copy_id') {
                      Clipboard.setData(
                        ClipboardData(text: selectedOrder!['id'].toString()),
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Order ID copied')),
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'copy_id',
                      child: Text('Copy order ID'),
                    ),
                  ],
                ),
              ]
            : null,
      ),

      // 🧠 MAGIC PART
      body: IndexedStack(
        index: selectedOrder == null ? 0 : 1,
        children: [_ordersList(), _orderDetails()],
      ),
    );
  }

  Color _orderCardColor(Map<String, dynamic> order) {
    final status = order['status'];
    final deliveryType = order['delivery_type'];
    final isDeliveryConfirmed = order['is_delivery_confirmed'] == true;
    final sellType = order['shops']?['sell_type'];

    // 🔵 Seller confirmed → waiting for Buja Fasta
    if (status == 'accepted' &&
        deliveryType == 'delivery' &&
        isDeliveryConfirmed == false &&
        sellType == 'physical') {
      return kSellerConfirmedBlue.withOpacity(0.10);
    }

    // 🟢 Buja Fasta confirmed → ready
    if (status == 'accepted' &&
        deliveryType == 'delivery' &&
        isDeliveryConfirmed == true &&
        sellType == 'physical') {
      return kDeliveryConfirmedGreen.withOpacity(0.12);
    }

    // 🟢 Non-delivery accepted (pickup etc.)
    if (status == 'accepted' && deliveryType != 'delivery') {
      return kDeliveryConfirmedGreen.withOpacity(0.12);
    }

    return Colors.white;
  }

  Color _getOrderBorderColor(Map<String, dynamic> order) {
    final status = order['status'];
    final deliveryType = order['delivery_type'];
    final isDeliveryConfirmed = order['is_delivery_confirmed'] == true;
    final sellType = order['shops']?['sell_type'];

    // 🔵 Seller confirmed → waiting for Buja Fasta
    if (status == 'accepted' &&
        deliveryType == 'delivery' &&
        !isDeliveryConfirmed &&
        sellType == 'physical') {
      return kSellerConfirmedBlue;
    }

    // 🟢 Delivery confirmed or pickup
    if (status == 'accepted') {
      return kDeliveryConfirmedGreen;
    }

    return Colors.transparent;
  }

  // 📄 ORDERS LIST VIEW
  Widget _ordersList() {
    if (loadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return const Center(child: Text('You have no orders'));
    }

    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];

        return Card(
          margin: const EdgeInsets.all(12),
          color: _orderCardColor(order),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: order['status'] == 'accepted'
                ? BorderSide(color: _getOrderBorderColor(order), width: 1.5)
                : BorderSide.none,
          ),
          child: ListTile(
            leading: Builder(
              builder: (_) {
                final images =
                    order['products']?['image_urls'] as List<dynamic>?;

                return CircleAvatar(
                  radius: 22,
                  backgroundImage: (images != null && images.isNotEmpty)
                      ? NetworkImage(images.first)
                      : null,
                  child: (images == null || images.isEmpty)
                      ? const Icon(Icons.shopping_bag)
                      : null,
                );
              },
            ),

            title: Text(
              order['products']?['name'] ?? 'Product',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            subtitle: Text(
              'Status: ${order['status']}',
              style: const TextStyle(fontSize: 12),
            ),

            trailing: Text(
              '${formatPrice(order['amount'])} BIF',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            onTap: () {
              _loadOrderDetails(order['id']);
            },
          ),
        );
      },
    );
  }

  // 📦 ORDER DETAILS VIEW
  Widget _orderDetails() {
    if (loadingDetails) {
      return const Center(child: CircularProgressIndicator());
    }

    if (selectedOrder == null) {
      return const SizedBox.shrink();
    }

    final o = selectedOrder!;
    // ✅ Decide if buyer can confirm received
    final bool canConfirmReceived =
        (o['delivery_type'] == 'delivery' && o['status'] == 'on_the_way') ||
        (o['delivery_type'] == 'pickup' && o['status'] == 'ready_to_pickup') ||
        (o['delivery_type'] == 'seller_pickup' && o['status'] == 'accepted');

    final product = o['products'];
    final shop = o['shops'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateTime.parse(
              o['created_at'],
            ).toLocal().toString().split('.').first,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),

          // 1️⃣ ORDER SUMMARY
          const Text(
            'Order summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // ⏳ PENDING STATUS MESSAGE
          if (o['status'] == 'pending') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _pendingStatusMessage(o),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ❌ REJECTED BY SELLER BANNER
          if (o['status'] == 'rejected') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Sorry! Your order was rejected by the seller',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'You were not charged for this order.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 📦 PICKUP ACCEPTED → WAIT FOR BUJA FASTA
          if (o['status'] == 'accepted' && o['delivery_type'] == 'pickup') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Seller accepted your order',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Please wait for Buja Fasta to accept your pickup.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 🌐 ONLINE SHOP + DELIVERY → WAIT FOR BUJA FASTA
          if (o['status'] == 'accepted' &&
              o['delivery_type'] == 'delivery' &&
              shop?['sell_type'] == 'online') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kSellerConfirmedBlue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: kSellerConfirmedBlue.withOpacity(0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Seller accepted your order',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Please wait for Buja Fasta to confirm delivery.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ✅ ACCEPTED + DELIVERY STATUS MESSAGE
          if (o['status'] == 'accepted' &&
              o['delivery_type'] == 'delivery' &&
              o['is_delivery_confirmed'] == false &&
              shop?['sell_type'] == 'physical') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kSellerConfirmedBlue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: kSellerConfirmedBlue.withOpacity(0.4),
                ),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sellerConfirmedMessage(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Note: If Buja Fasta takes more than 10 minutes, '
                    'please call +257 64 34 12 58.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (o['status'] == 'accepted' &&
              o['delivery_type'] == 'delivery' &&
              o['is_delivery_confirmed'] == true &&
              shop?['sell_type'] == 'physical') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kDeliveryConfirmedGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: kDeliveryConfirmedGreen.withOpacity(0.4),
                ),
              ),

              child: Text(
                _deliveryConfirmedMessage(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 🚚 ON THE WAY → BUYER REMINDER BANNER
          if (o['status'] == 'on_the_way' &&
              o['delivery_type'] == 'delivery' &&
              shop?['sell_type'] == 'physical') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Your order is on the way',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Please remember to confirm when you receive it.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 🌐 ONLINE SHOP + ON THE WAY → BUYER REMINDER
          if (o['status'] == 'on_the_way' &&
              o['delivery_type'] == 'delivery' &&
              shop?['sell_type'] == 'online') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Your order is on the way',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Please confirm when you receive it.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 📦 READY TO PICKUP → BUYER REMINDER BANNER
          if (o['status'] == 'ready_to_pickup' &&
              o['delivery_type'] == 'pickup') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Your item is ready to pickup at Buja Fasta',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Please remember to confirm when you receive it.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ✅ COMPLETED → ORDER FINISHED BANNER
          if (o['status'] == 'completed') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Order completed',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'This order was completed successfully.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage:
                    (product?['image_urls'] != null &&
                        product['image_urls'].isNotEmpty)
                    ? NetworkImage(product['image_urls'][0])
                    : null,
                child: product?['image_urls'] == null
                    ? const Icon(Icons.shopping_bag)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product?['name'] ?? 'Product',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Amount: ${formatPrice(o['amount'])} BIF'),
                    Text('Status: ${o['status']}'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 2️⃣ SHOP DETAILS
          const Text(
            'Shop details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Shop: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Flexible(
                child: Text(
                  shop?['shop_name'] ?? '-',
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ✅ VERIFIED TICK
              if (shop?['is_verified'] == true)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Image.asset(
                    'assets/verified_tick.png',
                    height: 16,
                    width: 16,
                  ),
                ),
            ],
          ),

          // 📍 LOCATION (SMART DISPLAY)
          if (shop?['sell_type'] == 'online')
            _infoRow('Location', 'Online shop')
          else
            _infoRow('Location', shop?['quartiers']?['name'] ?? '-'),

          const SizedBox(height: 24),

          // 3️⃣ PRODUCT DETAILS (FROM ORDERS)
          const Text(
            'Product details',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _infoRow('Name', product?['name'] ?? '-'),
          _infoRow('Quantity', o['quantity'].toString()),
          _infoRow('Price', '${formatPrice(o['subtotal'])} BIF'),
          _infoRow('Size', o['size'] ?? '-'),
          _infoRow('Condition', o['condition'] ?? '-'),
          _infoRow('Category', o['subcategory'] ?? '-'),

          const SizedBox(height: 24),

          // 4️⃣ DELIVERY / PICKUP
          const Text(
            'Delivery / Pickup',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 🟠 PICKUP AT BUJA FASTA SUBTITLE
          if (o['delivery_type'] == 'pickup')
            const Text(
              "Pickup at Buja Fasta pickup",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),

          // 🏪 PICKUP AT SELLER SHOP SUBTITLE
          if (shop?['sell_type'] == 'physical' &&
              o['delivery_type'] == 'seller_pickup')
            const Text(
              "Pickup at seller's shop",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),

          // 🚚 DELIVERY BY BUJA FASTA
          if (o['delivery_type'] == 'delivery') ...[
            Row(
              children: const [
                Text(
                  'Delivery by Buja Fasta',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 6),
                Icon(Icons.delivery_dining, size: 18),
              ],
            ),

            const SizedBox(height: 8),

            _infoRow('Delivery fee', '${formatPrice(o['delivery_fee'])} BIF'),
          ],

          // 🗺 ROUTE (KEEP AS IS)
          // 🗺 ROUTE (HUMAN-FRIENDLY)
          // 🗺 ROUTE (CORRECT LOGIC)
          if (shop?['sell_type'] == 'physical' &&
              o['delivery_type'] == 'seller_pickup') ...[
            _infoRow(
              'Route',
              '${o['origin_label'] ?? ''}, ${o['origin_address'] ?? ''}',
            ),
          ] else if (shop?['sell_type'] == 'online' &&
              o['delivery_type'] != 'delivery') ...[
            _infoRow('Route', 'Buja Fasta'),
          ] else ...[
            _infoRow(
              'Route',
              '${o['origin_label'] ?? ''} → ${o['destination_label'] ?? ''}',
            ),
          ],

          // 📍 SHIPPING ADDRESS (ONLY FOR DELIVERY)
          if (o['delivery_type'] == 'delivery' &&
              o['destination_address'] != null)
            _shippingAddressRow(
              context,
              'Shipping address',
              '${o['destination_label']} - ${o['destination_address']}',
            ),

          // 🗓 PICKUP DAY (ONLY FOR PICKUP)
          if (o['delivery_type'] != 'delivery' && o['pickup_day'] != null)
            _infoRow('Pickup day', o['pickup_day']),

          const SizedBox(height: 16),

          // 💰 FEES
          const Text(
            'Fees',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          _infoRow('Protection fee', '${formatPrice(o['protection_fee'])} BIF'),

          const SizedBox(height: 24),

          // 🧾 DELIVERY TOTAL
          const Divider(),
          _infoRow('Total', '${formatPrice(o['amount'])} BIF'),
          const Divider(),
          const SizedBox(height: 24),

          // ✅ Decide if buyer can confirm received
          if (canConfirmReceived)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmReceived,
                child: const Text('Confirm Received'),
              ),
            ),

          if (_canCancelOrder(o))
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _cancelOrder,
                child: const Text('Cancel Order'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _shippingAddressRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Shipping address'),
                        content: Text(value),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text(
                    'Read more',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String formatPrice(dynamic value) {
    if (value == null) return '0';

    final number = double.tryParse(value.toString());
    if (number == null) return value.toString();

    final intValue = number.toInt();

    return intValue.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }
}
