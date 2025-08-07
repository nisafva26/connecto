import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class PremiumSuccessBottomSheet extends StatelessWidget {
  final VoidCallback? onDone;

  const PremiumSuccessBottomSheet({super.key, this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: const BoxDecoration(
        color: Color(0xFF001311),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ Lottie success animation
          Lottie.asset(
            'assets/lottie/success.json',
            height: 120,
            repeat: false,
          ),

          const SizedBox(height: 12),

          // ✅ Title
          const Text(
            "Gathering Created!",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 8),

          // ✅ Subtext
          const Text(
            "Your gathering has been successfully created.\nInvitees will be notified!",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // ✅ Done button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onDone?.call();
              },
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text("Done"),
              
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent[700],
                foregroundColor: Colors.black,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
