import 'package:flutter/material.dart';
import 'package:bujafasta_app/models/product.dart';
import 'package:bujafasta_app/pages/checkout/checkout_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';

class BuyNowHandler {
  static Future<void> start({
    required BuildContext context,
    required int productId,
    int? offerId,

    // ✅ ADD THESE
    required String shopId,
    required String sellerId,
  }) async {
    // 1️⃣ Show loading spinner immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    // ⏳ Small delay so user FEELS feedback (UX trick)
    await Future.delayed(const Duration(milliseconds: 600));

    // 2️⃣ Close spinner
    Navigator.of(context).pop();

    // 3️⃣ Open bottom sheet
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 👈 VERY IMPORTANT
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return _BuyNowBottomSheet(
          productId: productId,
          offerId: offerId,
          shopId: shopId,
          sellerId: sellerId,
        );
      },
    );
  }
}

class _BuyNowBottomSheet extends StatefulWidget {
  final int productId;
  final int? offerId;
  final String shopId;
  final String sellerId;

  const _BuyNowBottomSheet({
    required this.productId,
    this.offerId,
    required this.shopId,
    required this.sellerId,
  });

  @override
  State<_BuyNowBottomSheet> createState() => _BuyNowBottomSheetState();
}

class _BuyNowBottomSheetState extends State<_BuyNowBottomSheet> {
  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  int qty = 1;
  int selectedImageIndex = 0;
  String? selectedSize;
  Product? product;
  bool loadingProduct = true;

  Future<void> _loadProduct() async {
    final res = await Supabase.instance.client
        .from('products')
        .select('''
        id,
        name,
        price,
        stock,
        image_urls,
        sizes,
        color
      ''')
        .eq('id', widget.productId)
        .single();

    setState(() {
      product = Product.fromMap(res);
      loadingProduct = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loadingProduct) {
      return const Center(child: CircularProgressIndicator());
    }
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Product image (single for now)
            AspectRatio(
              aspectRatio: 1.4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: product!.imageUrls.isNotEmpty
                    ? PageView.builder(
                        itemCount: product!.imageUrls.length,
                        onPageChanged: (i) {
                          setState(() => selectedImageIndex = i);
                        },
                        itemBuilder: (_, i) {
                          return CachedNetworkImage(
                            imageUrl: product!.imageUrls[i],
                            fit: BoxFit.cover,
                            placeholder: (context, _) =>
                                Container(color: Colors.grey[200]),
                            errorWidget: (context, _, __) => Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(color: Colors.grey[300]),
              ),
            ),

            const SizedBox(height: 10),

            // ── Product name
            Text(
              product!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 4),

            // ── Product price
            if (widget.offerId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "OFFER",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            Text(
              widget.offerId != null
                  ? "Offer price will be applied at checkout"
                  : "${product!.price} BIF",
              style: TextStyle(
                fontSize: widget.offerId != null ? 11 : 16,
                fontWeight: FontWeight.w600,
                color: widget.offerId != null
                    ? Colors.grey.shade600
                    : Colors.black,
              ),
            ),

            Text(
              "Only ${product!.stock} left",
              style: TextStyle(
                fontSize: 10, // 👈 VERY SMALL
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 14),

            // ── Size / Color title
            if (product!.sizes.isNotEmpty) ...[
              const Text(
                "Size",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: product!.sizes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final size = product!.sizes[index];
                    final isSelected = size == selectedSize;

                    return GestureDetector(
                      onTap: () {
                        setState(() => selectedSize = size);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFAA05) // ORANGE ✅
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          size,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            if (product!.color != null && product!.color!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  "Color: ${product!.color}",
                  style: TextStyle(
                    fontSize: 11, // 👈 SMALL & CLEAN
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ── Quantity
            Row(
              children: [
                const Text(
                  "Qty",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  onPressed: qty > 1 ? () => setState(() => qty--) : null,
                  icon: const Icon(Icons.remove),
                ),

                Text(qty.toString(), style: const TextStyle(fontSize: 14)),

                IconButton(
                  onPressed: qty < product!.stock
                      ? () => setState(() => qty++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Text(
              "Buja Fasta applies a small protection fee on every purchase",
              style: TextStyle(
                fontSize: 10, // 👈 VERY SMALL
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 8),

            // ── Continue button (FIXED bottom) with stock check
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: product!.stock > 0
                    ? () {
                        // 1️⃣ Validate size selection
                        if (product!.sizes.isNotEmpty && selectedSize == null) {
                          Fluttertoast.showToast(
                            msg: "Please select a size",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.black87,
                            textColor: Colors.white,
                            fontSize: 14,
                          );

                          return;
                        }

                        // 2️⃣ Close bottom sheet
                        Navigator.of(context).pop();

                        // 3️⃣ Navigate to checkout page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CheckoutPage(
                              product: product!,
                              initialQty: qty,
                              size: selectedSize,
                              color: product!.color,
                              offerId: widget.offerId,
                              // ✅ PASS IDS
                              sellerId: widget.sellerId,
                              shopId: widget.shopId,
                            ),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFAA05),
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Continue",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
