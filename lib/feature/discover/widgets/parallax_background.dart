import 'package:flutter/material.dart';


import 'package:flutter/material.dart';

class ParallaxImage extends StatelessWidget {
  const ParallaxImage({
    super.key,
    required this.asset,
    required this.extent,       // visible height
    this.speed = 0.35,          // 0..1
    this.overscan = 24,         // extra safety bleed
    this.alignmentX = 0.0,
    this.fit = BoxFit.cover,
  });

  final String asset;
  final double extent;
  final double speed;
  final double overscan;
  final double alignmentX;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final scrollable = Scrollable.of(context);
    if (scrollable == null) {
      return Image.asset(asset, fit: fit, height: extent, width: double.infinity);
    }

    // Constrain the visible box to exactly `extent`.
    return SizedBox(
      height: extent,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final w = constraints.maxWidth;
          final extra = extent * speed;
          final childH = extent + extra + overscan; // bleed
          final maxShift = extra / 2;

          return Flow(
            delegate: _ParallaxYDelegate(
              scrollable: scrollable,
              listItemContext: context,
              maxShift: maxShift,
            ),
            children: [
              // Allow vertical overflow but keep finite width.
              OverflowBox(
                minWidth: w, maxWidth: w,
                minHeight: childH, maxHeight: childH,
                alignment: Alignment.topCenter,
                child: Image.asset(
                  asset,
                  fit: fit,
                  width: w,
                  height: childH,
                  alignment: Alignment(alignmentX, 0),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ParallaxYDelegate extends FlowDelegate {
  _ParallaxYDelegate({
    required this.scrollable,
    required this.listItemContext,
    required this.maxShift,
  }) : super(repaint: scrollable.position);

  final ScrollableState scrollable;
  final BuildContext listItemContext;
  final double maxShift;

  @override
  void paintChildren(FlowPaintingContext context) {
    final vp = scrollable.context.findRenderObject() as RenderBox;
    final item = listItemContext.findRenderObject() as RenderBox;

    final itemTopLeft = item.localToGlobal(Offset.zero, ancestor: vp);
    final itemSize = item.size;

    final vpH = vp.size.height;
    final vpCenter = vpH / 2;
    final itemCenter = itemTopLeft.dy + itemSize.height / 2;

    // -1 (top) .. +1 (bottom)
    var frac = (vpCenter - itemCenter) / (vpH / 2);
    if (frac < -1) frac = -1;
    if (frac > 1) frac = 1;

    // Move opposite to scroll; stays within ±maxShift
    final dy = frac * maxShift;

    context.paintChild(0, transform: Matrix4.identity()..translate(0.0, dy));
  }

  @override
  bool shouldRepaint(_ParallaxYDelegate old) =>
      old.scrollable != scrollable ||
      old.listItemContext != listItemContext ||
      old.maxShift != maxShift;
}


/// Parallax image that works inside CustomScrollView (slivers).
// class ParallaxImage extends StatelessWidget {
//   const ParallaxImage({
//     super.key,
//     required this.asset,
//     required this.extent, // total visible height of the header
//     this.speed = 0.35,    // 0.0..1.0: how much extra the image moves
//     this.alignmentX = 0.0,
//     this.fit = BoxFit.cover,
//   });

//   final String asset;
//   final double extent;
//   final double speed;
//   final double alignmentX;
//   final BoxFit fit;

//   @override
//   Widget build(BuildContext context) {
//     // Flow needs the context of THIS list item.
//     return Flow(
//       delegate: _ParallaxFlowDelegate(
//         scrollable: Scrollable.of(context)!,
//         listItemContext: context,
//         speed: speed,
//       ),
//       children: [
//         // The child is larger vertically so we have pixels to parallax.
//         // Make it ~ (1 + speed) * extent tall.
//         SizedBox(
//           height: extent * (1.0 + speed),
//           width: double.infinity,
//           child: Image.asset(
//             asset,
//             fit: fit,
//             alignment: Alignment(alignmentX, 0), // keep horizontal framing
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _ParallaxFlowDelegate extends FlowDelegate {
//   _ParallaxFlowDelegate({
//     required this.scrollable,
//     required this.listItemContext,
//     required this.speed,
//   });

//   final ScrollableState scrollable;
//   final BuildContext listItemContext;
//   final double speed;

//   @override
//   void paintChildren(FlowPaintingContext context) {
//     // Where is the list item (header) inside the viewport?
//     final scrollBox = scrollable.context.findRenderObject() as RenderBox;
//     final itemBox = listItemContext.findRenderObject() as RenderBox;

//     final viewport = Offset.zero & scrollBox.size;
//     final itemOffset = itemBox.localToGlobal(Offset.zero, ancestor: scrollBox);
//     final itemRect = itemOffset & itemBox.size;

//     // 0 at top of screen, 1 at bottom; clamp for safety.
//     final visibleFraction =
//         (itemRect.top / viewport.height).clamp(0.0, 1.0);

//     // How far should we shift the oversized image?
//     // The extra height is speed * itemRect.height.
//     final extra = itemRect.height * speed;
//     final dy = -extra * visibleFraction;

//     context.paintChild(
//       0,
//       transform: Matrix4.translationValues(0, dy, 0),
//     );
//   }

//   @override
//   bool shouldRepaint(covariant _ParallaxFlowDelegate old) =>
//       old.scrollable != scrollable ||
//       old.listItemContext != listItemContext ||
//       old.speed != speed;
// }
