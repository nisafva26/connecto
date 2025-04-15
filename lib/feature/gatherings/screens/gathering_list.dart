import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/dashboard/widgets/common_appbar.dart';
import 'package:connecto/feature/gatherings/models/gathering_model.dart';
import 'package:connecto/feature/gatherings/widgets/empty_invite_card.dart';
import 'package:connecto/feature/gatherings/widgets/gathering_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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



class GatheringsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingGatheringsProvider);
    final upcomingAsync = ref.watch(upcomingGatheringsProvider);
    final previousGatheringsAsync = ref.watch(previousGatheringsProvider);

    return Scaffold(
      backgroundColor: const Color(0xff001311),
      appBar: CommonAppBar(),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            SizedBox(height: 16),
            _buildHeader("Pending Invites"),
            pendingAsync.when(
              data: (pendingList) => pendingList.isEmpty
                  ? EmptyInviteCard(title: "No pending invites")
                  : Column(
                      children: pendingList
                          .map((g) =>
                              GatheringCard(gathering: g, isPending: true))
                          .toList(),
                    ),
              loading: () => CircularProgressIndicator(),
              error: (e, _) => Text("Error loading pending"),
            ),
            SizedBox(height: 32),
            _buildHeader("Upcoming"),
            upcomingAsync.when(
              data: (upcomingList) => upcomingList.isEmpty
                  ? EmptyInviteCard(title: "No upcoming gatherings")
                  : Column(
                      children: upcomingList
                          .map((g) => GatheringCard(
                                gathering: g,
                                isPending: false,
                              ))
                          .toList(),
                    ),
              loading: () => CircularProgressIndicator(),
              error: (e, _) {
                log("error : $e");
                return Text("Error loading upcoming");
              },
            ),
            SizedBox(height: 32),
            _buildHeader("Previous events"),
            previousGatheringsAsync.when(
              data: (list) => list.isEmpty
                  ? Text('No previous events')
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: list.length,
                      itemBuilder: (_, index) {
                        final gathering = list[index];
                        return GatheringCard(
                            gathering: gathering, isPending: false);
                      },
                    ),
              loading: () => CircularProgressIndicator(),
              error: (e, _) {
                log('Error : $e');
                return Text('Error loading previous events $e');
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF03FFE2),
        shape: CircleBorder(),
        heroTag: 'fab-1',
        onPressed: () async {
          context.go('/gathering/create-gathering-circle');
        },
        child: Icon(Icons.add, size: 20),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'SFPRO',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
