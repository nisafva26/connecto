import 'package:flutter/material.dart';

class ParallaxX extends StatelessWidget {
  const ParallaxX({
    super.key,
    required this.extent,          // visible card width (e.g. 200)
    required this.image,
    this.height = 160,
    this.speed = 0.40,             // 0..1 — parallax strength
    this.overscan = 24,            // extra bleed to be super safe
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  final double extent;
  final double height;
  final ImageProvider image;
  final double speed;
  final double overscan;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final maxShift = extent * speed * 0.5;              // we translate ±maxShift
    final childWidth = extent + (maxShift * 2) + overscan; // bleed on BOTH sides

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        width: extent,
        height: height,
        child: Flow(
          delegate: _ParallaxXFlowDelegate(
            scrollable: Scrollable.of(context)!,
            listItemContext: context,
            maxShift: maxShift,
          ),
          children: [
            // Allow the image to extend outside the clip horizontally.
            OverflowBox(
              minWidth: childWidth,
              maxWidth: childWidth,
              minHeight: height,
              maxHeight: height,
              alignment: Alignment.center,
              child: Image(
                image: image,
                fit: fit,                 // crop vertically if needed
                width: childWidth,
                height: height,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParallaxXFlowDelegate extends FlowDelegate {
  _ParallaxXFlowDelegate({
    required this.scrollable,
    required this.listItemContext,
    required this.maxShift,
  }) : super(repaint: scrollable.position);

  final ScrollableState scrollable;
  final BuildContext listItemContext;
  final double maxShift;

  @override
  void paintChildren(FlowPaintingContext context) {
    final scrollBox = scrollable.context.findRenderObject() as RenderBox;
    final itemBox = listItemContext.findRenderObject() as RenderBox;

    final itemOffset = itemBox.localToGlobal(Offset.zero, ancestor: scrollBox);
    final itemSize = itemBox.size;
    final viewportW = scrollable.position.viewportDimension;

    final viewportCenter = viewportW / 2;
    final itemCenter = itemOffset.dx + itemSize.width / 2;

    var frac = (viewportCenter - itemCenter) / (viewportW / 2);
    frac = frac.clamp(-1.0, 1.0);

    // Translate within [-maxShift, +maxShift]
    final dx = (-frac * maxShift);
    context.paintChild(0, transform: Matrix4.identity()..translate(dx, 0.0));
  }

  @override
  bool shouldRepaint(_ParallaxXFlowDelegate old) =>
      old.scrollable != scrollable ||
      old.listItemContext != listItemContext ||
      old.maxShift != maxShift;
}
