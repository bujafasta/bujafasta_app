import 'package:flutter/material.dart';
import 'package:bujafasta_app/models/product.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';


class CheckoutPage extends StatefulWidget {
  final Product product;
  final int initialQty;
  final String? size;
  final String? color;
  final int? offerId; // 👈 ADD THIS
  // ✅ ADD THESE
  final String sellerId;
  final String shopId;

  const CheckoutPage({
    super.key,
    required this.product,
    required this.initialQty,
    this.size,
    this.color, //let, new order params titl
    this.offerId, // 👈 ADD THIS
    // ✅ REQUIRED NOW
    required this.sellerId,
    required this.shopId,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class ProvinceItem {
  final String id;
  final String name;

  ProvinceItem({required this.id, required this.name});
}

class _CheckoutPageState extends State<CheckoutPage> {
  void _resetCheckoutForm() {
    // 🧹 Clear text inputs
    firstNameCtrl.clear();
    lastNameCtrl.clear();
    emailCtrl.clear();
    phoneCtrl.clear();
    addressCtrl.clear();

    // 🔄 Reset selections
    deliveryType = null;
    selectedProvince = null;
    selectedQuartierId = null;
    selectedQuartierName = null;
    pickupDay = null;

    // 🔢 Reset quantity & totals
    qty = widget.initialQty;
    backendSubtotal = 0;
    backendDeliveryFee = 0;
    backendProtectionFee = 0;
    backendTotal = 0;

    // 🔁 Reset lists
    provinces.clear();
    quartiersFromBackend.clear();
  }

  void _showOrderSuccessSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isDismissible: false, // user must choose an action
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ ICON
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 40,
                  color: Colors.green,
                ),
              ),

              const SizedBox(height: 12),

              // 🎉 TITLE
              const Text(
                "Order placed successfully!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 6),

              // 📝 MESSAGE
              const Text(
                "Your order has been reserved and is now waiting for confirmation.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),

              const SizedBox(height: 20),

             

              // 👉 CONTINUE SHOPPING (ONLY ACTION)
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFAA05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); // close bottom sheet
                    Navigator.pop(context); // go back to Home
                  },
                  child: const Text(
                    "Continue shopping on Buja Fasta",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 📝 INFO MESSAGE
              const Text(
                "Your order is now waiting for the seller to confirm it.\n"
                "You can check your order status by going to your profile page, then My Orders.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _smallGreySpinner() {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
      ),
    );
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 14,
    );
  }

  bool submittingOrder = false;

  // 🔒 TEMP: hide seller pickup (future feature)
  final bool showSellerPickup = false;

  // ─── Text controllers (so we can autofill)
  final firstNameCtrl = TextEditingController();
  final lastNameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController(); // 👈 FULL ADDRESS
  bool shopIsOnline = false;
  bool loadingShopType = true;
  bool _validateBeforeOrder() {
    // 🚫 DELIVERY TYPE MUST BE SELECTED
    if (deliveryType == null) {
      _showToast('Please choose delivery or pickup');
      return false;
    }

    // 👤 BASIC INFO (ALWAYS REQUIRED)
    if (firstNameCtrl.text.trim().isEmpty) {
      _showToast('Please enter your first name');
      return false;
    }

    if (lastNameCtrl.text.trim().isEmpty) {
      _showToast('Please enter your last name');
      return false;
    }

    if (phoneCtrl.text.trim().isEmpty) {
      _showToast('Please enter your phone number');
      return false;
    }

    // 📦 DELIVERY RULES
    if (deliveryType == 'delivery') {
      if (selectedProvince == null) {
        _showToast('Please select a province');
        return false;
      }

      if (selectedQuartierId == null) {
        _showToast('Please select a quartier');
        return false;
      }

      if (addressCtrl.text.trim().length < 5) {
        _showToast('Full address must be at least 5 characters');
        return false;
      }
    }

    // 🏠 PICKUP RULES
    if (deliveryType == 'pickup' || deliveryType == 'seller_pickup') {
      if (pickupDay == null) {
        _showToast('Please select a pickup day');
        return false;
      }
    }

    // 💰 TOTAL MUST BE CALCULATED
    if (backendTotal <= 0) {
      _showToast('Please complete delivery or pickup details');
      return false;
    }

    return true; // ✅ ALL GOOD
  }

  // ─── Country code dropdown
  String selectedCountryCode = '+257'; // default Burundi

  late int qty;
  late String sellerId;
  late String shopId;

  int backendSubtotal = 0;
  int backendDeliveryFee = 0;
  int backendProtectionFee = 0;
  int backendTotal = 0;
  bool loadingBackendTotals = false;

  String? deliveryType; // null until user selects
  String? selectedQuartierId;
  String? selectedQuartierName;

  // ─── Provinces (from backend)
  // ─── Provinces
  List<ProvinceItem> provinces = [];
  ProvinceItem? selectedProvince;
  bool loadingProvinces = false;

  // ─── Quartiers (from backend)
  List<Map<String, dynamic>> quartiersFromBackend = [];
  bool loadingQuartiers = false;

  String? pickupDay; // null = no selection (placeholder)
  @override
  void initState() {
    super.initState();

    qty = widget.initialQty;
    sellerId = widget.sellerId;
    shopId = widget.shopId;

    _loadProfile(); // will auto-fill if logged in
    _loadShopType();
  }

  Future<void> _loadShopType() async {
    final supabase = Supabase.instance.client;

    final shop = await supabase
        .from('shops')
        .select('sell_type')
        .eq('id', shopId)
        .maybeSingle();

    if (shop != null && shop['sell_type'] == 'online') {
      shopIsOnline = true;
    }

    setState(() {
      loadingShopType = false;
    });
  }

  Future<void> _loadProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    final profile = await supabase
        .from('profiles')
        .select('first_name, last_name, country_code, phone, email')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) return;

    setState(() {
      firstNameCtrl.text = profile['first_name'] ?? '';
      lastNameCtrl.text = profile['last_name'] ?? '';
      emailCtrl.text = profile['email'] ?? '';
      phoneCtrl.text = profile['phone'] ?? '';
      selectedCountryCode = profile['country_code'] ?? '+257';
    });
  }

  Future<void> _loadProvinces() async {
    setState(() {
      loadingProvinces = true;
      provinces = [];
      selectedProvince = null;
      quartiersFromBackend = [];
      selectedQuartierId = null;
      selectedQuartierName = null;
    });

    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('provinces')
        .select('id, name')
        .order('name');

    for (final row in response) {
      provinces.add(ProvinceItem(id: row['id'], name: row['name']));
    }

    setState(() {
      loadingProvinces = false;
    });
  }

  Future<void> _loadQuartiersByProvince(String provinceId) async {
    setState(() {
      loadingQuartiers = true;
      quartiersFromBackend = [];
      selectedQuartierId = null;
      selectedQuartierName = null;
    });

    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('quartiers')
        .select('id, name, fee')
        .eq('province_id', provinceId)
        .order('name');

    for (final row in response) {
      quartiersFromBackend.add(row);
    }

    setState(() {
      loadingQuartiers = false;
    });
  }

  Future<void> _recalculateFromBackend() async {
    if (deliveryType == null) return;

    // delivery requires buyer quartier
    if (deliveryType == 'delivery' && selectedQuartierId == null) return;

    setState(() {
      loadingBackendTotals = true;
    });

    final supabase = Supabase.instance.client;

    try {
      final response = await supabase.rpc(
        'calculate_checkout_total',
        params: {
          'p_product_id': widget.product.id,
          'p_qty': qty,
          'p_delivery_type': deliveryType,
          'p_buyer_quartier_id': deliveryType == 'delivery'
              ? selectedQuartierId
              : null,
          'p_offer_id': widget.offerId, // 👈 VERY IMPORTANT
        },
      );

      setState(() {
        backendSubtotal = response['subtotal'] ?? 0;
        backendDeliveryFee = response['delivery_fee'] ?? 0;
        backendProtectionFee = response['protection_fee'] ?? 0;
        backendTotal = response['total'] ?? 0;
        loadingBackendTotals = false;
      });
    } catch (e) {
      setState(() {
        loadingBackendTotals = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFFAA05);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Checkout"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _inputWithController("First name", firstNameCtrl),
            _inputWithController("Last name", lastNameCtrl),

            // ─── Phone number with country code
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Country code dropdown
                  SizedBox(
                    width: 80, // slightly smaller but controlled
                    child: DropdownButtonFormField<String>(
                      value: selectedCountryCode,
                      isDense: true,
                      isExpanded: true, // 👈 THIS FIXES OVERFLOW
                      items: const [
                        DropdownMenuItem(
                          value: '+257',
                          child: Text('+257', overflow: TextOverflow.ellipsis),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => selectedCountryCode = v!),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Phone number input
                  Expanded(
                    child: TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: "Phone number",
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _inputWithController("Email address", emailCtrl),

            const SizedBox(height: 14),

            _sectionTitle("Delivery & Pickup"),
            if (!loadingShopType && shopIsOnline)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  "This shop operates online",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),

            _radioOption(
              title: "Delivery by Buja Fasta",
              value: 'delivery',
              group: deliveryType,
              onChanged: (v) {
                setState(() {
                  deliveryType = v;
                });
                _loadProvinces(); // RPC will run after quartier selection
              },
            ),

            if (deliveryType == 'delivery') ...[
              const SizedBox(height: 6),

              if (loadingProvinces)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Center(child: _smallGreySpinner()),
                )
              else
                DropdownButtonFormField<ProvinceItem>(
                  value: selectedProvince,
                  hint: const Text("Select province"),
                  isDense: true,
                  items: provinces
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.name), // 👈 USER SEES NAME
                        ),
                      )
                      .toList(),
                  onChanged: (p) {
                    if (p == null) return;

                    setState(() {
                      selectedProvince = p;
                    });

                    _loadQuartiersByProvince(p.id); // 👈 USE ID
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

              if (loadingQuartiers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Center(child: _smallGreySpinner()),
                )
              else
                DropdownButtonFormField<String>(
                  value: selectedQuartierId,
                  hint: const Text("Select quartier"),
                  isDense: true,
                  items: quartiersFromBackend.map((q) {
                    return DropdownMenuItem<String>(
                      value: q['id'],
                      child: Text(q['name']),
                    );
                  }).toList(),
                  onChanged: (id) {
                    final selected = quartiersFromBackend.firstWhere(
                      (q) => q['id'] == id,
                    );

                    setState(() {
                      selectedQuartierId = id;
                      selectedQuartierName = selected['name'];
                    });

                    _recalculateFromBackend();
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

              // 👇 FULL ADDRESS (VERY IMPORTANT)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: addressCtrl,
                  maxLines: 3, // 👈 long answer but not huge
                  decoration: InputDecoration(
                    hintText: "Full address (street, house, landmarks...)",
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],

            _radioOption(
              title: "Pickup on Buja Fasta",
              value: 'pickup',
              group: deliveryType,
              onChanged: (v) {
                setState(() {
                  deliveryType = v;

                  // reset delivery selections
                  selectedProvince = null;
                  selectedQuartierId = null;
                  selectedQuartierName = null;
                  addressCtrl.clear();
                });

                // 👇 calculate pickup fee (shop only)
                _recalculateFromBackend();
              },
            ),

            if (!shopIsOnline && showSellerPickup)
              _radioOption(
                title: "Pickup on seller’s shop",
                value: 'seller_pickup',
                group: deliveryType,
                onChanged: (v) {
                  setState(() {
                    deliveryType = v;
                    selectedProvince = null;
                    selectedQuartierId = null;
                    selectedQuartierName = null;
                    addressCtrl.clear();
                  });

                  _recalculateFromBackend();
                },
              ),

            if (deliveryType == 'pickup' ||
                deliveryType == 'seller_pickup') ...[
              const SizedBox(height: 6),
              _dropdown(
                hint: "Select day",
                value: pickupDay,
                items: const ['today', 'tomorrow'],
                onChanged: (v) => setState(() => pickupDay = v!),
              ),
            ],

            const SizedBox(height: 14),

            const Text(
              "Buja Fasta applies a small protection fee on every purchase",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),

            const SizedBox(height: 16),

            _sectionTitle("Order summary"),

            _qtyRow(orange),

            _row(
              "Subtotal",
              loadingBackendTotals
                  ? "Calculating..."
                  : "${backendSubtotal} BIF",
            ),

            _row(
              deliveryType == 'delivery'
                  ? "Delivery fee"
                  : deliveryType == 'pickup'
                  ? "Pickup fee"
                  : "Pickup",
              loadingBackendTotals
                  ? "Calculating..."
                  : "${backendDeliveryFee} BIF",
            ),

            _row(
              "Protection fee",
              loadingBackendTotals
                  ? "Calculating..."
                  : "${backendProtectionFee} BIF",
            ),

            const Divider(height: 24),

            _row(
              "Total",
              loadingBackendTotals ? "Calculating..." : "${backendTotal} BIF",
              bold: true,
            ),

            const SizedBox(height: 14),

            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Center(
                child: Text(
                  "All Buja Fasta payments are secure and protected.",
                  textAlign: TextAlign.center, // 👈 IMPORTANT
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: submittingOrder || deliveryType == null
                    ? null
                    : () async {
                        setState(() => submittingOrder = true);

                        // 👇 ADD THIS BLOCK
                        if (!_validateBeforeOrder()) {
                          setState(() => submittingOrder = false);
                          return;
                        }

                        final supabase = Supabase.instance.client;

                        try {
                          final res = await supabase.rpc(
                            'create_pending_order_and_lock_balance',
                            params: {
                              'p_destination_address':
                                  deliveryType == 'delivery'
                                  ? addressCtrl.text.trim()
                                  : null,

                              'p_product_id': widget.product.id,
                              'p_quantity': qty,
                              'p_size': widget.size,
                              'p_seller_id': sellerId,
                              'p_shop_id': shopId,

                              'p_amount': backendTotal.toDouble(),
                              'p_subtotal': backendSubtotal.toDouble(),
                              'p_delivery_fee': deliveryType == 'delivery'
                                  ? backendDeliveryFee.toDouble()
                                  : 0,
                              'p_pickup_fee': deliveryType == 'pickup'
                                  ? backendDeliveryFee.toDouble()
                                  : 0,
                              'p_protection_fee': backendProtectionFee
                                  .toDouble(),

                              'p_delivery_type': deliveryType,
                              'p_pickup_day':
                                  (deliveryType == 'pickup' ||
                                      deliveryType == 'seller_pickup')
                                  ? pickupDay
                                  : null,

                              'p_buyer_quartier_id': deliveryType == 'delivery'
                                  ? selectedQuartierId
                                  : null,

                              'p_shop_is_physical': !shopIsOnline,
                            },
                          );

                          if (res['ok'] != true) {
                            throw Exception('Order failed');
                          }

                          if (!mounted) return;
                          setState(() {
                            _resetCheckoutForm();
                          });

                          _showOrderSuccessSheet(context);
                        } catch (e) {
                          _handleBackendError(e);
                        } finally {
                          if (mounted) {
                            setState(() => submittingOrder = false);
                          }
                        }
                      },

                child: submittingOrder
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white70,
                          ),
                        ),
                      )
                    : const Text(
                        "Order now",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _dropdown({
    required String hint,
    required List<String> items,
    String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DropdownButtonFormField<String>(
        value: value,
        isDense: true,
        hint: Text(hint),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _handleBackendError(dynamic e) {
    final msg = e.toString().toLowerCase();

    String userMessage = 'Something went wrong. Please try again.';

    // 🔌 NO INTERNET / CONNECTION ISSUES
    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network') ||
        msg.contains('connection')) {
      userMessage = 'No internet connection. Please check your network.';
    }
    // ⏳ TIMEOUT / SUPABASE BUSY
    else if (msg.contains('timeout') ||
        msg.contains('timed out') ||
        msg.contains('canceling statement') ||
        msg.contains('too many requests') ||
        msg.contains('rate limit')) {
      userMessage = 'Service is busy. Please try again in a moment.';
    }
    // 🔐 AUTH / PROFILE
    else if (msg.contains('not authenticated')) {
      userMessage = 'Please log in to continue';
    } else if (msg.contains('profile not complete')) {
      userMessage = 'Please complete your profile';
    }
    // 💰 WALLET
    else if (msg.contains('insufficient')) {
      userMessage = 'Not enough balance';
    }
    // 📦 ORDER LOGIC
    else if (msg.contains('invalid pickup day')) {
      userMessage = 'Invalid pickup day selected';
    }

    Fluttertoast.showToast(
      msg: userMessage,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 14,
    );
  }

  Widget _radioOption({
    required String title,
    required String value,
    required String? group,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4), // 👈 closer spacing
      child: InkWell(
        onTap: () => onChanged(value),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start, // 👈 LEFT ALIGN
          children: [
            Radio<String>(
              value: value,
              groupValue: group,
              onChanged: (v) => onChanged(v!),
              visualDensity: VisualDensity.compact, // 👈 removes big gap
            ),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyRow(Color orange) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Text("Quantity", style: TextStyle(fontSize: 12)),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: qty > 1
                ? () {
                    setState(() => qty--);
                    _recalculateFromBackend();
                  }
                : null,

            icon: const Icon(Icons.remove, size: 18),
          ),
          Text("$qty", style: const TextStyle(fontSize: 12)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: qty < widget.product.stock
                ? () {
                    setState(() => qty++);
                    _recalculateFromBackend();
                  }
                : null,

            icon: Icon(Icons.add, size: 18, color: orange),
          ),
        ],
      ),
    );
  }
}

Widget _inputWithController(String hint, TextEditingController controller) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
