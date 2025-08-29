import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeOptionCard extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final bool selected;
  final int voteCount;
  final double ratio;      // 0..1 relative to max votes
  final VoidCallback onVote;
  final bool disabled;

  const TimeOptionCard({
    super.key,
    required this.start,
    required this.end,
    required this.selected,
    required this.voteCount,
    required this.ratio,
    required this.onVote,
    this.disabled = false,
  });

  String get _time =>
      "${DateFormat('h:mm a').format(start)} – ${DateFormat('h:mm a').format(end)}";
  String get _day => DateFormat('EEEE, MMMM d').format(start);

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xff0E1B1A);
    const accent = Color(0xFF03FFE2);

    // Always show at least a small visual even for 0 votes
    final double minBar = 0.12; // 12% baseline
    final num barFactor = (ratio.isNaN ? 0 : ratio).clamp(0.0, 1.0);
    final num widthFactor = (voteCount == 0) ? minBar : barFactor.clamp(minBar, 1.0);

    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_time,
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 4),
          Text(_day, style: const TextStyle(color: Colors.white70, fontSize: 12)),

          const Spacer(),

          // Always show the track + a small fill (even when 0)
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: widthFactor.toDouble(),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(voteCount == 0 ? 0 : 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text("$voteCount",
              style: const TextStyle(color: Colors.white70, fontSize: 12)),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: disabled ? null : onVote,
              style: ElevatedButton.styleFrom(
                backgroundColor: selected ? Colors.white : accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: accent.withOpacity(.35),
                disabledForegroundColor: Colors.black.withOpacity(.6),
              ),
              child: Text(selected ? "Voted" : "Vote"),
            ),
          ),
        ],
      ),
    );
  }
}
