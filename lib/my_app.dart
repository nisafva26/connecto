import 'dart:developer';

import 'package:connecto/feature/access_request/screens/access_request_screen.dart';
import 'package:connecto/feature/auth/model/user_model.dart';
import 'package:connecto/feature/auth/screens/login_screen.dart';
import 'package:connecto/feature/auth/screens/login_success.dart';
import 'package:connecto/feature/auth/screens/user_details_screen.dart';
import 'package:connecto/feature/bond_score/screens/bond_relationship_screen.dart';
import 'package:connecto/feature/circles/models/circle_model.dart';
import 'package:connecto/feature/circles/screens/circle_chat_screen.dart';
import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/feature/circles/screens/create_circle_screen.dart';
import 'package:connecto/feature/dashboard/screens/friends_details_screen.dart';
import 'package:connecto/feature/dashboard/screens/home_screen.dart.dart';
import 'package:connecto/feature/discover/screens/discover_screen.dart';
import 'package:connecto/feature/discover/screens/location_details_Screen.dart';
import 'package:connecto/feature/discover/screens/select_location_discover.dart';
import 'package:connecto/feature/gatherings/models/gathering_model.dart';
import 'package:connecto/feature/gatherings/screens/create_gathering_circle.dart';
import 'package:connecto/feature/gatherings/screens/create_gathering_screen.dart';
import 'package:connecto/feature/gatherings/screens/edit_gathering_circle.dart';
import 'package:connecto/feature/gatherings/screens/gathering_details_screen.dart';
import 'package:connecto/feature/gatherings/screens/gathering_list.dart';
import 'package:connecto/feature/gatherings/screens/location_details_gathering.dart';
import 'package:connecto/feature/gatherings/screens/select_location_gathering.dart';
import 'package:connecto/feature/gatherings/screens/select_location_screen.dart';
import 'package:connecto/feature/pings/screens/ping_chat_screen.dart';
import 'package:connecto/feature/video_creation/screens/video_from_photos_screen.dart';
import 'package:connecto/notification_handler.dart';
import 'package:connecto/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ Preserve navigation state
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

// Providers
final authStateProvider =
    StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

// final userDataProvider = StreamProvider.family<DocumentSnapshot?, String>(
//     (ref, uid) =>
//         FirebaseFirestore.instance.collection('users').doc(uid).snapshots());

final userDataProvider = FutureProvider.family<DocumentSnapshot?, String>(
  (ref, uid) async {
    return await FirebaseFirestore.instance.collection('users').doc(uid).get();
  },
);

final lastRouteProvider = StateProvider<String>((ref) => '/bond');

final accessRequestProvider = FutureProvider.family<DocumentSnapshot?, String>(
  (ref, phoneNumber) async {
    log('access number : $phoneNumber');
    final doc = await FirebaseFirestore.instance
        .collection('accessRequests')
        .doc(phoneNumber)
        .get();
    log('doc : ${doc.data()}');
    log('returing == ${doc.exists && doc.data()?['status'] == 'approved' ? doc : null}');
    return doc.exists && doc.data()?['status'] == 'approved' ? doc : null;
  },
);

