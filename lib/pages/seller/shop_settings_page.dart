import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

class ShopSettingsPage extends StatefulWidget {
  const ShopSettingsPage({super.key});

  @override
  State<ShopSettingsPage> createState() => _ShopSettingsPageState();
}

class _ShopSettingsPageState extends State<ShopSettingsPage> {
  final supabase = Supabase.instance.client;

  bool _vacationMode = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVacationMode();
  }

  // ---------------------------
  // LOAD CURRENT VACATION MODE
  // ---------------------------
  Future<void> _loadVacationMode() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final shop = await supabase
        .from('shops')
        .select('is_vacation')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (shop != null) {
      setState(() {
        _vacationMode = shop['is_vacation'] == true;
        _loading = false;
      });
    }
  }

  // ---------------------------
  // TOGGLE VACATION MODE
  // ---------------------------
  Future<void> _toggleVacationMode(bool value) async {
    setState(() => _vacationMode = value);

    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase
        .from('shops')
        .update({'is_vacation': value})
        .eq('owner_id', user.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Shop settings'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 12),

                // ---------------------------
                // SHOP INFORMATION CARD
                // ---------------------------
                SettingsCard(
                  child: ListTile(
                    leading: const Icon(Icons.store_outlined),
                    title: const Text(
                      'Shop information',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'View your shop details, verification status and linked account',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ShopInformationPage(),
                        ),
                      );
                    },
                  ),
                ),

                // ---------------------------
                // VACATION MODE CARD
                // ---------------------------
                SettingsCard(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.pause_circle_outline),
                    title: const Text(
                      'Vacation mode',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'When enabled, your shop and all products will be hidden from buyers until you resume',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                    value: _vacationMode,
                    onChanged: _toggleVacationMode,
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
    );
  }
}

// ----------------------------------------------------
// SIMPLE SHOP INFORMATION PAGE (READ-ONLY)
// ----------------------------------------------------
class ShopInformationPage extends StatefulWidget {
  const ShopInformationPage({super.key});

  @override
  State<ShopInformationPage> createState() => _ShopInformationPageState();
}

class _ShopInformationPageState extends State<ShopInformationPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? shop;
  Map<String, dynamic>? profile;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final shopRes = await supabase
        .from('shops')
        .select()
        .eq('owner_id', user.id)
        .maybeSingle();

    final profileRes = await supabase
        .from('profiles')
        .select(
          'first_name,last_name,email,phone,country_code,role,is_suspended',
        )
        .eq('id', user.id)
        .maybeSingle();

    setState(() {
      shop = shopRes;
      profile = profileRes;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Shop information'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 12),

                // ===========================
                // SHOP DETAILS BOX
                // ===========================
                SettingsCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _boxTitle('Shop details'),

                        _infoTile('Shop name', shop?['shop_name']),
                        _infoTile('Description', shop?['description']),
                        _infoTile('Sell type', shop?['sell_type']),
                        _infoTile('Address', shop?['address']),

                        const Divider(height: 24),

                        _infoTile(
                          'Verification status',
                          shop?['is_verified'] == true
                              ? 'Verified'
                              : 'Not verified',
                        ),
                        _infoTile(
                          'Review status',
                          shop?['is_under_review'] == true
                              ? 'Under review'
                              : 'Approved',
                        ),
                        _infoTile(
                          'Vacation mode',
                          shop?['is_vacation'] == true ? 'Enabled' : 'Disabled',
                        ),
                      ],
                    ),
                  ),
                ),

                // ===========================
                // LINKED ACCOUNT BOX
                // ===========================
                SettingsCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _boxTitle('Linked account'),

                        _infoTile(
                          'Full name',
                          '${profile?['first_name'] ?? ''} ${profile?['last_name'] ?? ''}',
                        ),
                        _infoTile('Email', profile?['email']),
                        _infoTile(
                          'Phone number',
                          '${profile?['country_code'] ?? ''} ${profile?['phone'] ?? ''}',
                        ),
                        _infoTile('Role', profile?['role']),
                        _infoTile(
                          'Account status',
                          profile?['is_suspended'] == true
                              ? 'Suspended'
                              : 'Active',
                        ),
                      ],
                    ),
                  ),
                ),

                // ===========================
                // TECHNICAL BOX
                // ===========================
                SettingsCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _boxTitle('Technical information'),
                        _copyTile(context, 'Shop ID', shop?['id']),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
    );
  }

  // ---------------------------
  // UI HELPERS
  // ---------------------------

  Widget _boxTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _infoTile(String label, String? value) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _copyTile(BuildContext context, String label, String? value) {
    if (value == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Shop ID copied')));
            },
          ),
        ],
      ),
    );
  }
}

class SettingsCard extends StatelessWidget {
  final Widget child;

  const SettingsCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}
