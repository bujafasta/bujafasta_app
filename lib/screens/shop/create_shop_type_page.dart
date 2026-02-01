import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateShopTypePage extends StatefulWidget {
  const CreateShopTypePage({super.key});

  @override
  State<CreateShopTypePage> createState() => _CreateShopTypePageState();
}

class _CreateShopTypePageState extends State<CreateShopTypePage> {
  @override
  void initState() {
    super.initState();
    _redirectIfShopExists();
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

  String? selected; // "physical" or "online"

  void _continue() {
    if (selected == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose how you sell')));
      return;
    }

    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    final shopName = args?['shop_name'] ?? '';

    if (selected == "physical") {
      // Physical → must enter address → then final creation
      Navigator.pushNamed(
        context,
        '/create-shop-address',
        arguments: {'shop_name': shopName, 'sell_type': selected},
      );
    } else {
      // Online only → go to province selection page
      Navigator.pushNamed(
        context,
        '/create-shop-online-province',
        arguments: {'shop_name': shopName, 'sell_type': selected},
      );
    }
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
              "How do you sell?",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 8),

            Text(
              "Choose the option that matches your business.",
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),

            const SizedBox(height: 30),

            _optionTile(
              title: "I have a physical shop",
              subtitle: "Your buyers can visit your location",
              value: "physical",
              icon: Icons.store_mall_directory_rounded,
            ),

            const SizedBox(height: 12),

            _optionTile(
              title: "I sell online only",
              subtitle: "You deliver or use pickup points",
              value: "online",
              icon: Icons.local_shipping_outlined,
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

            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final isSelected = selected == value;

    return GestureDetector(
      onTap: () => setState(() => selected = value),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFAA07).withValues(alpha: 0.15)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFAA07) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.black87),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFFFAA07) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
