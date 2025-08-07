import 'dart:developer';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/common_widgets/continue_button.dart';
import 'package:connecto/feature/auth/controller/auth_provider.dart';
import 'package:connecto/feature/auth/model/user_model.dart';
import 'package:connecto/feature/dashboard/screens/access_request_admin.dart';
import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/feature/discover/screens/discover_screen.dart';
import 'package:connecto/feature/gatherings/screens/gathering_list.dart';
import 'package:connecto/riverpod_observers/my_app_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class MainScreen extends StatefulWidget {
  final Widget child;
  MainScreen({super.key, required this.child});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex =
        _getIndexFromPath(GoRouter.of(context).state.matchedLocation);
  }

  int _getIndexFromPath(String path) {
    if (path.contains('discover')) return 0;
    if (path.contains('gathering')) return 1;
    if (path.contains('bond')) return 2;

    if (path.contains('profile')) return 3;
    return 0; // default to first tab
  }

  static List<Widget> pages = [
    DiscoverScreen(),
    GatheringsTab(),
    BondScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouter.of(context).state.matchedLocation;
    _selectedIndex = _getIndexFromPath(currentPath); // ✅ sync with path
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      // widget.child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xff03FFE2),
        currentIndex: _selectedIndex,
        backgroundColor: Color(0xff091F1E),
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Navigate based on the index
          // ✅ Navigate via GoRouter
          switch (index) {
            case 0:
              context.go('/discover');
              break;
            case 1:
              context.go('/gathering');
              break;
            case 2:
              context.go('/bond');
              break;
            case 3:
              context.go('/profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.circle_outlined), label: 'Discover'),
          BottomNavigationBarItem(
              icon: Icon(Icons.hourglass_full), label: 'Gatherings'),
          BottomNavigationBarItem(
              icon: Icon(Icons.emoji_emotions_outlined),
              label: 'Bond',
              backgroundColor: Colors.white),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class SettingScreen extends ConsumerWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    Future<void> updateUserName(String newName) async {
      final currentUser = auth.currentUser;
      if (currentUser == null) {}

      try {
        await firestore.collection('users').doc(currentUser!.uid).update({
          'fullName': newName,
        });

        // ref.invalidate(userDataProvider(currentUser.uid));

        log("✅ User name updated successfully to $newName");
      } catch (e) {
        log("❌ Error updating name: $e");
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('Settings screen in bond route')),
      body: Center(
          child: IconButton(
              onPressed: () {
                updateUserName('Nisaf V A');
              },
              icon: Icon(Icons.update))),
    );
  }
}

// class GatheringScreen extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('GatheringScreen')),
//       body: Center(child: Text('Welcome to theGatheringScreen')),
//     );
//   }
// }

class RankScreen extends StatelessWidget {
  const RankScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('RankScreen')),
      body: Center(child: Text('Welcome to the RankScreen')),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  final Set<String> adminPhones = const {
    '+971559533272',
    '+916282745946',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final accessRequestsAsync = ref.watch(adminNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));
          final isAdmin = adminPhones.contains(user.phoneNumber);
          log('is admin : $isAdmin');

          final initials = user.fullName
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase();

          return Padding(
            padding: const EdgeInsets.all(20.0).copyWith(top: 50, bottom: 50),
            child: Column(
              children: [
                // Neon Glow Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.6),
                        blurRadius: 25,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Full Name
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),

                // Gender label
                Text(
                  user.gender,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 30),

                // Info Tiles
                _buildInfoTile(
                  context,
                  icon: Icons.phone,
                  label: 'Phone',
                  value: user.phoneNumber,
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  context,
                  icon: Icons.group,
                  label: 'Friends',
                  value: '${user.friends.length} friends',
                ),

                const SizedBox(height: 12),
                if (isAdmin) ...[
                  // const SizedBox(height: 30),
                  GestureDetector(
                    onTap: () {
                      context.go(
                          '/profile/admin-access-requests'); // Route to detailed screen
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.tertiary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.verified_user,
                            color: Color(0xFF03FFE2)),
                        title: const Text("User Access Requests",
                            style: TextStyle(color: Colors.white)),
                        subtitle: accessRequestsAsync.when(
                          data: (requests) => Text(
                            "${requests.length} pending request's",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          loading: () => const Text("Loading...",
                              style: TextStyle(color: Colors.grey)),
                          error: (e, _) {
                            log('error : $e');
                            return Text("Error ",
                                style: TextStyle(color: Colors.red));
                          },
                        ),
                        
                        trailing: const Icon(Icons.arrow_forward_ios,
                            color: Colors.white38),
                      ),
                    ),
                  ),
                ],

                // Edit Profile (optional)
                // OutlinedButton.icon(
                //   onPressed: () {}, // future use
                //   icon: const Icon(Icons.edit, size: 20),
                //   label: const Text('Edit Profile'),
                //   style: OutlinedButton.styleFrom(
                //     foregroundColor: Theme.of(context).colorScheme.primary,
                //     side: BorderSide(
                //         color: Theme.of(context).colorScheme.primary),
                //     padding: const EdgeInsets.symmetric(
                //         horizontal: 20, vertical: 14),
                //     shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(12)),
                //   ),
                // ),

                const SizedBox(height: 20),

                // // Logout Button
                // ElevatedButton.icon(
                //   onPressed: () => ref.read(authProvider.notifier).logout(ref),
                //   icon: const Icon(Icons.logout),
                //   label: const Text('Logout'),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.redAccent,
                //     foregroundColor: Colors.white,
                //     padding: const EdgeInsets.symmetric(
                //         horizontal: 28, vertical: 14),
                //     shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(14)),
                //   ),
                // ),
                Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        ref.read(authProvider.notifier).logout(ref, context),
                    icon: const Icon(Icons.logout, color: Colors.black),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff03FFE2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(fontSize: 15, color: Colors.white)),
            ],
          )
        ],
      ),
    );
  }
}

// Similarly, create GatheringScreen, RankScreen, and ProfileScreen
