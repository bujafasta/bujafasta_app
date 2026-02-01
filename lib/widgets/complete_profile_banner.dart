import 'package:flutter/material.dart';

class CompleteProfileBanner extends StatefulWidget {
  final ValueNotifier<int>? nudge;

  const CompleteProfileBanner({super.key, this.nudge});

  @override
  State<CompleteProfileBanner> createState() => _CompleteProfileBannerState();
}

class _CompleteProfileBannerState extends State<CompleteProfileBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    widget.nudge?.addListener(_shake);
  }

  void _shake() {
    if (_controller.isAnimating) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    widget.nudge?.removeListener(_shake);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: child,
        );
      },
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/complete-profile').then((result) {
            if (result == true) {
              widget.nudge?.value++; // still okay (optional)
            }
          });
        },

        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          color: Colors.black.withValues(alpha: 0.85),
          child: RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              children: [
                TextSpan(
                  text: 'Please complete your profile. ',
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: 'tap here',
                  style: TextStyle(
                    color: Color(0xFFF57C00), // 🔥 kAccent
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
