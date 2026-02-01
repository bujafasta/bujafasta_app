import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminOrderDetailsPage extends StatefulWidget {
  final String orderId;

  const AdminOrderDetailsPage({super.key, required this.orderId});

  @override
  State<AdminOrderDetailsPage> createState() => _AdminOrderDetailsPageState();
}

class _AdminOrderDetailsPageState extends State<AdminOrderDetailsPage> {
  bool _isPhysicalShop(Map<String, dynamic>? shop) {
    return shop?['sell_type'] == 'physical';
  }

  bool _isDelivery(Map<String, dynamic> o) {
    return o['delivery_type'] == 'delivery';
  }

  bool _isPickup(Map<String, dynamic> o) {
    return o['delivery_type'] == 'pickup';
  }

  bool _isSellerPickup(Map<String, dynamic> o) {
    return o['delivery_type'] == 'seller_pickup';
  }

  final supabase = Supabase.instance.client;

  bool _loading = true;
  Map<String, dynamic>? _order;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  // ============================================
  // LOAD FULL ORDER DETAILS (ADMIN)
  // ============================================
  Future<void> _loadOrderDetails() async {
    try {
      final res = await supabase
          .from('orders')
          .select('''
            id,
status,
is_delivery_confirmed,
created_at,
amount,
subtotal,
quantity,
size,
condition,
subcategory,


            delivery_type,
            delivery_fee,
            pickup_fee,
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
              quartier_id,
              quartiers ( name )
            )
          ''')
          .eq('id', widget.orderId)
          .maybeSingle();

      _order = res;
    } catch (e) {
      debugPrint('ADMIN ORDER DETAILS ERROR: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _confirmDelivery(bool confirm) async {
    try {
      await supabase.rpc(
        'admin_confirm_delivery',
        params: {'p_order_id': widget.orderId, 'p_confirm': confirm},
      );

      // 🔄 Reload order after update
      await _loadOrderDetails();

      if (mounted) {
        final type = _order?['delivery_type'];

        String actionLabel;
        if (type == 'pickup') {
          actionLabel = 'Pickup';
        } else {
          actionLabel = 'Delivery';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              confirm
                  ? '$actionLabel confirmed successfully'
                  : '$actionLabel rejected',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('ADMIN CONFIRM DELIVERY ERROR: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update delivery status')),
        );
      }
    }
  }

  // ============================================
  // DELIVERY LABEL
  // ============================================
  String _deliveryLabel(String? type) {
    switch (type) {
      case 'delivery':
        return 'Delivery by Buja Fasta';
      case 'pickup':
        return 'Pickup at Buja Fasta';
      case 'seller_pickup':
        return 'Pickup at seller shop';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
          ? const Center(child: Text('Order not found'))
          : _buildDetails(),
    );
  }

  // ============================================
  // MAIN UI
  // ============================================
  Widget _buildDetails() {
    final o = _order!;
    final product = o['products'];
    final buyer = o['buyer'];
    final seller = o['seller'];
    final shop = o['shops'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(o['created_at'].toString()),
            style: TextStyle(fontSize: 12, color: Colors.grey.withOpacity(0.6)),
          ),
          const SizedBox(height: 8),

          _sectionTitle('Product details'),
          _productCard(product, o),

          const SizedBox(height: 24),
          _sectionTitle('Buyer details'),
          _info('Name', '${buyer?['first_name']} ${buyer?['last_name']}'),
          _info('Phone', buyer?['phone']),
          _info('Email', buyer?['email']),
          // BUYER ADDRESS (INLINE + READ MORE)
          if (_isDelivery(o))
            _infoRowWithReadMoreInline(
              context,
              'Address',
              '${o['destination_label']} ${o['destination_address']}',
            )
          else
            _info('Address', '-'),

          const SizedBox(height: 24),
          _sectionTitle('Seller & shop details'),
          _info('Shop name', shop?['shop_name']),
          _info('Sell type', shop?['sell_type']),
          // SHOP LOCATION — ALWAYS SELLER ADDRESS FOR PHYSICAL SHOPS
          if (_isPhysicalShop(shop))
            _infoWithReadMore('Shop location', _buildSellerFullAddress(o))
          else
            _info('Shop location', 'Online shop'),

          _info(
            'Seller name',
            '${seller?['first_name']} ${seller?['last_name']}',
          ),
          _info('Seller phone', seller?['phone']),
          _info('Seller email', seller?['email']),

          const SizedBox(height: 24),
          _sectionTitle('Delivery / Pickup'),

          // 🚚 DELIVERY SUBTITLE
          if (_isDelivery(o))
            const Text(
              'Delivery by Buja Fasta',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),

          // 🏪 SELLER PICKUP SUBTITLE
          if (_isSellerPickup(o))
            const Text(
              "Pickup on seller's shop",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),

          // 📍 BUJA FASTA PICKUP SUBTITLE
          if (_isPickup(o))
            const Text(
              'Pickup at Buja Fasta',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),

          const SizedBox(height: 6),

          _info('Type', _deliveryLabel(o['delivery_type'])),

          // PICKUP DAY (for pickup types)
          if (!_isDelivery(o) && o['pickup_day'] != null)
            _info('Pickup day', o['pickup_day']),

          // ROUTE DISPLAY
          if (_isDelivery(o))
            _infoWithReadMore(
              'Route',
              '${o['origin_label']} ${o['origin_address']} → '
                  '${o['destination_label']} ${o['destination_address']}',
            )
          else
            _infoWithReadMore(
              'Route',
              _isSellerPickup(o)
                  ? '${o['origin_label']} ${o['origin_address']}'
                  : 'Buja Fasta',
            ),

          const SizedBox(height: 24),
          _sectionTitle('Fees'),

          if (_isDelivery(o))
            _info('Delivery fee', '${formatPrice(o['delivery_fee'])} BIF'),

          if (!_isDelivery(o))
            _info('Pickup fee', '${formatPrice(o['pickup_fee'])} BIF'),

          _info('Protection fee', '${formatPrice(o['protection_fee'])} BIF'),

          const Divider(),
          _info('Total', '${formatPrice(o['amount'])} BIF'),

          const Divider(),
          const SizedBox(height: 16),
          _info('Order ID', o['id']),
          // ============================================
          // 🚚 BUJA FASTA DELIVERY DECISION (ADMIN)
          // ============================================
          if (o['status'] == 'accepted' &&
              (o['delivery_type'] == 'delivery' ||
                  o['delivery_type'] == 'pickup') &&
              o['is_delivery_confirmed'] == false)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),

                  const Text(
                    'Buja Fasta delivery decision',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      // ❌ REJECT DELIVERY
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _confirmDelivery(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Text('Reject delivery'),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // ✅ CONFIRM DELIVERY
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _confirmDelivery(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Confirm delivery'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    final date = DateTime.parse(raw).toLocal();

    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String formatPrice(dynamic value) {
    if (value == null) return '0';

    final number = double.tryParse(value.toString());
    if (number == null) return value.toString();

    final intValue = number.toInt();

    // add thousand separators manually
    return intValue.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }

  // ============================================
  // SMALL UI HELPERS
  // ============================================
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _info(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _infoWithReadMore(String label, String value, {int maxChars = 40}) {
    if (value.isEmpty) return const SizedBox();

    final isLong = value.length > maxChars;
    final shortText = isLong ? '${value.substring(0, maxChars)}...' : value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: GestureDetector(
              onTap: isLong
                  ? () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(label),
                          content: Text(value),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    }
                  : null,
              child: Text(
                shortText,
                style: TextStyle(
                  decoration: isLong
                      ? TextDecoration.underline
                      : TextDecoration.none,
                  color: isLong ? Colors.blue : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRowWithReadMoreInline(
    BuildContext context,
    String label,
    String value,
  ) {
    if (value.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120, // keeps alignment consistent
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
                        title: Text(label),
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

  /// 👇👇👇 ADD THIS RIGHT HERE
  String _buildSellerFullAddress(Map<String, dynamic> o) {
    final label = o['origin_label']?.toString().trim();
    final address = o['origin_address']?.toString().trim();

    if (label != null && address != null && address.isNotEmpty) {
      return '$label, $address';
    }

    if (label != null) {
      return label;
    }

    return 'Unknown seller location';
  }

  Widget _productCard(Map<String, dynamic>? product, Map<String, dynamic> o) {
    final images = product?['image_urls'] as List<dynamic>?;

    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundImage: images != null && images.isNotEmpty
              ? NetworkImage(images.first)
              : null,
          child: images == null || images.isEmpty
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
              Text(
                '${formatPrice(o['subtotal'])} BIF',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),

              Text('Quantity: ${o['quantity']}'),

              Text('Size: ${o['size'] ?? '-'}'),
              Text('Condition: ${o['condition'] ?? '-'}'),
              Text('Category: ${o['subcategory'] ?? '-'}'),
            ],
          ),
        ),
      ],
    );
  }
}
