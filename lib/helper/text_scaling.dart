import 'package:flutter/widgets.dart';

extension TextScaling on BuildContext {
  double scaleText(double baseSize) {
    double screenWidth = MediaQuery.of(this).size.width;
    return (screenWidth / 360) * baseSize; // 360 is base design width
  }
}
