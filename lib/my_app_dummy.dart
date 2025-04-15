// import 'dart:developer';

// import 'package:connecto/feature/auth/screens/login_screen.dart';
// import 'package:connecto/feature/auth/screens/login_success.dart';
// import 'package:connecto/feature/auth/screens/user_details_screen.dart';
// import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
// import 'package:connecto/feature/dashboard/circles/screens/create_circle_screen.dart';
// import 'package:connecto/feature/dashboard/screens/friends_details_screen.dart';
// import 'package:connecto/feature/dashboard/screens/home_screen.dart.dart';
// import 'package:connecto/theme/app_theme.dart';
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// // ✅ Preserve navigation state
// final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
// final GlobalKey<NavigatorState> _shellNavigatorKey =
//     GlobalKey<NavigatorState>();

// // Providers
// final authStateProvider =
//     StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

// final userDataProvider = StreamProvider.family<DocumentSnapshot?, String>(
//     (ref, uid) =>
//         FirebaseFirestore.instance.collection('users').doc(uid).snapshots());

// final lastRouteProvider = StateProvider<String>((ref) => '/bond');

// // ✅ Define Router Outside MyApp
// final goRouterProvider = Provider<GoRouter>((ref) {
//   final user = ref.watch(authStateProvider).asData?.value;
//   final userId = user?.uid; // ✅ Extract UID safely
//   final userData = userId != null
//       ? ref.watch(userDataProvider(userId)).asData?.value
//       : null; // ✅ Only watch if userId is not null

//   return GoRouter(
//     navigatorKey: _rootNavigatorKey,
//     debugLogDiagnostics: false,
//     initialLocation: '/', // ✅ Start from last route
//     observers: [NavigatorObserver()],
//     // refreshListenable: GoRouterRefreshNotifier(ref),
//     redirect: (context, state) {
//       // ✅ If Firebase redirects to an unrecognized deep link, stay on the same page
//       if (state.uri.toString().contains("firebaseauth/link")) {
//         log("🚨 Ignoring Firebase Web Verification Redirect: ${state.uri}");
//         return '/'; // 🔹 Stay on the same page
//       }
//     },

//     routes: [
//       // ✅ Login Route
//       GoRoute(
//         path: '/',
//         builder: (context, state) => LoginScreen(),
//         redirect: (context, state) {
//           log('inside redirect....${state.fullPath}');
//           log("url : ${state.uri.toString()}");

//           // log('user $user');
//           if (user == null) return '/';

//           if (state.fullPath == '/') {
//             log('=======success trigggered=====');
//             return '/success';
//           }

//           // final justLoggedIn = ref.read(justLoggedInProvider);

//           // log('just logged in value in / route: $justLoggedIn');

//           // final lastRoute = ref.read(lastRouteProvider);

//           if (userData != null && userData.exists) {
//             log('====should go to bond');
//             return '/bond';
//           } else if (userData != null && !userData.exists) {
//             return '/user-details';
//           }
//           return null;
// // Wait for the async update
//         },
//       ),

//       // ✅ ShellRoute for Bottom Navigation (Persistent)
//       ShellRoute(
//         navigatorKey: _shellNavigatorKey,
//         builder: (context, state, child) {
//           log('inside bond shell route ${state.fullPath}');
//           return MainScreen(child: child);
//         },
//         routes: [
//           GoRoute(
//             path: '/bond',
//             builder: (context, state) => BondScreen(),
//             routes: [
//               GoRoute(
//                 path: 'setting',
//                 parentNavigatorKey: _rootNavigatorKey,
//                 builder: (context, state) => SettingScreen(),
//               ),
//               GoRoute(
//                 path: 'create-circle',
//                 parentNavigatorKey: _rootNavigatorKey,
//                 builder: (context, state) {
//                   final Map<String, dynamic> data =
//                       state.extra as Map<String, dynamic>;

