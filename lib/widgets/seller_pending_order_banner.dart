import 'package:flutter/material.dart';
import 'package:bujafasta_app/pages/seller/seller_orders_page.dart';

class SellerPendingOrderBanner extends StatelessWidget {
  const SellerPendingOrderBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: const Color(0xFFFFAA07), // deep orange
      child: InkWell(
        onTap: () {
          // 👉 Go to seller orders page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SellerOrdersPage(),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: const [
              Icon(Icons.shopping_bag, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You have a new order, tap here to complete it',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
