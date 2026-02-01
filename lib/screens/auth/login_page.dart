import 'package:flutter/material.dart';
import 'package:bujafasta_app/screens/auth/signup_page.dart';
import 'package:bujafasta_app/screens/auth/forgot_password_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/services/global_message_listener.dart';
import 'package:bujafasta_app/state/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color kAccent = Color(0xFFF57C00);

  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  bool _enableGoogleLogin = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    const redirectUri = 'bujafasta://login-callback';

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google, // Change Provider.google to OAuthProvider.google
        redirectTo: redirectUri,
      );

      // Mobile browser will open automatically.
      // DeepLinkHandler will complete the login after redirect.
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Google sign-in failed: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, BuildContext context) {
    final fill = Theme.of(context).brightness == Brightness.dark
        ? const Color.fromRGBO(255, 255, 255, 0.03)
        : const Color.fromRGBO(0, 0, 0, 0.03);
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/buja_fasta_logo_title.png',
      height: 72,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Text(
        'Buja Fasta',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Align(alignment: Alignment.center, child: logo),
              const SizedBox(height: 28),
              Text(
                'Welcome back',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Login to continue to your account',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Email / Phone / Username
              TextField(
                controller: _userCtrl,
                decoration: _inputDecoration('Email', context),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // Password
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: _inputDecoration('Password', context).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                textInputAction: TextInputAction.done,
              ),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordPage(),
                      ),
                    );
                  },

                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                  ),
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(color: kAccent),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Login button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final email = _userCtrl.text.trim();
                          final password = _passCtrl.text.trim();

                          if (email.isEmpty || password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill all fields'),
                              ),
                            );
                            return;
                          }

                          setState(() => _isLoading = true);

                          try {
                            final res = await Supabase.instance.client.auth
                                .signInWithPassword(
                                  email: email,
                                  password: password,
                                );

                            if (!mounted) return;

                            if (res.session != null) {
                              // 🔔 TELL THE WHOLE APP: USER IS LOGGED IN
                              isLoggedInNotifier.value = true;
                              // ✅ START GLOBAL MESSAGE LISTENER
                              GlobalMessageListener.start();

                              // 👉 go to home
                              if (!mounted) return;
                              Navigator.pushReplacementNamed(context, '/home');
                            } else {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Login failed: no session returned',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;

                            String message = 'Login failed. Please try again.';

                            if (e is AuthApiException) {
                              // ❌ Wrong email or password
                              if (e.code == 'invalid_credentials') {
                                message = 'Wrong email or password';
                              } else {
                                message = 'Unable to login. Please try again.';
                              }
                            } else if (e.toString().contains(
                                  'SocketException',
                                ) ||
                                e.toString().contains('Failed host lookup')) {
                              // 🌐 No internet
                              message =
                                  'No internet connection. Check your network.';
                            } else if (e is AuthRetryableFetchException) {
                              // 🔄 Supabase unreachable
                              message =
                                  'Service temporarily unavailable. Try again.';
                            }

                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          } finally {
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    shadowColor: Colors.black12,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                ),
              ),

              const SizedBox(height: 18),
              Row(
                children: const [
                  Expanded(child: Divider()),
                  SizedBox(width: 12),
                  Text('or'),
                  SizedBox(width: 12),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 18),

              // Alternate actions / social placeholders
              Center(
                child: Text(
                  'Create an account',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),

              // Social buttons column: Google above, Create Account below, both centered
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_enableGoogleLogin) ...[
                    SizedBox(
                      width: 220,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/google_logo.png',
                              width: 20,
                              height: 20,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.g_mobiledata, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Google',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignupPage(),
                          ),
                        );
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.person_add, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Create Account',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bottom small text
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignupPage(),
                          ),
                        );
                      },

                      child: Text(
                        'Create one',
                        style: TextStyle(
                          color: kAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
