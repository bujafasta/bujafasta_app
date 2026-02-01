import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:bujafasta_app/models/product.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:reorderables/reorderables.dart';

const Color kPrimaryOrange = Color(0xFFFF9800);
const Color kDarkBlack = Color(0xFF121212);
const Color kSoftGrey = Color(0xFFE0E0E0);
const Color kBorderGrey = Color(0xFFBDBDBD);

// Add this top-level variable so `supabase` is defined in this file.
final supabase = Supabase.instance.client;

class ImagePopupItem extends StatelessWidget {
  Widget _iconFallback() {
    return Container(
      width: 100,
      height: 100,
      color: Colors.grey[200],
      child: Icon(
        iconFallbacks[label] ?? Icons.category,
        size: 40,
        color: Colors.grey,
      ),
    );
  }

  final String label;
  final String imagePath;
  final VoidCallback onTap;
  final Map<String, IconData> iconFallbacks;

  const ImagePopupItem({
    super.key,
    required this.label,
    required this.imagePath,
    required this.onTap,
    required this.iconFallbacks,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imagePath.isNotEmpty
                  ? (imagePath.startsWith('http')
                        ? Image.network(
                            imagePath,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,

                            // 👇 SHOW FALLBACK WHILE LOADING
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child; // ✅ image fully loaded
                              }
                              return _iconFallback(); // ⏳ still loading → show fallback
                            },

                            // ❌ IF IMAGE FAILS
                            errorBuilder: (_, __, ___) => _iconFallback(),
                          )
                        : Image.asset(
                            imagePath,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _iconFallback(),
                          ))
                  : _iconFallback(), // ✅ THIS LINE WAS MISSING
            ),

            const SizedBox(width: 20),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 18))),
          ],
        ),
      ),
    );
  }
}

class MultiSelectSizePopup extends StatefulWidget {
  final List<String> sizes;
  final List<String> initialSelection;
  final Function(List<String>) onConfirm;

  const MultiSelectSizePopup({
    super.key,
    required this.sizes,
    required this.initialSelection,
    required this.onConfirm,
  });

  @override
  State<MultiSelectSizePopup> createState() => _MultiSelectSizePopupState();
}

class SingleSelectSizePopup extends StatefulWidget {
  final List<String> sizes;
  final String? selected;
  final Function(String) onConfirm;

  const SingleSelectSizePopup({
    super.key,
    required this.sizes,
    required this.selected,
    required this.onConfirm,
  });

  @override
  State<SingleSelectSizePopup> createState() => _SingleSelectSizePopupState();
}

class _SingleSelectSizePopupState extends State<SingleSelectSizePopup> {
  String? selectedSize;

