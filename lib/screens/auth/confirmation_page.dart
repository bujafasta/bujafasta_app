import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConfirmationPage extends StatefulWidget {
  final String email;

  const ConfirmationPage({super.key, required this.email});

  static const Color kAccent = Color(0xFFF57C00); // deep orange

  @override
  State<ConfirmationPage> createState() => _ConfirmationPageState();
}

class _ConfirmationPageState extends State<ConfirmationPage> {
  int _secondsLeft = 0;
  Timer? _timer;

  void _startCountdown() {
    setState(() => _secondsLeft = 60);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) {
        timer.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resendEmail() async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.auth.resend(type: OtpType.signup, email: widget.email);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Confirmation email resent")),
      );

      _startCountdown();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Check your email"),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // 📧 Email icon
              Icon(
                Icons.mark_email_read_outlined,
                size: 90,
                color: ConfirmationPage.kAccent,
              ),

              const SizedBox(height: 24),

              // Main text
              Text(
                "We sent a confirmation link to",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),

              const SizedBox(height: 6),

              // Email
              Text(
                widget.email,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // 👇 NEW spam text
              const Text(
                "Please also check your spam folder",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),

              const SizedBox(height: 22),

              // 🔁 Resend
              TextButton(
                onPressed: _secondsLeft == 0 ? _resendEmail : null,
                child: Text(
                  _secondsLeft == 0
                      ? "Can't see it? Resend"
                      : "Resend again in $_secondsLeft seconds",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(height: 16),

              // 🔒 VERY SMALL SECURITY NOTE
              const Text(
                "Note: For security reasons, if this email was previously used to create a Buja Fasta account, "
                "you may not receive a new confirmation link. Try logging in instead.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),

              const Spacer(),

              // 🔙 Back to sign in
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  "Back to Sign In",
                  style: TextStyle(
                    color: ConfirmationPage.kAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
