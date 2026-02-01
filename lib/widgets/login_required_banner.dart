import 'package:flutter/material.dart';

class LoginRequiredBanner extends StatelessWidget {
  const LoginRequiredBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),

        // 👇 MATERIAL + INKWELL = PERFECT TAP HANDLING
        child: Material(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(14),

          child: InkWell(
            borderRadius: BorderRadius.circular(14),

            // ✅ THIS FIXES EVERYTHING
            onTap: () {
              Navigator.pushNamed(context, '/login');
            },

            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(
                            text: 'Log in and enjoy. ',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: '     Tap here',
                            style: TextStyle(
                              color: Color(0xFFF57C00),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Color(0xFFF57C00),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