  @override
  void initState() {
    super.initState();
    selectedSize = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select size',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              children: widget.sizes.map((size) {
                return RadioListTile<String>(
                  value: size,
                  groupValue: selectedSize,
                  activeColor: kPrimaryOrange,
                  title: Text(size),
                  onChanged: (v) {
                    setState(() => selectedSize = v);
                  },
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: selectedSize == null
                    ? null
                    : () {
                        widget.onConfirm(selectedSize!);
                        Navigator.pop(context);
                      },
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SingleSelectColorPopup extends StatefulWidget {
  final List<Map<String, Color>> colors;
  final String? selected;
  final Function(String) onConfirm;

  const SingleSelectColorPopup({
    super.key,
    required this.colors,
    required this.selected,
    required this.onConfirm,
  });

  @override
  State<SingleSelectColorPopup> createState() => _SingleSelectColorPopupState();
}

class _SingleSelectColorPopupState extends State<SingleSelectColorPopup> {
  String? selectedColor;
  String query = '';

  @override
  void initState() {
    super.initState();
    selectedColor = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.colors.where((c) {
      final name = c.keys.first.toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🔍 Search
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search color',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),

          const Divider(height: 1),

          // 🎨 Single-select list
          Flexible(
            child: ListView(
              children: filtered.map((colorMap) {
                final name = colorMap.keys.first;
                final color = colorMap.values.first;

                return RadioListTile<String>(
                  value: name,
                  groupValue: selectedColor,
                  onChanged: (v) {
                    setState(() => selectedColor = v);
                  },
                  title: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(name),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // ✅ OK
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: selectedColor == null
                  ? null
                  : () {
                      widget.onConfirm(selectedColor!);
                      Navigator.pop(context);
                    },
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiSelectSizePopupState extends State<MultiSelectSizePopup> {
  late Set<String> selectedSizes;

  @override
  void initState() {
    super.initState();
    selectedSizes = Set.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            // 🔹 HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Sizes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  // ❌ Close
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 🔹 SIZE LIST (SCROLLABLE, SAFE)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: widget.sizes.map((size) {
                  return CheckboxListTile(
                    title: Text(size),
                    value: selectedSizes.contains(size),
                    activeColor: kPrimaryOrange,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          selectedSizes.add(size);
                        } else {
                          selectedSizes.remove(size);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),

            const Divider(height: 1),

            // 🔹 MODERN OK BUTTON
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    widget.onConfirm(selectedSizes.toList());
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.white, fontSize: 16),
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

class AddItemPage extends StatefulWidget {
  final void Function(Product product) onPost;
  const AddItemPage({super.key, required this.onPost});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  bool _isLiquidProduct() {
    return _subcategory?.toLowerCase().contains('perfume') == true ||
        _subcategory?.toLowerCase().contains('care') == true;
  }

  // ✅ TEMP: Only these 8 category images are allowed to be local
  // All of them live directly inside assets/
  final Map<String, String> categoryImageMap = {
    'Fashion': 'assets/fashion.webp',
    'Beauty & Health': 'assets/beauty_&_health.webp',
    'Bags & Travel bags': 'assets/bags_&_travel_bags.webp',
    'Phones': 'assets/phones.webp',
    'Phone accessories': 'assets/phone_accessories.webp',
    'Music listening accessories': 'assets/headphones.webp',
    'Sportswear & Equipment': 'assets/sportswear_&_equipment.webp',
    'Computers & Tablets': 'assets/computers_&_tablets.webp',
  };

  // ✅ Built-in ICON fallbacks for Fashion subcategories
  // These are used when NO local image & NO backend image
  final Map<String, IconData> subcategoryIconMap = {
    'Women': Icons.woman,
    'Men': Icons.man,
  };

  final Map<String, String> subcategoryImageMap = {
    // LEVEL 1 WOMEN
    'Women': 'assets/women.jpg',
    'Men': 'assets/men.jpg',

    // 👩 WOMEN – SUBCATEGORY 2 (LOCAL IMAGES)
    'Tops for women': 'assets/tops_for_women.jpg',
    'Bottoms for women': 'assets/bottoms_for_women.jpg',
    'Dresses & Jumpsuits': 'assets/dresses.jpg',
    'Handbags for women': 'assets/handbags.jpg',
    'Complete sets for women': 'assets/complete_sets_for_women.jpg',
    'Shoes for women': 'assets/shoes_for_women.jpg',
    'Jewelry for women': 'assets/jewelry_for_women.jpg',
    'Accessories for women': 'assets/accessories_for_women.jpg',
    'Suits for women': 'assets/suits_for_women.jpg',
    'Underwear for women': 'assets/underwear_for_women.jpg',
    'Head & hair accessories for women':
        'assets/head_and_hair_accessories_for_women.jpg',
    'Watches for women': 'assets/watches_for_women.jpg',

    // 👚 WOMEN – TOPS (SUBCATEGORY 3)
    'Vests': 'assets/vest_for_women.jpg',
    'T-Shirts': 'assets/t_shirt_for_women.jpg',
    'Shirts': 'assets/shirt_for_women.jpg',
    'Hoodies': 'assets/hoodies_for_women.jpg',
    'Crop Tops': 'assets/crop_tops.jpg',

    // 👖 WOMEN – BOTTOMS (SUBCATEGORY 3)
    'Jeans': 'assets/jeans_for_women.jpg',
    'Shorts': 'assets/shorts_for_women.jpg',
    'Skirts': 'assets/skirts_for_women.jpg',
    'Leggings': 'assets/leggings_for_women.jpg',
    'Trousers': 'assets/trousers_for_women.jpg',

    // 👗 WOMEN - DRESSES AND JUMPSUITS
    'Jumpsuits': 'assets/jumpsuits.jpg',
    'Evening Dresses': 'assets/evening_dresses.jpg',
    'Casual Dresses': 'assets/casual_dresses.jpg',

    // 👜 WOMEN - HAND BAG
    'Handbags': 'assets/handbags_for_women.jpg',
    'Clutches': 'assets/clutches_for_women.jpg',
    'Backpacks': 'assets/backpacks_for_women.jpg',

    // 👠 WOMEN - FOOTWEAR
    'Sandals': 'assets/sandals_for_women.jpg',
    'Heels': 'assets/heels_for_women.jpg',
    'Flip Flops': 'assets/flip_flops_for_women.jpg',
    'Sneakers': 'assets/sneakers_for_women.jpg',

    // 👩 WOMEN - JEWELRY
    'Anklets': 'assets/anklet_for_women.jpg',
    'Bracelets': 'assets/bracelet_for_women.jpg',
    'Brooch Pins': 'assets/brooch_pin_for_women.jpg',
    'Earrings': 'assets/earrings_for_women.jpg',
    'Necklaces': 'assets/necklace_for_women.jpg',
    'Nose Jewelry': 'assets/nose_jewery_for_women.jpg',
    'Rings': 'assets/rings_for_women.jpg',
    'Toe Rings': 'assets/toe_ring_for_women.jpg',
    'Waist Chains': 'assets/waist_chain_for_women.jpg',

    // 👒 WOMEN - ACCESSORIES
    'Sunglasses': 'assets/sunglasses_for_women.jpg',
    'Belts': 'assets/belts_for_women.jpg',
    'Gloves': 'assets/gloves_for_women.jpg',
    'Scarves': 'assets/scarves_for_women.jpg',

    // 👔 WOMEN - SUITS
    'Skirt Suits': 'assets/skirt_suit_for_women.jpg',
    'Trouser Suits': 'assets/trouser_suit_for_women.jpg',

    // 👙 WOMEN - UNDERWEAR
    'Bras': 'assets/bras_for_women.jpg',
    'Panties': 'assets/panties_for_women.jpg',
    'Lingerie Set': 'assets/lingerie_set_for_women.jpg',

    // 👒 WOMEN - HAIR ACCESSORIES
    'Caps': 'assets/caps_for_women.jpg',
    'Hair Accessories': 'assets/hair_accessories_for_women.jpg',

    // ⌚ WOMEN - WATCHES
    'Analog Watches': 'assets/analog_watch_for_women.jpg',
    'Digital Watches': 'assets/digital_watch_for_women.jpg',
    'Smart Watches': 'assets/smart_watch_for_women.jpg',

    //................................... MEN

    // 👨 MEN – TOPS (SUBCATEGORY 3)
    'Men Shirts': 'assets/shirt_for_men.jpg',
    'Men T-Shirts': 'assets/t_shirt_for_men.jpg',
    'Men Vests': 'assets/vest_for_men.jpg',
    'Men Singlets': 'assets/singlets_for_men.jpg',
    'Men Hoodies': 'assets/hoodies_for_men.jpg',

    // 👨 MEN – BOTTOMS (SUBCATEGORY 3)
    'Men Jeans': 'assets/jeans_for_men.jpg',
    'Men Trousers': 'assets/trousers_for_men.jpg',
    'Men Shorts': 'assets/shorts_for_men.jpg',

    // 👨 MEN – FOOTWEAR (SUBCATEGORY 3)
    'Sandals (Men)': 'assets/sandals_for_men.jpg',
    'Sneakers (Men)': 'assets/sneakers_for_men.jpg',
    'Formal Shoes': 'assets/formal_shoes_for_men.jpg',
    'Flip Flops (Men)': 'assets/flip_flops_for_men.jpg',

    // 👨 MEN – ACCESSORIES (SUBCATEGORY 3)
    'Men Belts': 'assets/belts_for_men.jpg',
    'Men Caps': 'assets/caps_for_men.jpg',
    'Men Scarves': 'assets/scarves_for_men.jpg',
    'Men Sunglasses': 'assets/sunglasses_for_men.jpg',
    'Men Socks': 'assets/socks_for_men.jpg',

    // 👨 MEN – JEWELRY (SUBCATEGORY 3)
    'Men Necklaces': 'assets/necklace_for_men.jpg',
    'Men Bracelets': 'assets/bracelet_for_men.jpg',
    'Men Rings': 'assets/rings_for_men.jpg',

    // 👨 MEN – UNDERWEAR (SUBCATEGORY 3)
    'Men Boxers': 'assets/boxers_for_men.jpg',
    'Men Singlets': 'assets/singlet_for_men.jpg',

    // 👨 MEN – SUBCATEGORY 2 (LOCAL IMAGES)
    'Tops for men': 'assets/tops_for_men.jpg',
    'Bottoms for men': 'assets/bottoms_for_men.jpg',
    'Shoes for men': 'assets/shoes_for_men.jpg',
    'Complete sets for men': 'assets/complete_sets_for_men.jpg',
    'Suits for men': 'assets/suits_for_men.jpg',
    'Watches for men': 'assets/watches_for_men.jpg',
    'Accessories for men': 'assets/accessories_for_men.jpg',
    'Jewelry for men': 'assets/jewelry_for_men.jpg',
    'Underwear for men': 'assets/underwear_for_men.jpg',

    // 💄 BEAUTY & HEALTH
    'Perfumes': 'assets/perfumes.jpg',
    'Body care': 'assets/body_care.jpg',
    'Face care': 'assets/face_care.jpg',
    'Nail care': 'assets/nail_care.jpg',
    'Hair care': 'assets/hair_care.jpg',
    'Makeup': 'assets/makeup.jpg',
    'Hand care': 'assets/hand_care.jpg',

    // 📱 PHONES – BRAND LOGOS
    'Apple (iPhone)': 'assets/apple_(iphone).jpg',
    'Samsung': 'assets/samsung.jpg',
    'Google (Pixel)': 'assets/google_(pixel).jpg',
    'Infinix': 'assets/infinix.jpg',
    'Tecno': 'assets/tecno.jpg',
    'Oppo': 'assets/oppo.jpg',
    'Huawei': 'assets/huawei.jpg',
    'Nokia': 'assets/nokia.jpg',
    'Sony (Xperia)': 'assets/sony_(xperia).jpg',
    'Itel': 'assets/itel.jpg',
    'Xiaomi': 'assets/xiaomi.jpg',
    'Vivo': 'assets/vivo.jpg',
    'Sharp': 'assets/sharp.jpg',
    'Realme': 'assets/realme.jpg',
    'OnePlus': 'assets/oneplus.jpg',
    'Motorola': 'assets/motorola.jpg',
    'Honor': 'assets/honor.jpg',
    'ZTE': 'assets/zte.jpg',
    'LG': 'assets/lg.jpg',
    'HTC': 'assets/htc.jpg',
    'Nothing': 'assets/nothing.jpg',
    'Wiko': 'assets/wiko.jpg',
    'Hisense': 'assets/hisense.jpg',
    'Lava': 'assets/lava.jpg',
    'Alcatel': 'assets/alcatel.jpg',
    'BlackBerry': 'assets/blackberry.jpg',

    // 🔌 PHONE ACCESSORIES – IMAGES
    'Phone Cases': 'assets/phone_cases.jpg',
    'Chargers': 'assets/chargers.jpg',
    'Power Banks': 'assets/power_banks.jpg',
    'Bluetooth Earbuds': 'assets/bluetooth_earbuds.jpg',

    // 🏀 SPORTS – IMAGES
    'Clothing': 'assets/clothing.jpg',
    'Footwear': 'assets/footwear.jpg',
    'Equipment': 'assets/equipment.jpg',

    // 🎧 MUSIC – IMAGES
    'AirPods': 'assets/bluetooth_earbuds.jpg',
    'Headphones': 'assets/headphones.jpg',
    'Bluetooth Speaker': 'assets/bluetooth_speaker.jpg',

    // 💻 COMPUTERS & TABLETS – IMAGES
    'Desktop': 'assets/desktop.jpg',
    'Laptop': 'assets/laptop.jpg',
    'Tablet': 'assets/tablet.jpg',

    // 🧳 BAGS & TRAVEL BAGS – IMAGES
    'Bag': 'assets/bag.jpg',
    'Travel bag': 'assets/travel_bag.jpg',
  };

  final GlobalKey _subcategoryKey = GlobalKey();
  final GlobalKey _subcategory2Key = GlobalKey();
  final GlobalKey _subcategory3Key = GlobalKey();
  final GlobalKey _sizeKey = GlobalKey();
  final GlobalKey _conditionKey = GlobalKey(); // 👈 ADD THIS

  final ScrollController _scrollController = ScrollController();
  bool niaAiEnabled = false; // 👈 Nia AI switch (UI only for now)
  GlobalKey? _highlightKey; // 👈 which section is glowing

  final _formKey = GlobalKey<FormState>();
  String? _category;
  String? _subcategory;
  String? _subcategory2;
  String? _subcategory3;
  String? _condition;
  List<String> _sizes = [];
  String? _details;
  String? _name;
  String? _price;
  bool _isUploading = false;

  String? _shopId;
  // ❌ Validation error flags (ONLY set on submit)
  bool _submitAttempted = false;

  bool _imageError = false;
  bool _categoryError = false;
  bool _subcategoryError = false;
  bool _subcategory2Error = false;
  bool _subcategory3Error = false;
  bool _conditionError = false;
  bool _detailsError = false;
  bool _nameError = false;
  bool _priceError = false;
  bool _showRequiredMessage = false;

  int stock = 1;
  final TextEditingController _stockController = TextEditingController(
    text: '1',
  );

  String? selectedColor;

  InputDecoration modernInput(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black87),
      prefixIcon: icon != null ? Icon(icon, color: Colors.black54) : null,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderGrey, width: 2),
      ),
    );
  }

  Widget sectionCard({
    required Widget child,
    GlobalKey? sectionKey,
    bool hasError = false,
  }) {
    final bool isHighlighted =
        sectionKey != null && sectionKey == _highlightKey;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasError
            ? Colors.red.withOpacity(0.05)
            : isHighlighted
            ? kPrimaryOrange.withOpacity(0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError
              ? Colors.red
              : isHighlighted
              ? kPrimaryOrange
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    _stockController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadNiaAiState();
  }

  // 🤖 Scroll smartly to a section
  void _niaScrollToKey(GlobalKey key) {
    if (!niaAiEnabled) return;

    Future.delayed(const Duration(milliseconds: 250), () {
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          alignment: 0.15,
        );
      }
    });
  }

  void _scrollToFirstError() {
    if (_imageError) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
      return;
    }

    if (_categoryError) {
      _niaScrollToKey(_subcategoryKey);
      return;
    }

    if (_subcategoryError) {
      _niaScrollToKey(_subcategoryKey);
      return;
    }

    if (_subcategory2Error) {
      _niaScrollToKey(_subcategory2Key);
      return;
    }

    if (_subcategory3Error) {
      _niaScrollToKey(_subcategory3Key);
      return;
    }

    if (_conditionError) {
      _niaScrollToKey(_conditionKey);
      return;
    }
  }

  // ✨ Soft highlight a section
  void _highlightSection(GlobalKey key) {
    if (!niaAiEnabled) return;

    setState(() {
      _highlightKey = key;
    });

    // Remove highlight after 1 second
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _highlightKey = null;
        });
      }
    });
  }

  Future<void> _loadNiaAiState() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final profile = await supabase
        .from('profiles')
        .select('nia_is_active')
        .eq('id', user.id)
        .maybeSingle();

    if (profile != null && mounted) {
      setState(() {
        niaAiEnabled = profile['nia_is_active'] ?? false;
      });
    }
  }

  void _openNiaAiMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 🧠 Nia AI logo + text
                  Row(
                    children: [
                      Image.asset('assets/nia_ai.png', width: 40, height: 40),
                      const SizedBox(width: 12),
                      const Text(
                        'Nia BETA',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // 🔘 Switch (NOW REACTS INSTANTLY)
                  Switch(
                    value: niaAiEnabled,
                    onChanged: (value) async {
                      // 🔁 Update bottom sheet UI instantly
                      setModalState(() {
                        niaAiEnabled = value;
                      });

                      // 🔁 Update parent page state
                      setState(() {
                        niaAiEnabled = value;
                      });

                      // 🗄️ Save to database
                      final user = supabase.auth.currentUser;
                      if (user != null) {
                        await supabase
                            .from('profiles')
                            .update({'nia_is_active': value})
                            .eq('id', user.id);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openPreview(int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) {
          final PageController controller = PageController(
            initialPage: initialIndex,
          );

          int currentIndex = initialIndex;
          double dragY = 0;

          return StatefulBuilder(
            builder: (context, setPreviewState) {
              final double opacity = (1 - (dragY.abs() / 300)).clamp(0.3, 1.0);

              return Scaffold(
                backgroundColor: Colors.black.withOpacity(opacity),
                body: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    setPreviewState(() {
                      dragY += details.delta.dy;
                    });
                  },
                  onVerticalDragEnd: (details) {
                    if (dragY.abs() > 120) {
                      Navigator.pop(context); // 👈 swipe UP or DOWN closes
                    } else {
                      // Snap back
                      setPreviewState(() {
                        dragY = 0;
                      });
                    }
                  },
                  child: Stack(
                    children: [
                      Transform.translate(
                        offset: Offset(0, dragY),
                        child: PageView.builder(
                          controller: controller,
                          itemCount: _images.length,
                          onPageChanged: (i) {
                            setPreviewState(() {
                              currentIndex = i;
                              dragY = 0;
                            });
                          },
                          itemBuilder: (_, i) {
                            return Center(
                              child: InteractiveViewer(
                                child: Image.file(
                                  File(_images[i].path),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // ❌ Delete
                      Positioned(
                        top: 40,
                        right: 20,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _images.removeAt(currentIndex);
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),

                      // ✖ Close
                      Positioned(
                        top: 40,
                        left: 20,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // Image picker variables
  final ImagePicker _picker = ImagePicker();
  List<XFile> _images = [];

  final List<String> categories = [
    'Fashion',
    'Beauty & Health',
    'Bags & Travel bags',
    'Phones',
    'Phone accessories',
    'Computers & Tablets',
    'Music listening accessories',
    'Sportswear & Equipment',
  ];

  final Map<String, List<String>> subcategories = {
    // 👗 FASHION (NEW STRUCTURE)
    'Fashion': ['Women', 'Men'],

    // 💄 BEAUTY
    'Beauty & Health': [
      'Perfumes',
      'Body care',
      'Face care',
      'Nail care',
      'Hair care',
      'Makeup',
      'Hand care',
      'Other',
    ],

    // 🧳 BAGS
    'Bags & Travel bags': ['Bag', 'Travel bag'],

    // 📱 PHONES (FULL ORIGINAL LIST — NOTHING REMOVED)
    'Phones': [
      'Apple (iPhone)',
      'Samsung',
      'Google (Pixel)',
      'Infinix',
      'Tecno',
      'Oppo',
      'Huawei',
      'Nokia',
      'Sony (Xperia)',
      'Itel',
      'Xiaomi',
      'Vivo',
      'Sharp',
      'Realme',
      'OnePlus',
      'Motorola',
      'Honor',
      'ZTE',
      'LG',
      'HTC',
      'Nothing',
      'Wiko',
      'Hisense',
      'Lava',
      'Alcatel',
      'BlackBerry',
    ],

    // 🔌 PHONE ACCESSORIES (SIMPLIFIED)
    'Phone accessories': [
      'Phone Cases',
      'Chargers',
      'Power Banks',
      'Bluetooth Earbuds',
    ],

    // 💻 COMPUTERS
    'Computers & Tablets': ['Laptop', 'Desktop', 'Tablet'],

    // 🎧 MUSIC (SIMPLIFIED)
    'Music listening accessories': [
      'AirPods',
      'Headphones',
      'Bluetooth Speaker',
    ],

    // 🏀 SPORTS
    'Sportswear & Equipment': ['Clothing', 'Footwear', 'Equipment', 'Others'],
  };

  final List<String> conditions = ['New', 'Like new'];

  // ================= SIZE GROUPS =================

  // Letter sizes
  final List<String> clothingLetterSizes = [
    'XXS',
    'XS',
    'S',
    'M',
    'L',
    'XL',
    '2XL',
    '3XL',
    '4XL',
  ];

  // Numeric clothing sizes (after XL)
  final List<String> clothingNumberSizes = [
    '2',
    '2.5',
    '3',
    '3.5',
    '4',
    '4.5',
    '5',
    '5.5',
    '6',
    '6.5',
    '7',
    '7.5',
    '8',
    '8.5',
    '9',
    '9.5',
    '10',
    '10.5',
    '11',
    '11.5',
    '12',
    '12.5',
    '13',
    '13.5',
    '14',
    '14.5',
    '15',
    '15.5',
    '16',
    '16.5',
    '17',
    '17.5',
    '18',
    '18.5',
    '19',
    '19.5',
    '20',
  ];

  // Shoe sizes (numbers ONLY, no XL)
  final List<String> shoeSizes = [
    '36',
    '36.5',
    '37',
    '37.5',
    '38',
    '38.5',
    '39',
    '39.5',
    '40',
    '40.5',
    '41',
    '41.5',
    '42',
    '42.5',
    '43',
    '43.5',
    '44',
    '44.5',
    '45',
    '45.5',
    '46',
    '46.5',
    '47',
    '47.5',
    '48',
  ];

  // Liquid sizes
  final List<String> liquidSizes = [
    '5mL',
    '10mL',
    '15mL',
    '20mL',
    '25mL',
    '30mL',
    '40mL',
    '50mL',
    '60mL',
    '70mL',
    '80mL',
    '90mL',
    '100mL',
    '120mL',
    '150mL',
    '180mL',
    '200mL',
    '250mL',
    '300mL',
    '330mL',
    '350mL',
    '400mL',
    '450mL',
    '500mL',
    '600mL',
    '650mL',
    '700mL',
    '750mL',
    '800mL',
    '900mL',
    '1L',
    '1.25L',
    '1.5L',
    '1.75L',
    '2L',
  ];

  List<String> getAvailableSizes() {
    // 🧥 CLOTHING (tops, bottoms, sports clothing)
    final bool isClothing =
        // 👕 NORMAL CLOTHING
        _subcategory2?.toLowerCase().contains('tops') == true ||
        _subcategory2?.toLowerCase().contains('bottoms') == true ||
        _subcategory2?.toLowerCase().contains('clothing') == true ||
        // 👚 COMPLETE SETS (IMPORTANT FIX)
        _subcategory2 == 'Complete sets for women' ||
        _subcategory2 == 'Complete sets for men' ||
        // 👕 SUBCATEGORY 3 BASED CLOTHING
        (_subcategory3 != null &&
            [
              'shirts',
              't-shirts',
              'crop tops',
              'vests',
              'hoodies',
              'jeans',
              'trousers',
              'skirts',
              'shorts',
              'leggings',
              'jersey',
              'sports vest',
            ].contains(_subcategory3!.toLowerCase()));

    if (isClothing) {
      return [...clothingLetterSizes, ...clothingNumberSizes];
    }

    // 👟 SHOES
    final bool isShoes =
        _subcategory2?.toLowerCase().contains('shoes') == true ||
        _subcategory3 != null &&
            [
              'sandals',
              'sneakers',
              'heels',
              'formal shoes',
              'flip flops',
              'running shoes',
              'football boots',
              'basketball shoes',
            ].contains(_subcategory3!.toLowerCase());

    if (isShoes) {
      // 👟 ADULT SHOES
      return shoeSizes;
    }

    // 🧴 LIQUIDS (perfumes, body care)
    final bool isLiquid =
        _subcategory?.toLowerCase().contains('perfume') == true ||
        _subcategory?.toLowerCase().contains('care') == true;

    if (isLiquid) {
      return liquidSizes;
    }

    // 🚫 NO SIZE (phones, electronics, accessories)
    return [];
  }

  // ======================================================
  // SINGLE SOURCE OF TRUTH FOR SUBCATEGORY 3
  // ======================================================
  //
  // This function decides:
  // - Should Subcategory 3 be SHOWN?
  // - Should Subcategory 3 be REQUIRED?
  //
  // UI and validation MUST BOTH use this
  //
  bool _needsSubcategory3() {
    // If user hasn’t selected enough levels → no subcategory 3
    if (_subcategory == null || _subcategory2 == null) {
      return false;
    }

    // Get possible subcategory 3 list
    final List<String> sub3List =
        subcategories2[_subcategory!]?[_subcategory2!] ?? [];

    // If there is NO list → no subcategory 3
    if (sub3List.isEmpty) {
      return false;
    }

    // These subcategory2 values NEVER require subcategory 3
    const excludedSubcategory2 = {
      'Complete sets for women',
      'Complete sets for men',
      'Suits for men',
      'Watches for men',
      'Watches for women',
    };

    // If this subcategory2 is excluded → no subcategory 3
    if (excludedSubcategory2.contains(_subcategory2)) {
      return false;
    }

    // Otherwise → YES, subcategory 3 exists and is required
    return true;
  }

  final Map<String, Map<String, List<String>>> subcategories2 = {
    'Women': {
      // 1️⃣ Tops
      'Tops for women': [
        'Shirts',
        'T-Shirts',
        'Crop Tops',
        'Vests',
        'Hoodies',
        'Others',
      ],

      // 2️⃣ Bottoms
      'Bottoms for women': [
        'Jeans',
        'Trousers',
        'Skirts',
        'Shorts',
        'Leggings',
        'Other',
      ],

      // 3️⃣ Dresses & Jumpsuits (AS YOU REQUESTED)
      'Dresses & Jumpsuits': ['Evening Dresses', 'Casual Dresses', 'Jumpsuits'],

      // 4️⃣ Handbags
      'Handbags for women': ['Handbags', 'Clutches', 'Backpacks', 'Other'],

      // 5️⃣ Complete sets
      'Complete sets for women': [
        'Two-piece sets',
        'Three-piece sets',
        'Matching sets',
        'Other',
      ],

      // 6️⃣ Shoes
      'Shoes for women': [
        'Sandals',
        'Sneakers',
        'Heels',
        'Flip Flops',
        'Other',
      ],

      // 7️⃣ Jewelry
      'Jewelry for women': [
        'Necklaces',
        'Earrings',
        'Bracelets',
        'Rings',
        'Anklets',
        'Brooch Pins',
        'Nose Jewelry',
        'Toe Rings',
        'Waist Chains',
        'Others',
      ],

      // 8️⃣ Accessories
      'Accessories for women': [
        'Belts',
        'Scarves',
        'Sunglasses',
        'Gloves',
        'Other',
      ],

      // 9️⃣ Suits
      'Suits for women': ['Trouser Suits', 'Skirt Suits', 'Other'],

      // 🔟 Underwear
      'Underwear for women': ['Panties', 'Bras', 'Lingerie Set', 'Other'],

      // 1️⃣1️⃣ Head & hair
      'Head & hair accessories for women': [
        'Caps',
        'Hair Accessories',
        'Other',
      ],

      // 1️⃣2️⃣ Watches
      'Watches for women': [
        'Analog Watches',
        'Digital Watches',
        'Smart Watches',
        'Other',
      ],
    },

    'Men': {
      // 👕 Tops
      'Tops for men': [
        'Men Shirts',
        'Men T-Shirts',
        'Men Vests',
        'Men Singlets',
        'Men Hoodies',
        'Other',
      ],

      // 👖 Bottoms
      'Bottoms for men': ['Men Jeans', 'Men Trousers', 'Men Shorts', 'Other'],

      // 👞 Shoes
      'Shoes for men': [
        'Sandals (Men)',
        'Sneakers (Men)',
        'Formal Shoes',
        'Flip Flops (Men)',
        'Other',
      ],

      // 🧥 Suits
      'Suits for men': ['Trouser Suits', 'Other'],

      // 🧢 Complete sets
      'Complete sets for men': [
        'Two-piece sets',
        'Three-piece sets',
        'Matching sets',
        'Other',
      ],

      // ⌚ Watches
      'Watches for men': [
        'Men Analog Watches',
        'Men Digital Watches',
        'Men Smart Watches',
        'Other',
      ],

      // 🧣 Accessories
      'Accessories for men': [
        'Men Belts',
        'Men Caps',
        'Men Scarves',
        'Men Sunglasses',
        'Men Socks',
        'Other',
      ],

      // 💍 Jewelry
      'Jewelry for men': [
        'Men Necklaces',
        'Men Bracelets',
        'Men Rings',
        'Other',
      ],

      // 👕 Underwear
      'Underwear for men': ['Men Boxers', 'Men Singlets', 'Other'],
    },

    'Sportswear & Equipment': {
      'Clothing': [
        'Jersey',
        'Jersey Sets',
        'Sports Vest',
        'Leggings',
        'Socks',
        'Track Jacket',
        'Others',
      ],
      'Footwear': [
        'Running shoes',
        'Football boots',
        'Basketball shoes',
        'Socks',
        'Other',
      ],
      'Equipment': [
        'Football',
        'Basketballs',
        'Tennis rackets',
        'Boxing gloves',
        'Goalkeeper gloves',
        'Swim goggles & caps',
        'Cycling helmets & gloves',
        'Badminton sets',
        'Other',
      ],
    },
  };

  Future<void> pickImages() async {
    if (_images.length >= 6) return;

    final List<XFile>? picked = await _picker.pickMultiImage();

    if (picked == null) return;

    setState(() {
      final remaining = 6 - _images.length;
      _images.addAll(picked.take(remaining));

      // ✅ CLEAR IMAGE ERROR WHEN IMAGE IS ADDED
      if (_images.isNotEmpty) {
        _imageError = false;
      }
    });
  }

  void _showImageSelectionPopup(
    BuildContext context,
    List<String> items,
    String title,
    Function(String) onSelect,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: items.map((item) {
                        return ImagePopupItem(
                          label: item,
                          imagePath:
                              subcategoryImageMap[item] ??
                              categoryImageMap[item] ??
                              '',

                          iconFallbacks: subcategoryIconMap,
                          onTap: () {
                            onSelect(item);
                            Navigator.of(context).pop();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSizeSelectionPopup(BuildContext context) {
    final sizes = getAvailableSizes();

    if (_isLiquidProduct()) {
      // 🧴 LIQUID → SINGLE SIZE ONLY
      showDialog(
        context: context,
        builder: (_) => SingleSelectSizePopup(
          sizes: sizes,
          selected: _sizes.isNotEmpty ? _sizes.first : null,
          onConfirm: (selected) {
            setState(() {
              _sizes = [selected]; // 👈 FORCE SINGLE VALUE
            });
          },
        ),
      );
    } else {
      // 👕 👟 CLOTHES / SHOES → MULTI SIZE
      showDialog(
        context: context,
        builder: (_) => MultiSelectSizePopup(
          sizes: sizes,
          initialSelection: _sizes,
          onConfirm: (selected) {
            setState(() {
              _sizes = selected;
            });
          },
        ),
      );
    }
  }

  Future<void> _uploadProduct(Product product) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw 'Not logged in';

    // 1️⃣ Get seller's shop id
    final shop = await supabase
        .from('shops')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (shop == null) throw 'Shop not found';

    // 2️⃣ UPLOAD IMAGES TO STORAGE
    List<String> imageUrls = [];

    for (int i = 0; i < _images.length; i++) {
      final XFile image = _images[i];

      // Unique file path
      final String filePath =
          '${shop['id']}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

      // Upload image
      await supabase.storage
          .from('products')
          .upload(
            filePath,
            File(image.path),
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      // Get public URL
      final String publicUrl = supabase.storage
          .from('products')
          .getPublicUrl(filePath);

      imageUrls.add(publicUrl);
    }

    // 3️⃣ INSERT PRODUCT WITH IMAGE URLS
    await supabase.from('products').insert({
      'owner_id': user.id,
      'shop_id': shop['id'],
      'name': product.name,
      'price': product.price,
      'category': product.category,
      'subcategory': product.subcategory ?? '',
      'subcategory2': product.subcategory2 ?? '',
      'subcategory3': _subcategory3,
      'condition': product.condition,
      'details': product.details,
      'image_urls': imageUrls, // ✅ FIXED
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
      'stock': stock,
      'sizes': _sizes,
    });
  }

  void _submit() async {
    if (_isUploading) return;

    FocusScope.of(context).unfocus();

    // ✅ IMMEDIATE UI RESPONSE
    setState(() {
      _isUploading = true;
      _submitAttempted = true;
    });

    try {
      // 🔴 VALIDATION ONLY (NO SETSTATE)
      _imageError = _images.isEmpty;
      _categoryError = _category == null;
      // Subcategory is required ONLY if category has subcategories
      _subcategoryError =
          _category != null &&
          (subcategories[_category!] ?? []).isNotEmpty &&
          _subcategory == null;

      // Subcategory 2 is required ONLY if it exists for selected subcategory
      _subcategory2Error =
          _subcategory != null &&
          (subcategories2[_subcategory!] ?? {}).isNotEmpty &&
          _subcategory2 == null;

      // Subcategory 3 validation uses SAME logic as UI
      _subcategory3Error = _needsSubcategory3() && _subcategory3 == null;

      _conditionError = _condition == null;
      _detailsError = _details == null || _details!.isEmpty;
      _nameError = _name == null || _name!.isEmpty;
      _priceError = _price == null || _price!.isEmpty;

      if (_imageError ||
          _categoryError ||
          _subcategoryError ||
          _subcategory2Error ||
          _subcategory3Error ||
          _conditionError ||
          _detailsError ||
          _nameError ||
          _priceError ||
          !_formKey.currentState!.validate()) {
        setState(() {
          _isUploading = false;
          _showRequiredMessage = true;
        });

        // 🔥 AUTO SCROLL TO FIRST ERROR (SAFE)
        _scrollToFirstError();

        return;
      }

      final user = supabase.auth.currentUser;
      if (user == null) throw 'Not logged in';

      final shop = await supabase
          .from('shops')
          .select('id')
          .eq('owner_id', user.id)
          .maybeSingle();

      if (shop == null) throw 'Shop not found';

      final product = Product(
        raw: const {},
        name: _name!,
        price: _price!,
        category: _category!,
        subcategory: _subcategory,
        subcategory2: _subcategory2,
        subcategory3: _subcategory3,
        condition: _condition!,
        details: _details!,
        shopId: shop['id'],
      );

      await _uploadProduct(product);

      widget.onPost(product);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Product uploaded successfully')),
      );

      setState(() {
        _images.clear();

        _category = null;
        _subcategory = null;
        _subcategory2 = null;
        _subcategory3 = null;

        _condition = null;
        _sizes.clear();
        selectedColor = null;

        _details = null;
        _name = null;
        _price = null;

        // 🔴 RESET ERROR FLAGS
        _imageError = false;
        _categoryError = false;
        _subcategoryError = false;
        _subcategory2Error = false;
        _subcategory3Error = false;
        _conditionError = false;
        _detailsError = false;
        _nameError = false;
        _priceError = false;

        _submitAttempted = false;

        stock = 1;
        _stockController.text = '1';
      });

      // 🔑 IMPORTANT: reset Form fields
      _formKey.currentState?.reset();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Upload failed. Try again'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Make this page a standalone Scaffold so it works as an IndexedStack child.
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController, // 👈 ADD THIS LINE
          padding: const EdgeInsets.only(
            bottom: 80,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Item',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: kDarkBlack,
                      ),
                    ),

                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: _openNiaAiMenu, // 👈 OPEN NIA AI MENU
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                sectionCard(
                  hasError: _submitAttempted && _imageError,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Product Images (max 6) *",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: kDarkBlack,
                        ),
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        height: 100,
                        child: ReorderableRow(
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }

                              final item = _images.removeAt(oldIndex);
                              _images.insert(newIndex, item);
                            });
                          },
                          children: [
                            for (int i = 0; i < _images.length; i++)
                              Container(
                                key: ValueKey(_images[i].path),
                                margin: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () => _openPreview(i),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          image: DecorationImage(
                                            image: FileImage(
                                              File(_images[i].path),
                                            ),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),

                                      // ❌ DELETE BUTTON
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _images.removeAt(i);

                                              if (_images.isEmpty &&
                                                  _submitAttempted) {
                                                _imageError = true;
                                              }
                                            });
                                          },
                                          child: const CircleAvatar(
                                            radius: 12,
                                            backgroundColor: Colors.black54,
                                            child: Icon(
                                              Icons.close,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // ⭐ COVER LABEL
                                      if (i == 0)
                                        Positioned(
                                          bottom: 4,
                                          left: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: kPrimaryOrange,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Cover',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                            // ➕ ADD IMAGE BUTTON (NOT DRAGGABLE)
                            if (_images.length < 6)
                              Container(
                                key: const ValueKey('add_image'),
                                child: GestureDetector(
                                  onTap: pickImages,
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: kPrimaryOrange),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: kPrimaryOrange,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      if (_submitAttempted && _imageError)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Upload at least one image',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16), // 👈 THIS IS THE CORRECT PLACE

                sectionCard(
                  child: TextField(
                    controller: _stockController, // 👈 CONNECT CONTROLLER
                    keyboardType: TextInputType.number,
                    onChanged: (v) => stock = int.tryParse(v) ?? 1,
                    decoration: modernInput('Stock', icon: Icons.inventory),
                  ),
                ),

                const SizedBox(height: 12),

                sectionCard(
                  hasError: _submitAttempted && _categoryError,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Category *',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showImageSelectionPopup(
                          context,
                          categories,
                          'Select Category',
                          (value) => setState(() {
                            _category = value;
                            _categoryError = false; // 👈 ADD THIS
                            _subcategory = null;
                            _subcategory2 = null;
                            _subcategory3 = null;
                            _sizes.clear();

                            // 🤖 NIA AI: guide to next step
                            if (niaAiEnabled) {
                              Future.delayed(
                                const Duration(milliseconds: 300),
                                () {
                                  _niaScrollToKey(_subcategoryKey);
                                  _highlightSection(_subcategoryKey);
                                },
                              );
                            }
                          }),
                        ),
                        child: InputDecorator(
                          decoration: modernInput('Select category'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _category ?? 'Select category',
                                  style: TextStyle(
                                    color: _category == null
                                        ? Colors.grey
                                        : Colors.black,
                                  ),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 🔹 Subcategory (LEVEL 1)
                if (_category != null)
                  Container(
                    key: _subcategoryKey,
                    child: sectionCard(
                      sectionKey: _subcategoryKey,
                      hasError: _submitAttempted && _subcategoryError,

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Subcategory',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _showImageSelectionPopup(
                              context,
                              subcategories[_category!] ?? [],
                              'Select Subcategory',
                              (value) => setState(() {
                                _subcategory = value;
                                _subcategoryError = false; // 👈 ADD THIS
                                _subcategory2 = null;
                                _subcategory3 = null;
                                _sizes.clear();

                                // 🤖 Nia AI → move to Subcategory 2
                                if (niaAiEnabled) {
                                  _niaScrollToKey(_subcategory2Key);
                                  _highlightSection(_subcategory2Key);
                                }
                              }),
                            ),
                            child: InputDecorator(
                              decoration: modernInput('Select subcategory'),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _subcategory ?? 'Select subcategory',
                                      style: TextStyle(
                                        color: _subcategory == null
                                            ? Colors.grey
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Show Subcategory 2 only when we have options for the
                // selected category + subcategory (collapses otherwise).
                if (_subcategory != null &&
                    (subcategories2[_subcategory!] ?? {}).isNotEmpty)
                  Container(
                    key: _subcategory2Key,
                    child: sectionCard(
                      sectionKey: _subcategory2Key,
                      hasError: _submitAttempted && _subcategory2Error,

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Subcategory 2',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _showImageSelectionPopup(
                              context,
                              subcategories2[_subcategory!]!.keys.toList(),
                              'Select Subcategory 2',
                              (value) => setState(() {
                                _subcategory2 = value;
                                _subcategory2Error = false; // 👈 ADD THIS
                                _subcategory3 = null;
                                _sizes.clear();

                                // 🤖 NIA AI FLOW CONTROL
                                final hasSub3 =
                                    (subcategories2[_subcategory!]?[_subcategory2!] ??
                                            [])
                                        .isNotEmpty &&
                                    _subcategory2 !=
                                        'Complete sets for women' &&
                                    _subcategory2 != 'Complete sets for men' &&
                                    _subcategory2 != 'Suits for men';

                                if (niaAiEnabled) {
                                  if (hasSub3) {
                                    _niaScrollToKey(_subcategory3Key);
                                    _highlightSection(_subcategory3Key);
                                  } else {
                                    // 👈 NO SUBCATEGORY 3 → GO TO CONDITION
                                    _niaScrollToKey(_conditionKey);
                                    _highlightSection(_conditionKey);
                                  }
                                }
                              }),
                            ),
                            child: InputDecorator(
                              decoration: modernInput('Select subcategory'),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _subcategory2 ?? 'Select subcategory',
                                      style: TextStyle(
                                        color: _subcategory2 == null
                                            ? Colors.grey
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ), // ✅ closes sectionCard
                  ), // ✅ closes Container
                // 🔹 Subcategory 3 (e.g. Jeans, Trousers, Shirts)
                // 🔹 Subcategory 3 (e.g. Jeans, Trousers, Shirts)
                if (_needsSubcategory3())
                  sectionCard(
                    sectionKey: _subcategory3Key,
                    hasError: _submitAttempted && _subcategory3Error,

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Subcategory 3',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showImageSelectionPopup(
                            context,
                            subcategories2[_subcategory!]![_subcategory2!]!,
                            'Select type',
                            (value) => setState(() {
                              _subcategory3 = value;
                              _subcategory3Error = false; // 👈 ADD THIS
                              _sizes.clear(); // 👈 VERY IMPORTANT
                              if (niaAiEnabled) {
                                _niaScrollToKey(_conditionKey);
                                _highlightSection(_conditionKey);
                              }
                            }),
                          ),
                          child: InputDecorator(
                            decoration: modernInput('Select type'),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _subcategory3 ?? 'Select type',
                                    style: TextStyle(
                                      color: _subcategory3 == null
                                          ? Colors.grey
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                sectionCard(
                  sectionKey: _conditionKey,
                  hasError: _submitAttempted && _conditionError,

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Condition *',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _condition,
                        items: conditions
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _condition = v;
                            _conditionError = false;
                          });

                          if (niaAiEnabled && getAvailableSizes().isNotEmpty) {
                            _niaScrollToKey(_sizeKey);
                            _highlightSection(_sizeKey);
                          }
                        },

                        decoration: modernInput('Select condition'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                if (getAvailableSizes().isNotEmpty)
                  sectionCard(
                    sectionKey: _sizeKey,

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Size (optional)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showSizeSelectionPopup(context),
                          child: InputDecorator(
                            decoration: modernInput('Select size'),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _sizes.isEmpty
                                        ? (_isLiquidProduct()
                                              ? 'Select size'
                                              : 'Select size(s)')
                                        : _sizes.join(', '),

                                    style: TextStyle(
                                      color: _sizes.isEmpty
                                          ? Colors.grey
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),

                sectionCard(
                  hasError: _submitAttempted && _detailsError,

                  child: TextFormField(
                    decoration: modernInput('Details'),
                    maxLines: 3,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter details' : null,
                    onChanged: (v) {
                      _details = v;
                      if (v.isNotEmpty) {
                        setState(() => _detailsError = false);
                      }
                    },
                  ),
                ),

                const SizedBox(height: 10),

                sectionCard(
                  hasError: _submitAttempted && _nameError,

                  child: TextFormField(
                    decoration: modernInput('Name'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter product name' : null,
                    onChanged: (v) {
                      _name = v;
                      if (v.isNotEmpty) {
                        setState(() => _nameError = false);
                      }
                    },
                  ),
                ),

                const SizedBox(height: 10),

                sectionCard(
                  hasError: _submitAttempted && _priceError,

                  child: TextFormField(
                    decoration: modernInput('Price'),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter price' : null,
                    onChanged: (v) {
                      _price = v;
                      if (v.isNotEmpty) {
                        setState(() => _priceError = false);
                      }
                    },
                  ),
                ),

                if (_submitAttempted && _showRequiredMessage)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Please fill all required fields (*)',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _isUploading ? null : _submit,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryOrange,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: _isUploading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        )
                      : const Text(
                          'Post',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
