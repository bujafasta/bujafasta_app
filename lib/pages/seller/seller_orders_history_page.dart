import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/pages/seller/seller_orders_page.dart';

class SellerOrdersHistoryPage extends StatefulWidget {
  const SellerOrdersHistoryPage({super.key});

  @override
  State<SellerOrdersHistoryPage> createState() =>
      _SellerOrdersHistoryPageState();
}

class _SellerOrdersHistoryPageState extends State<SellerOrdersHistoryPage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => loading = true);

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final res = await supabase
        .from('orders')
        .select('id, subtotal, status, created_at, products(name, image_urls)')
        .eq('seller_id', user.id)
        .inFilter('status', ['completed', 'rejected', 'cancelled', 'expired'])
        .order('created_at', ascending: false);

    setState(() {
      orders = List<Map<String, dynamic>>.from(res);
      loading = false;
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'accepted':
        return Colors.blue;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.black;
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
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SellerOrdersPage(),
                        ),
                      );
                    },
                    child: const Text('Pending'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: null, // already on History
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
          ? const Center(child: Text('No order history'))
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final product = order['products'];

                return Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: Builder(
                      builder: (_) {
                        final images = product?['image_urls'] as List<dynamic>?;

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

                    title: Text(product?['name'] ?? 'Product'),
                    subtitle: Text('Earnings: ${order['subtotal']}'),

                    trailing: Text(
                      order['status'],
                      style: TextStyle(
                        color: _statusColor(order['status']),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
