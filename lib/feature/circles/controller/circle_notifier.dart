import 'dart:developer';

import 'package:connecto/feature/circles/models/circle_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

String normalizePhoneNumber(String phone) {
  // Keep + at the start if exists, and remove all non-digit characters
  return phone
      .replaceAll(RegExp(r'[^\d+]'), '')
      .replaceAllMapped(RegExp(r'^\+?'), (m) => m.group(0) ?? '');
}

/// State Notifier for Managing Circle Creation
class CircleNotifier extends StateNotifier<CircleState> {
  CircleNotifier() : super(CircleState.idle());

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Function to Add Circle
  Future<void> addCircle({
    required String circleName,
    required String circleColor,
    required List<Map<String, String>>
        members, // [{fullName: "John", phoneNumber: "123456"}]
    String? circleId, // Optional custom ID
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      state = CircleState.error("User not logged in");
      return;
    }

    state = CircleState.loading(); // Show loading state

    try {
      // final circleRef = _firestore.collection('circles').doc();
      final circleRef = circleId != null
          ? _firestore.collection('circles').doc(circleId)
          : _firestore.collection('circles').doc();

      List<String> registeredUserIds = [];
      List<Map<String, String>> unregisteredUsers = [];
      registeredUserIds.add(currentUser.uid);

      // 🔹 Identify Registered vs. Unregistered Users
      for (var member in members) {
        final rawPhone = member['phoneNumber'] ?? '';
        final normalizedPhone = normalizePhoneNumber(rawPhone);
        log('normalised numner : $normalizedPhone - name : ${member['fullName']}');
        final querySnapshot = await _firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: normalizedPhone)
            .get();

        // ✅ Ensure current user is added to registered users

        if (querySnapshot.docs.isNotEmpty) {
          registeredUserIds.add(querySnapshot.docs.first.id); // Store user ID
        } else {
          unregisteredUsers.add({
            'fullName': member['fullName'] ?? '',
            'phoneNumber': normalizedPhone,
          });
          // Store as unregistered user
        }
      }

      log('registered id : $registeredUserIds');
      log('un registered id : $unregisteredUsers');

      // 🔹 Create Circle Document in Firestore
      await circleRef.set({
        'circleName': circleName,
        'circleColor': circleColor, // Store as HEX
        'createdBy': currentUser.uid,
        'registeredUsers': registeredUserIds, // Store only user IDs
        'unregisteredUsers': unregisteredUsers, // Store names & phone numbers
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('groupChats')
          .doc(circleRef.id)
          .set({
        'circleId': circleRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': {
          'text': '',
          'senderId': '',
          'timestamp': FieldValue.serverTimestamp(),
        },
      });

      // Small delay before state change
      state = CircleState.success();
      log('state : ${state.status}');

      // 🔹 Update Each Registered User's Document (Store only circle ID)
      final batch = _firestore.batch();
      for (var userId in registeredUserIds) {
        final userRef = _firestore.collection('users').doc(userId);
        batch.update(userRef, {
          'circles': FieldValue.arrayUnion([circleRef.id])
        });
      }
      await batch.commit();

      // 🔹 Create initial groupChatFlags for each user
      for (final userId in registeredUserIds) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('groupChatFlags')
            .doc(circleRef.id)
            .set({
          'hasNewMessage': false,
          'lastActivity': FieldValue.serverTimestamp(),
        });
      }

      log('===batch process complete====');
    } catch (e) {
      state = CircleState.error(e.toString());
      print("❌ Error adding circle: $e");
    }
  }


  // Create or update groupChatFlags for each member except sender
Future<void> updateGroupChatFlagsForNewMessage({
  required String senderId,
  required String circleId,
  required List<String> participantIds,
}) async {
  final batch = FirebaseFirestore.instance.batch();
  final now = Timestamp.now();

  for (final userId in participantIds) {
    if (userId == senderId) continue;

    final flagRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('groupChatFlags')
        .doc(circleId);

    batch.set(flagRef, {
      'hasNewMessage': true,
      'lastActivity': now,
    }, SetOptions(merge: true));
  }

  await batch.commit();
}

// Clear new message flag when user opens the group chat
Future<void> clearGroupChatFlag({
  required String userId,
  required String circleId,
}) async {
  final flagRef = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('groupChatFlags')
      .doc(circleId);

  await flagRef.update({'hasNewMessage': false});
}

// Get group chat flags (to show unread dot in UI)
Future<bool> hasUnreadGroupMessage(String userId, String circleId) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('groupChatFlags')
      .doc(circleId)
      .get();

  return doc.exists ? (doc.data()?['hasNewMessage'] ?? false) : false;
}

  /// Reset State to Idle
  void resetState() {
    state = CircleState.idle();
  }
}

/// Riverpod Provider for Circle Notifier
final circleNotifierProvider =
    StateNotifierProvider<CircleNotifier, CircleState>((ref) {
  return CircleNotifier();
});
