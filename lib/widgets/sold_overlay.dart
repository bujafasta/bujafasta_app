import 'package:flutter/material.dart';

class SoldOverlay extends StatelessWidget {
  const SoldOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.65),
      child: const Center(
        child: Icon(
          Icons.checkroom,
          size: 42,
          color: Colors.white,
        ),
      ),
    );
  }
}
