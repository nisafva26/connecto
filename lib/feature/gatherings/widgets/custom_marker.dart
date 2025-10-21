import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Future<Uint8List> createMarkerFromInitials(String initials) async {
//   final recorder = PictureRecorder();
//   final canvas = Canvas(recorder);

//   final size = 100.0;
//   final textStyle = TextStyle(
//     color: Colors.black,
//     fontSize: 40,
//     fontWeight: FontWeight.bold,
//   );

//   final painter = TextPainter(
//     text: TextSpan(text: initials, style: textStyle),
//     textAlign: TextAlign.center,

//     textDirection: TextDirection.ltr,
//   );

//   painter.layout();

//   // Draw circle
//   final paint = Paint()..color = Color(0xFF03FFE2);
//   canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);

//   // Draw text
//   painter.paint(
//     canvas,
//     Offset((size - painter.width) / 2, (size - painter.height) / 2),
//   );

//   final picture = recorder.endRecording();
//   final img = await picture.toImage(size.toInt(), size.toInt());
//   final byteData = await img.toByteData(format: ImageByteFormat.png);
//   return byteData!.buffer.asUint8List();
// }

// Ensure you have these imports:
import 'package:flutter/services.dart';
import 'dart:math';

// Import for Random class

// Helper function to generate a stable color based on a string
Color _getColorForInitials(String initials) {
  final hash = initials.hashCode;
  final random = Random(hash); // Seed the random generator with the hash

  // Generate distinct colors (avoiding very dark/light colors)
  return Color.fromARGB(
    255,
    50 + random.nextInt(200), // R: 50-249
    50 + random.nextInt(200), // G: 50-249
    50 + random.nextInt(200), // B: 50-249
  );
}

Future<Uint8List> createMarkerFromInitials(String initials) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  // Marker Dimensions
  const markerWidth = 100.0;
  const markerHeight = 130.0;

  // Pin Head (Circle) definition
  const headRadius = 40.0;
  const headCenterY = headRadius;
  final center = Offset(markerWidth / 2, headCenterY);

  // Pin Tip location
  const tipPoint = Offset(markerWidth / 2, markerHeight - 5.0);

  // --- Style and Color ---
  // final userColor = _getColorForInitials(initials);
  final userColor = Color(0xFF082523);
  const borderColor = Colors.white;
  const borderWidth = 6.0;

  // ----------------------------------------------------
  // 1. DEFINE THE COMPLETE PIN SHAPE (Path for Shadow/Fill)
  // ----------------------------------------------------
  final pinPath = Path();
  pinPath.addArc(
    Rect.fromCircle(center: center, radius: headRadius),
    pi * 0.5, // Start from the bottom of the circle
    -pi, // Sweep 180 degrees counter-clockwise to the top
  );
  pinPath.lineTo(center.dx + headRadius,
      headCenterY); // Line back to the start of the point
  pinPath.lineTo(tipPoint.dx, tipPoint.dy); // Line down to the tip
  pinPath.lineTo(center.dx - headRadius,
      headCenterY); // Line from tip back up to the left side
  pinPath.close();

  // ----------------------------------------------------
  // 2. DRAW SHADOW
  // ----------------------------------------------------
  final shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.4)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
  canvas.drawPath(pinPath.shift(const Offset(0, 5)), shadowPaint);

  // ----------------------------------------------------
  // 3. DRAW PIN TAIL FILL (The pointed green/colored part)
  // ----------------------------------------------------
  // Define only the triangle part of the path
  final tailPath = Path();
  tailPath.moveTo(center.dx - headRadius, headCenterY);
  tailPath.lineTo(tipPoint.dx, tipPoint.dy);
  tailPath.lineTo(center.dx + headRadius, headCenterY);
  tailPath.close();

  final fillPaint = Paint()..color = userColor;
  canvas.drawPath(tailPath, fillPaint);

  // ----------------------------------------------------
  // 4. DRAW PIN HEAD FILL (The circular green/colored part)
  // ----------------------------------------------------
  // Draw the circular head fill directly
  canvas.drawCircle(center, headRadius, fillPaint);

  // ----------------------------------------------------
  // 5. DRAW WHITE BORDER (Stroke only, around the head)
  // ----------------------------------------------------
  // Draw the white stroke for the circle head on top of the fill
  final borderPaint = Paint()
    ..color = borderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = borderWidth;

  canvas.drawCircle(center, headRadius - (borderWidth / 2), borderPaint);

  // ----------------------------------------------------
  // 6. DRAW TEXT
  // ----------------------------------------------------
  final textStyle = TextStyle(
    color: Colors.white,
    fontSize: 36,
    fontWeight: FontWeight.bold,
    shadows: [
      Shadow(
        color: Colors.black.withOpacity(0.5),
        offset: const Offset(1, 1),
        blurRadius: 2,
      ),
    ],
  );

  final painter = TextPainter(
    text: TextSpan(text: initials, style: textStyle),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  );
  painter.layout();

  painter.paint(
    canvas,
    Offset(center.dx - painter.width / 2, headCenterY - painter.height / 2),
  );

  // --- Finalize ---
  final picture = recorder.endRecording();
  final img = await picture.toImage(markerWidth.toInt(), markerHeight.toInt());
  final byteData = await img.toByteData(format: ImageByteFormat.png);

  return byteData!.buffer.asUint8List();
}


