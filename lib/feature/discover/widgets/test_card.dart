import 'package:flutter/material.dart';
import 'dart:ui';


class PadelEventCard extends StatelessWidget {
  const PadelEventCard({
    super.key,
    this.onTap,
    required this.imageProvider,
  });

  final VoidCallback? onTap;
  final ImageProvider imageProvider;

  // Extracted colors sampled from the mock (teal glass gradient + UI neutrals)
  static const _bgDark = Color(0xFF0C1C1A); // card background
  static const _pillBg = Color(0xFFE8F2FF); // light blue chip bg
  static const _pillText = Color(0xFF1E76FF); // chip text blue
  static const _title = Color(0xFFEAF0EE); // near-white title
  static const _meta = Color(0xFF9DA5A5); // subtitle grey
  static const _icon = Color(0xFFB8C4C3); // subtle icon tint

  // Gradient sampled/approximated from the image footer (teal/green glass)
  static const List<Color> _glassStops = <Color>[
    Color(0x00000000), // transparent at top of the overlay
    Color(0xCC163733), // ~ 0.6 opacity deep teal (#163733)
    Color(0xF01A3F3A), // ~ 0.94 opacity teal (#1A3F3A)
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 300,
        width: 230,
        decoration: BoxDecoration(
          color: _bgDark,
          borderRadius: BorderRadius.circular(22),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background photo
            Image(
              height: 150,
              image: imageProvider,
              fit: BoxFit.cover,
            ),

            // Pill: spots left
            Positioned(
              top: 14,
              left: 14,
              child: _SpotsLeftPill(
                text: '2 spots left',
              ),
            ),

            // Bottom glass gradient + blur
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 222,
              child: _BottomGlass(),
            ),

            // Content
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: _CardBody(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomGlass extends StatelessWidget {
  const _BottomGlass();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient veil
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.10, 0.58, 1.0],
              colors: PadelEventCard._glassStops,
            ),
          ),
        ),
        // Subtle blur to get that glassy, diffused look
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

class _CardBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      color: PadelEventCard._title,
      fontWeight: FontWeight.w700,
      fontSize: 24,
      height: 1.15,
    );
    const metaStyle = TextStyle(
      color: PadelEventCard._meta,
      fontWeight: FontWeight.w500,
      fontSize: 16,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Padel dubai', style: titleStyle),
        const SizedBox(height: 10),
        Row(
          children: const [
            Icon(Icons.location_on_rounded, size: 18, color: PadelEventCard._icon),
            SizedBox(width: 8),
            Text('Umm Suqeim', style: metaStyle),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: const [
            Icon(Icons.access_time_filled_rounded, size: 18, color: PadelEventCard._icon),
            SizedBox(width: 8),
            Text('7 PM - 09 Sep 2024', style: metaStyle),
          ],
        ),
        const SizedBox(height: 14),
        // const _AvatarRow(),
      ],
    );
  }
}

class _AvatarRow extends StatelessWidget {
  const _AvatarRow();

  @override
  Widget build(BuildContext context) {
    final avatars = [
      const NetworkImage('https://images.unsplash.com/photo-1531123414780-f7423f1a4d9c?w=96'),
      const NetworkImage('https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=96'),
      const NetworkImage('https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=96'),
      const NetworkImage('https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?w=96'),
    ];

    final chips = <Widget>[];
    for (var i = 0; i < avatars.length; i++) {
      chips.add(Positioned(
        left: i * 34.0,
        child: _Avatar(image: avatars[i]),
      ));
    }

    chips.add(Positioned(
      left: avatars.length * 34.0,
      child: const _PlusTwo(),
    ));

    return SizedBox(
      height: 40,
      width: (avatars.length + 1) * 34 + 26,
      child: Stack(children: chips),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.image});
  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
        image: DecorationImage(image: image, fit: BoxFit.cover),
      ),
    );
  }
}

class _PlusTwo extends StatelessWidget {
  const _PlusTwo();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        '+2',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF2B2B2B),
        ),
      ),
    );
  }
}

class _SpotsLeftPill extends StatelessWidget {
  const _SpotsLeftPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: PadelEventCard._pillBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: PadelEventCard._pillText,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}
