import 'dart:developer';
import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connecto/feature/auth/model/user_model.dart';
import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/feature/dashboard/widgets/common_appbar.dart';
import 'package:connecto/feature/dashboard/widgets/common_sliver_appbar.dart';
import 'package:connecto/feature/dashboard/widgets/common_transparent_appbar.dart';
import 'package:connecto/feature/dashboard/widgets/greetings_sliver_apparbar.dart';
import 'package:connecto/feature/discover/data/activity_model.dart';
import 'package:connecto/feature/discover/helpers/photo_cache_helper.dart';
import 'package:connecto/feature/discover/helpers/place_cache_helper.dart';
import 'package:connecto/feature/discover/widgets/activity_strip.dart';
import 'package:connecto/feature/discover/widgets/cache_data_googleplaces.dart';
import 'package:connecto/feature/discover/widgets/category_card_shimmer.dart';
import 'package:connecto/feature/discover/widgets/parallax_background.dart';
import 'package:connecto/feature/discover/widgets/parallax_horizontal_image.dart';
import 'package:connecto/feature/discover/widgets/test_card.dart';
import 'package:connecto/feature/gatherings/data/acitivity_data.dart';
import 'package:connecto/feature/gatherings/models/catoegory_places.dart';
import 'package:connecto/feature/gatherings/models/gathering_model.dart';
import 'package:connecto/feature/gatherings/screens/create_gathering_circle.dart';
import 'package:connecto/feature/gatherings/screens/gathering_list.dart';
import 'package:connecto/feature/gatherings/widgets/gathering_card.dart';

import 'package:connecto/helper/get_initials.dart';
import 'package:connecto/my_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

const double kHeaderHeight = 400;

const double headerHeight = 360; // gradient block
const double overlap = 30;

const double kOverlap = 300;

