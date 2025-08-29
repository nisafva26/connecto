import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GreetingHeaderWithOverlap extends ConsumerWidget {
  const GreetingHeaderWithOverlap({
    super.key,
    required this.nameAsync,
    required this.upcomingCount,
    required this.showUpcomingTitle,
    this.overlapChild,
  });

  final AsyncValue<dynamic> nameAsync;
  final int upcomingCount;
  final bool showUpcomingTitle;
  final Widget? overlapChild; // null = no hero card

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Gradient area tall enough to sit behind the hero card
        Container(
          height: overlapChild == null ? 250 : 340,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF12302E), Color(0xFF0E2624), Color(0xFF0A1F1E)],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, topPad + 18, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniIdentity(nameAsync: nameAsync),
                const SizedBox(height: 18),
                _GlassGreetingCard(nameAsync: nameAsync),
                if (showUpcomingTitle) ...[
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Text(
                        "Your upcoming events",
                        style: TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 8),
                      _countPill(upcomingCount),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else
                  const SizedBox(height: 16),
                if (overlapChild != null) const SizedBox(height: 96),
              ],
            ),
          ),
        ),

        if (overlapChild != null)
          Positioned(
            left: 24, right: 24, bottom: -36,
            child: overlapChild!,
          ),
      ],
    );
  }
}


class _MiniIdentity extends StatelessWidget {
  const _MiniIdentity({required this.nameAsync});
  final AsyncValue<dynamic> nameAsync;

  @override
  Widget build(BuildContext context) {
    return nameAsync.when(
      data: (u) {
        final name = (u?.fullName ?? 'Friend').toString();
        return Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF03FFE2).withOpacity(0.35),
                    blurRadius: 12, spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                child: Text(_initials(name),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const Text("Samurai Monster",
                    style: TextStyle(color: Color(0xFFBFD8D5), fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox(height: 40),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _GlassGreetingCard extends StatelessWidget {
  const _GlassGreetingCard({required this.nameAsync});
  final AsyncValue<dynamic> nameAsync;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: nameAsync.when(
            data: (u) {
              final first = (u?.fullName ?? 'Friend').toString().split(' ').first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text("${_greeting()}, ",
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                    Text(first,
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                    const Text(" 👋", style: TextStyle(fontSize: 24)),
                  ]),
                  const SizedBox(height: 6),
                  const Text(
                    "It’s a great weather for outdoor activities",
                    style: TextStyle(color: Color(0xFFCFE6E4), fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            },
            loading: () => const SizedBox(height: 48),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

Widget _sectionTitle(String title, int count) => Row(
  children: [
    Text(title,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
    const SizedBox(width: 6),
    _countPill(count),
  ],
);

Widget _countPill(int count) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(color: const Color(0xFF0F3B35), borderRadius: BorderRadius.circular(12)),
  child: Text('$count',
      style: const TextStyle(color: Color(0xFF03FFE2), fontSize: 12, fontWeight: FontWeight.w700)),
);

Widget _viewAll(VoidCallback onTap) => GestureDetector(
  onTap: onTap,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: const [
      Text("View all",
          style: TextStyle(color: Color(0xFF03FFE2), fontWeight: FontWeight.w600, fontSize: 14)),
      SizedBox(width: 4),
      Icon(Icons.arrow_forward, color: Color(0xFF03FFE2), size: 16),
    ],
  ),
);

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final a = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : '';
  final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
  return (a + b).toUpperCase();
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good Morning';
  if (h < 17) return 'Good Afternoon';
  if (h < 21) return 'Good Evening';
  return 'Good Night';
}
