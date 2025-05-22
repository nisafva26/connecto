import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/auth/model/user_model.dart';
import 'package:connecto/feature/bond_score/models/bond_activity_model.dart';
import 'package:connecto/feature/bond_score/models/bond_score_model.dart';
import 'package:connecto/feature/bond_score/widgets/bond_badges_section.dart';
import 'package:connecto/feature/bond_score/widgets/relationship_nodata_widget.dart';
import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/helper/get_initials.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final bondProvider =
    StreamProvider.family<BondScoreModel, String>((ref, bondId) {
  return FirebaseFirestore.instance
      .collection('bonds')
      .doc(bondId)
      .snapshots()
      .map((doc) => BondScoreModel.fromJson(doc.id, doc.data()!));
});

final bondActivitiesProvider =
    StreamProvider.family<List<BondActivityModel>, String>((ref, bondId) {
  return FirebaseFirestore.instance
      .collection('bonds')
      .doc(bondId)
      .collection('activities')
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => BondActivityModel.fromJson(doc.data()))
          .toList());
});

const allBadges = [
  {"key": "always_on_time", "label": "Always On time", "icon": Icons.timer},
  {
    "key": "event_planner",
    "label": "Event Planner",
    "icon": Icons.calendar_today
  },
  {
    "key": "fast_responder",
    "label": "Fast responder",
    "icon": Icons.fast_forward
  },
  {"key": "mr_caring", "label": "Mr. Caring", "icon": Icons.favorite_border},
];

class BondRelationshipScreen extends ConsumerStatefulWidget {
  final String friendId;
  final String friendName;

  const BondRelationshipScreen({
    super.key,
    required this.friendId,
    required this.friendName,
  });

  @override
  ConsumerState<BondRelationshipScreen> createState() =>
      _BondRelationshipScreenState();
}

