import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PlaceCard extends StatelessWidget {
  const PlaceCard({super.key, required this.title, required this.address, required this.imageUrl});
  final String title;
  final String address;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(12);

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: const Color(0xff091F1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // ---------- Column = image + glass panel ----------
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image with bottom fade (so it blends into the smudge)
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.transparent, Colors.black],
                    stops: [0.0, 0.22], // fade only the bottom ~22%
                  ).createShader(Rect.fromLTWH(0, 0, rect.width, rect.height)),
                  blendMode: BlendMode.dstIn, // apply as alpha mask
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (c, _) => const SizedBox(
                      height: 140, child: Center(child: CircularProgressIndicator())),
                    errorWidget: (c, _, __) => const SizedBox(
                      height: 140, child: Center(child: Icon(Icons.error))),
                  ),
                ),

                // ---- Glassy info panel with teal gradient ----
                Stack(
                  children: [
                    // radial corner glows behind the glass
                    Positioned(
                      bottom: -50, left: -40,
                      child: _radialGlow(const Color(0xFF3C8884), 140),
                    ),
                    Positioned(
                      bottom: -40, right: -25,
                      child: _radialGlow(const Color(0xFF4AAEAA), 150),
                    ),

                    // glass layer
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: radius, bottomRight: radius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                const Color(0xFF00332E).withOpacity(0.82),
                                const Color(0xFF3C8884).withOpacity(0.58),
                                const Color(0xFF4AAEAA).withOpacity(0.36),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: radius, bottomRight: radius),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    shadows: [
                                      Shadow(blurRadius: 6, offset: Offset(0,1), color: Colors.black26)
                                    ],
                                  )),
                              const SizedBox(height: 6),
                              Text(address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xff9DA5A5),
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ---------- Smudge bridge (overlaps image & glass) ----------
            Positioned(
              top: 140 - 22, // sits at the image bottom; adjust height as you like
              left: 0, right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: radius, bottomRight: radius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.20), // light fog on image edge
                          Colors.white.withOpacity(0.00),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // small helper for corner glow
  Widget _radialGlow(Color c, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [c, Colors.transparent],
        radius: 0.95,
      ),
    ),
  );
}
