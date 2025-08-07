import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connecto/feature/gatherings/models/gathering_model.dart';
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
    List<Map<String, String>> allContacts = const [], // optional
    bool isPublic = false, // new
    int maxPublicParticipants = 0, // new
    required String photoRef,
    required String placeId,
    String? circleId,
  }) async {
    state = state.copyWith(status: CreateGatheringStatus.loading);

    try {
      final hostId = auth.currentUser!.uid;
      final hostPhoneNumber = auth.currentUser!.phoneNumber;

      /// 🔍 Step 0: Identify which non-registered contacts are actually registered
      /// 🔍 Step 0: Identify which non-registered contacts are actually registered
      final phones = allContacts.map((c) => c['phoneNumber']).toList();

      log('all contacts phones : $phones');

      List<QueryDocumentSnapshot<Map<String, dynamic>>> existingDocs = [];

      if (phones.isNotEmpty) {
        final snap = await firestore
            .collection('users')
            .where('phoneNumber', whereIn: phones)
            .get();
        existingDocs = snap.docs;
      }

      log('user collection snapshot length: ${existingDocs.length}');

      final registeredUsers = <Map<String, String>>[];
      final stillNonRegistered = <Map<String, String>>[];

      for (final contact in allContacts) {
        final contactPhone = contact['phoneNumber'];

        QueryDocumentSnapshot<Map<String, dynamic>>? match;
        try {
          match = existingDocs.firstWhere(
            (doc) => doc['phoneNumber'] == contactPhone,
          );
        } catch (_) {
          match = null;
        }

        if (match != null) {
          registeredUsers.add({
            'id': match.id,
            'name': match['fullName'] ?? contact['fullName'] ?? '',
            'phoneNumber': match['phoneNumber'] ?? contact['phoneNumber'] ?? ''
          });
        } else {
          stillNonRegistered.add(contact);
        }
      }

      log('====already registered users : $registeredUsers');

      // ✅ Merge resolved registered contacts into invitees
      inviteesWithNames.addAll(registeredUsers);

      // 1. Build invitees map with names
      final Map<String, dynamic> invitees = {
        for (var item in inviteesWithNames)
          item['id']!: {
            "status": "pending",
            "host": false,
            "name": item['name'] ?? '',
            "phoneNumber": item['phoneNumber']
          },
        hostId: {
          "status": "accepted",
          "host": true,
          "phoneNumber": hostPhoneNumber ?? '',
          "name": hostName,
          "respondedAt": Timestamp.now(),
        },
      };

      // 2. Prepare non-registered invitees map
      final Map<String, dynamic> nonRegisteredInvitees = {
        for (var contact in stillNonRegistered)
          contact['phoneNumber']!: {
            "name": contact['fullName'] ?? '',
            "phone": contact['phoneNumber'],
            "status": "invited",
            "inviteLink": "https://connecto.app/invite", // placeholder
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
        "nonRegisteredInvitees": nonRegisteredInvitees,
        "isPublic": isPublic,
        "maxPublicParticipants": maxPublicParticipants,
        "publicJoinCount": 0,
        "joinedPublicUsers": {}, // initially empty
        "photoRef": photoRef,
        "placeId": placeId,
        if (circleId != null) "circleId": circleId, // ✅ Only added if not null
      });

      final gatheringId = gatheringDoc.id;

      // 3. Subcollection for registered invitees
      for (final item in inviteesWithNames) {
        final inviteeId = item['id']!;
        final inviteeData = {
          'name': item['name'] ?? '',
          'status': 'pending',
          'host': false,
          "phoneNumber": item['phoneNumber'] ?? '',
          'sharing': true,
        };

        await firestore
            .collection('gatherings')
            .doc(gatheringId)
            .collection('invitees')
            .doc(inviteeId)
            .set(inviteeData);
      }

      // 4. Subcollection for non-registered contacts
      for (final contact in stillNonRegistered) {
        final phone = contact['phoneNumber']!;
        final data = {
          'name': contact['fullName'] ?? '',
          'phone': phone,
          'status': 'invited',
          'inviteLink': "https://connecto.app/invite",
        };

        await firestore
            .collection('gatherings')
            .doc(gatheringId)
            .collection('nonRegisteredInvitees')
            .doc(phone)
            .set(data);
      }

      // 5. Add host to subcollection
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

      // 6. Add gathering reference in each user's document
      for (String userId in invitees.keys) {
        await firestore.collection('users').doc(userId).set({
          "gatherings": {gatheringId: true}
        }, SetOptions(merge: true));
      }

      if (circleId != null && circleId.isNotEmpty) {
        await sendEventMessageToGroup(gatheringId, hostName, circleId);
      }

      triggerSendGatheringNotification(gatheringId);

      state = state.copyWith(status: CreateGatheringStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: CreateGatheringStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> sendEventMessageToGroup(
      String gatheringId, String senderName, String circleId) async {
    final firestore = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser!;

    final gatheringDoc =
        await firestore.collection('gatherings').doc(gatheringId).get();
    if (!gatheringDoc.exists) return;

    final gathering = GatheringModel.fromDoc(gatheringDoc);

    final messageRef = firestore
        .collection('groupChats')
        .doc(circleId)
        .collection('messages')
        .doc();

    await messageRef.set({
      'messageId': messageRef.id,
      'senderId': user.uid,
      'senderName': senderName,
      'timestamp': FieldValue.serverTimestamp(),

      // 👇 Event-related fields
      'type': 'event',
      'eventId': gatheringId,
      'eventName': gathering.name,
      'eventType': gathering.eventType,
      'eventDateTime': gathering.dateTime,
      'eventLocation': gathering.location.name,
    });

    // Optional: Update lastMessage
    await firestore.collection('groupChats').doc(circleId).update({
      'lastMessage': {
        'text': '$senderName created an event 🎉',
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': user.uid,
      }
    });
  }

  Future<void> triggerSendGatheringNotification(String gatheringId) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('sendGatheringNotification');
      final result = await callable.call({'gatheringId': gatheringId});
      print('✅ Notification sent to ${result.data['sent']} invitees');
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  Future<void> editGathering({
    required String gatheringId,
    required String gatheringName,
    required String eventType,
    required DateTime dateTime,
    required String recurrenceType,
    required bool isRecurring,
    required Map<String, dynamic> location,
    required List<Map<String, String>> inviteesWithNames,
    required String hostName,
    List<Map<String, String>> allContacts = const [],
  }) async {
    state = state.copyWith(status: CreateGatheringStatus.loading);

    try {
      final hostId = auth.currentUser!.uid;

      /// Step 0: Normalize contacts and check which ones are registered
      /// 🔍 Step 0: Identify which non-registered contacts are actually registered
      final phones = allContacts.map((c) => c['phoneNumber']).toList();

      log('all contacts phones : $phones');

      List<QueryDocumentSnapshot<Map<String, dynamic>>> existingDocs = [];

      if (phones.isNotEmpty) {
        final snap = await firestore
            .collection('users')
            .where('phoneNumber', whereIn: phones)
            .get();
        existingDocs = snap.docs;
      }

      log('user collection snapshot length: ${existingDocs.length}');

      final registeredUsers = <Map<String, String>>[];
      final stillNonRegistered = <Map<String, String>>[];

      for (final contact in allContacts) {
        final contactPhone = contact['phoneNumber'];

        QueryDocumentSnapshot<Map<String, dynamic>>? match;
        try {
          match = existingDocs.firstWhere(
            (doc) => doc['phoneNumber'] == contactPhone,
          );
        } catch (_) {
          match = null;
        }

        if (match != null) {
          registeredUsers.add({
            'id': match.id,
            'name': match['fullName'] ?? contact['fullName'] ?? '',
            'phoneNumber': match['phoneNumber'] ?? contact['phoneNumber'] ?? ''
          });
        } else {
          stillNonRegistered.add(contact);
        }
      }

      inviteesWithNames.addAll(registeredUsers);

      final Map<String, dynamic> invitees = {
        for (var item in inviteesWithNames)
          item['id']!: {
            "status": "pending",
            "host": false,
            "name": item['name'] ?? '',
            "phoneNumber": item['phoneNumber'] ?? ''
          },
        hostId: {
          "status": "accepted",
          "host": true,
          "name": hostName,
          "respondedAt": Timestamp.now(),
        },
      };

      final Map<String, dynamic> nonRegisteredInvitees = {
        for (var contact in stillNonRegistered)
          contact['phoneNumber']!: {
            "name": contact['fullName'] ?? '',
            "phone": contact['phoneNumber'],
            "status": "invited",
            "inviteLink": "https://connecto.app/invite",
          },
      };

      // Update gathering document
      await firestore.collection('gatherings').doc(gatheringId).update({
        "name": gatheringName,
        "eventType": eventType,
        "isRecurring": isRecurring,
        "recurrenceType": recurrenceType,
        "dateTime": Timestamp.fromDate(dateTime),
        "location": location,
        "invitees": invitees,
        "nonRegisteredInvitees": nonRegisteredInvitees,
      });

      // ✅ Overwrite subcollections
      final gatheringRef = firestore.collection('gatherings').doc(gatheringId);

      // Clear and re-add invitees subcollection
      final inviteeDocs = await gatheringRef.collection('invitees').get();
      for (final doc in inviteeDocs.docs) {
        await doc.reference.delete();
      }
      for (final item in inviteesWithNames) {
        await gatheringRef.collection('invitees').doc(item['id']).set({
          'name': item['name'] ?? '',
          'status': 'pending',
          'host': false,
          'phoneNumber': item['phoneNumber'] ?? '',
          'sharing': true,
        });
      }
      await gatheringRef.collection('invitees').doc(hostId).set({
        'name': hostName,
        'status': 'accepted',
        'host': true,
        'respondedAt': Timestamp.now(),
        'sharing': true,
      });

      // Clear and re-add nonRegisteredInvitees subcollection
      final nonRegDocs =
          await gatheringRef.collection('nonRegisteredInvitees').get();
      for (final doc in nonRegDocs.docs) {
        await doc.reference.delete();
      }
      for (final contact in stillNonRegistered) {
        await gatheringRef
            .collection('nonRegisteredInvitees')
            .doc(contact['phoneNumber'])
            .set({
          'name': contact['fullName'] ?? '',
          'phone': contact['phoneNumber'],
          'status': 'invited',
          'inviteLink': "https://connecto.app/invite",
        });
      }

      // ✅ Update user gatherings map
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
