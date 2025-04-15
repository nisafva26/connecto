import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<Uint8List> createMarkerFromInitials(String initials) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  final size = 100.0;
  final textStyle = TextStyle(
    color: Colors.black,
    fontSize: 40,
    fontWeight: FontWeight.bold,
  );

  final painter = TextPainter(
    text: TextSpan(text: initials, style: textStyle),
    textAlign: TextAlign.center,
    
    textDirection: TextDirection.ltr,
  );

  painter.layout();

  // Draw circle
  final paint = Paint()..color = Color(0xFF03FFE2);
  canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);

  // Draw text
  painter.paint(
    canvas,
    Offset((size - painter.width) / 2, (size - painter.height) / 2),
  );

  final picture = recorder.endRecording();
  final img = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await img.toByteData(format: ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
