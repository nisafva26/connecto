import 'package:flutter/material.dart';

class PingVisualizerChat extends StatelessWidget {
  final List<int> pattern;

  PingVisualizerChat({required this.pattern});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: pattern.map((duration) {
        return Container(
          width: duration / 8, // Scale for UI
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
