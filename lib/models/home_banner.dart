class HomeBanner {
  final int id;
  final String imageUrl;
  final int productId;

  HomeBanner({
    required this.id,
    required this.imageUrl,
    required this.productId,
  });

  factory HomeBanner.fromMap(Map<String, dynamic> map) {
    return HomeBanner(
      id: map['id'],
      imageUrl: map['image_url'],
      productId: map['product_id'] as int,
    );
  }
}
