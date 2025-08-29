import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/helper/get_initials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CommonSliverAppBar extends SliverPersistentHeaderDelegate {
  final WidgetRef ref;
  CommonSliverAppBar(this.ref);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color:  Colors.transparent, // background
      padding: const EdgeInsets.symmetric(horizontal: 23).copyWith(
        top: MediaQuery.paddingOf(context).top + 12, // safe area
       
      ),
      child: Row(
        children: [
          // 🔹 Avatar + Glow
          ref.watch(currentUserProvider).when(
            data: (user) {
              if (user == null) return const SizedBox();
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF03FFE2).withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                  child: Text(
                    getInitials(user.fullName),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
            error: (_, __) => const SizedBox(),
            loading: () => const SizedBox(),
          ),

          const SizedBox(width: 16),

          // 🔹 Name + Status
          ref.watch(currentUserProvider).when(
            data: (user) {
              if (user == null) return _buildText("No User", "Unknown");
              return _buildText(user.fullName, user.phoneNumber);
            },
            loading: () => _buildText("Loading...", "Fetching data..."),
            error: (_, __) => _buildText("Error", "Could not fetch data",
                color: Colors.red, subColor: Colors.redAccent),
          ),

          const Spacer(),
          const Icon(Icons.settings, color: Colors.transparent),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 70 + MediaQueryData.fromWindow(WidgetsBinding.instance.window).padding.top;

  @override
  double get minExtent => kToolbarHeight + MediaQueryData.fromWindow(WidgetsBinding.instance.window).padding.top;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;

  Widget _buildText(String title, String subtitle,
      {Color color = const Color(0xffEFF1F5),
      Color subColor = const Color(0xff6B6E7C)}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
        Text(subtitle,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subColor)),
      ],
    );
  }
}
