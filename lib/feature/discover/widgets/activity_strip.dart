import 'package:connecto/feature/discover/data/activity_model.dart';
import 'package:connecto/feature/discover/widgets/activity_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------- strip (replaces your GridView) ----------
class ActivityStrip extends StatefulWidget {
  const ActivityStrip({
    super.key,
    required this.items,
    this.initialSelected,
    required this.onSelected,
  });

  final List<Activity> items;
  final String? initialSelected;
  final ValueChanged<String> onSelected;

  @override
  State<ActivityStrip> createState() => _ActivityStripState();
}

class _ActivityStripState extends State<ActivityStrip> {
  late String? selected = widget.initialSelected;
  final _controller = ScrollController();

  static const double _cardWidth = 159;
  static const double _gap = 16;
  static const double _hPad = 20;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {})); // lightweight
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _parallaxForIndex(BuildContext context, int index) {
    // where the card sits in the scrollable content
    final itemLeft = _hPad + index * (_cardWidth + _gap);
    final itemCenter = itemLeft + _cardWidth / 2;

    // viewport
    final vpWidth = MediaQuery.of(context).size.width;
    final scroll = _controller.offset;
    final vpCenter = scroll + vpWidth / 2;

    // -1 (far left) .. 0 (center) .. 1 (far right), clamped
    final raw = (itemCenter - vpCenter) / (vpWidth / 2);
    return raw.clamp(-1.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 142,
      child: ListView.separated(
        controller: _controller,
        padding: const EdgeInsets.symmetric(horizontal: _hPad),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: widget.items.length,
        separatorBuilder: (_, __) => const SizedBox(width: _gap),
        itemBuilder: (_, i) {
          final a = widget.items[i];
          final isSel = selected == a.name;
          final p = _parallaxForIndex(context, i);

          return ActivityCard(
            data: a,
            isSelected: isSel,
            parallax: p,
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => selected = a.name);
              widget.onSelected(a.name);
            },
          );
        },
      ),
    );
  }
}

