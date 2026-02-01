import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateShopOnlineProvincePage extends StatefulWidget {
  const CreateShopOnlineProvincePage({super.key});

  @override
  State<CreateShopOnlineProvincePage> createState() =>
      _CreateShopOnlineProvincePageState();
}

// SAME MODEL STYLE YOU ALREADY USE
class ProvinceItem {
  final String id;
  final String name;

  ProvinceItem({required this.id, required this.name});
}

class _CreateShopOnlineProvincePageState
    extends State<CreateShopOnlineProvincePage> {
  // ─── Province state
  List<ProvinceItem> provinces = [];
  ProvinceItem? selectedProvince;
  bool loadingProvinces = false;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  // ─── Load provinces from Supabase (SAME AS ADDRESS PAGE)
  Future<void> _loadProvinces() async {
    setState(() {
      loadingProvinces = true;
      provinces = [];
      selectedProvince = null;
    });

    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('provinces')
        .select('id, name')
        .order('name');

    for (final row in response) {
      provinces.add(
        ProvinceItem(id: row['id'], name: row['name']),
      );
    }

    setState(() {
      loadingProvinces = false;
    });
  }

  // ─── Continue button logic
  void _continue() {
    // 1️⃣ Validate province
    if (selectedProvince == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a province')),
      );
      return;
    }

    // 2️⃣ Get previous arguments
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final shopName = args['shop_name'];
    final sellType = args['sell_type'];

    // 3️⃣ Continue to FINAL page (same as before)
    Navigator.pushNamed(
      context,
      '/create-shop-final',
      arguments: {
        'shop_name': shopName,
        'sell_type': sellType,

        // 👇 pass selected province
        'province_id': selectedProvince!.id,
        'province_name': selectedProvince!.name,

        // online shops don’t have address
        'address': null,
      },
    );
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
        title: const Text(
          "Shop Setup",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Where do you operate?",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 8),

            Text(
              "Select the province where your online shop operates.",
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 30),

            // ─── Province Dropdown (FROM BACKEND)
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
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.name),
                            ),
                          )
                          .toList(),
                      onChanged: (p) {
                        if (p == null) return;
                        setState(() {
                          selectedProvince = p;
                        });
                      },
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
                  "Continue",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
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
