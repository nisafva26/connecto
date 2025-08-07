import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LocationSearchCardSkeleton extends StatelessWidget {
  const LocationSearchCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 23, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // border: Border.all(color: Colors.red)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 20),
            // Title placeholder
            Container(
              height: 20,
              width: 150,
              color: Colors.grey.shade700,
            ),
            const SizedBox(height: 14),
            // Location placeholder
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Container(
                  height: 14,
                  width: 200,
                  color: Colors.grey.shade700,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Container(
                  height: 14,
                  width: 100,
                  color: Colors.grey.shade700,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
