import 'package:flutter/material.dart';

class PingVisualizer extends StatelessWidget {
  final List<int> pattern;

  PingVisualizer({required this.pattern});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: pattern.map((duration) {
        return Container(
          width: duration / 4, // Scale for UI
          height: 5,
          margin: EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }).toList(),
    );
  }
}