// ✅ Define Router Outside MyApp
final goRouterProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  final userId = user?.uid; // ✅ Extract UID safely
  final userData = userId != null
      ? ref.watch(userDataProvider(userId)).asData?.value
      : null; // ✅ Only watch if userId is not null

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: false,
    initialLocation: '/', // ✅ Start from last route
    observers: [NavigatorObserver()],
    // refreshListenable: GoRouterRefreshNotifier(ref),
    redirect: (context, state) {
      // log('user $user');
      if (user == null) return '/';

      // if (user == null) {
      //   final phone = state.uri.queryParameters['phone'] ??
      //       ref.read(requestedPhoneProvider);
      //   ;
      //   log('phone in router: $phone');
      //   final accessDoc =
      //       ref.watch(accessRequestProvider(phone ?? '')).asData?.value;

      //   log('aacess doc : $accessDoc');

      //   if (accessDoc == null) {
      //     return '/access-request';
      //   }
      //   return '/';
      // }

      // ✅ If Firebase redirects to an unrecognized deep link, stay on the same page
      if (state.uri.toString().contains("firebaseauth/link")) {
        log("🚨 Ignoring Firebase Web Verification Redirect: ${state.uri}");
        return '/'; // 🔹 Stay on the same page
      }
    },

    routes: [
      GoRoute(
        path: '/access-request',
        builder: (context, state) => AccessRequestScreen(),
      ),
      // ✅ Login Route
      GoRoute(
        path: '/',
        builder: (context, state) => LoginScreen(),
        redirect: (context, state) {
          log('inside redirect....${state.fullPath}');
          log("url : ${state.uri.toString()}");

          // log('user $user');
          if (user == null) return '/';

          if (state.fullPath == '/') {
            log('=======success trigggered=====');
            return '/success';
          }

          // final justLoggedIn = ref.read(justLoggedInProvider);

          // log('just logged in value in / route: $justLoggedIn');

          // final lastRoute = ref.read(lastRouteProvider);

          if (userData != null && userData.exists) {
            log('====should go to bond');
            return '/discover';
          } else if (userData != null && !userData.exists) {
            log('user data is null , going to collect user data');
            return '/user-details';
          }
          return null;
// Wait for the async update
        },
      ),

      // ✅ ShellRoute for Bottom Navigation (Persistent)
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          log('inside bond shell route ${state.fullPath}');

          return MainScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/bond',
            name: 'bond',
            builder: (context, state) {
              // final index = state.extra as int;
              // log('=====index in gorouter====: $index');
              return BondScreen();
            },
            routes: [
              GoRoute(
                path: 'setting',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) =>
                    // SettingScreen()
                    VideoFromPhotosScreen(),
              ),
              // GoRoute(
              //     path: 'create-gathering/:friendID',
              //     parentNavigatorKey: _rootNavigatorKey,
              //     builder: (context, state) {
              //       final friendID = state.pathParameters['friendID']!;
              //       return CreateGatheringScreen(
              //         friendID: friendID,
              //       );
              //     }),
              GoRoute(
                path: '/select-location',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final eventType = state.extra as String;
                  return AddLocationScreen(eventType: eventType);
                },
              ),
              GoRoute(
                path: 'group-chat/:circleId',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final circleId = state.pathParameters['circleId']!;

                  final circle = state.extra as CircleModel;

                  return GroupPingChatScreen(
                    circleId: circleId,
                    circle: circle,
                  );
                },
              ),

              GoRoute(
                path: 'chat/:chatId',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final chatId = state.pathParameters['chatId']!;
                  final extra = state.extra as Map<String, dynamic>;

                  return PingChatScreen(
                    chatId: chatId,
                    friendId: extra['friendId'],
                    friendName: extra['friendName'],
                    // friendProfilePic: extra['friendProfilePic'],
                    // friend: extra['friend'],
                  );
                },
                routes: [
                  GoRoute(
                    name: 'createGathering',
                    parentNavigatorKey: rootNavigatorKey,
                    path: 'create-gathering/:friendID',
                    builder: (context, state) {
                      final friendID = state.pathParameters['friendID']!;
                      final extra = state.extra as Map<String, dynamic>;
                      return CreateGatheringScreen(
                        friendID: friendID,
                        friend: extra['friend'],
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'create-circle',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final Map<String, dynamic> data =
                      state.extra as Map<String, dynamic>;

                  log('data : $data');
                  return CreateCircleScreen(
                      selectedUsers: data['selectedUsers']);
                },
              ),
              GoRoute(
                path: 'friend-details/:name/:phoneNumber',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final name = state.pathParameters['name'] ?? 'Unknown';
                  final phoneNumber =
                      state.pathParameters['phoneNumber'] ?? 'N/A';
                  return FriendDetailsScreen(
                      name: name, phoneNumber: phoneNumber);
                },
              ),
            ],
          ),
          GoRoute(
              path: '/gathering',
              builder: (context, state) => GatheringsTab(),
              routes: [
                GoRoute(
                  // name: 'createGatheringCircle',
                  parentNavigatorKey: rootNavigatorKey,
                  path: 'create-gathering-circle',
                  builder: (context, state) {
                    // // return CreateGatheringCircleScreen();
                    // final place = state.extra as PlacesSearchResult?;
                    // // final extra = state.extra as Map<String, dynamic>?;
                    // final activity = state.uri.queryParameters['activity'] ??
                    //     ''; // pass via query string

                    // return CreateGatheringCircleScreen(
                    //   place: place,
                    //   initialActivity: activity,
                    //   registeredUsers:
                    //       state.extra['registeredUsers'] as List<UserModel>?,
                    //   unregisteredUsers: extra?['unregisteredUsers']
                    //       as List<Map<String, String>>?,
                    // );

                    final extra = state.extra as Map<String, dynamic>?;

                    return CreateGatheringCircleScreen(
                      place: extra?['place'] as PlacesSearchResult?,
                      initialActivity: extra?['activity'] as String?,
                      registeredUsers:
                          extra?['registeredUsers'] as List<UserModel>?,
                      unregisteredUsers: extra?['unregisteredUsers']
                          as List<Map<String, String>>?,
                    );
                  },
                ),
                GoRoute(
                  path: 'gathering-details/:gatheringId',
                  // use your app's root navigator key
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    final gatheringId = state.pathParameters['gatheringId']!;
                    return GatheringDetailsScreen(gatheringId: gatheringId);
                  },
                ),
                GoRoute(
                  path: 'edit',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) {
                    final gathering = state.extra as GatheringModel;
                    return EditGatheringCircle(gathering: gathering);
                  },
                ),
                GoRoute(
                  path: 'select-location',
                  builder: (context, state) {
                    final eventType = state.extra as String;
                    return SelectLocationGatheringScreen(eventType: eventType);
                  },
                ),
                GoRoute(
                  path: 'location-details',
                  builder: (context, state) {
                    final data = state.extra as Map<String, dynamic>;
                    final place = data['place'] as PlacesSearchResult;
                    final activity = data['activity'] as String;
                    return LocationDetailsGatheringScreen(
                      placesSearchResult: place,
                      activty: activity,
                    );
                  },
                ),
              ]),
          GoRoute(
            path: '/discover',
            builder: (context, state) => DiscoverScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => ProfileScreen(),
          ),
        ],
      ),

      GoRoute(
        path: '/select-location',
        builder: (context, state) {
          final eventType = state.extra as String;
          return SelectLocationScreen(eventType: eventType);
        },
      ),

      GoRoute(
        path: '/location-details',
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          final place = data['place'] as PlacesSearchResult;
          final activity = data['activity'] as String;
          return LocationDetailsScreen(
            placesSearchResult: place,
            activty: activity,
          );
        },
      ),

      GoRoute(
        path: '/bond-relation/:friendId',
        builder: (context, state) {
          final friendId = state.pathParameters['friendId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};

          return BondRelationshipScreen(
            friendId: friendId,
            friendName: extra['friendName'] ?? '',
          );
        },
      ),

      GoRoute(
        path: '/user-details',
        builder: (context, state) => UserDetailsScreen(),
      ),

      GoRoute(
        path: '/success',
        builder: (context, state) => SuccessScreen(),
        redirect: (context, state) {
          // final user = ref.watch(authStateProvider).asData?.value;
          // final userData =
          //     ref.watch(userDataProvider(user?.uid ?? '')).asData?.value;

          final container = ProviderContainer();
          final justLoggedIn = container.read(justLoggedInProvider);

          log('just logged in value : $justLoggedIn');

          if (user == null) return '/';

          // ✅ Delay redirection to allow SuccessScreen to be shown for 3 seconds
          if (justLoggedIn) {
            // ✅ Reset the login state so this screen doesn't show again after reopening
            Future.microtask(() {
              ref.read(justLoggedInProvider.notifier).state = false;
            });
            Future.delayed(Duration(seconds: 3), () {
              if (userData != null && userData.exists) {
                return '/discover'; // ✅ Move to bond screen after delay
              } else if (userData != null && !userData.exists) {
                return '/user-details'; // ✅ Move to user-details if needed
              }
            });
          } else {
            if (userData != null && userData.exists) return '/discover';
            if (userData != null && !userData.exists) return '/user-details';
          }

          return null;
        },
      ),
    ],
  );
});

// class MyApp extends ConsumerWidget {
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
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

class MyApp extends ConsumerStatefulWidget {
  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Setup notification tap handling with context
    Future.microtask(() {
      // NotificationHandler.handleInitialMessage(context);
      // NotificationHandler.listenToForegroundMessages(context);
      NotificationHandler.listenToMessageTap(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
      theme: AppTheme.lightTheme,
      title: 'Connecto',
    );
  }
}

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen<User?>(
      authStateProvider.select((value) => value.asData?.value),
      (previous, next) {
        log('=======refreshing=====');
        notifyListeners(); // ✅ Notify GoRouter to refresh when auth state changes
      },
    );
  }
}
