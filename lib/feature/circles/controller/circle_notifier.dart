import 'dart:developer';

import 'package:connecto/feature/circles/models/circle_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

      // 🔹 Identify Registered vs. Unregistered Users
      for (var member in members) {
        final querySnapshot = await _firestore
            .collection('users')
            .where('phoneNumber', isEqualTo: member['phoneNumber'])
            .get();

        // ✅ Ensure current user is added to registered users
        registeredUserIds.add(currentUser.uid);

        if (querySnapshot.docs.isNotEmpty) {
          registeredUserIds.add(querySnapshot.docs.first.id); // Store user ID
        } else {
          unregisteredUsers.add(member); // Store as unregistered user
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
      log('===batch process complete====');
    } catch (e) {
      state = CircleState.error(e.toString());
      print("❌ Error adding circle: $e");
    }
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
