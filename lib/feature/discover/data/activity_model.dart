import 'package:flutter/material.dart';

class Activity {
  final String name;
  final List<Color> gradient; // light → mid → dark
  final String? asset;        // top artwork (optional PNG/SVG)
  final Alignment imageAlign; // where the art sits
  final String? backgroundImage;

  const Activity({
    required this.name,
    required this.gradient,
    this.asset,
    this.imageAlign = Alignment.topLeft,
    this.backgroundImage
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
    asset: 'assets/images/football_new.png',
    imageAlign: Alignment.topLeft,
    backgroundImage: 'assets/images/football_bg.png'
  ),
  Activity(
    name: 'Running',
    gradient: [
      Color(0xFFFF8A7A), // coral
      Color(0xFFCB8AA0), // warm mauve
      Color(0xFF9FB3C9), // cool grey-blue bottom
    ],
    asset: 'assets/images/running.png',
    imageAlign: Alignment.topCenter,
    backgroundImage: 'assets/images/running_bg.png'
  ),
  Activity(
    name: 'Matcha',
    gradient: [
      Color(0xFF5CF0C9), // mint
      Color(0xFF39D8C0),
      Color(0xFF3BA6D4),
    ],
    asset: 'assets/images/macha.png',
    imageAlign: Alignment.topRight,
    backgroundImage: 'assets/images/macha_bg.png'
  ),
   Activity(
    name: 'Padel',
    gradient: [
      Color(0xFF5CF0C9), // mint
      Color(0xFF39D8C0),
      Color(0xFF3BA6D4),
    ],
    asset: 'assets/images/padel.png',
    imageAlign: Alignment.topRight,
    backgroundImage: 'assets/images/padel_bg.png'
  ),
   Activity(
    name: 'Coffee',
    gradient: [
      Color(0xFF5CF0C9), // mint
      Color(0xFF39D8C0),
      Color(0xFF3BA6D4),
    ],
    asset: 'assets/images/coffee.png',
    imageAlign: Alignment.topRight,
    backgroundImage: 'assets/images/coffee_bg.png'
  ),
];
