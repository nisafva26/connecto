import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connecto/feature/dashboard/widgets/common_appbar.dart';
import 'package:connecto/feature/discover/widgets/category_card_shimmer.dart';
import 'package:connecto/feature/gatherings/data/acitivity_data.dart';
import 'package:connecto/feature/gatherings/models/catoegory_places.dart';
import 'package:connecto/feature/gatherings/models/gathering_model.dart';
import 'package:connecto/feature/gatherings/screens/gathering_list.dart';
import 'package:connecto/feature/gatherings/widgets/gathering_card.dart';

import 'package:connecto/helper/get_initials.dart';
import 'package:connecto/my_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as map;

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final List<Map<String, dynamic>> activities = reservedActivityList;

  String? selectedActivity;
  final subtitleColor = const Color(0xff9DA5A5);
  @override
  Future<Position> getCurrentPosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    // Geolocator.requestPermission();
    log('permission : $permission');

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw Exception("Location permission not granted");
      }
    }
    final position = await Geolocator.getCurrentPosition();
    log('cur pos in fn : $position');
    return position;
  }

  Future<List<CategoryPlaces>> fetchSuggestedDiscoverPlaces(
      Position currentPosition) async {
    final GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: googleApiKey);

    final List<String> categories = [
      "Desert camping",
      "Padel Tennis",
      "Sheesha Longue",
      "Football",
    ];

    final List<CategoryPlaces> categorizedResults = [];

    for (final category in categories) {
      final PlacesSearchResponse response = await places.searchByText(
        category,
        location: Location(
          lat: currentPosition.latitude,
          lng: currentPosition.longitude,
        ),
        radius: 10000, // 10km
      );

      if (response.isOkay && response.results.isNotEmpty) {
        categorizedResults.add(
          CategoryPlaces(category: category, results: response.results),
        );
      }
    }

    return categorizedResults;
  }

  List<CategoryPlaces> placeSuggestions = [];
  bool isPlaceLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadSuggestedPlaces();
    });
  }

  Future<void> _loadSuggestedPlaces() async {
    try {
      final position = await getCurrentPosition(); // Ensure permissions handled
      final results = await fetchSuggestedDiscoverPlaces(position);
      setState(() {
        placeSuggestions = results;
        isPlaceLoading = false;
      });
      log('suggested places : ${placeSuggestions}');
    } catch (e) {
      log("Error loading places: $e");
      setState(() => isPlaceLoading = false);
    }
  }

  Widget build(BuildContext context) {
    final publicGatheringAsync = ref.watch(publicGatheringsProvider);
    final upcomingAsync = ref.watch(upcomingGatheringsProvider);
    final pendingAsync = ref.watch(pendingGatheringsProvider);
    return Scaffold(
      backgroundColor: const Color(0xff001311),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF03FFE2),
        shape: const CircleBorder(),
        heroTag: 'fab-2',
        onPressed: () {
          context.go('/gathering/create-gathering-circle');
        },
        child: const Icon(Icons.add, size: 20),
      ),
      appBar: CommonAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding:
              const EdgeInsets.all(20.0).copyWith(top: 25, right: 0, left: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              upcomingAsync.when(
                data: (upcomingList) => upcomingList.isEmpty
                    ? SizedBox()
                    : Padding(
                        padding: const EdgeInsets.only(right: 20, left: 20),
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
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFF00312D),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  '${upcomingList.length}',
                                                  style: TextStyle(
                                                    color:
                                                        const Color(0xFF03FFE2),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          GatheringCard(
                                              gathering: pendingList.first,
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00312D),
                                    borderRadius: BorderRadius.circular(20),
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
                                isPending: false),
                            SizedBox(
                              height: 16,
                            ),
                            GestureDetector(
                              onTap: () {
                                // context.push('/gathering'); // or context.push
                                GoRouter.of(rootNavigatorKey.currentContext!)
                                    .go('/gathering');
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
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
                                      color: Color(0xFF03FFE2), size: 16),
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
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: activities.length,
                  physics: NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.only(right: 20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 182 / 104,
                  ),
                  itemBuilder: (context, index) {
                    String activity = activities[index]['name'];
                    bool isSelected = selectedActivity == activity;
                    return GestureDetector(
                      onTap: () {
                        // setState(() {
                        //   selectedActivity = activity;
                        // });

                        context.push('/select-location', extra: activity);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Color(0xff091F1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Color(0xFF03FFE2)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(activities[index]['icon'],
                                color: Color(0xFF03FFE2)),
                            SizedBox(height: 8),
                            Text(
                              activity,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'SFPRO'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
                            height: 327,
                            child: ListView.builder(
                              itemCount: publicList.length,
                              shrinkWrap: true,
                              scrollDirection: Axis.horizontal,
                              itemBuilder: (context, index) {
                                final gathering = publicList[index];
                                List<String> inviteeNames = [
                                  ...gathering.invitees.values
                                      .map((e) => e.name),
                                  ...gathering.nonRegisteredInvitees.values
                                      .map((e) => e.name),
                                  ...gathering.joinedPublicUsers.values
                                      .map((e) => e.name),
                                ];
                                return Padding(
                                  padding: EdgeInsets.only(
                                      left: index == 0 ? 20 : 0),
                                  child: buildEventHorizontalCard(
                                      context, gathering, inviteeNames),
                                );
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
        ),
      ),
    );
  }

  Padding buildEventHorizontalCard(BuildContext context,
      GatheringModel gathering, List<String> inviteeNames) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: InkWell(
        onTap: () {
          context.push('/gathering/gathering-details/${gathering.id}',
              extra: gathering);
        },
        child: Container(
          height: 327,
          width: 200,
          decoration: ShapeDecoration(
            color: const Color(0xFF091F1E),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    height: 160,
                    fit: BoxFit.cover,
                    width: MediaQuery.sizeOf(context).width,
                    imageUrl:
                        'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${gathering.photoRef}&key=$googleApiKey',
                    placeholder: (context, url) =>
                        Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                Expanded(
                  child: Text(
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
                ),
                SizedBox(
                  height: 8,
                ),
                Row(
                  children: [
                    Icon(Icons.location_on, color: subtitleColor, size: 18),
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
                      Icon(Icons.access_time, color: subtitleColor, size: 18),
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
                child: GestureDetector(
                  onTap: () {
                    context.push(
                      '/gathering/create-gathering-circle',
                      extra: {
                        'activity': category.category, // String?
                        'place': place,
                      },
                    );
                  },
                  child: Container(
                    width: 200,
                    padding: EdgeInsets.all(12),
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
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  height: 160,
                                  fit: BoxFit.cover,
                                  width: MediaQuery.sizeOf(context).width,
                                  imageUrl:
                                      'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${place.photos[0].photoReference}&key=$googleApiKey',
                                  placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) =>
                                      Icon(Icons.error),
                                ),
                              ),
                        SizedBox(height: 20),
                        Text(
                          place.name ?? "Unnamed",
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
                          maxLines: 1,
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
              );
            },
          ),
        ),
      ],
    );
  }
}
