import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/auth/screens/login_screen.dart';
import 'package:connecto/feature/auth/screens/user_details_screen.dart';
import 'package:connecto/feature/pings/model/ping_model.dart';
import 'package:connecto/my_app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Import the theme file

import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // GoRouter.optionURLReflectsImperativeAPIs = true;
  await dotenv.load();
  await setUp();
  await Firebase.initializeApp();
  runApp(ProviderScope(child: MyApp()));
}

Future<void> setUp() async {
  MapboxOptions.setAccessToken(
      'pk.eyJ1IjoibmlzYWZ2YSIsImEiOiJjbThoM2h5dmcwdnV3MmtvaXFidXhtb3gzIn0.59ykk4I9gCbLASEyxjIyvw');
}

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       theme: AppTheme.lightTheme,
//       home: AuthWrapper(),
//     );
//   }
// }

final List<PingModel> predefinedPings = [
  PingModel(
    id: 'ping4',
    name: "Good morning",
    pattern: [500, 100, 200, 50, 100],
    isCustom: false,
    createdAt: DateTime.now(),
  ),
  PingModel(
    id: 'ping1',
    name: "I Miss You",
    pattern: [100, 50, 300, 50, 100],
    isCustom: false,
    createdAt: DateTime.now(),
  ),
  PingModel(
    id: 'ping2',
    name: "Morning Hug",
    pattern: [100, 50, 100, 50, 100, 50, 300],
    isCustom: false,
    createdAt: DateTime.now(),
  ),
  PingModel(
    id: 'ping3',
    name: "I'm Here for You",
    pattern: [200, 100, 400, 50, 100],
    isCustom: false,
    createdAt: DateTime.now(),
  ),
];

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final userDataProvider =
    FutureProvider.family<DocumentSnapshot, String>((ref, uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).get();
});

class AuthWrapper extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    log('====auth state ===== $authState');

    return authState.when(
        data: (user) {
          if (user != null) {
            log('user not null');
            final userData = ref.watch(userDataProvider(user.uid));
            return userData.when(
                data: (doc) {
                  if (doc.exists) {
                    return HomeScreen(user: user);
                  } else {
                    return UserDetailsScreen();
                  }
                },
                loading: () =>
                    Scaffold(body: Center(child: CircularProgressIndicator())),
                error: (e, _) => Scaffold(
                    body: Center(child: Text('Error loading user data'))));
          } else {
            log('else part : user is null===');
            return LoginScreen();
          }
        },
        loading: () =>
            Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            Scaffold(body: Center(child: Text('Error: ${e.toString()}'))));
  }
}

// class AuthWrapper extends ConsumerWidget {
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     // return StreamBuilder<User?>(
//     //   stream: FirebaseAuth.instance.authStateChanges(),
//     //   builder: (context, snapshot) {
//     //     if (snapshot.connectionState == ConnectionState.waiting) {
//     //       return Scaffold(
//     //         body: Center(
//     //             child:
//     //                 CircularProgressIndicator()), // Loading indicator while checking auth state
//     //       );
//     //     }
//     //     if (snapshot.hasData && snapshot.data != null) {
//     //       return HomeScreen(user: snapshot.data!,); // User is logged in
//     //     } else {
//     //       return LoginScreen(); // User is not logged in
//     //     }
//     //   },
//     // );

//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Scaffold(
//             body: Center(child: CircularProgressIndicator()), // Show loading
//           );
//         }
//         if (snapshot.hasData && snapshot.data != null) {
//           return FutureBuilder<DocumentSnapshot>(
//             future: FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(snapshot.data!.uid)
//                 .get(),
//             builder: (context, userSnapshot) {
//               if (userSnapshot.connectionState == ConnectionState.waiting) {
//                 return Scaffold(
//                   body: Center(child: CircularProgressIndicator()), // Loading user data
//                 );
//               }
//               if (userSnapshot.hasData && userSnapshot.data!.exists) {
//                 return HomeScreen(user: snapshot.data!,); // User data exists -> Go to Home
//               } else {
//                 return UserDetailsScreen(); // User data missing -> Collect details
//               }
//             },
//           );
//         } else {
//           return LoginScreen(); // User not logged in
//         }
//       },
//     );
//   }
// }

class HomeScreen extends StatelessWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  void _logout(BuildContext context) async {
    log('inside logout feature');
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.logout,
              color: Colors.white,
            ),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: Text('Welcome to Home Screen! ${user.phoneNumber} blahhhh'),
      ),
    );
  }
}
