import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PollResultCard extends StatelessWidget {
  final List<ResultBarItem> locations;
  final List<ResultTimeItem> times;
  final VoidCallback? onCreateFromWinner;

  const PollResultCard({
    super.key,
    required this.locations,
    required this.times,
    this.onCreateFromWinner,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xff0C1D1B);
    const sectionBg = Color(0xff0E1B1A);
    const accent = Color(0xFF03FFE2);

    final maxLoc = locations.isEmpty
        ? 1
        : locations.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ---------- LOCATION CHART ----------
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: sectionBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            height: 220, // fixed chart height
            child: LayoutBuilder(
              builder: (_, constraints) {
                // space used by count text, logo, name + paddings
                const topNumber = 20.0;
                const bottomBlock = 70.0; // logo+name area + gaps
                final maxBarSpace =
                    (constraints.maxHeight - topNumber - bottomBlock)
                        .clamp(40.0, 140.0);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: locations.map((e) {
                    final ratio =
                        maxLoc == 0 ? 0.0 : (e.count / maxLoc.toDouble());
                    // tiny base for 0
                    final barH = (ratio == 0 ? 0.12 : ratio.clamp(0.12, 1.0)) *
                        maxBarSpace;

                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // count on top
                          Text("${e.count}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          // bar itself
                          Container(
                            height: barH,
                            width: 19,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // logo
                          // _LogoSquare(url: e.logoUrl),
                          const SizedBox(height: 6),
                          // name (new)
                          Text(
                            e.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 18),
        const Text("Time",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),

        // ---------- TIME ROWS ----------
        ...times.map((t) => _TimeRow(item: t)).toList(),

        if (onCreateFromWinner != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCreateFromWinner,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("Create from the winner  →"),
            ),
          ),
        ],
      ]),
    );
  }
}

/* ---------- sub-widgets ---------- */

class _LogoSquare extends StatelessWidget {
  final String? url;
  const _LogoSquare({this.url});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: (url == null || url!.isEmpty)
          ? const SizedBox()
          : CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final ResultTimeItem item;
  const _TimeRow({required this.item});

  String _fmtRange(DateTime s, DateTime e) =>
      "${DateFormat('h:mm a').format(s)} – ${DateFormat('h:mm a').format(e)}";
  String _day(DateTime d) => DateFormat('EEEE, MMM d').format(d);

  @override
  Widget build(BuildContext context) {
    const rowBg = Color(0xff0E1B1A);
    const accent = Color(0xFF03FFE2);

    final ratio = item.maxCount == 0
        ? 0.0
        : (item.count / item.maxCount.toDouble()).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white, fontSize: 14),
            children: [
              TextSpan(
                text: _fmtRange(item.start, item.end),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: "  "),
              TextSpan(
                text: _day(item.start),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // baseline + filled portion; for 0 keep only tiny base
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            if (ratio == 0.0)
              FractionallySizedBox(
                widthFactor: .16, // tiny base for zero
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              )
            else
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text("${item.count}",
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }
}

/* ---------- data models consumed by the card ---------- */

class ResultBarItem {
  final String label; // location name (shown under logo)
  final int count;
  final String? logoUrl;
  ResultBarItem({
    required this.label,
    required this.count,
    this.logoUrl,
  });
}

class ResultTimeItem {
  final DateTime start, end;
  final int count;
  final int maxCount;
  ResultTimeItem({
    required this.start,
    required this.end,
    required this.count,
    required this.maxCount,
  });
}
