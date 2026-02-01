import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateShopAddressPage extends StatefulWidget {
  const CreateShopAddressPage({super.key});

  @override
  State<CreateShopAddressPage> createState() => _CreateShopAddressPageState();
}

class ProvinceItem {
  final String id;
  final String name;

  ProvinceItem({required this.id, required this.name});
}

class QuartierItem {
  final String id;
  final String name;

  QuartierItem({required this.id, required this.name});
}

class _CreateShopAddressPageState extends State<CreateShopAddressPage> {
  @override
  void initState() {
    super.initState();
    _redirectIfShopExists();
    _loadProvinces(); // 👈 LOAD FROM DB
  }

  Future<void> _redirectIfShopExists() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) return;

    final shop = await client
        .from('shops')
        .select()
        .eq('owner_id', user.id)
        .maybeSingle();

    if (shop != null && mounted) {
      Navigator.pushReplacementNamed(context, '/my-shop');
    }
  }

  final _addressCtrl = TextEditingController();

  // ─── Provinces (from backend)
  List<ProvinceItem> provinces = [];
  ProvinceItem? selectedProvince;
  bool loadingProvinces = false;
  
  // ─── Quartiers (from backend)
  List<QuartierItem> quartiersFromBackend = [];
  QuartierItem? selectedQuartier;
  bool loadingQuartiers = false;

  void _continue() {
    // 1️⃣ Validate province
    if (selectedProvince == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a province')));
      return;
    }

    // 2️⃣ Validate quartier
    if (selectedQuartier == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a quartier')));
      return;
    }

    // 3️⃣ Validate address
    final address = _addressCtrl.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter your shop address')));
      return;
    }

    // 4️⃣ Safe to continue
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final shopName = args['shop_name'];
    final sellType = args['sell_type'];

    Navigator.pushNamed(
      context,
      '/create-shop-final',
      arguments: {
        'shop_name': shopName,
        'sell_type': sellType,
        'province_id': selectedProvince!.id,
        'province_name': selectedProvince!.name,
        'quartier_id': selectedQuartier!.id,
        'quartier_name': selectedQuartier!.name,

        'address': address,
      },
    );
  }

  Future<void> _loadProvinces() async {
    setState(() {
      loadingProvinces = true;
      provinces = [];
      selectedProvince = null;
      quartiersFromBackend = [];
      selectedQuartier = null;
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
      selectedQuartier = null;
    });

    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('quartiers')
        .select('id, name')
        .eq('province_id', provinceId)
        .order('name');

    for (final row in response) {
      quartiersFromBackend.add(QuartierItem(id: row['id'], name: row['name']));
    }

    setState(() {
      loadingQuartiers = false;
    });
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFFFFAA07);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text("Shop Location"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Where is your shop located?",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 10),

            Text(
              "Provide your shop address so customers can find you.",
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 30),

            // ─── Province Dropdown ───
            loadingProvinces
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButtonFormField<ProvinceItem>(
                      value: selectedProvince,
                      decoration: const InputDecoration(
                        labelText: "Province",
                        border: InputBorder.none,
                      ),
                      items: provinces
                          .map(
                            (p) =>
                                DropdownMenuItem(value: p, child: Text(p.name)),
                          )
                          .toList(),
                      onChanged: (p) {
                        if (p == null) return;

                        setState(() {
                          selectedProvince = p;
                        });

                        _loadQuartiersByProvince(p.id);
                      },
                    ),
                  ),

            const SizedBox(height: 16),

            // ─── Quartier Dropdown ───
            // ─── Quartier Dropdown ───
            loadingQuartiers
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButtonFormField<QuartierItem>(
                      value: selectedQuartier,
                      decoration: const InputDecoration(
                        labelText: "Quartier",
                        border: InputBorder.none,
                      ),
                      items: quartiersFromBackend
                          .map(
                            (q) =>
                                DropdownMenuItem(value: q, child: Text(q.name)),
                          )
                          .toList(),
                      onChanged: (q) {
                        if (q == null) return;
                        setState(() {
                          selectedQuartier = q;
                        });
                      },
                    ),
                  ),

            const SizedBox(height: 16),

            // ─── Shop Address ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: "Shop Address",
                  border: InputBorder.none,
                ),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Next",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
