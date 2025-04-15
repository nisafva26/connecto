import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CreateGatheringStatus { idle, loading, success, error }

class CreateGatheringState {
  final CreateGatheringStatus status;
  final String? errorMessage;

  const CreateGatheringState({
    this.status = CreateGatheringStatus.idle,
    this.errorMessage,
  });

  CreateGatheringState copyWith({
    CreateGatheringStatus? status,
    String? errorMessage,
  }) {
    return CreateGatheringState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

final createGatheringProvider =
    StateNotifierProvider<CreateGatheringNotifier, CreateGatheringState>(
  (ref) => CreateGatheringNotifier(
      FirebaseFirestore.instance, FirebaseAuth.instance),
);

class CreateGatheringNotifier extends StateNotifier<CreateGatheringState> {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  CreateGatheringNotifier(this.firestore, this.auth)
      : super(const CreateGatheringState());

  Future<void> createGathering({
    required String gatheringName,
    required String eventType,
    required DateTime dateTime,
    required String recurrenceType,
    required bool isRecurring,
    required Map<String, dynamic> location,
    required List<Map<String, String>> inviteesWithNames,
    required String hostName,
  }) async {
    state = state.copyWith(status: CreateGatheringStatus.loading);

    try {
      final hostId = auth.currentUser!.uid;

      // 1. Build invitees map with names
      final Map<String, dynamic> invitees = {
        for (var item in inviteesWithNames)
          item['id']!: {
            "status": "pending",
            "host": false,
            "name": item['name'] ?? '',
          },
        hostId: {
          "status": "accepted",
          "host": true,
          "name": hostName, // Optional: fallback
          "respondedAt": Timestamp.now(),
        },
      };

      final gatheringDoc = await firestore.collection('gatherings').add({
        "name": gatheringName,
        "eventType": eventType,
        "hostId": hostId,
        "isRecurring": isRecurring,
        "recurrenceType": recurrenceType,
        "dateTime": Timestamp.fromDate(dateTime),
        "location": location,
        "status": "upcoming",
        "invitees": invitees,
      });

      final gatheringId = gatheringDoc.id;
      
      //setting up invitee collection for better access while ordering .
      for (final item in inviteesWithNames) {
        final inviteeId = item['id']!;
        final inviteeData = {
          'name': item['name'] ?? '',
          'status': 'pending',
          'host': false,
          'sharing': true,
        };

        await firestore
            .collection('gatherings')
            .doc(gatheringId)
            .collection('invitees')
            .doc(inviteeId)
            .set(inviteeData);
      }

// Also add for host
      await firestore
          .collection('gatherings')
          .doc(gatheringId)
          .collection('invitees')
          .doc(hostId)
          .set({
        'name': hostName,
        'status': 'accepted',
        'host': true,
        'respondedAt': Timestamp.now(),
        'sharing': true,
      });

      for (String userId in invitees.keys) {
        await firestore.collection('users').doc(userId).set({
          "gatherings": {gatheringId: true}
        }, SetOptions(merge: true));
      }

      state = state.copyWith(status: CreateGatheringStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: CreateGatheringStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() {
    state = const CreateGatheringState(); // idle state
  }
}
