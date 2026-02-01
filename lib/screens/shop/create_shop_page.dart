import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateShopPage extends StatefulWidget {
  const CreateShopPage({super.key});

  @override
  State<CreateShopPage> createState() => _CreateShopPageState();
}

class _CreateShopPageState extends State<CreateShopPage> {
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

  final _nameCtrl = TextEditingController();
  final _loading = false;
  bool _nameLimitReached = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a shop name')));
      return;
    }

    if (name.length > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shop name must be 30 characters or less'),
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/create-shop-type', // we will build this next
      arguments: {'shop_name': name},
    );
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFFFFAA07);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          "Create Your Shop",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            const Text(
              "Let's set up your shop",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 6),

            Text(
              "Choose a name your buyers will recognize.",
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 28),

            // Input card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _nameCtrl,
                maxLength: 30, // 👈 HARD LIMIT
                decoration: InputDecoration(
                  border: InputBorder.none,
                  labelText: "Shop Name",
                  labelStyle: const TextStyle(fontSize: 16),

                  // 👇 COUNTER (3 / 30)
                  counterText: '${_nameCtrl.text.length} / 30',

                  // 👇 RED WARNING
                  errorText: _nameLimitReached
                      ? 'Maximum 30 characters allowed'
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _nameLimitReached = value.length >= 30;
                  });
                },
              ),
            ),

            const Spacer(),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _goToNextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
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
}
