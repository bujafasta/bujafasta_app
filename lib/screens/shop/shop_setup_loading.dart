import 'dart:async';
import 'package:flutter/material.dart';

class ShopSetupLoading extends StatefulWidget {
  const ShopSetupLoading({super.key});

  @override
  State<ShopSetupLoading> createState() => _ShopSetupLoadingState();
}

class _ShopSetupLoadingState extends State<ShopSetupLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  final List<String> messages = [
    "Preparing your shop…",
    "Configuring settings…",
    "Almost ready…",
    "Finalizing setup…",
  ];

  int _messageIndex = 0;
  double percent = 0;
  bool showPopup = false; // ⬅ NEW: popup visibility

  @override
  void initState() {
    super.initState();

    // Total duration = 4 seconds
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _progress = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.addListener(() {
      double rawValue = _controller.value;
      double p = rawValue * 100;

      // Lag effects
      if (p > 89 && p < 92) {
        p = 89 + (p - 89) * 0.3;
      }
      if (p > 99 && p < 100) {
        p = 99 + (p - 99) * 0.45;
      }

      p = p.clamp(0, 100);

      setState(() => percent = p);

      // When hits 100% show popup
      if (percent >= 100 && !showPopup) {
        setState(() => showPopup = true);

        // Hide popup after 1 second → navigate to MyShop
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              "/home",
              arguments: {'openShop': true},
            );
          }
        });
      }
    });

    _controller.forward();

    // Change messages every 700ms
    Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (_messageIndex < messages.length - 1) {
        setState(() => _messageIndex++);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFFFFAA07);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // MAIN LOADING CARD
          Center(
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Please wait while your shop is being created",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 25),

                  // Progress bar background
                  Container(
                    height: 10,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (context, child) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 10,
                            width: 3 * percent,
                            decoration: BoxDecoration(
                              color: brandColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    "${percent.toInt()}%",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    messages[_messageIndex],
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // SUCCESS POPUP
          if (showPopup)
            AnimatedScale(
              scale: showPopup ? 1 : 0.7,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: showPopup ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: brandColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    "🎉 Shop Created!",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