//                   log('data : $data');
//                   return CreateCircleScreen(
//                       selectedUsers: data['selectedUsers']);
//                 },
//               ),
//               GoRoute(
//                 path: 'friend-details/:name/:phoneNumber',
//                 parentNavigatorKey: _rootNavigatorKey,
//                 builder: (context, state) {
//                   final name = state.pathParameters['name'] ?? 'Unknown';
//                   final phoneNumber =
//                       state.pathParameters['phoneNumber'] ?? 'N/A';
//                   return FriendDetailsScreen(
//                       name: name, phoneNumber: phoneNumber);
//                 },
//               ),
//             ],
//           ),
//           GoRoute(
//             path: '/gathering',
//             builder: (context, state) => GatheringScreen(),
//           ),
//           GoRoute(
//             path: '/rank',
//             builder: (context, state) => RankScreen(),
//           ),
//           GoRoute(
//             path: '/profile',
//             builder: (context, state) => ProfileScreen(),
//           ),
//         ],
//       ),

//       GoRoute(
//         path: '/user-details',
//         builder: (context, state) => UserDetailsScreen(),
//       ),

//       GoRoute(
//         path: '/success',
//         builder: (context, state) => SuccessScreen(),
//         redirect: (context, state) {
//           // final user = ref.watch(authStateProvider).asData?.value;
//           // final userData =
//           //     ref.watch(userDataProvider(user?.uid ?? '')).asData?.value;

//           final container = ProviderContainer();
//           final justLoggedIn = container.read(justLoggedInProvider);

//           log('just logged in value : $justLoggedIn');

//           if (user == null) return '/';

//           // ✅ Delay redirection to allow SuccessScreen to be shown for 3 seconds
//           if (justLoggedIn) {
//             // ✅ Reset the login state so this screen doesn't show again after reopening
//             Future.microtask(() {
//               ref.read(justLoggedInProvider.notifier).state = false;
//             });
//             Future.delayed(Duration(seconds: 3), () {
//               if (userData != null && userData.exists) {
//                 return '/bond'; // ✅ Move to bond screen after delay
//               } else if (userData != null && !userData.exists) {
//                 return '/user-details'; // ✅ Move to user-details if needed
//               }
//             });
//           } else {
//             if (userData != null && userData.exists) return '/bond';
//             if (userData != null && !userData.exists) return '/user-details';
//           }

//           return null;
//         },
//       ),
//     ],
//   );
// });

// class MyApp extends ConsumerWidget {
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     // final router = GoRouter(
//     //   navigatorKey: _rootNavigatorKey, // ✅ Preserve navigation state
//     //   debugLogDiagnostics: false,
//     //   // initialLocation: '/bond/friend-details/Jabbar/+91 6282-745944',
//     //   initialLocation: '/bond',
//     //   observers: [NavigatorObserver()],

//     //   routes: [
//     //     // ✅ Login Route
//     //     GoRoute(
//     //       path: '/',
//     //       builder: (context, state) => LoginScreen(),
//     //       redirect: (context, state) {
//     //         log('inside redirect....${state.fullPath}');
//     //         // final user = ref.watch(authStateProvider).asData?.value;
//     //         // // log('user : $user');
//     //         // if (user == null) return '/';
//     //         // final userData =
//     //         //     ref.watch(userDataProvider(user.uid)).asData?.value;

//     //         // // ✅ Preserve last visited route
//     //         // final lastRoute = ref.read(lastRouteProvider);
//     //         // log('last route : $lastRoute');
//     //         // if (userData != null && userData.exists) {
//     //         //   log('user data exist should go to bond screen');
//     //         //   return '/bond';
//     //         // } else if (userData != null && !userData.exists) {
//     //         //   return '/user-details';
//     //         // }
//     //         return '/bond'; // Redirect to main screen after login
//     //       },
//     //     ),

//     //     /// ✅ ShellRoute for Bottom Navigation (Persistent Navigation)
//     //     ShellRoute(
//     //       navigatorKey: _shellNavigatorKey, // Preserve state across tabs
//     //       builder: (context, state, child) {
//     //         log('inside bond shell route ${state.fullPath}');
//     //         return MainScreen(child: child); // Keeps bottom navigation intact
//     //       },
//     //       routes: [
//     //         // ✅ Bond Tab (Default)
//     //         GoRoute(
//     //           path: '/bond',
//     //           builder: (context, state) => BondScreen(),
//     //           routes: [
//     //             GoRoute(
//     //               path: 'setting',
//     //               parentNavigatorKey:
//     //                   _rootNavigatorKey, // ✅ Opens on top of Shell
//     //               builder: (context, state) => SettingScreen(),
//     //             ),
//     //             GoRoute(
//     //               path: 'friend-details/:name/:phoneNumber',
//     //               parentNavigatorKey:
//     //                   _rootNavigatorKey, // ✅ Opens on top of Shell
//     //               builder: (context, state) {
//     //                 final name = state.pathParameters['name'] ?? 'Unknown';
//     //                 final phoneNumber =
//     //                     state.pathParameters['phoneNumber'] ?? 'N/A';
//     //                 return FriendDetailsScreen(
//     //                     name: name, phoneNumber: phoneNumber);
//     //               },
//     //             ),
//     //           ],
//     //         ),

