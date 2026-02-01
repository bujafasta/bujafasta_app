import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalAccountInfoPage extends StatefulWidget {
  const PersonalAccountInfoPage({super.key});

  @override
  State<PersonalAccountInfoPage> createState() =>
      _PersonalAccountInfoPageState();
}

class _PersonalAccountInfoPageState extends State<PersonalAccountInfoPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _profile;

  static const Color kAccent = Color(0xFFF57C00);
  static const Color kGrey = Color(0xFFF3F3F3);
  static const Color kDark = Colors.black87;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      setState(() {
        _error = 'User not logged in';
        _loading = false;
      });
      return;
    }

    try {
      final data = await client
          .from('profiles')
          .select('''
          first_name,
          last_name,
          gender,
          phone,
          country_code,
          email,
          role,
          created_at,
          is_complete,
          pin_set,
          is_suspended
        ''')
          .eq('id', user.id)
          .single();

      setState(() {
        _profile = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error =
            'We couldn’t load your account information.\n\n'
            'This may be because your profile is not complete.\n\n'
            'Please complete your profile and try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Personal & Account Info',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Personal information'),
                  _infoCard([
                    _infoRow('First name', _profile!['first_name']),
                    _infoRow('Last name', _profile!['last_name']),
                    _infoRow('Gender', _profile!['gender'] ?? 'Not specified'),
                    _infoRow(
                      'Phone',
                      '${_profile!['country_code'] ?? ''} ${_profile!['phone'] ?? ''}',
                    ),
                    _infoRow(
                      'Profile status',
                      _profile!['is_complete'] == true
                          ? 'Completed'
                          : 'Incomplete',
                    ),
                  ]),

                  const SizedBox(height: 24),

                  _sectionTitle('Account details'),
                  _infoCard([
                    _infoRow('Email', _profile!['email'] ?? 'Not provided'),
                    _infoRow('Role', _profile!['role'] ?? 'User'),
                    _infoRow(
                      'PIN',
                      _profile!['pin_set'] == true ? 'PIN set' : 'No PIN',
                    ),
                    _infoRow(
                      'Account status',
                      _profile!['is_suspended'] == true
                          ? 'Suspended'
                          : 'Active',
                    ),
                    _infoRow('Joined', _formatDate(_profile!['created_at'])),
                  ]),
                ],
              ),
            ),
    );
  }

  // ===== UI HELPERS =====

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Text(
            value ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w600, color: kDark),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    final date = DateTime.tryParse(iso);
    if (date == null) return '-';
    return '${date.day}/${date.month}/${date.year}';
  }
}
