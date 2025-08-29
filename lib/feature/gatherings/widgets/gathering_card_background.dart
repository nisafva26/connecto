import 'dart:ui';
import 'package:flutter/material.dart';

class GatheringCardBackground extends StatelessWidget {
  const GatheringCardBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: Stack(
        children: [
          // 1) Base diagonal teal gradient (matches Figma tone)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.85, -0.85), // top-left
                end: Alignment(0.9, 0.9),        // bottom-right
                colors: [
                  Color(0xFF0B2625), // deep teal
                  Color(0xFF1F4846),
                  Color(0xFF2E5E5B),
                  Color(0xFF3C7270), // lighter teal
                ],
                stops: [0.0, 0.35, 0.68, 1.0],
              ),
            ),
          ),

          // 2) Glow blob — bottom-left (teal)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.85, 1.05), // slightly out of frame
                    radius: 0.95,
                    colors: [
                      Color(0xFF3C8884), // inner glow
                      Color(0x003C8884), // fade to transparent
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 2) Glow blob — bottom-right (aqua)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(1.05, 0.95), // bottom-right corner
                    radius: 0.9,
                    colors: [
                      Color(0x664AAEAA), // softer than solid to avoid wash-out
                      Color(0x004AAEAA),
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3) Subtle edge vignette for depth (transparent middle → dark edges)
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (rect) => const RadialGradient(
                center: Alignment(0.2, 0.1), // a tiny bias to the title area
                radius: 1.2,
                colors: [Colors.transparent, Color(0xAA000000)],
                stops: [0.65, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.darken,
              child: const ColoredBox(color: Colors.black),
            ),
          ),

          // Optional: tiny blur to get that frosted softness
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: const SizedBox.expand(),
          ),

          // Your content
          Container(
            // keep a light inner shadow feel
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000), // 15% black
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}
