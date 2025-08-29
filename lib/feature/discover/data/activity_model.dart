import 'package:flutter/material.dart';

class Activity {
  final String name;
  final List<Color> gradient; // light → mid → dark
  final String? asset;        // top artwork (optional PNG/SVG)
  final Alignment imageAlign; // where the art sits

  const Activity({
    required this.name,
    required this.gradient,
    this.asset,
    this.imageAlign = Alignment.topLeft,
  });
}

// tuned to the screenshot palette
const activitiesNew = <Activity>[
  Activity(
    name: 'Football',
    gradient: [
      Color(0xFFF38BF5), // pink
      Color(0xFFB374FF), // violet mid
      Color(0xFF6A5AED), // deep purple bottom
    ],
    asset: 'assets/images/football.png',
    imageAlign: Alignment.topLeft,
  ),
  Activity(
    name: 'Running',
    gradient: [
      Color(0xFFFF8A7A), // coral
      Color(0xFFCB8AA0), // warm mauve
      Color(0xFF9FB3C9), // cool grey-blue bottom
    ],
    asset: 'assets/images/running_leg.png',
    imageAlign: Alignment.topCenter,
  ),
  Activity(
    name: 'Matcha',
    gradient: [
      Color(0xFF5CF0C9), // mint
      Color(0xFF39D8C0),
      Color(0xFF3BA6D4),
    ],
    asset: 'assets/images/running_leg.png',
    imageAlign: Alignment.topRight,
  ),
];
