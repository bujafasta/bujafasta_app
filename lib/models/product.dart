import 'dart:typed_data';

class Product {
  final Map<String, dynamic> raw; // 👈 ADD THIS
  final int? id;
  final String? ownerId; // 👈 ADDED
  final String name;
  final String price;
  final String category;
  final String? subcategory;
  final String? subcategory2;
  final String? subcategory3; // 👈 ADD THIS
  final String condition;
  final List<String> sizes;
  final int stock; // 👈 ADD THIS
  final String? color; // 👈 ADD THIS
  final String? details;
  final Uint8List? imageBytes;
  final String shopId;

  // OLD (keep temporarily if other pages still use it)
  final String? imageUrl;

  // NEW — multiple images
  final List<String> imageUrls;

  final String? status; // 👈 OPTIONAL: helps admin panel
  final String? rejectReason; // 👈 OPTIONAL: helps admin panel
  final bool isSold; // 👈 SOLD STATUS
  final bool isHidden; // 👈 HIDDEN STATUS
  final bool isDeleted; // 👈 SOFT DELETE

  Product({
    required this.raw, // 🔥 ADD THIS (FIRST)
    this.id,
    this.ownerId,
    required this.name,
    required this.price,
    required this.category,
    this.subcategory,
    this.subcategory2,
    this.subcategory3, // 👈 NEW
    required this.condition,
    this.sizes = const [],
    this.stock = 0, // 👈 ADD THIS (SAFE DEFAULT)
    this.color, // 👈 ADD THIS
    this.details,
    this.imageBytes,
    this.imageUrl, // keep for backward compatibility
    this.imageUrls = const [], // 👈 IMPORTANT
    this.status,
    this.rejectReason,
    this.isSold = false, // 👈 ADD THIS
    this.isHidden = false, // 👈 HIDDEN (DEFAULT FALSE)
    this.isDeleted = false, // 👈 DEFAULT
    required this.shopId,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      raw: map, // 🔥 THIS WAS MISSING
      id: map['id'] as int?,
      ownerId: map['owner_id']?.toString(), // 👈 ADDED
      name: map['name']?.toString() ?? '',
      price: map['price']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      subcategory: map['subcategory']?.toString(),
      subcategory2: map['subcategory2']?.toString(),
      subcategory3: map['subcategory3']?.toString(), // 👈 NEW
      condition: map['condition']?.toString() ?? '',
      sizes: map['sizes'] != null ? List<String>.from(map['sizes']) : [],
      details: map['details']?.toString(),
      imageUrl: (map['image_urls'] is List && map['image_urls'].isNotEmpty)
          ? map['image_urls'][0].toString()
          : map['image_url']?.toString(),

      imageUrls: map['image_urls'] != null
          ? List<String>.from(map['image_urls'])
          : [],

      stock: map['stock'] ?? 0, // 👈 ADD THIS
      color: map['color']?.toString(), // 👈 PASTE IT HERE ✅

      status: map['status']?.toString(), // 👈 ADDED
      rejectReason: map['reject_reason']?.toString(), // 👈 ADDED
      isSold: map['is_sold'] == true, // 👈 ADD THIS
      isHidden: map['is_hidden'] == true, // 👈 ADD THIS
      isDeleted: map['is_deleted'] == true, // 👈 ADD THIS
      shopId: map['shop_id']?.toString() ?? '',

      imageBytes: null,
    );
  }
}
