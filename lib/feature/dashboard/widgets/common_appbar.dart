import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/helper/get_initials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CommonAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const CommonAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Container(
      color: const Color(0xff091F1E),
      padding: const EdgeInsets.symmetric(horizontal: 23).copyWith(top: 40),
      child: Row(
        children: [
          userAsync.when(data: (user) {
            return Row(
              children: [
                // CircleAvatar(
                //   radius: 20,
                //   backgroundColor: Colors.white,
                //   child: Text(
                //     getInitials(user!.fullName),
                //     style: TextStyle(fontWeight: FontWeight.w700),
                //   ),
                // ),
                Container(
                 decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF03FFE2)
                            .withOpacity(0.4), // Glow effect
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        Theme.of(context).colorScheme.tertiary, // dark circle
                    child: Text(
                      getInitials(user!.fullName),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),
              ],
            );
          }, error: (err, stack) {
            return SizedBox();
          }, loading: () {
            return SizedBox();
          }),

          /// 🔹 User Name & Status
          userAsync.when(
            data: (user) {
              if (user == null) {
                return _buildText("No User", "Unknown");
              }
              return _buildText(user.fullName, user.phoneNumber);
            },
            loading: () => _buildText("Loading...", "Fetching data..."),
            error: (err, stack) => _buildText("Error", "Could not fetch data",
                color: Colors.red, subColor: Colors.redAccent),
          ),

          const Spacer(),
          IconButton(
            onPressed: () {
              // context.go('/bond/setting');
            },
            icon: const Icon(Icons.settings, color: Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _buildText(String title, String subtitle,
      {Color color = const Color(0xffEFF1F5),
      Color subColor = const Color(0xff6B6E7C)}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: color)),
        Text(subtitle,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: subColor)),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(57);
}
