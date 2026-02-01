import 'package:flutter/material.dart';
import 'package:bujafasta_app/pages/my_shop.dart';

class MyShopPublicPage extends StatelessWidget {
  final String shopId;
  final String sellerId;

  const MyShopPublicPage({
    super.key,
    required this.shopId,
    required this.sellerId,
  });

  @override
  Widget build(BuildContext context) {
    return MyShopPage(
      readOnly: true, // 👈 buyer mode
      shopId: shopId, // 👈 IMPORTANT
    );
  }
}