class _BondRelationshipScreenState
    extends ConsumerState<BondRelationshipScreen> {
  bool _showAllActivities = false;

  String getBondId(String a, String b) {
    final sorted = [a, b]..sort();
    return "${sorted[0]}_${sorted[1]}";
  }

  Widget buildActivityRow(BondActivityModel activity) {
    final labelMap = {
      'ping': 'Ping sent',
      'gathering_created': 'Gathering created',
      'on_time_arrival': 'On time arrival',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (activity.type == 'ping')
            const Icon(Icons.emoji_emotions, size: 18, color: Colors.white),
          if (activity.type == 'gathering_created')
            const Icon(Icons.event, size: 18, color: Colors.white),
          if (activity.type == 'on_time_arrival')
            const Icon(Icons.timer, size: 18, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labelMap[activity.type] ?? activity.type,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if (activity.bonus != null)
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Colors.redAccent, size: 16),
                      Text(" Ping streak bonus x${activity.bonus}",
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13)),
                    ],
                  )
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "+${activity.value}"
            "${activity.bonus != null ? '' : ''}",
            style: TextStyle(
              color: activity.bonus != null ? Colors.white70 : Colors.white,
              fontSize: 14,
              fontWeight:
                  activity.bonus != null ? FontWeight.bold : FontWeight.normal,
              decoration: activity.bonus != null
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
          ),
          if (activity.bonus != null)
            Text(" +${activity.value * activity.bonus!}",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14))
        ],
      ),
    );
  }

  Widget buildBadgesRow({
    required String name,
    required String initials,
    required List<String> earnedBadges,
  }) {
    final allBadges = [
      {'label': 'Always On time', 'icon': Icons.timer},
      {'label': 'Event Planner', 'icon': Icons.event},
      {'label': 'Fast responder', 'icon': Icons.fast_forward},
      {'label': 'Mr. Caring', 'icon': Icons.favorite_border},
    ];

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101F1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Text(initials, style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                "${earnedBadges.length} Badge${earnedBadges.length > 1 ? 's' : ''}",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              )
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: allBadges.map((badge) {
              final isEarned = earnedBadges.contains(badge['label']);
              return Opacity(
                opacity: isEarned ? 1.0 : 0.25,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF0C1C1B),
                      child: Icon(
                        badge['icon'] as IconData,
                        color: Colors.tealAccent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      badge['label'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    )
                  ],
                ),
              );
            }).toList(),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final bondId = getBondId(currentUserId, widget.friendId);

    final bondAsync = ref.watch(bondProvider(bondId));
    final activitiesAsync = ref.watch(bondActivitiesProvider(bondId));
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.asData?.value;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Relationship Score",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'SFPRO',
            fontWeight: FontWeight.w700,
            letterSpacing: -0.55,
          ),
        ),
        centerTitle: true,
      ),
      body: bondAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final currentPoints = 0;
          final friendPoints = 0;

          return RelationNoDataWidget(
              userAsync: userAsync, widget: widget, user: user);
        },
        data: (bond) {
          final currentPoints = bond.userPoints[currentUserId] ?? 0;
          final friendPoints = bond.userPoints[widget.friendId] ?? 0;

          log('bond data : ${bond.badgeProgress}');

          return Container(
            height: MediaQuery.of(context).size.height,
            child: Stack(
              children: [
                Container(
                  height: 316,
                  width: MediaQuery.sizeOf(context).width,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF03ffe2),
                        Color(0xFF01675B),
                        Color(0xFF001311),
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 26),
                        Column(
                          children: [
                            userAsync.when(
                              data: (user) {
                                if (user == null) {
                                  return CircleAvatar(
                                      radius: 19,
                                      child: Text(getInitials('No User')));
                                }
                                return CircleAvatar(
                                    radius: 19,
                                    backgroundColor: Colors.white,
                                    child: Text(
                                      getInitials(user.fullName),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ));
                              },
                              loading: () => CircleAvatar(
                                  radius: 19,
                                  child: Text(getInitials('No User'))),
                              error: (err, stack) => CircleAvatar(
                                  radius: 19,
                                  child: Text(getInitials('No User'))),
                            ),
                            const SizedBox(height: 6),
                            Text("You",
                                style: TextStyle(
                                    color: const Color(0xFFEFF1F5),
                                    fontSize: 16,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(width: 50),
                        Column(
                          children: [
                            CircleAvatar(
                                radius: 19,
                                backgroundColor: Colors.white,
                                child: Text(
                                  getInitials(widget.friendName),
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                )),
                            const SizedBox(height: 6),
                            Text(widget.friendName,
                                style: TextStyle(
                                    color: const Color(0xFFEFF1F5),
                                    fontSize: 16,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w600)),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  top: 199,
                  left: 0,
                  right: 0,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.all(16).copyWith(bottom: 0),
                          padding:
                              const EdgeInsets.all(20).copyWith(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF101F1E),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                minHeight: 7,
                                value: bond.nextLevelThreshold != null
                                    ? bond.totalPoints /
                                        bond.nextLevelThreshold!
                                    : 1,
                                backgroundColor: Colors.grey.shade800,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 17),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("${bond.totalPoints} points",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  Row(
                                    children: [
                                      const Icon(Icons.emoji_events,
                                          color: Colors.white, size: 20),
                                      Text("  Level ${bond.level}",
                                          style: TextStyle(color: Colors.white))
                                    ],
                                  )
                                ],
                              ),
                              if (bond.nextLevelThreshold != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 15),
                                  child: Row(
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                  radius: 10,
                                                  backgroundColor: Colors.white,
                                                  child: Text(
                                                      getInitials(
                                                          user!.fullName),
                                                      style: TextStyle(
                                                          fontSize: 9))),
                                              SizedBox(width: 7),
                                              Text(currentPoints.toString(),
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              SizedBox(width: 5),
                                              Text('points',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12)),
                                            ],
                                          ),
                                          SizedBox(
                                            height: 5,
                                          ),
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                  radius: 10,
                                                  backgroundColor: Colors.white,
                                                  child: Text(
                                                      getInitials(
                                                          widget.friendName),
                                                      style: TextStyle(
                                                          fontSize: 9))),
                                              SizedBox(width: 7),
                                              Text(friendPoints.toString(),
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              SizedBox(width: 5),
                                              Text('points',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Spacer(),
                                      Text(
                                          "+${bond.nextLevelThreshold! - bond.totalPoints} points to next level",
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Text("Points",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      height: 1.4)),
                              const SizedBox(height: 10),
                              activitiesAsync.when(
                                loading: () => const Center(
                                    child: CircularProgressIndicator()),
                                error: (e, _) =>
                                    Center(child: Text("Error: $e")),
                                data: (acts) {
                                  acts.take(5).toList();
                                  final isExpandable = acts.length > 5;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AnimatedCrossFade(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        firstChild: Column(
                                          children: acts
                                              .take(5)
                                              .map(buildActivityRow)
                                              .toList(),
                                        ),
                                        secondChild: Column(
                                          children: acts
                                              .map(buildActivityRow)
                                              .toList(),
                                        ),
                                        crossFadeState: _showAllActivities
                                            ? CrossFadeState.showSecond
                                            : CrossFadeState.showFirst,
                                      ),
                                      if (isExpandable)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () {
                                              setState(() =>
                                                  _showAllActivities =
                                                      !_showAllActivities);
                                            },
                                            child: Text(
                                              _showAllActivities
                                                  ? "View less"
                                                  : "View more",
                                              style: const TextStyle(
                                                  color: Colors.tealAccent),
                                            ),
                                          ),
                                        )
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 29),
                        BondBadgesSection(
                          bond: bond,
                          currentUserId: currentUserId,
                          currentUserName: user?.fullName ?? "You",
                          friendId: widget.friendId,
                          friendName: widget.friendName,
                        ),
                        SizedBox(height: 100),
                      ],
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
