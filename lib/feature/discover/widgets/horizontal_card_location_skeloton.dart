import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class MinimalMapCardSkeleton extends StatelessWidget {
  const MinimalMapCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      child: Container(
        width: 320,
        height: 150,
        margin: const EdgeInsets.symmetric(horizontal: 12).copyWith(right: 0),
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: const Color(0xFF091F1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          children: [
            // Left skeleton text blocks
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: 120, color: Colors.grey),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 160, color: Colors.grey),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 100, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right image block
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
