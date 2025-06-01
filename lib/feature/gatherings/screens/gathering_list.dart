import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/dashboard/widgets/common_appbar.dart';
import 'package:connecto/feature/gatherings/models/gathering_model.dart';
import 'package:connecto/feature/gatherings/widgets/empty_invite_card.dart';
import 'package:connecto/feature/gatherings/widgets/gathering_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_indicator/loading_indicator.dart';

// gathering_providers.dart
// final pendingGatheringsProvider =
//     StreamProvider.autoDispose<List<GatheringModel>>((ref) {
//   final uid = FirebaseAuth.instance.currentUser!.uid;
//   return FirebaseFirestore.instance
//       .collection('gatherings')
//       .where('invitees.$uid.status', isEqualTo: 'pending')
//       .snapshots()
//       .map((snapshot) =>
//           snapshot.docs.map((doc) => GatheringModel.fromDoc(doc)).toList());
// });

// final upcomingGatheringsProvider =
//     StreamProvider.autoDispose<List<GatheringModel>>((ref) {
//   final uid = FirebaseAuth.instance.currentUser!.uid;
//   return FirebaseFirestore.instance
//       .collection('gatherings')
//       .where('invitees.$uid.status', isEqualTo: 'accepted')
//       .where('dateTime', isGreaterThan: DateTime.now())
//       .orderBy('dateTime')
//       .snapshots()
//       .map((snapshot) =>
//           snapshot.docs.map((doc) => GatheringModel.fromDoc(doc)).toList());
// });

// final previousGatheringsProvider = StreamProvider<List<GatheringModel>>((ref) {
//   final uid = FirebaseAuth.instance.currentUser!.uid;
//   final now = Timestamp.fromDate(DateTime.now());

//   return FirebaseFirestore.instance
//       .collection('gatherings')
//       .where('invitees.$uid.status', isEqualTo: 'accepted')
//       .where('dateTime', isLessThan: now)
//       .orderBy('dateTime', descending: true)
//       .snapshots()
//       .map((snapshot) =>
//           snapshot.docs.map((doc) => GatheringModel.fromDoc(doc)).toList());
// });

final pendingGatheringsProvider =
    StreamProvider.autoDispose<List<GatheringModel>>((ref) async* {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final snapshots = FirebaseFirestore.instance
      .collectionGroup('invitees')
      .where('status', isEqualTo: 'pending')
      .snapshots();

  await for (final snap in snapshots) {
    final userDocs = snap.docs.where((doc) => doc.id == uid).toList();

    final gatheringRefs = userDocs
        .map((doc) => doc.reference.parent.parent)
        .whereType<DocumentReference>();

    final gatheringDocs =
        await Future.wait(gatheringRefs.map((ref) => ref.get()));

    yield gatheringDocs
        .where((doc) => doc.exists)
        .map((doc) => GatheringModel.fromDoc(doc))
        .where((g) => g.dateTime.isAfter(DateTime.now()))
        .toList();
  }
});

