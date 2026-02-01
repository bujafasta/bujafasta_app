import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bujafasta_app/services/pin_service.dart';
import 'package:bujafasta_app/services/pin_cache_service.dart';

// ============================================
// PIN SETUP SCREEN
// ============================================
// Shown when user first accesses wallet

class PinSetupScreen extends StatefulWidget {
  final VoidCallback onPinSet;

  const PinSetupScreen({super.key, required this.onPinSet});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  static const Color kDeepOrange = Color(0xFFF57C00);

  final PinService _pinService = PinService();

  final TextEditingController _pin1Controller = TextEditingController();
  final TextEditingController _pin2Controller = TextEditingController();

  final FocusNode _pin1Focus = FocusNode();
  final FocusNode _pin2Focus = FocusNode();

  bool _showPin2 = false;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _pin1Controller.dispose();
    _pin2Controller.dispose();
    _pin1Focus.dispose();
    _pin2Focus.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final pin1 = _pin1Controller.text.trim();

    // Validate first PIN
    if (pin1.length != 4) {
      setState(() {
        _errorMessage = 'PIN must be 4 digits';
      });
      return;
    }

    if (!_showPin2) {
      // Show confirm PIN screen
      setState(() {
        _showPin2 = true;
        _errorMessage = null;
      });
      _pin2Focus.requestFocus();
    } else {
      // Verify both PINs match
      final pin2 = _pin2Controller.text.trim();

      if (pin2.length != 4) {
        setState(() {
          _errorMessage = 'PIN must be 4 digits';
        });
        return;
      }

      if (pin1 != pin2) {
        setState(() {
          _errorMessage = 'PINs do not match';
        });
        return;
      }

      // Create wallet with PIN
      setState(() {
        _isLoading = true;
      });

      final success = await _pinService.setPin(pin: pin1);

      setState(() {
        _isLoading = false;
      });

      if (success) {
        // ✅ CACHE PIN LOCALLY (SOURCE OF TRUTH)
        await PinCacheService.setPinSet(true);

        // ✅ Notify parent AFTER cache is saved
        widget.onPinSet();
      } else {
        setState(() {
          _errorMessage = 'Failed to create wallet. Please try again.';
        });
      }
    }
  } // 👈 👈 👈 THIS WAS MISSING

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kDeepOrange))
            : SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kDeepOrange.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 60,
                        color: kDeepOrange,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Title
                    Text(
                      _showPin2 ? 'Confirm PIN' : 'Create Wallet PIN',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      _showPin2
                          ? 'Re-enter your 4-digit PIN'
                          : 'Set a 4-digit PIN to secure your wallet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // PIN Input
                    if (!_showPin2)
                      _buildPinInput(
                        controller: _pin1Controller,
                        focusNode: _pin1Focus,
                        autofocus: true,
                      )
                    else
                      _buildPinInput(
                        controller: _pin2Controller,
                        focusNode: _pin2Focus,
                        autofocus: true,
                      ),

                    const SizedBox(height: 16),

                    // Error message
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),

                    const SizedBox(height: 40),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kDeepOrange,

                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _showPin2 ? 'Set PIN' : 'Continue',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Back button (only on confirm screen)
                    if (_showPin2)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showPin2 = false;
                            _pin2Controller.clear();
                            _errorMessage = null;
                          });
                          _pin1Focus.requestFocus();
                        },
                        child: const Text(
                          'Go Back',
                          style: TextStyle(color: kDeepOrange),
                        ),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPinInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool autofocus,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // PIN BOXES
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            return Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: controller.text.length > index
                      ? kDeepOrange
                      : Colors.grey.shade300,
                  width: 2,
                ),

                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: controller.text.length > index
                    ? const Icon(Icons.circle, size: 14)
                    : null,
              ),
            );
          }),
        ),

        // HIDDEN TEXT FIELD - FIXED SIZE
        Opacity(
          opacity: 0, // Still invisible
          child: Container(
            width: 56 * 4 + 8 * 6, // Calculate total width of PIN boxes
            height: 56,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                setState(() {
                  _errorMessage = null;
                });
              },
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 1), // Make cursor tiny
            ),
          ),
        ),
      ],
    );
  }
}
