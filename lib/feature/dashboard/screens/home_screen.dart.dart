import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/auth/controller/auth_provider.dart';
import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/feature/discover/screens/discover_screen.dart';
import 'package:connecto/feature/gatherings/screens/gathering_list.dart';
import 'package:connecto/riverpod_observers/my_app_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          // switch (index) {
          //   case 0:
          //     context.go('/main/bond');
          //     break;
          //   case 1:
          //     context.go('/main/gathering');
          //     break;
          //   case 2:
          //     context.go('/main/rank');
          //     break;
          //   case 3:
          //     context.go('/main/profile');
          //     break;
          // }
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void logout(BuildContext context) async {
      log('inside logout feature');
      //  await MyAppProviders.invalidateAllProviders(ref);
      // await FirebaseAuth.instance.signOut();

      ref.read(authProvider.notifier).logout(ref);
    }

    return Scaffold(
      appBar: AppBar(title: Text('ProfileScreen')),
      body: Center(
        child: IconButton(
          icon: Icon(
            Icons.logout,
            color: Colors.white,
          ),
          onPressed: () => logout(context),
        ),
      ),
    );
  }
}

// Similarly, create GatheringScreen, RankScreen, and ProfileScreen
