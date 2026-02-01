import 'package:flutter/material.dart';
import 'package:bujafasta_app/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/screens/auth/confirmation_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  static const Color kAccent = Color(0xFFF57C00); // deep orange

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _hidePass = true;
  bool _hideConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _togglePass() => setState(() => _hidePass = !_hidePass);
  void _toggleConfirm() => setState(() => _hideConfirm = !_hideConfirm);

  InputDecoration _dec(
    String label,
    BuildContext context, {
    bool? isPassword,
    VoidCallback? toggle,
  }) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withAlpha(8)
          : Colors.black.withAlpha(8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      suffixIcon: isPassword == true
          ? IconButton(
              icon: Icon(
                (toggle == _togglePass ? _hidePass : _hideConfirm)
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: kAccent,
              ),

              onPressed: toggle,
            )
          : null,
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleSignUp() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    // Basic validations (keep your existing validation)
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      _showSnack('Please enter a valid email address');
      return;
    }

    if (password != confirm) {
      _showSnack('Passwords do not match');
      return;
    }

    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await AuthService.signUp(
        email: email,
        password: password,
        username:
            email, // or you can change this if you want a separate username
      );

      // Check if user exists (profile was created in AuthService)
      if (res.user == null) {
        _showSnack('Signup failed. Try again.');
        return;
      }

      // Check if email confirmation is needed
      if (res.session == null) {
        // Email confirmation required
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ConfirmationPage(email: email)),
        );
      } else {
        // User is already confirmed and logged in
        if (!mounted) return;
        // Navigate to home/main screen
        Navigator.of(context).pushReplacementNamed('/complete-profile');
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();

      // Supabase v2 error messages
      if (msg.contains('already') ||
          msg.contains('exists') ||
          msg.contains('registered')) {
        _showSnack('This email already has an account');
      } else if (msg.contains('weak') || msg.contains('password')) {
        _showSnack('Password is too weak. Try a stronger password.');
      } else {
        _showSnack(e.message);
      }
    } catch (e) {
      _showSnack('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _emailCtrl,
                decoration: _dec('Email', context),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _passCtrl,
                decoration: _dec(
                  'Password',
                  context,
                  isPassword: true,
                  toggle: _togglePass,
                ),
                obscureText: _hidePass,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _confirmCtrl,
                decoration: _dec(
                  'Confirm password',
                  context,
                  isPassword: true,
                  toggle: _toggleConfirm,
                ),
                obscureText: _hideConfirm,
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Create account',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      'Login',
                      style: TextStyle(
                        color: kAccent, // deep orange
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
