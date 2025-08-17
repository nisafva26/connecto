import 'dart:ui';

import 'package:connecto/feature/auth/model/user_model.dart';
import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/helper/get_initials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GreetingSliverAppBar extends ConsumerWidget {
  const GreetingSliverAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return SliverAppBar(
      pinned: true,
      stretch: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      expandedHeight: 240,
      backgroundColor: const Color(0xff091F1E),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: LayoutBuilder(
        builder: (ctx, constraints) {
          final collapsed = constraints.biggest.height <=
              kToolbarHeight + MediaQuery.paddingOf(context).top + 8;

          return FlexibleSpaceBar(
            titlePadding: const EdgeInsetsDirectional.only(
              start: 20, bottom: 12, end: 20),
            // When collapsed, show a compact title; when expanded, we show the big card below
            title: collapsed
                ? _CollapsedTitle(userAsync: userAsync)
                : const SizedBox.shrink(),
            background: _ExpandedGreeting(userAsync: userAsync),
          );
        },
      ),
    );
  }
}

class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle({required this.userAsync});
  final AsyncValue<UserModel?> userAsync;

  @override
  Widget build(BuildContext context) {
    return userAsync.when(
      data: (u) => Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            child: Text(getInitials(u?.fullName ?? ''),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Text(
            _greetingForNow(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      loading: () => const Text('Loading…'),
      error: (_, __) => const Text(''),
    );
  }
}

class _ExpandedGreeting extends StatelessWidget {
  const _ExpandedGreeting({required this.userAsync});
  final AsyncValue<UserModel?> userAsync;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Stack(
      fit: StackFit.expand,
      children: [
        // background image/gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF12302E), Color(0xFF0A1F1E)]),
          ),
        ),
        // glass card sitting at the bottom
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, top + 16, 20, 16),
            child: ClipRRect(
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
                  child: userAsync.when(
                    data: (u) => _GreetingContent(name: u?.fullName ?? 'Friend'),
                    loading: () => const _GreetingContent(name: '...'),
                    error: (_, __) => const _GreetingContent(name: 'Friend'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GreetingContent extends StatelessWidget {
  const _GreetingContent({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              '${_greetingForNow()}, ',
              style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            Text(
              name.split(' ').first,
              style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const Text(' 👋', style: TextStyle(fontSize: 22)),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          "It’s a great weather for outdoor activities",
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFCFE6E4)),
        ),
      ],
    );
  }
}

String _greetingForNow() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good Morning';
  if (h < 17) return 'Good Afternoon';
  if (h < 21) return 'Good Evening';
  return 'Good Night';
}