const double kStartContentAt = 300; // where your greeting sits
const double kParallaxFactor = 0.35;

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with TickerProviderStateMixin {
  final List<Map<String, dynamic>> activities = reservedActivityList;

  late final AnimationController _controller = AnimationController(
    duration: const Duration(seconds: 2),
    vsync: this,
  )..forward();

  String? selectedActivity;
  final subtitleColor = const Color(0xff9DA5A5);
  // Future<Position> getCurrentPosition() async {
  //   LocationPermission permission = await Geolocator.checkPermission();
  //   // Geolocator.requestPermission();
  //   log('permission : $permission');

  //   if (permission == LocationPermission.denied ||
  //       permission == LocationPermission.deniedForever) {
  //     permission = await Geolocator.requestPermission();
  //     if (permission != LocationPermission.always &&
  //         permission != LocationPermission.whileInUse) {
  //       throw Exception("Location permission not granted");
  //     }
  //   }
  //   final position = await Geolocator.getCurrentPosition();
  //   log('======cur pos in fn : $position');
  //   return position;
  // }

  Future<Position> getCurrentPosition() async {
  // 1️⃣ Check if location services are enabled
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception("Location services are disabled");
  }

  // 2️⃣ Check and request permission if needed
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception("Location permission denied");
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception(
        "Location permissions are permanently denied, please enable them from settings.");
  }

  // 3️⃣ Now safely get the position
  return await Geolocator.getCurrentPosition(
    // desiredAccuracy: LocationAccuracy.high,
  );
}


  /// Optimized: cache-first, smaller radius, limit results.
  Future<List<CategoryPlaces>> fetchSuggestedDiscoverPlacesOptimized(
    Position currentPosition, {
    // tuning knobs
    List<String> categories = const [
      'Desert camping',
      'Padel Tennis',
      'Sheesha Longue',
      'Football',
    ],
    int radiusMeters = 3000, // ↓ from 10km → 3km
    int maxResultsPerCategory = 6, // show only what you need
    Duration cacheTtl = const Duration(hours: 12), // refresh twice a day
  }) async {
    final places = GoogleMapsPlaces(apiKey: googleApiKey);

    final cache = PlacesCache();
    final cacheKey = cache.key(
      categories: categories,
      lat: currentPosition.latitude,
      lng: currentPosition.longitude,
      radius: radiusMeters,
      maxPerCategory: maxResultsPerCategory,
    );

    // 1) Cache-first
    final cached = cache.get(cacheKey, cacheTtl);
    if (cached != null) return cached;

    // 2) Fetch minimal fresh data (sequential to avoid bursty costs)
    final List<CategoryPlaces> out = [];
    final loc = Location(
      lat: currentPosition.latitude,
      lng: currentPosition.longitude,
    );

    for (final category in categories) {
      final resp = await places.searchByText(
        category,
        location: loc,
        radius: radiusMeters,
        // rankby cannot be used with radius + keyword together in some endpoints,
        // Text Search uses relevance by default which is fine here.
        // If you switch to NearbySearch, you can play with rankby=prominence/distance.
      );

      if (resp.isOkay && resp.results.isNotEmpty) {
        final trimmed = resp.results.take(maxResultsPerCategory).toList();
        out.add(CategoryPlaces(category: category, results: trimmed));
      } else {
        out.add(CategoryPlaces(category: category, results: const []));
      }
    }

    // 3) Save to cache
    cache.put(cacheKey, out);
    return out;
  }

  Future<List<CategoryPlaces>> fetchSuggestedDiscoverPlaces(
    Position currentPosition, {
    List<String> categories = const [
      'Desert camping',
      'Padel Tennis',
      'Sheesha Longue',
      'Football',
    ],
    int radiusMeters = 3000,
    int maxResultsPerCategory = 6,
    Duration cacheTtl = const Duration(hours: 12),
  }) async {
    log('4.=====inside fetch suggestions===');
    final cacheKey = PlacesCacheHelper.buildKey(
      categories: categories,
      lat: currentPosition.latitude,
      lng: currentPosition.longitude,
      radius: radiusMeters,
      maxPerCategory: maxResultsPerCategory,
    );

    // 1) Try cache
    final cached = await PlacesCacheHelper.load(cacheKey, ttl: cacheTtl);
    log("==chached places : $cached");
    if (cached != null) return cached;
    log('==places not in cache====');

    // 2) Fetch fresh
    final List<CategoryPlaces> out = [];
    final loc = Location(
      lat: currentPosition.latitude,
      lng: currentPosition.longitude,
    );

    final places = GoogleMapsPlaces(apiKey: googleApiKey);

    for (final category in categories) {
      final resp = await places.searchByText(
        category,
        location: loc,
        radius: radiusMeters,
      );

      if (resp.isOkay && resp.results.isNotEmpty) {
        final trimmed = resp.results.take(maxResultsPerCategory).toList();
        out.add(CategoryPlaces(category: category, results: trimmed));
      } else {
        out.add(CategoryPlaces(category: category, results: const []));
      }
    }

    // 3) Save cache
    await PlacesCacheHelper.save(cacheKey, out);
    return out;
  }

  // Future<List<CategoryPlaces>> fetchSuggestedDiscoverPlaces(
  //     Position currentPosition) async {
  //   final GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: googleApiKey);

  //   final List<String> categories = [
  //     "Desert camping",
  //     "Padel Tennis",
  //     "Sheesha Longue",
  //     "Football",
  //   ];

  //   final List<CategoryPlaces> categorizedResults = [];

  //   for (final category in categories) {
  //     final PlacesSearchResponse response = await places.searchByText(
  //       category,
  //       location: Location(
  //         lat: currentPosition.latitude,
  //         lng: currentPosition.longitude,
  //       ),
  //       radius: 10000, // 10km
  //     );

  //     if (response.isOkay && response.results.isNotEmpty) {
  //       categorizedResults.add(
  //         CategoryPlaces(category: category, results: response.results),
  //       );
  //     }
  //   }

  //   return categorizedResults;
  // }

  List<CategoryPlaces> placeSuggestions = [];
  bool isPlaceLoading = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    log('1. inside initstate');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      log('2.===== inside widgets binding====');
      _loadSuggestedPlaces();
    });
  }

  Future<void> _loadSuggestedPlaces() async {
    log('3....inside _load');
    try {
      final position = await getCurrentPosition(); // Ensure permissions handled
      log('3.5 : ====== position : $position');
      final results = await fetchSuggestedDiscoverPlaces(position);
      log('5..results : $results');
      setState(() {
        placeSuggestions = results;
        isPlaceLoading = false;
      });
      log('suggested places : $placeSuggestions');
    } catch (e) {
      log("Error loading places: $e");
      setState(() => isPlaceLoading = false);
    }
  }

  Widget build(BuildContext context) {
    final publicGatheringAsync = ref.watch(publicGatheringsProvider);
    final upcomingAsync = ref.watch(upcomingGatheringsProvider);
    final pendingAsync = ref.watch(pendingGatheringsProvider);
    final userAsync = ref.watch(currentUserProvider);

    final double topPad = MediaQuery.paddingOf(context).top;

    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xff001311),
      // floatingActionButton: FloatingActionButton(
      //   backgroundColor: const Color(0xFF03FFE2),
      //   shape: const CircleBorder(),
      //   heroTag: 'fab-2',
      //   onPressed: () {
      //     context.go('/gathering/create-gathering-circle');
      //   },
      //   child: const Icon(Icons.add, size: 20),
      // ),

      floatingActionButton: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // 1. The expanding container
          OpenContainer(
            transitionDuration: const Duration(milliseconds: 500),
            closedShape: const CircleBorder(),
            closedElevation: 6.0,
            openElevation: 0.0,
            closedColor: const Color(0xFF03FFE2),
            openColor: Theme.of(context).scaffoldBackgroundColor,
            closedBuilder: (context, openContainer) {
              return SizedBox(
                height: 56,
                width: 56,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact(); // ✅ Vibration on tap
                      openContainer();
                    },
                    customBorder: const CircleBorder(),
                    splashColor:
                        Colors.white.withOpacity(0.2), // ✅ Subtle ripple
                    child: const SizedBox(), // No icon here
                  ),
                ),
              );
            },
            openBuilder: (context, _) => CreateGatheringCircleScreen(),
          ),

          // 2. Static Icon overlay
          Positioned(
            child: IgnorePointer(
              child: Container(
                height: 56,
                width: 56,
                alignment: Alignment.center,
                child: const Icon(Icons.add, size: 20, color: Colors.black),
              ),
            ),
          ),
        ],
      ),

      // SliverPersistentHeader(
      //   pinned: false, // stays visible on scroll
      //   delegate: CommonSliverAppBar(ref),
      // ),
      // // Push content down so the first card starts at 300 from top
      // SliverToBoxAdapter(child: SizedBox(height: 40)),
      // SliverToBoxAdapter(
      //   child: Padding(
      //     padding: const EdgeInsets.all(20.0),
      //     child: Column(
      //       crossAxisAlignment: CrossAxisAlignment.start,
      //       children: [
      //         Text(
      //           'Good Morning ✋',
      //           style: TextStyle(
      //             color: const Color(0xFFEFF1F5),
      //             fontSize: 24,
      //             fontFamily: 'Inter',
      //             fontWeight: FontWeight.w600,
      //             height: 1.08,
      //           ),
      //         ),
      //         Text(
      //           'It’s a great weather for outdoor activities',
      //           style: TextStyle(
      //             color: Colors.white,
      //             fontSize: 14,
      //             fontFamily: 'Inter',
      //             fontWeight: FontWeight.w400,
      //             height: 1.86,
      //           ),
      //         )
      //       ],
      //     ),
      //   ),
      // ),

      //  IgnorePointer(
      //   child: Container(
      //     height: headerHeight + topPad,
      //     width: double.infinity,

      //     // 🌅 Background image
      //     decoration: BoxDecoration(
      //       image: DecorationImage(
      //         image:
      //             const AssetImage('assets/images/landscape_morning.png'),
      //         fit: BoxFit.cover,
      //         // nudge image up (≈ 50–100px depending on height)
      //         // -1.0 = top, 0 = center, 1.0 = bottom
      //         // tweak to taste
      //       ),
      //     ),

      //     // 🌗 Gradient overlay (on top of the image)
      //     foregroundDecoration: const BoxDecoration(
      //       gradient: LinearGradient(
      //         begin: Alignment.topCenter,
      //         end: Alignment.bottomCenter,
      //         colors: [
      //           Color(0x00092422), // transparent top
      //           Color(0xFF091F1E), // dark bottom
      //         ],
      //         stops: [0.4, 1.0],
      //       ),
      //     ),
      //   ),
      // ),

      // appBar: CommonAppBar(),

      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0)
                  .copyWith(top: 0, right: 0, left: 0),
              child: Stack(
                children: [
                  // 🔹 Parallax background
                  SizedBox(
                    height: kHeaderHeight + MediaQuery.paddingOf(context).top,
                    width: double.infinity,
                    child: IgnorePointer(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned.fill(
                            top: -topInset,
                            child: ParallaxImage(
                              asset: 'assets/images/landscape_morning.png',
                              extent: kHeaderHeight +
                                  MediaQuery.paddingOf(context).top,
                              speed: 0.35,
                              overscan: 32,
                            ),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00092422), Color(0xFF091F1E)],
                                stops: [0.4, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: 800,
                    decoration: BoxDecoration(
                      // color: Colors.transparent,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        // begin: Alignment(0.48, -0.00),
                        // end: Alignment(0.5,.7),
                        colors: [
                          const Color(0x00092422),
                          const Color(0xFF001311)
                        ],
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SafeArea(child: CommonTransparentAppBar()),
                      SizedBox(
                        height: 30,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: const TextStyle(
                                color: Color(0xFFEFF1F5),
                                fontSize: 24,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                height: 1.08,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getActivitySuggestion(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w400,
                                height: 1.86,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      upcomingAsync.when(
                        data: (upcomingList) => upcomingList.isEmpty
                            ? SizedBox()
                            : Padding(
                                padding:
                                    const EdgeInsets.only(right: 20, left: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    pendingAsync.when(
                                      data: (pendingList) => pendingList.isEmpty
                                          ?
                                          // EmptyInviteCard(title: "No pending invites")
                                          SizedBox()
                                          : Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        'Your pending event requests',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 18,
                                                          fontFamily: 'SFPRO',
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8,
                                                                vertical: 2),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              0xFF00312D),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                        child: Text(
                                                          '${upcomingList.length}',
                                                          style: TextStyle(
                                                            color: const Color(
                                                                0xFF03FFE2),
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  GatheringCard(
                                                      gathering:
                                                          pendingList.first,
                                                      isPending: true),
                                                  SizedBox(
                                                    height: 16,
                                                  ),
                                                  GestureDetector(
                                                    onTap: () {
                                                      // context.push('/gathering'); // or context.push
                                                      GoRouter.of(rootNavigatorKey
                                                              .currentContext!)
                                                          .go('/gathering');
                                                    },
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        Text(
                                                          "View all",
                                                          style: TextStyle(
                                                            color: Color(
                                                                0xFF03FFE2),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 4),
                                                        const Icon(
                                                            Icons.arrow_forward,
                                                            color: Color(
                                                                0xFF03FFE2),
                                                            size: 16),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 32),
                                                ]),
                                      loading: () => SizedBox(),
                                      error: (e, _) =>
                                          Text("Error loading pending: $e"),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'Your upcoming events',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontFamily: 'SFPRO',
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00312D),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            '${upcomingList.length}',
                                            style: TextStyle(
                                              color: const Color(0xFF03FFE2),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // ...upcomingList.map((g) =>
                                    //     GatheringCard(gathering: g, isPending: false)),
                                    GatheringCard(
                                            gathering: upcomingList.first,
                                            isPending: false)
                                        .animate()
                                        .fadeIn(duration: 300.ms)
                                    // .scale(begin: 0.95, end: 1.0)
                                    // .scaleXY(begin: 0.95, end: 1.0),
                                    ,
                                    SizedBox(
                                      height: 16,
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        // context.push('/gathering'); // or context.push
                                        GoRouter.of(rootNavigatorKey
                                                .currentContext!)
                                            .go('/gathering');
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            "View all",
                                            style: TextStyle(
                                              color: Color(0xFF03FFE2),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.arrow_forward,
                                              color: Color(0xFF03FFE2),
                                              size: 16),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                  ],
                                ),
                              ),
                        loading: () => SizedBox(),
                        error: (e, _) {
                          log("error : $e");
                          return Text("Error loading upcoming: $e");
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Text("Search by category",
                            style: TextStyle(
                                fontFamily: 'SFPRO',
                                // color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w400)),
                      ),
                      SizedBox(height: 16),

                      // PadelEventCard(
                      //   imageProvider: const NetworkImage('https://www.exoticadubai.tajhotels.com/wp-content/uploads/sites/470/2023/08/Padel-Court-2-edited.jpg'),
                      //   onTap: () {},
                      // ),

                      // Container(
                      //   width: 375,
                      //   height: 162,
                      //   padding: const EdgeInsets.symmetric(
                      //       horizontal: 16, vertical: 24),
                      //   decoration: ShapeDecoration(
                      //     gradient: LinearGradient(
                      //       begin: Alignment(0.50, 1.00),
                      //       end: Alignment(0.50, 0.00),
                      //       colors: [
                      //         const Color(0xFF001311),
                      //         const Color(0xFF3C8884)
                      //       ],
                      //     ),
                      //     shape: RoundedRectangleBorder(
                      //       borderRadius: BorderRadius.only(
                      //         bottomLeft: Radius.circular(8),
                      //         bottomRight: Radius.circular(8),
                      //       ),
                      //     ),
                      //     shadows: [
                      //       BoxShadow(
                      //         color: Color(0x3F000000),
                      //         blurRadius: 4,
                      //         offset: Offset(0, 4),
                      //         spreadRadius: 0,
                      //       )
                      //     ],
                      //   ),
                      // ),

                      // replace your GridView with:
                      ActivityStrip(
                        items: activitiesNew,
                        initialSelected: selectedActivity,
                        onSelected: (name) {
                          context.push('/select-location', extra: name);
                        },
                      ),

                      // Padding(
                      //   padding: const EdgeInsets.only(left: 20),
                      //   child: GridView.builder(
                      //     shrinkWrap: true,
                      //     itemCount: activities.length,
                      //     physics: NeverScrollableScrollPhysics(),
                      //     padding: EdgeInsets.only(right: 20),
                      //     gridDelegate:
                      //         SliverGridDelegateWithFixedCrossAxisCount(
                      //       crossAxisCount: 2,
                      //       crossAxisSpacing: 16,
                      //       mainAxisSpacing: 16,
                      //       childAspectRatio: 182 / 104,
                      //     ),
                      //     itemBuilder: (context, index) {
                      //       String activity = activities[index]['name'];
                      //       bool isSelected = selectedActivity == activity;

                      //       return Bounceable(
                      //         onTap: () {
                      //           // setState(() {
                      //           //   selectedActivity = activity;
                      //           // });
                      //           HapticFeedback.lightImpact();

                      //           context.push('/select-location',
                      //               extra: activity);
                      //         },
                      //         child: Container(
                      //           padding: EdgeInsets.symmetric(horizontal: 16),
                      //           decoration: BoxDecoration(
                      //             color: Color(0xff091F1E),
                      //             borderRadius: BorderRadius.circular(12),
                      //             border: Border.all(
                      //               color: isSelected
                      //                   ? Color(0xFF03FFE2)
                      //                   : Colors.transparent,
                      //               width: 2,
                      //             ),
                      //           ),
                      //           child: Column(
                      //             mainAxisAlignment: MainAxisAlignment.center,
                      //             children: [
                      //               Icon(activities[index]['icon'],
                      //                   color: Color(0xFF03FFE2)),
                      //               SizedBox(height: 8),
                      //               Text(
                      //                 activity,
                      //                 style: TextStyle(
                      //                     color: Colors.white,
                      //                     fontSize: 14,
                      //                     fontWeight: FontWeight.w500,
                      //                     fontFamily: 'SFPRO'),
                      //               ),
                      //             ],
                      //           ),
                      //         ),
                      //       )
                      //           .animate()
                      //           .fadeIn(duration: 300.ms)
                      //           // .scale(begin: 0.95, end: 1.0)
                      //           .scaleXY(begin: 0.95, end: 1.0)
                      //           .then(
                      //               delay: Duration(milliseconds: index * 100));
                      //     },
                      //   ),
                      // ),
                      SizedBox(
                        height: 16,
                      ),

                      publicGatheringAsync.when(
                        data: (publicList) => publicList.isEmpty
                            ? SizedBox()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 36,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: Text(
                                      'Trending public events',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontFamily: 'SFPRO',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 8,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: Text(
                                      'Suggestions based on your location',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontFamily: 'SFPRO',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 24,
                                  ),
                                  Container(
                                    height: 308,
                                    child: ListView.builder(
                                      itemCount: publicList.length,
                                      shrinkWrap: true,
                                      scrollDirection: Axis.horizontal,
                                      itemBuilder: (context, index) {
                                        final gathering = publicList[index];
                                        List<String> inviteeNames = [
                                          ...gathering.invitees.values
                                              .map((e) => e.name),
                                          ...gathering
                                              .nonRegisteredInvitees.values
                                              .map((e) => e.name),
                                          ...gathering.joinedPublicUsers.values
                                              .map((e) => e.name),
                                        ];
                                        return Padding(
                                            padding: EdgeInsets.only(
                                                left: index == 0 ? 20 : 0),
                                            child: buildEventHorizontalCard(
                                                context,
                                                gathering,
                                                inviteeNames));
                                      },
                                    ),
                                  ),
                                ],
                              ),
                        loading: () => SizedBox(),
                        error: (e, _) {
                          log('error : $e');
                          return Text("Error loading public: $e");
                        },
                      ),
                      if (placeSuggestions.isNotEmpty)
                        ...placeSuggestions
                            .map((category) => buildCategoryGrid(category))
                            .toList(),
                      if (placeSuggestions.isEmpty) ...[
                        buildCategoryGridShimmer(),
                        buildCategoryGridShimmer()
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: kHeaderHeight)),
        ],
      ),
    );
  }

  Padding buildEventHorizontalCard(BuildContext context,
      GatheringModel gathering, List<String> inviteeNames) {
    const double _imageHeight = 160; // your ParallaxX height
    const double _seamHeight = 88; // how tall the glass band is
    const double _overlapUp = 26; // how far the band climbs into the image
   
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Bounceable(
        onTap: () {
          context.push('/gathering/gathering-details/${gathering.id}',
              extra: gathering);
        },
        child: Container(
          // height: 313,
          width: 200,
          decoration: ShapeDecoration(
            color: const Color(0xFF091F1E),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      // ClipRRect(
                      //   borderRadius: const BorderRadius.only(
                      //     topLeft: Radius.circular(12),
                      //     topRight: Radius.circular(12),
                      //   ),
                      //   child: ParallaxX(
                      //     extent: 200, // the card’s width (visible part)
                      //     height: 160, // your image height
                      //     speed: 0.40, // tweak 0.25–0.55
                      //     overscan: 32,
                      //     borderRadius: const BorderRadius.only(
                      //       topLeft: Radius.circular(12),
                      //       topRight: Radius.circular(12),
                      //     ),
                      //     image: CachedNetworkImageProvider(
                      //       'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${gathering.photoRef}&key=$googleApiKey',
                      //     ),
                      //     fit: BoxFit.cover,
                      //   ),
                      // ),
                      ShaderMask(
                        shaderCallback: (Rect rect) {
                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            // keep most of the image opaque, fade in last ~30%
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.white.withOpacity(.4)
                            ],
                            stops: [0.0, 0.7, 1.0],
                          ).createShader(rect);
                        },
                        blendMode: BlendMode.dstIn,
                        child: ParallaxX(
                          extent: 200,
                          height: 160,
                          speed: 0.40,
                          overscan: 32,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          image: CachedNetworkImageProvider(
                            // 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${gathering.photoRef}&key=$googleApiKey',
                            placePhotoUrl(gathering.photoRef!,
                                width: 200, apiKey: googleApiKey!),
                            cacheManager: placePhotoCache,
                            cacheKey: placePhotoCacheKey(gathering.photoRef!,
                                width: 200),
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                  // SizedBox(
                  //   height: 20,
                  // ),
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: Container(
                      // height: 153,
                      // decoration: BoxDecoration(
                      //   borderRadius: const BorderRadius.only(
                      //     bottomLeft: Radius.circular(12),
                      //     bottomRight: Radius.circular(12),
                      //   ),
                      // ),
                      padding: EdgeInsets.all(0),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(0.50, 1.00),
                                  end: Alignment(0.50, 0.00),
                                  colors: [
                                    const Color(0xFF091F1E),
                                    const Color(0xFF0F4A47)
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(1.05, 1), // bottom-right
                                  radius: 0.9,
                                  colors: [
                                    Color(0x664AAEAA), // soft aqua
                                    Color(0x004AAEAA),
                                  ],
                                  stops: [0.0, 1.0],
                                ),
                              ),
                            ),
                          ),
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 0, sigmaY: 15),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0)
                                    .copyWith(top: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      gathering.name,
                                      style: TextStyle(
                                        color: Colors.white,
                                        overflow: TextOverflow.ellipsis,
                                        fontSize: 16,
                                        fontFamily: 'SFPRO',
                                        fontWeight: FontWeight.w700,
                                        height: 1.38,
                                      ),
                                    ),
                                    SizedBox(
                                      height: 8,
                                    ),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on,
                                            color: subtitleColor, size: 18),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            gathering.location.name,
                                            maxLines: 1,
                                            style: TextStyle(
                                              color: subtitleColor,
                                              overflow: TextOverflow.ellipsis,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    FittedBox(
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time,
                                              color: subtitleColor, size: 18),
                                          const SizedBox(width: 6),
                                          Text(
                                            "${formatTime(gathering.dateTime)} – ${formatDate(gathering.dateTime)}",
                                            style: TextStyle(
                                              color: subtitleColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: 10,
                                    ),
                                    buildInviteeAvatars(inviteeNames),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildInviteeAvatars(List<String> names) {
    const double avatarSize = 24;
    const double overlap = 20;

    List<Widget> avatars = [];

    final showNames = names.take(9).toList();
    final remaining = names.length - showNames.length;

    for (int i = 0; i < showNames.length; i++) {
      avatars.add(Positioned(
        left: i * overlap.toDouble(),
        child: CircleAvatar(
          radius: avatarSize / 2,
          backgroundColor: Colors.white,
          child: Text(
            getInitials(showNames[i]),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ));
    }

    if (remaining > 0) {
      avatars.add(Positioned(
        left: showNames.length * overlap.toDouble(),
        child: CircleAvatar(
          radius: avatarSize / 2,
          backgroundColor: Colors.white,
          child: Text("+$remaining",
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ));
    }

    return SizedBox(
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: avatars,
      ),
    );
  }

  String formatDate(DateTime dateTime) =>
      DateFormat('dd MMM yyyy').format(dateTime);

  String formatTime(DateTime dateTime) =>
      DateFormat('h:mm a').format(dateTime).toUpperCase();

  Widget _buildTimeStatus(DateTime eventTime, BuildContext context) {
    final now = DateTime.now();
    final start = eventTime;
    final end =
        eventTime.add(Duration(minutes: 60)); // ⏱️ Event duration = 1 hour
    String label;
    Color bgColor;

    if (now.isBefore(start)) {
      final diff = start.difference(now);
      label = 'Starts in ${formatDuration(diff)}';
      bgColor = Theme.of(context).colorScheme.secondary;
    } else if (now.isAfter(start) && now.isBefore(end)) {
      label = 'Ongoing';
      bgColor = Theme.of(context).colorScheme.primary;
    } else {
      label = 'Event ended';
      bgColor = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: ShapeDecoration(
        color: bgColor,
        shape: RoundedRectangleBorder(
          // side: BorderSide(width: 1, color: Colors.white),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: label == 'Event ended' ? Colors.white : Color(0xFF243443),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String formatDuration(Duration diff) {
    final totalMinutes = diff.inMinutes.abs();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Widget buildCategoryGrid(CategoryPlaces category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 36),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            category.category,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
        SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            "Suggested based on what's trending near you",
            style: TextStyle(fontSize: 14, color: Color(0xff9DA5A5)),
          ),
        ),
        SizedBox(height: 16),
        Container(
          height: 265,
          child: ListView.builder(
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            itemCount: category.results.length,
            itemBuilder: (context, index) {
              final place = category.results[index];
              return Padding(
                padding: EdgeInsets.only(right: 16, left: index == 0 ? 20 : 0),
                child: Bounceable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    // context.push(
                    //   '/gathering/create-gathering-circle',
                    //   extra: {
                    //     'activity': category.category, // String?
                    //     'place': place,
                    //   },
                    // );
                    context.push(
                      '/location-details',
                      extra: {
                        'place': place,
                        'activity': category.category,
                      },
                    );
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 200,

                        // padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xff091F1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon(Icons.location_on, color: Color(0xFF03FFE2)),
                            place.photos.isEmpty ||
                                    place.photos[0].photoReference.isEmpty
                                ? Container(
                                    height: 160,
                                    width: double.infinity,
                                    color: Colors.grey.shade800,
                                    alignment: Alignment.center,
                                    child: Icon(Icons.image_not_supported,
                                        color: Colors.white),
                                  )
                                : ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
                                    ),
                                    child: ShaderMask(
                                      shaderCallback: (Rect rect) {
                                        return LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          // keep most of the image opaque, fade in last ~30%
                                          colors: [
                                            Colors.white,
                                            Colors.white,
                                            Colors.white.withOpacity(.4)
                                          ],
                                          stops: [0.0, 0.7, 1.0],
                                        ).createShader(rect);
                                      },
                                      blendMode: BlendMode.dstIn,
                                      child: ParallaxX(
                                        extent:
                                            200, // the card’s width (visible part)
                                        height: 160, // your image height
                                        speed: 0.40, // tweak 0.25–0.55
                                        overscan: 32,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                          topRight: Radius.circular(12),
                                        ),

                                        image: CachedNetworkImageProvider(
                                          'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${place.photos[0].photoReference}&key=$googleApiKey',
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),

                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              child: Container(
                                height: 105,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment(0.50, 1.00),
                                    end: Alignment(0.50, 0.00),
                                    colors: [
                                      const Color(0xFF091F1E),
                                      const Color(0xFF0F4A47)
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment(0.50, 1.00),
                                            end: Alignment(0.50, 0.00),
                                            colors: [
                                              const Color(0xFF091F1E),
                                              const Color(0xFF0F4A47)
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: const BoxDecoration(
                                          gradient: RadialGradient(
                                            center: Alignment(
                                                1.05, 1), // bottom-right
                                            radius: 0.9,
                                            colors: [
                                              Color(0x664AAEAA), // soft aqua
                                              Color(0x004AAEAA),
                                            ],
                                            stops: [0.0, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                    BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 15, sigmaY: 15),
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0)
                                              .copyWith(top: 17),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                place.name,
                                                // 'test',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                place.formattedAddress ?? '',
                                                // '',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xff9DA5A5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  // .scale(begin: 0.95, end: 1.0)
                  .scaleXY(begin: 0.95, end: 1.0)
                  .then(delay: Duration(milliseconds: index * 100));
            },
          ),
        ),
      ],
    )
        .animate()
        // .slideX(begin: 0.2)
        .fadeIn();
  }
}

// --- Logic ---
String _getGreeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good Morning ✋';
  if (h < 17) return 'Good Afternoon ✋';
  return 'Good Evening ✋';
}

enum _TimeSlot { morning, afternoon, evening, night }

_TimeSlot _slotForNow(DateTime now) {
  final h = now.hour;
  if (h >= 20 || h < 5) return _TimeSlot.night; // 8pm–4:59am
  if (h >= 17) return _TimeSlot.evening; // 5pm–7:59pm
  if (h >= 12) return _TimeSlot.afternoon; // 12pm–4:59pm
  return _TimeSlot.morning; // 5am–11:59am
}

String _getActivitySuggestion() {
  // Your catalog grouped by time of day.
  const morning = [
    'running',
    'football',
    'padel tennis',
  ];
  const afternoon = [
    'football',
    'padel tennis',
    'running',
  ];
  const evening = [
    'football',
    'padel tennis',
    'running',
    'macha',
    'sheeha lounge',
  ];
  const night = [
    'desert camping',
    'sheeha lounge',
    'macha',
  ];

  final now = DateTime.now();
  final slot = _slotForNow(now);

  final list = switch (slot) {
    _TimeSlot.morning => morning,
    _TimeSlot.afternoon => afternoon,
    _TimeSlot.evening => evening,
    _TimeSlot.night => night,
  };

  // Deterministic pick for the day (stable across rebuilds, changes next day).
  final dailyIndex = _indexForToday(list.length);
  final activity = list[dailyIndex];

  // Keep your original copy; change to “It’s great weather…” if you prefer.
  return "It’s a great weather for $activity";
}

// Stable daily index without Random().
int _indexForToday(int length) {
  final now = DateTime.now();
  final key = '${now.year}-${now.month}-${now.day}';
  // Simple hash → positive → mod list length
  final hash = key.hashCode & 0x7fffffff;
  return hash % length;
}
