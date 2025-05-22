import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/gatherings/models/gathering_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


// final chatGatheringsProvider = FutureProvider.family<List<GatheringModel>, String>((ref, friendId) async {
//   final uid = FirebaseAuth.instance.currentUser!.uid;
//   final firestore = FirebaseFirestore.instance;

//   final userDoc = await firestore.collection('users').doc(uid).get();
//   final userGatheringMap = userDoc.data()?['gatherings'] as Map<String, dynamic>? ?? {};

//   List<GatheringModel> pending = [];
//   List<GatheringModel> accepted = [];

//   for (final gatheringId in userGatheringMap.keys) {
//     final gatheringDoc = await firestore.collection('gatherings').doc(gatheringId).get();
//     if (!gatheringDoc.exists) continue;

//     final data = gatheringDoc.data()!;
//     final hostId = data['hostId'];
//     final invitees = data['invitees'] as Map<String, dynamic>? ?? {};

//     if (!(invitees.containsKey(friendId) || hostId == friendId)) continue;

//     final status = invitees[uid]?['status'] ?? 'pending';
//     final gathering = GatheringModel.fromMap(data..['id'] = gatheringId, gatheringId);

//     if (status == 'pending') {
//       pending.add(gathering);
//     } else if (status == 'accepted') {
//       accepted.add(gathering);
//     }
//   }

//   // Sort accepted by upcoming
//   accepted.sort((a, b) => a.dateTime.compareTo(b.dateTime));

//   // Combine pending first, then accepted
//   return [...pending, ...accepted];
// });

final chatGatheringsProvider = FutureProvider.family<List<GatheringModel>, String>((ref, friendId) async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final firestore = FirebaseFirestore.instance;

  final userDoc = await firestore.collection('users').doc(uid).get();
  final userGatheringMap = userDoc.data()?['gatherings'] as Map<String, dynamic>? ?? {};
  final gatheringIds = userGatheringMap.keys.toList();

  // Fetch all gathering docs in parallel
  final docs = await Future.wait(
    gatheringIds.map((id) => firestore.collection('gatherings').doc(id).get()),
  );

  List<GatheringModel> pending = [];
  List<GatheringModel> accepted = [];

  for (final doc in docs) {
    if (!doc.exists) continue;

    final data = doc.data()!;
    final hostId = data['hostId'];
    final invitees = data['invitees'] as Map<String, dynamic>? ?? {};

    if (!(invitees.containsKey(friendId) || hostId == friendId)) continue;

    final status = invitees[uid]?['status'] ?? 'pending';
    final gathering = GatheringModel.fromMap({...data, 'id': doc.id}, doc.id);

    if (status == 'pending') {
      pending.add(gathering);
    } else if (status == 'accepted') {
      accepted.add(gathering);
    }
  }

  accepted.sort((a, b) => a.dateTime.compareTo(b.dateTime));

  return [...pending, ...accepted];
});







