import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bujafasta_app/services/pin_service.dart';
import 'package:bujafasta_app/screens/auth/verify_password_screen.dart';
import 'package:bujafasta_app/screens/auth/reset_pin_screen.dart';

// ============================================
// PIN VERIFICATION SCREEN
// ============================================
// Shown when user with existing PIN opens wallet

class PinVerifyScreen extends StatefulWidget {
  final VoidCallback onPinVerified;

  const PinVerifyScreen({super.key, required this.onPinVerified});

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen> {
  static const Color kDeepOrange = Color(0xFFF57C00);

  final PinService _pinService = PinService();
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocus = FocusNode();

  String? _errorMessage;
  bool _isLoading = false;
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus on PIN input when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLocked) {
        _pinFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _onForgotPinPressed() async {
    final bool? verified = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VerifyPasswordScreen()),
    );

    // == true means: password was correct
    if (verified == true) {
      final bool? pinReset = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ResetPinScreen()),
      );

      // == true means: PIN reset succeeded
      if (pinReset == true) {
        setState(() {
          _errorMessage = null;
          _isLocked = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN reset successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();

    if (pin.length != 4) {
      setState(() {
        _errorMessage = 'PIN must be 4 digits';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _pinService.verifyPin(pin: pin);

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      // ✅ PIN CORRECT
      widget.onPinVerified();
    } else {
      // ❌ PIN WRONG
      _pinController.clear();

      setState(() {
        _errorMessage = result['message'];
        _isLocked = result['locked'] == true;
      });

      if (!_isLocked) {
        _pinFocus.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // 👈 ADD THIS
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Enter PIN'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kDeepOrange))
          : SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                children: [
                  // Lock icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _isLocked
                          ? Colors.red.shade50
                          : kDeepOrange.withOpacity(0.12),

                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isLocked ? Icons.lock : Icons.lock_outline,
                      size: 60,
                      color: _isLocked ? Colors.red : kDeepOrange,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Title
                  Text(
                    _isLocked ? 'Wallet Locked' : 'Enter Your PIN',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    _isLocked
                        ? 'Too many failed attempts'
                        : 'Enter your 4-digit PIN to access wallet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 40),

                  // PIN Input (FIXED – tappable like Set PIN)
                  if (!_isLocked)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // VISUAL PIN BOXES
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            return Container(
                              width: 56,
                              height: 56,
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _pinController.text.length > index
                                      ? kDeepOrange
                                      : Colors.grey.shade300,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: _pinController.text.length > index
                                    ? const Icon(Icons.circle, size: 14)
                                    : null,
                              ),
                            );
                          }),
                        ),

                        // INVISIBLE TEXT FIELD (COVERS ALL BOXES)
                        Opacity(
                          opacity: 0,
                          child: Container(
                            width: 56 * 4 + 8 * 6, // exact width of all boxes
                            height: 56,
                            child: TextField(
                              controller: _pinController,
                              focusNode: _pinFocus,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              obscureText: true,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _errorMessage = null;
                                });

                                // AUTO VERIFY
                                if (value.length == 4) {
                                  _verifyPin();
                                }
                              },
                              decoration: const InputDecoration(
                                counterText: '',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(fontSize: 1),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 48), // 👈 replaces Spacer()
                  // Forgot PIN button
                  TextButton(
                    onPressed: _onForgotPinPressed,
                    child: const Text(
                      'Forgot PIN? ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
