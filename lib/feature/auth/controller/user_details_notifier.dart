import 'dart:developer';

import 'package:connecto/feature/auth/model/user_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserDetailsState { idle, loading, success, error }

class UserDetailsNotifier extends StateNotifier<UserModel?> {
  final Ref ref;
  UserDetailsState stateStatus = UserDetailsState.idle;
  String errorMessage = '';

  UserDetailsNotifier(this.ref) : super(null);

  void setUserDetails(String fullName, DateTime dob, String gender) {
    log('inside set user details');
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      log('current user : ${currentUser.phoneNumber}');
      state = UserModel(
          id: currentUser.uid,
          fullName: fullName,
          dob: dob,
          gender: gender,
          phoneNumber: currentUser.phoneNumber ?? 'Not Available',
          lastActive: DateTime.now().toUtc(),
          friends: [],
          isActive: true);

      log("state : ${state}");
    }
  }

  Future<void> saveUserDetailsToFirestore() async {
    if (state != null) {
      log('state is not null , going to save');
      try {
        stateStatus = UserDetailsState.loading;
        ref
            .read(userDetailsStateProvider.notifier)
            .update((state) => UserDetailsState.loading);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(state!.id)
            .set(state!.toMap());
        stateStatus = UserDetailsState.success;

        updateUserFcmToken();

        ref
            .read(userDetailsStateProvider.notifier)
            .update((state) => UserDetailsState.success);
      } catch (e) {
        stateStatus = UserDetailsState.error;
        errorMessage = e.toString();
        log('error : $errorMessage');
        ref
            .read(userDetailsStateProvider.notifier)
            .update((state) => UserDetailsState.error);
      }
    }
  }

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
}

// Separate provider for handling UI state separate from UserModel
final userDetailsStateProvider = StateProvider<UserDetailsState>((ref) {
  return UserDetailsState.idle;
});

final userDetailsProvider =
    StateNotifierProvider<UserDetailsNotifier, UserModel?>((ref) {
  return UserDetailsNotifier(ref);
});