final upcomingGatheringsProvider =
    StreamProvider.autoDispose<List<GatheringModel>>((ref) async* {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final snapshots = FirebaseFirestore.instance
      .collectionGroup('invitees')
      .where('status', isEqualTo: 'accepted')
      .snapshots();

  await for (final snap in snapshots) {
    final userDocs = snap.docs.where((doc) => doc.id == uid).toList();

    final gatheringRefs = userDocs
        .map((doc) => doc.reference.parent.parent)
        .whereType<DocumentReference>();

    final gatheringDocs =
        await Future.wait(gatheringRefs.map((ref) => ref.get()));

    final upcoming = gatheringDocs
        .where((doc) => doc.exists)
        .map((doc) => GatheringModel.fromDoc(doc))
        .where((g) => g.dateTime.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    yield upcoming;
  }
});

final previousGatheringsProvider =
    StreamProvider.autoDispose<List<GatheringModel>>((ref) async* {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final snapshots = FirebaseFirestore.instance
      .collectionGroup('invitees')
      .where('status', isEqualTo: 'accepted')
      .snapshots();

  await for (final snap in snapshots) {
    final userDocs = snap.docs.where((doc) => doc.id == uid).toList();

    final gatheringRefs = userDocs
        .map((doc) => doc.reference.parent.parent)
        .whereType<DocumentReference>();

    final gatheringDocs =
        await Future.wait(gatheringRefs.map((ref) => ref.get()));

    final previous = gatheringDocs
        .where((doc) => doc.exists)
        .map((doc) => GatheringModel.fromDoc(doc))
        .where((g) => g.dateTime.isBefore(DateTime.now()))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    yield previous;
  }
});

final publicGatheringsProvider = StreamProvider<List<GatheringModel>>((ref) {
  final query = FirebaseFirestore.instance
      .collection('gatherings')
      .where('isPublic', isEqualTo: true)
      .where('status', whereIn: ['upcoming', 'confirmed'])
      .orderBy('dateTime')
      .snapshots();

  return query.map((snapshot) {
    return snapshot.docs.map((doc) => GatheringModel.fromDoc(doc)).toList();
  });
});

class GatheringsTab extends ConsumerStatefulWidget {
  const GatheringsTab({super.key});

  @override
  ConsumerState<GatheringsTab> createState() => _GatheringsTabState();
}

class _GatheringsTabState extends ConsumerState<GatheringsTab> {
  int _selectedTabIndex = 0;

  Future<void> updateUserFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        log('going to update fcm token : $fcmToken');
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': fcmToken,
          'lastTokenUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("❌ Error saving FCM token: $e");
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    updateUserFcmToken();
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingGatheringsProvider);
    final upcomingAsync = ref.watch(upcomingGatheringsProvider);
    final previousGatheringsAsync = ref.watch(previousGatheringsProvider);
    final publicGatheringAsync = ref.watch(publicGatheringsProvider);

    return Scaffold(
      backgroundColor: const Color(0xff001311),
      appBar: CommonAppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // const SizedBox(height: 16),
            Container(
              height: 52,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Color(0xff091F1E)),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => _selectedTabIndex = 0),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedTabIndex == 0
                            ? Theme.of(context).colorScheme.secondary
                            : Color(0xff091F1E),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Your events',
                          style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Inter',
                              fontWeight: _selectedTabIndex == 1
                                  ? FontWeight.w400
                                  : FontWeight.w700,
                              color: _selectedTabIndex == 0
                                  ? Color(0xff243443)
                                  : Color(0xffAAB0B7))),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => _selectedTabIndex = 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedTabIndex == 1
                            ? Theme.of(context).colorScheme.secondary
                            : const Color(0xff091F1E),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: publicGatheringAsync.when(
                        data: (publicList) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Public Events',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Inter',
                                  fontWeight: _selectedTabIndex == 1
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: _selectedTabIndex == 1
                                      ? const Color(0xff243443)
                                      : const Color(0xffAAB0B7),
                                ),
                              ),
                              if (publicList.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${publicList.length}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              ]
                            ],
                          );
                        },
                        loading: () => const Text('Public Events'),
                        error: (e, _) => const Text('Public Events'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedTabIndex == 1) ...[
              // _buildHeader("Public Events"),
              publicGatheringAsync.when(
                data: (publicList) => publicList.isEmpty
                    ? EmptyInviteCard(title: "No public invites")
                    : Column(
                        children: publicList
                            .map((g) =>
                                GatheringCard(gathering: g, isPending: false))
                            .toList(),
                      ),
                loading: () => _loadingWidget(),
                error: (e, _) {
                  log('error : $e');
                  return Text("Error loading public: $e");
                },
              ),
              const SizedBox(height: 32),
            ],

            if (_selectedTabIndex == 0) ...[
              pendingAsync.when(
                data: (pendingList) => pendingList.isEmpty
                    ?
                    // EmptyInviteCard(title: "No pending invites")
                    SizedBox()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            _buildHeader("Pending Invites"),
                            ...pendingList.map((g) =>
                                GatheringCard(gathering: g, isPending: true)),
                            const SizedBox(height: 32),
                          ]),
                loading: () => _loadingWidget(),
                error: (e, _) => Text("Error loading pending: $e"),
              ),
              upcomingAsync.when(
                data: (upcomingList) => upcomingList.isEmpty
                    ? SizedBox()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader("Upcoming"),
                          ...upcomingList.map((g) =>
                              GatheringCard(gathering: g, isPending: false)),
                          const SizedBox(height: 32),
                        ],
                      ),
                loading: () => _loadingWidget(),
                error: (e, _) {
                  log("error : $e");
                  return Text("Error loading upcoming: $e");
                },
              ),
              previousGatheringsAsync.when(
                data: (list) => list.isEmpty
                    ?
                    //  const Text('No previous events')
                    SizedBox()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader("Previous events"),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: list.length,
                            itemBuilder: (_, index) {
                              final gathering = list[index];
                              return GatheringCard(
                                  gathering: gathering, isPending: false);
                            },
                          ),
                        ],
                      ),
                loading: () => _loadingWidget(),
                error: (e, _) {
                  log('Error : $e');
                  return Text('Error loading previous events: $e');
                },
              ),
            ]
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF03FFE2),
        shape: const CircleBorder(),
        heroTag: 'fab-1',
        onPressed: () {
          context.go('/gathering/create-gathering-circle');
        },
        child: const Icon(Icons.calendar_today, size: 20),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'SFPRO',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _loadingWidget() {
    return const Center(
      child: SizedBox(
        height: 40,
        child: LoadingIndicator(
          indicatorType: Indicator.ballBeat,
          colors: [Colors.white],
        ),
      ),
    );
  }
}
