import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/services/pin_service.dart';
import 'package:bujafasta_app/pages/wallet/pin_setup_screen.dart';
import 'package:bujafasta_app/services/shop_cache_service.dart';

class CreateShopFinalPage extends StatefulWidget {
  const CreateShopFinalPage({super.key});

  @override
  State<CreateShopFinalPage> createState() => _CreateShopFinalPageState();
}

class _CreateShopFinalPageState extends State<CreateShopFinalPage> {
  @override
  void initState() {
    super.initState();
    _redirectIfShopExists();
  }

  Future<void> _redirectIfShopExists() async {
    // 1️⃣ FAST PATH → check cache first
    final hasShopCached = await ShopCacheService.hasShop();

    if (hasShopCached && mounted) {
      Navigator.pushReplacementNamed(context, '/my-shop');
      return;
    }

    // 2️⃣ FALLBACK → check Supabase only if cache says NO
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) return;

    final shop = await client
        .from('shops')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (shop != null) {
      // ✅ update cache so we never re-check again
      await ShopCacheService.setHasShop(true);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/my-shop');
      }
    }
  }

  bool _saving = false;
  final supabase = Supabase.instance.client;
  final PinService _pinService = PinService();

  Future<void> _ensurePinThenCreateShop() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      // 1️⃣ Check if PIN is already set
      final hasPin = await _pinService.isPinSet();

      if (hasPin) {
        // ✅ PIN exists → proceed normally
        await _createShop();
        return;
      }

      // ❌ PIN not set → redirect to PIN setup
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PinSetupScreen(
            onPinSet: () {
              Navigator.pop(context);
            },
          ),
        ),
      );

      // 2️⃣ After returning, check again
      final pinNowSet = await _pinService.isPinSet();

      if (pinNowSet) {
        // ✅ PIN successfully created → continue shop creation
        await _createShop();
      } else {
        // ❌ User backed out
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN setup required to create a shop')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createShop() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pushNamed(context, '/login');
      }
      return;
    }

    // Read arguments
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final shopName = args['shop_name'];
    final sellType = args['sell_type']; // "physical" or "online"
    final address = args['address']; // could be null
    final provinceId = args['province_id'];
    final provinceName = args['province_name']; // UI only
    final quartierId = args['quartier_id'];
    final quartierName = args['quartier_name']; // UI only

    try {
      // Insert into Supabase
      await supabase.from('shops').insert({
        'owner_id': user.id,
        'shop_name': shopName,
        'description': null,
        'sell_type': sellType,
        'address': address,

        // ✅ FOREIGN KEYS
        'province_id': provinceId,
        'quartier_id': quartierId,
      });
      // ✅ CACHE: user now HAS a shop
      await ShopCacheService.setHasShop(true);

      if (!mounted) return;

      // SnackBar success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Shop created successfully")),
      );

      // Navigate to loading screen (which will redirect to MyShop)
      Navigator.pushReplacementNamed(
        context,
        '/shop-setup-loading',
        arguments: {'fromSetup': true}, // <--- ADD THIS FLAG
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error creating shop: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFFFFAA07);

    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final shopName = args['shop_name'];
    final sellType = args['sell_type'];
    final address = args['address'];
    final provinceId = args['province_id'];
    final provinceName = args['province_name']; // UI only
    final quartierId = args['quartier_id'];
    final quartierName = args['quartier_name']; // UI only

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Review & Create"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Confirm your details",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),

                const SizedBox(height: 20),

                _infoTile("Shop name", shopName),
                const SizedBox(height: 14),

                _infoTile(
                  "Selling type",
                  sellType == "physical" ? "Physical shop" : "Online only",
                ),
                const SizedBox(height: 14),

                if (provinceName != null) _infoTile("Province", provinceName),

                const SizedBox(height: 14),

                if (quartierName != null) _infoTile("Quartier", quartierName),

                const SizedBox(height: 14),

                if (address != null && address.toString().trim().isNotEmpty)
                  _infoTile("Shop address", address),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _ensurePinThenCreateShop,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text(
                            "Create Shop",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