//     //         // ✅ Gathering Tab
//     //         GoRoute(
//     //           path: '/gathering',
//     //           builder: (context, state) => GatheringScreen(),
//     //         ),

//     //         // ✅ Rank Tab
//     //         GoRoute(
//     //           path: '/rank',
//     //           builder: (context, state) => RankScreen(),
//     //         ),

//     //         // ✅ Profile Tab
//     //         GoRoute(
//     //           path: '/profile',
//     //           builder: (context, state) => ProfileScreen(),
//     //         ),
//     //       ],
//     //     ),

//     //     // ✅ User Details Route
//     //     GoRoute(
//     //       path: '/user-details',
//     //       builder: (context, state) => UserDetailsScreen(),
//     //     ),

//     //     // ✅ Success Screen Route
//     //     GoRoute(
//     //       path: '/success',
//     //       builder: (context, state) => SuccessScreen(),
//     //       redirect: (context, state) {
//     //         final user = ref.watch(authStateProvider).asData?.value;
//     //         if (user == null) return '/';
//     //         final userData =
//     //             ref.watch(userDataProvider(user.uid)).asData?.value;
//     //         if (userData != null && userData.exists) {
//     //           return '/bond';
//     //         } else if (userData != null && !userData.exists) {
//     //           return '/user-details';
//     //         }
//     //         return null;
//     //       },
//     //     ),
//     //   ],
//     // );
//     final router = ref.watch(goRouterProvider); // ✅ Use GoRouter from provider
//     return MaterialApp.router(
//       // routerConfig: router,
//       routeInformationParser: router.routeInformationParser,
//       routeInformationProvider: router.routeInformationProvider,
//       routerDelegate: router.routerDelegate,
//       theme: AppTheme.lightTheme,
//       title: 'Connecto',
//     );
//   }
// }

// // class CustomRouteObserver extends NavigatorObserver {
// //   final WidgetRef ref;

// //   CustomRouteObserver(this.ref);

// //   @override
// //   void didPush(Route route, Route? previousRoute) {
// //     if (route.settings.name != null) {
// //       print('📌 Route pushed: ${route.settings.name}'); // Debugging print
// //       Future.microtask(() {
// //         ref.read(lastRouteProvider.notifier).state = route.settings.name!;
// //         print('✅ Updated lastRouteProvider: ${ref.read(lastRouteProvider)}');
// //       });
// //     } else {
// //       print('⚠️ Route name is null for: $route');
// //     }
// //     super.didPush(route, previousRoute);
// //   }
// // }

// // class GoRouterRefreshNotifier extends ChangeNotifier {
// //   GoRouterRefreshNotifier(Ref ref) {
// //     ref.listen(authStateProvider, (previous, next) {
// //       log('inside refresh litsenable .. state change ? $previous $next');
// //       if (previous?.value != next?.value) {
// //         notifyListeners(); // ✅ Trigger navigation update when auth state changes
// //       }
// //     });
// //   }
// // }

// // class GoRouterRefreshNotifier extends ChangeNotifier {
// //   GoRouterRefreshNotifier(this.ref) {
// //     ref.listen(
// //       authStateProvider,
// //       (_, next) {
// //         notifyListeners(); // ✅ Triggers GoRouter rebuild on auth change
// //       },
// //     );
// //   }

// //   final Ref ref;
// // }

// class GoRouterRefreshNotifier extends ChangeNotifier {
//   GoRouterRefreshNotifier(Ref ref) {
//     ref.listen<User?>(
//       authStateProvider.select((value) => value.asData?.value),
//       (previous, next) {
//         log('=======refreshing=====');
//         notifyListeners(); // ✅ Notify GoRouter to refresh when auth state changes
//       },
//     );
//   }
// }
