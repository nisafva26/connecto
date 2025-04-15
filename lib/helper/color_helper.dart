import 'dart:ui';

import 'package:flutter/material.dart';

String colorToHex(Color color) {
  return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
}

Color hexToColor(String hex) {
  hex = hex.replaceAll("#", ""); // Remove # if present
  return Color(int.parse("0xFF$hex"));
}

Color getTextColor(Color color) {
  return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
