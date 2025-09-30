import 'package:connecto/feature/discover/data/activity_model.dart';
import 'package:flutter/material.dart';

// ---------- card ----------
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.data,
    required this.isSelected,
    this.onTap,
    this.parallax = 0.0, // -1..1 (left..right of center)
  });

  final Activity data;
  final bool isSelected;
  final VoidCallback? onTap;
  final double parallax;

  @override
  Widget build(BuildContext context) {
    //  final newParallax = -parallax * 15;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.only(topRight: Radius.circular(12)),
        child: AnimatedContainer(
          duration:  Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 149,
          height: 280,
          decoration: BoxDecoration(
            image: DecorationImage(image: AssetImage(data.backgroundImage!),fit: BoxFit.cover),
            borderRadius: BorderRadius.circular(12),
            
            // gradient: LinearGradient(
            //   begin: Alignment.topLeft,
            //   end: Alignment.bottomCenter,
            //   colors: data.gradient,
            //   stops: const [0.0, 0.55, 1.0],
            // ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              // if (isSelected)
              //   const BoxShadow(
              //     color: Color(0x8003FFE2),
              //     blurRadius: 22,
              //     spreadRadius: 1.5,
              //   ),
            ],
          ),
          child: Stack(
            children: [
              // dotted texture (move slightly opposite for depth)
              // Positioned.fill(
              //   bottom: 0,
              //   child: Transform.translate(
              //     offset: Offset(-parallax * 6, 0),
              //     child: const _DotOverlay(),
              //   ),
              // ),
        
              // soft bottom fade
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.10),
                        Colors.black.withOpacity(0.22),
                      ],
                      stops: const [0.4, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
        
              // hero art (foreground moves more)
              if (data.asset != null)
                Positioned(
                  top: -10,
                  right: -10,
                  child: Transform.translate(
                    
                    offset: Offset(parallax * 16, 0),
                    child: Image.asset(
                      data.asset!,
                      width: 109,
                      height: 109,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
        
              // label (stable)
              Positioned(
                  left: 16,
                  right: 20,
                  bottom: 18,
                  child: Text(
                    data.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'SFPRO',
                      fontSize: 20,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                            blurRadius: 4,
                            color: Color(0x55000000),
                            offset: Offset(0, 2)),
                      ],
                    ),
                  ) // extract if you like
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel();

  @override
  Widget build(BuildContext context) {
    // use DefaultTextStyle.merge if you pass the name dynamically
    return SizedBox(); // placeholder, see below how we pass text
  }
}

// ---------- dotted overlay ----------
class _DotOverlay extends StatelessWidget {
  const _DotOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _DotPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x33FFFFFF) // very subtle
      ..style = PaintingStyle.fill;
    const spacing = 10.0;
    const radius = 1.2;

    for (double y = 14; y < size.height - 14; y += spacing) {
      for (double x = 14; x < size.width - 14; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
