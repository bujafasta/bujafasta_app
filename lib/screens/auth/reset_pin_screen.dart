import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bujafasta_app/services/pin_service.dart';

class ResetPinScreen extends StatefulWidget {
  const ResetPinScreen({super.key});

  @override
  State<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends State<ResetPinScreen> {
  final _pinService = PinService();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetPin() async {
    final newPin = _newPinCtrl.text.trim();
    final confirmPin = _confirmPinCtrl.text.trim();

    if (newPin.length != 4) {
      setState(() => _error = 'PIN must be 4 digits');
      return;
    }

    if (newPin != confirmPin) {
      setState(() => _error = 'PINs do not match');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await _pinService.resetPin(newPin: newPin);

    // when you see == true
    // it means: "the action succeeded"
    if (success == true) {
      if (!mounted) return;
      Navigator.pop(context, true); // PIN reset success
    } else {
      setState(() => _error = 'Failed to reset PIN');
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset PIN'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            TextField(
              controller: _newPinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'New PIN',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _confirmPinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _resetPin,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Reset PIN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
