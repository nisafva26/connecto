import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connecto/feature/dashboard/widgets/common_appbar.dart';
import 'package:connecto/feature/gatherings/models/gathering_model.dart';
import 'package:connecto/feature/gatherings/screens/gathering_list.dart';
import 'package:connecto/feature/gatherings/widgets/gathering_card.dart';

import 'package:connecto/helper/get_initials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final List<Map<String, dynamic>> activities = [
    {"name": "Football", "icon": Icons.sports_soccer},
    {"name": "Birthday", "icon": Icons.celebration},
    {"name": "Desert camping", "icon": Icons.terrain},
    {"name": "Padel Tennis", "icon": Icons.sports_tennis},
  ];

  String? selectedActivity;
  final subtitleColor = const Color(0xff9DA5A5);
  @override
  Widget build(BuildContext context) {
    final publicGatheringAsync = ref.watch(publicGatheringsProvider);
    return Scaffold(
      backgroundColor: const Color(0xff001311),
      appBar: CommonAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0).copyWith(top: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Search by category",
                  style: TextStyle(
                      fontFamily: 'SFPRO',
                      // color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400)),
              SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                itemCount: activities.length,
                physics: NeverScrollableScrollPhysics(),
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
                      setState(() {
                        selectedActivity = activity;
                      });
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
              publicGatheringAsync.when(
                data: (publicList) => publicList.isEmpty
                    ? SizedBox()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 36,
                          ),
                          Text(
                            'Trending public events',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontFamily: 'SFPRO',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(
                            height: 8,
                          ),
                          Text(
                            'Suggestions based on your location',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'SFPRO',
                              fontWeight: FontWeight.w500,
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
                                return buildEventHorizontalCard(
                                    context, gathering, inviteeNames);
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
          context.go('/gathering/gathering-details/${gathering.id}',
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
}
