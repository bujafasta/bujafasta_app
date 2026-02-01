import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class VerifyCodePage extends StatefulWidget {
  final String? email;
  const VerifyCodePage({super.key, this.email});

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  static const Color kAccent = Color(0xFFFFAA07);
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  bool _isResendVisible = false;
  int _resendCountdown = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    // Auto-focus first box
    Future.delayed(const Duration(milliseconds: 300), () {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _isResendVisible = true;
      _resendCountdown = 60;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCountdown--;
      });
      if (_resendCountdown <= 0) {
        _countdownTimer?.cancel();
        setState(() {
          _isResendVisible = false;
        });
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code resent (UI-only)')));
  }

  bool get _isComplete => _controllers.every((c) => c.text.isNotEmpty);

  void _onCodeChanged(String value, int index) {
    if (value.length > 1) {
      // Handle paste: split and distribute characters
      final chars = value.split('');
      for (int i = 0; i < chars.length && index + i < 6; i++) {
        _controllers[index + i].text = chars[i];
        if (index + i < 5) {
          _focusNodes[index + i + 1].requestFocus();
        }
      }
      setState(() {});
      return;
    }

    if (value.isNotEmpty && index < 5) {
      // Auto-advance to next box
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _onKeyDown(KeyEvent event, int index) {
    // Handle backspace to go back
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Back tapped (UI-only)')),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: mq.size.height - mq.padding.vertical - kToolbarHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Verify Your Code',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the 6-digit code sent to your email to confirm it\'s you.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // 6 input boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      6,
                      (i) => SizedBox(
                        width: 50,
                        height: 50,
                        child: KeyboardListener(
                          focusNode: FocusNode(),
                          onKeyEvent: (event) => _onKeyDown(event, i),
                          child: TextField(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            keyboardType: TextInputType.text,
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color.fromRGBO(255, 255, 255, 0.04)
                                  : const Color.fromRGBO(0, 0, 0, 0.04),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.1),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.08),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: kAccent,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (value) => _onCodeChanged(value, i),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      'This is a UI-only demo — any 6 characters will work.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ),

                  const Spacer(),

                  // Continue button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isComplete
                          ? () {
                              // navigation removed — do not push HomePage; show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Verification successful (UI-only)',
                                  ),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: _isComplete ? 2 : 0,
                        shadowColor: Colors.black12,
                      ),
                      child: Text(
                        'Continue',
                        style: TextStyle(
                          color: _isComplete
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.6),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Resend code link (moved below Continue button)
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: _isResendVisible ? null : _startCountdown,
                      child: Text(
                        _isResendVisible
                            ? 'Resend in $_resendCountdown s'
                            : 'Resend code?',
                        style: TextStyle(
                          color: _isResendVisible ? Colors.grey : kAccent,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
