import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

Widget buildCategoryGridShimmer() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(height: 36),
      Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade800,
          highlightColor: Colors.grey.shade700,
          child: Container(
            height: 20,
            width: 150,
            color: Colors.white,
          ),
        ),
      ),
      SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade800,
          highlightColor: Colors.grey.shade700,
          child: Container(
            height: 14,
            width: 240,
            color: Colors.white,
          ),
        ),
      ),
      SizedBox(height: 16),
      Container(
        height: 265,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(right: 16, left: index == 0 ? 20 : 0),
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade800,
                highlightColor: Colors.grey.shade700,
                child: Container(
                  width: 200,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 160,
                        width: double.infinity,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 20),
                      Container(
                        height: 14,
                        width: 120,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 4),
                      Container(
                        height: 12,
                        width: 100,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
