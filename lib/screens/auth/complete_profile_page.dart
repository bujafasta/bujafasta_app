import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/services/device_service.dart';
import 'package:bujafasta_app/state/profile_completion_state.dart';

const Color kAccent = Color(0xFFF57C00);
const Color kDark = Colors.black87;
const Color kGrey = Color(0xFFF3F3F3);

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();

  String _countryCode = '+257';
  String? _gender;
  String? _error;
  bool _loading = false;

  final List<String> _countryCodes = ['+257'];
  final List<String> _genders = ['Male', 'Female', 'Prefer not to say'];

  /// ✅ Clean human input (spaces)
  String cleanName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _save() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _error = null);

    final first = cleanName(_first.text);
    final last = cleanName(_last.text);
    final phone = _phone.text.trim();

    // 🔴 REQUIRED
    if (first.isEmpty || last.isEmpty || phone.isEmpty) {
      setState(() {
        _error = 'All fields are required except gender.';
      });
      return;
    }

    // 🔴 NAME VALIDATION (human friendly)
    bool invalidName(String name) {
      if (name.length < 2) return true;

      // Letters and spaces only
      if (!RegExp(r'^[a-zA-Z ]+$').hasMatch(name)) return true;

      // Block ddd / aaa / ttt (ignore spaces)
      final noSpace = name.replaceAll(' ', '').toLowerCase();
      if (RegExp(r'(.)\1\1').hasMatch(noSpace)) return true;

      return false;
    }

    if (invalidName(first)) {
      setState(() {
        _error =
            'First name must contain letters only and not repeated letters like ddd.';
      });
      return;
    }

    if (invalidName(last)) {
      setState(() {
        _error =
            'Last name must contain letters only and not repeated letters like ttt.';
      });
      return;
    }

    // 🔴 PHONE NUMBERS ONLY
    if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
      setState(() {
        _error = 'Phone number must contain digits only.';
      });
      return;
    }

    // 🔴 BURUNDI RULES
    if (_countryCode == '+257') {
      if (phone.length != 8) {
        setState(() {
          _error = 'Burundian phone numbers must be exactly 8 digits.';
        });
        return;
      }

      if (!(phone.startsWith('6') || phone.startsWith('7'))) {
        setState(() {
          _error = 'Burundian phone numbers must start with 6 or 7.';
        });
        return;
      }
    }

    setState(() => _loading = true);

    try {
      await Supabase.instance.client.rpc(
        'complete_profile_phone_check',
        params: {
          'p_first_name': first,
          'p_last_name': last,
          'p_country_code': _countryCode,
          'p_phone': phone,
          'p_gender': _gender,
        },
      );

      if (!context.mounted) return;

      // 🔔 TELL THE WHOLE APP PROFILE IS NOW COMPLETE
      profileCompleteNotifier.value = true;

      // go back
      Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (e.message.contains('PHONE_ALREADY_USED')) {
        setState(() {
          _error = 'This phone number is already linked to another account.';
        });
      } else {
        setState(() {
          _error = 'Something went wrong. Please try again.';
        });
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        title: const Text(
          "Complete Profile",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _inputField(_first, "First name"),
              const SizedBox(height: 14),
              _inputField(_last, "Last name"),
              const SizedBox(height: 14),

              // 📞 PHONE
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: kAccent),

                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _countryCode,
                        items: _countryCodes
                            .map(
                              (code) => DropdownMenuItem(
                                value: code,
                                child: Text(code),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _countryCode = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: "Phone number",
                        filled: true,
                        fillColor: kGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kAccent),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 🚻 GENDER (OPTIONAL)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: InputDecoration(
                        labelText: "Gender (optional)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: _genders
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() => _gender = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    color: kAccent,

                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Why we ask"),
                          content: const Text(
                            "Selecting your gender helps us personalize the content you see. This field is optional.",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Got it"),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFFFAA05))),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Next",
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
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: kGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kAccent, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _confirmAndLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave profile setup?'),
        content: const Text(
          'Are you sure you want to quit without filling your profile?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (shouldLogout != true) return;

    // 🔄 show spinner
    setState(() => _loading = true);

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    try {
      if (user != null) {
        final deviceId = await getDeviceId();

        await client
            .from('user_devices')
            .delete()
            .eq('device_id', deviceId)
            .eq('user_id', user.id);
      }

      await client.auth.signOut();

      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } finally {
      // safety: if navigation fails for any reason
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
