import 'package:flutter/material.dart';

class EmptyInviteCard extends StatelessWidget {
  final String title;

  const EmptyInviteCard({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 12),
      // margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF2B3C3A), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_empty_rounded, color: Color(0xFF6B6E7C)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
