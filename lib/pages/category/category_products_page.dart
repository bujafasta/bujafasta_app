import 'package:flutter/material.dart';
import 'package:bujafasta_app/models/product.dart';
import 'package:bujafasta_app/pages/product/product_details_page.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class CategoryProductsPage extends StatelessWidget {
  final String title;
  final String subcategory; // e.g. women
  final String subcategory2; // e.g. Tops
  final List<Product> allProducts;

  const CategoryProductsPage({
    super.key,
    required this.title,
    required this.subcategory,
    required this.subcategory2,
    required this.allProducts,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ SAFE FILTER
    final products = allProducts.where((p) {
      final sub = (p.subcategory ?? '').toLowerCase();
      final sub2 = (p.subcategory2 ?? '').toLowerCase();

      return sub == subcategory.toLowerCase() &&
          sub2 == subcategory2.toLowerCase();
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: products.isEmpty
          ? const Center(
              child: Text(
                'No products found',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: MasonryGridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 8,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final item = products[index];

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
                            height: [180.0, 220.0, 260.0][index % 3],

                            width: double.infinity,
                            child: item.imageUrls.isNotEmpty
                                ? Image.network(
                                    item.imageUrls.first,
                                    fit: BoxFit.cover,
                                  )
                                : Container(color: Colors.grey[200]),
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
                          item.price,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