Future<Uint8List> createMarkerFromActivity(String activity) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  // === Marker Dimensions (same as initials) ===
  const markerWidth = 100.0;
  const markerHeight = 130.0;
  const headRadius = 40.0;
  const headCenterY = headRadius;
  final center = Offset(markerWidth / 2, headCenterY);
  const tipPoint = Offset(markerWidth / 2, markerHeight - 5.0);

  // === Colors ===
  const userColor = Color(0xFF082523);
  const borderColor = Colors.white;
  const borderWidth = 6.0;

  // === Pin Shape ===
  final pinPath = Path()
    ..addArc(Rect.fromCircle(center: center, radius: headRadius), pi * 0.5, -pi)
    ..lineTo(center.dx + headRadius, headCenterY)
    ..lineTo(tipPoint.dx, tipPoint.dy)
    ..lineTo(center.dx - headRadius, headCenterY)
    ..close();

  // === Shadow ===
  final shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.4)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
  canvas.drawPath(pinPath.shift(const Offset(0, 5)), shadowPaint);

  // === Tail Fill ===
  final tailPath = Path()
    ..moveTo(center.dx - headRadius, headCenterY)
    ..lineTo(tipPoint.dx, tipPoint.dy)
    ..lineTo(center.dx + headRadius, headCenterY)
    ..close();
  final fillPaint = Paint()..color = userColor;
  canvas.drawPath(tailPath, fillPaint);

  // === Head Fill ===
  canvas.drawCircle(center, headRadius, fillPaint);

  // === Border ===
  final borderPaint = Paint()
    ..color = borderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = borderWidth;
  canvas.drawCircle(center, headRadius - (borderWidth / 2), borderPaint);

  // === Icon Selection ===
  final iconData = _getActivityIcon(activity);

  // === Draw Icon ===
  final textPainter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
        fontSize: 42,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(1, 1),
            blurRadius: 2,
          ),
        ],
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(center.dx - textPainter.width / 2, headCenterY - textPainter.height / 2),
  );

  // === Finalize ===
  final picture = recorder.endRecording();
  final img = await picture.toImage(markerWidth.toInt(), markerHeight.toInt());
  final byteData = await img.toByteData(format: ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

// ------------------------------------------------------
// Icon Mapper: choose based on activity keyword
// ------------------------------------------------------
IconData _getActivityIcon(String activity) {
  final lower = activity.toLowerCase();
  if (lower.contains('coffee')) return Icons.local_cafe_rounded;
  if (lower.contains('padel')) return Icons.sports_tennis_rounded;
  if (lower.contains('macha')) return Icons.emoji_people_rounded;
  if (lower.contains('running') || lower.contains('run')) return Icons.directions_run_rounded;
  if (lower.contains('football')) return Icons.sports_soccer_rounded;
  if (lower.contains('birthday')) return Icons.cake_rounded;
  if (lower.contains('sheesha') || lower.contains('shisha')) return Icons.smoking_rooms_rounded;
  return Icons.place_rounded; // fallback
}


Future<Uint8List> createRectangularMarker(String placeName) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  // --- Dimensions ---
  const double width = 220.0;   // Wider marker
  const double height = 90.0;   // Rectangle height
  const double tipHeight = 40.0; // Triangle pointer height
  const double borderRadius = 20.0;

  // Colors
  const bgColor = Color(0xFF082523);
  const borderColor = Colors.white;
  const borderWidth = 4.0;

  // Shadow
  final shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.3)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

  // Base rectangle with rounded corners
  final rect = RRect.fromLTRBR(
    0,
    0,
    width,
    height,
    const Radius.circular(borderRadius),
  );

  // Draw shadow (slightly offset)
  canvas.drawRRect(rect.shift(const Offset(0, 3)), shadowPaint);

  // Draw background
  final bgPaint = Paint()..color = bgColor;
  canvas.drawRRect(rect, bgPaint);

  // Draw border
  final borderPaint = Paint()
    ..color = borderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = borderWidth;
  canvas.drawRRect(rect.deflate(borderWidth / 2), borderPaint);

  // --- Draw tip triangle ---
  final tipPath = Path()
    ..moveTo(width / 2 - 10, height)
    ..lineTo(width / 2 + 10, height)
    ..lineTo(width / 2, height + tipHeight)
    ..close();
  canvas.drawPath(tipPath, bgPaint);
  canvas.drawPath(tipPath, borderPaint);

  // --- Draw text ---
  final textStyle = const TextStyle(
    color: Colors.white,
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  final textPainter = TextPainter(
    text: TextSpan(text: placeName, style: textStyle),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  );
  textPainter.layout(maxWidth: width - 20);

  // Center text
  textPainter.paint(
    canvas,
    Offset(
      (width - textPainter.width) / 2,
      (height - textPainter.height) / 2,
    ),
  );

  // --- Finalize ---
  final totalHeight = height + tipHeight;
  final picture = recorder.endRecording();
  final image = await picture.toImage(width.toInt(), totalHeight.toInt());
  final byteData = await image.toByteData(format: ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}


Future<Uint8List> createMarkerFromPlaceName(String placeName) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);

  // === MARKER SCALE SETTINGS ===
  // Try these first; adjust scaleFactor if still cramped
  const scaleFactor = 1.3; // Increase this to make bigger markers (1.0 = normal)
  final headRadius = 40.0 * scaleFactor;
  final markerWidth = 100.0 * scaleFactor;
  final markerHeight = 130.0 * scaleFactor;

  final headCenterY = headRadius;
  final center = Offset(markerWidth / 2, headCenterY);
  final tipPoint = Offset(markerWidth / 2, markerHeight - 5.0);

  // === COLORS & STYLES ===
  const userColor = Color(0xFF082523);
  const borderColor = Colors.white;
  const borderWidth = 6.0 * scaleFactor;

  // === SHAPE PATH ===
  final pinPath = Path()
    ..addArc(Rect.fromCircle(center: center, radius: headRadius), pi * 0.5, -pi)
    ..lineTo(center.dx + headRadius, headCenterY)
    ..lineTo(tipPoint.dx, tipPoint.dy)
    ..lineTo(center.dx - headRadius, headCenterY)
    ..close();

  // SHADOW
  final shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.4)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 * scaleFactor);
  canvas.drawPath(pinPath.shift(Offset(0, 5 * scaleFactor)), shadowPaint);

  // TAIL (bottom triangle)
  final tailPath = Path()
    ..moveTo(center.dx - headRadius, headCenterY)
    ..lineTo(tipPoint.dx, tipPoint.dy)
    ..lineTo(center.dx + headRadius, headCenterY)
    ..close();
  final fillPaint = Paint()..color = userColor;
  canvas.drawPath(tailPath, fillPaint);

  // HEAD (circle)
  canvas.drawCircle(center, headRadius, fillPaint);

  // BORDER
  final borderPaint = Paint()
    ..color = borderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = borderWidth;
  canvas.drawCircle(center, headRadius - (borderWidth / 2), borderPaint);

  // === TEXT (auto-fit multi-line) ===
  const maxLines = 3;
  final padding = 14.0 * scaleFactor;
  final maxTextWidth = (headRadius * 2) - padding * 2;
  final maxTextHeight = (headRadius * 2) - padding * 2;

  double fontSize = 20.0 * scaleFactor;
  const minFontSize = 10.0;

  TextPainter painter;
  const baseStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    shadows: [
      Shadow(color: Color(0x80000000), offset: Offset(1, 1), blurRadius: 2),
    ],
  );

  while (true) {
    final firstWord = placeName.trim().split(RegExp(r'\s+')).first;
    final textStyle = baseStyle.copyWith(fontSize: fontSize);
    painter = TextPainter(
      text: TextSpan(text: firstWord, style: textStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      
      // ellipsis: '…',
    );
    painter.layout(maxWidth: maxTextWidth);

    final fits = painter.height <= maxTextHeight;
    if (fits) break;

    fontSize -= 1.0;
    if (fontSize < minFontSize) {
      fontSize = minFontSize;
      painter.layout(maxWidth: maxTextWidth);
      break;
    }
  }

  painter.paint(
    canvas,
    Offset(center.dx - painter.width / 2, headCenterY - painter.height / 2),
  );

  // === FINALIZE ===
  final picture = recorder.endRecording();
  final img = await picture.toImage(markerWidth.toInt(), markerHeight.toInt());
  final byteData = await img.toByteData(format: ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}




// Future<Uint8List> createMarkerFromPlaceName(String placeName) async {
//   final recorder = PictureRecorder();
//   final canvas = Canvas(recorder);

//   // --- Match EXACT dimensions & style of createMarkerFromInitials ---
//   const markerWidth = 100.0;
//   const markerHeight = 130.0;

//   const headRadius = 40.0;
//   const headCenterY = headRadius;
//   final center = Offset(markerWidth / 2, headCenterY);

//   const tipPoint = Offset(markerWidth / 2, markerHeight - 5.0);

//   // Colors/border same as initials marker
//   const userColor = Color(0xFF082523);
//   const borderColor = Colors.white;
//   const borderWidth = 6.0;

//   // 1) Full pin path (for shadow offset)
//   final pinPath = Path()
//     ..addArc(
//       Rect.fromCircle(center: center, radius: headRadius),
//       pi * 0.5,
//       -pi,
//     )
//     ..lineTo(center.dx + headRadius, headCenterY)
//     ..lineTo(tipPoint.dx, tipPoint.dy)
//     ..lineTo(center.dx - headRadius, headCenterY)
//     ..close();

//   // 2) Shadow (same)
//   final shadowPaint = Paint()
//     ..color = Colors.black.withOpacity(0.4)
//     ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
//   canvas.drawPath(pinPath.shift(const Offset(0, 5)), shadowPaint);

//   // 3) Tail fill (triangle only) — same style as initials marker
//   final tailPath = Path()
//     ..moveTo(center.dx - headRadius, headCenterY)
//     ..lineTo(tipPoint.dx, tipPoint.dy)
//     ..lineTo(center.dx + headRadius, headCenterY)
//     ..close();
//   final fillPaint = Paint()..color = userColor;
//   canvas.drawPath(tailPath, fillPaint);

//   // 4) Head fill (circle) — same
//   canvas.drawCircle(center, headRadius, fillPaint);

//   // 5) White circular border — same
//   final borderPaint = Paint()
//     ..color = borderColor
//     ..style = PaintingStyle.stroke
//     ..strokeWidth = borderWidth;
//   canvas.drawCircle(center, headRadius - (borderWidth / 2), borderPaint);

//   // 6) Place name text — auto-fit into the circle
//   //    Try to keep bold, shrink font down until it fits height & lines.
//   const maxLines = 3;
//   const padding = 12.0; // inner padding so text doesn't touch border
//   final maxTextWidth = (headRadius * 2) - padding * 2;
//   final maxTextHeight = (headRadius * 2) - padding * 2;

//   // Start a bit smaller than initials (since it's multi-word)
//   double fontSize = 26.0;
//   const minFontSize = 10.0;

//   TextPainter painter;
//   TextStyle baseStyle = const TextStyle(
//     color: Colors.white,
//     fontWeight: FontWeight.bold,
//     // Keep the same subtle shadow as initials for parity
//     shadows: [
//       Shadow(
//         color: Color(0x80000000),
//         offset: Offset(1, 1),
//         blurRadius: 2,
//       ),
//     ],
//   );

//   while (true) {
//     final textStyle = baseStyle.copyWith(fontSize: fontSize);
//     painter = TextPainter(
//       text: TextSpan(text: placeName, style: textStyle),
//       textAlign: TextAlign.center,
//       textDirection: TextDirection.ltr,
//       maxLines: maxLines,
//       ellipsis: '…',
//     );
//     painter.layout(maxWidth: maxTextWidth);

//     final fitsHeight = painter.height <= maxTextHeight;
//     final fitsLines = !painter.didExceedMaxLines;

//     if (fitsHeight && fitsLines) break;

//     fontSize -= 1.0;
//     if (fontSize < minFontSize) {
//       // Stop shrinking; will ellipsize within maxLines.
//       painter = TextPainter(
//         text: TextSpan(text: placeName, style: baseStyle.copyWith(fontSize: minFontSize)),
//         textAlign: TextAlign.center,
//         textDirection: TextDirection.ltr,
//         maxLines: maxLines,
//         ellipsis: '…',
//       );
//       painter.layout(maxWidth: maxTextWidth);
//       break;
//     }
//   }

//   painter.paint(
//     canvas,
//     Offset(
//       center.dx - painter.width / 2,
//       headCenterY - painter.height / 2,
//     ),
//   );

//   // --- Finalize ---
//   final picture = recorder.endRecording();
//   final img = await picture.toImage(markerWidth.toInt(), markerHeight.toInt());
//   final byteData = await img.toByteData(format: ImageByteFormat.png);
//   return byteData!.buffer.asUint8List();
// }


// Future<Uint8List> createMarkerFromPlaceName(String placeName) async {
//   final recorder = PictureRecorder();
//   final canvas = Canvas(recorder);

//   // --- Marker Dimensions (Increased Head Size) ---
//   const headRadius = 50.0; // Increased radius to fit more text
//   const markerWidth = headRadius * 2;
//   const markerHeight = markerWidth + (headRadius / 2); // Adjusted for pin shape

//   // Pin Head (Circle) definition
//   const headCenterY = headRadius;
//   final center = Offset(markerWidth / 2, headCenterY);

//   // Pin Tip location
//   const tipPoint = Offset(markerWidth / 2, markerHeight - 5.0);

//   // --- Style and Color ---
//   final userColor = Color(0xFF082523); // Use placeName for color generation
//   const borderColor = Colors.white;
//   const borderWidth = 6.0;

//   // ----------------------------------------------------
//   // 1. DEFINE THE COMPLETE PIN SHAPE (Path for Shadow/Fill)
//   // ----------------------------------------------------
//   final pinPath = Path();
//   pinPath.addArc(
//     Rect.fromCircle(center: center, radius: headRadius),
//     pi * 0.5, // Start from the bottom of the circle
//     -pi, // Sweep 180 degrees counter-clockwise to the top
//   );
//   pinPath.lineTo(center.dx + headRadius, headCenterY);
//   pinPath.lineTo(tipPoint.dx, tipPoint.dy);
//   pinPath.lineTo(center.dx - headRadius, headCenterY);
//   pinPath.close();

//   // ----------------------------------------------------
//   // 2. DRAW SHADOW
//   // ----------------------------------------------------
//   final shadowPaint = Paint()
//     ..color = Colors.black.withOpacity(0.4)
//     ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
//   canvas.drawPath(pinPath.shift(const Offset(0, 5)), shadowPaint);

//   // ----------------------------------------------------
//   // 3. DRAW PIN FILL (The colored part)
//   // ----------------------------------------------------
//   final fillPaint = Paint()..color = userColor;
//   canvas.drawPath(pinPath, fillPaint);

//   // ----------------------------------------------------
//   // 4. DRAW WHITE BORDER (Stroke only, around the head)
//   // ----------------------------------------------------
//   final borderPaint = Paint()
//     ..color = borderColor
//     ..style = PaintingStyle.stroke
//     ..strokeWidth = borderWidth;

//   canvas.drawCircle(center, headRadius - (borderWidth / 2), borderPaint);

//   // ----------------------------------------------------
//   // 5. DRAW TEXT (Adjusted for Place Name)
//   // ----------------------------------------------------
//   // Use a smaller font size and set the text to wrap
//   const fontSize = 20.0;
//   const maxLines = 3; // Allow up to 3 lines

//   final textStyle = TextStyle(
//     color: Colors.white,
//     fontSize: fontSize,
//     fontWeight: FontWeight.bold,
//     shadows: [
//       Shadow(
//         color: Colors.black.withOpacity(0.5),
//         offset: const Offset(1, 1),
//         blurRadius: 2,
//       ),
//     ],
//   );

//   final painter = TextPainter(
//     text: TextSpan(text: placeName, style: textStyle),
//     textAlign: TextAlign.center,
//     textDirection: TextDirection.ltr,
//     maxLines: maxLines, // Set maximum lines for safety
//   );

//   // Layout the text, constraining its width to fit within the circle
//   // We use the circle's diameter minus some padding (e.g., 20.0)
//   final textMaxWidth = markerWidth - 20.0;
//   painter.layout(maxWidth: textMaxWidth);

//   // Calculate the vertical offset to center the multi-line text
//   painter.paint(
//     canvas,
//     Offset(
//       center.dx - painter.width / 2,
//       headCenterY - painter.height / 2, // Centered vertically
//     ),
//   );

//   // --- Finalize ---
//   final picture = recorder.endRecording();
//   final img = await picture.toImage(markerWidth.toInt(), markerHeight.toInt());
//   final byteData = await img.toByteData(format: ImageByteFormat.png);

//   return byteData!.buffer.asUint8List();
// }

// Future<Uint8List> createMarkerFromInitials(String initials) async {
//   final recorder = PictureRecorder();
//   final canvas = Canvas(recorder);

//   // Marker Dimensions
//   const markerWidth = 100.0;
//   const markerHeight = 130.0; // Increased height slightly to accommodate the tip
  
//   // Pin Head (Circle) definition
//   const headRadius = 40.0;
//   // Center is slightly lower than radius to give space for the point
//   const headCenterY = headRadius; 
//   final center = Offset(markerWidth / 2, headCenterY);
  
//   // Pin Tip (where it points on the map)
//   const tipPoint = Offset(markerWidth / 2, markerHeight - 5.0); // Tip location

//   // --- Style and Color ---
//   final userColor = _getColorForInitials(initials);
//   const borderColor = Colors.white;
//   const borderWidth = 6.0;
  
//   // --- Pin Shape (Path) ---
//   final pinPath = Path();
  
//   // 1. Start the Path at the top-left edge of the circle's bounding box
//   pinPath.moveTo(center.dx - headRadius, headCenterY);

//   // 2. Draw the main circle head using an arc (180 degrees) and then the connecting line
//   pinPath.arcTo(
//     Rect.fromCircle(center: center, radius: headRadius), 
//     pi, // Start angle (left side of circle)
//     -pi, // Sweep angle (180 degrees counter-clockwise to the right side)
//     false, // forceMoveTo: false
//   );
  
//   // 3. Draw the bottom triangular segment
//   // Line from right edge of circle (end of arc) down to the tip
//   pinPath.lineTo(tipPoint.dx, tipPoint.dy); 
  
//   // Line from the tip back up to the left edge of the circle (start of the arc)
//   pinPath.lineTo(center.dx - headRadius, headCenterY); 

//   pinPath.close(); // Close the path for a perfect fill

//   // --- Drawing Steps ---

//   // 4. Draw Shadow (using the corrected path)
//   final shadowPaint = Paint()
//     ..color = Colors.black.withOpacity(0.4)
//     ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
//   canvas.drawPath(pinPath.shift(const Offset(0, 5)), shadowPaint);

//   // 5. Draw the main pin body (Fill) - This will now fill the entire defined shape
//   final fillPaint = Paint()..color = userColor;
//   canvas.drawPath(pinPath, fillPaint);

//   // 6. Draw the white border around the pin head (only the circle part)
//   final borderPaint = Paint()
//     ..color = borderColor
//     ..style = PaintingStyle.stroke
    
//     ..strokeWidth = borderWidth;
  
//   // Only draw the white stroke for the circle head, not the whole pin body
//   canvas.drawCircle(center, headRadius - (borderWidth / 2), borderPaint);


//   // 7. Draw the text (Initials) - Centered in the head
//   final textStyle = TextStyle(
//     color: Colors.white, 
//     fontSize: 36, 
//     fontWeight: FontWeight.bold,
//     shadows: [
//       Shadow(
//         color: Colors.black.withOpacity(0.5),
//         offset: const Offset(1, 1),
//         blurRadius: 2,
//       ),
//     ],
//   );

//   final painter = TextPainter(
//     text: TextSpan(text: initials, style: textStyle),
//     textAlign: TextAlign.center,
//     textDirection: TextDirection.ltr,
//   );
//   painter.layout();

//   painter.paint(
//     canvas,
//     Offset(center.dx - painter.width / 2, headCenterY - painter.height / 2),
//   );

//   // --- Finalize ---
//   final picture = recorder.endRecording();
//   final img = await picture.toImage(markerWidth.toInt(), markerHeight.toInt());
//   final byteData = await img.toByteData(format: ImageByteFormat.png);
  
//   return byteData!.buffer.asUint8List();
// }



// ... (include the _getColorForInitials function above this one)

// Future<Uint8List> createMarkerFromInitials(String initials) async {
//   final recorder = PictureRecorder();
//   final canvas = Canvas(recorder);

//   final size = 100.0;
//   final radius = size / 2;
//   final center = Offset(radius, radius);
  
//   // 🆕 1. Generate stable color for this user
//   final userColor = _getColorForInitials(initials);
//   const borderColor = Colors.white;
//   const borderWidth = 6.0;

//   // --- Drawing Steps ---
  
//   // 🆕 2. Draw a subtle drop shadow for depth
//   final shadowPaint = Paint()
//     ..color = Colors.black.withOpacity(0.3)
//     ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5.0);
//   canvas.drawCircle(center + const Offset(0, 3), radius, shadowPaint);


//   // 🆕 3. Draw the background color circle (the primary color)
//   final fillPaint = Paint()..color = userColor;
//   canvas.drawCircle(center, radius, fillPaint);


//   // 🆕 4. Draw the white border circle
//   final borderPaint = Paint()
//     ..color = borderColor
//     ..style = PaintingStyle.stroke
//     ..strokeWidth = borderWidth;
//   canvas.drawCircle(center, radius - (borderWidth / 2), borderPaint);


//   // 🆕 5. Prepare Text
//   final textStyle = TextStyle(
//     // 💡 Use white text for better contrast against generated colors
//     color: Colors.white, 
//     fontSize: 40,
//     fontWeight: FontWeight.bold,
//     // Add a slight shadow to the text for readability
//     shadows: [
//       Shadow(
//         color: Colors.black.withOpacity(0.5),
//         offset: const Offset(1, 1),
//         blurRadius: 2,
//       ),
//     ],
//   );

//   final painter = TextPainter(
//     text: TextSpan(text: initials, style: textStyle),
//     textAlign: TextAlign.center,
//     textDirection: TextDirection.ltr,
//   );
//   painter.layout();

//   // 6. Draw text
//   painter.paint(
//     canvas,
//     Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
//   );

//   final picture = recorder.endRecording();
//   final img = await picture.toImage(size.toInt(), size.toInt());
//   final byteData = await img.toByteData(format: ImageByteFormat.png);
  
//   return byteData!.buffer.asUint8List();
// }
