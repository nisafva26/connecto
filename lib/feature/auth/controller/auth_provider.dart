import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connecto/feature/auth/controller/user_details_notifier.dart';
import 'package:connecto/feature/auth/screens/login_screen.dart';
import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/feature/gatherings/providers/chat_gathering_provider.dart';
import 'package:connecto/feature/gatherings/screens/gathering_list.dart';
import 'package:connecto/feature/pings/screens/ping_chat_screen.dart';
import 'package:connecto/my_app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum AuthState {
  idle,
  sendingOtp,
  otpSent,
  verifying,
  authenticated,
  error,
  otpError
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.idle);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _verificationId = '';

  Future<void> sendOTP(String phoneNumber, WidgetRef ref) async {
    log("inside sent otp fn");
    state = AuthState.sendingOtp;
    try {
      log('phone number : $phoneNumber');
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          state = AuthState.authenticated; // Move to success screen
          ref.read(justLoggedInProvider.notifier).state = true;
        },
        verificationFailed: (FirebaseAuthException e) {
          state = AuthState.error;
          log("verification failed : ${e.toString()}");
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          state = AuthState.otpSent;
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      state = AuthState.error;
      log('error occured====');
    }
  }

  Future<void> verifyOTP(String otp, WidgetRef ref) async {
    state = AuthState.verifying;
    log('otp in fn : $otp');
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );
      log('creditial : ${credential}');
      await _auth.signInWithCredential(credential).then((value) {
        log('after verifying value : $value');
      });
      // ✅ Ensure `justLoggedInProvider` is updated
      ref.read(justLoggedInProvider.notifier).state = true;
      log('justLoggedInProvider set to: ${ref.read(justLoggedInProvider)}');

      state = AuthState.authenticated; // Move to success screen
    } catch (e) {
      log("caught error in verifying : ${e.toString()}");
      state = AuthState.otpError;
    }
  }

  Future<void> logout(WidgetRef ref, BuildContext context) async {
    try {
      final uid = _auth.currentUser?.uid;

      // ❌ Optional: Remove FCM token from Firestore
      // if (uid != null) {
      //   await _firestore.collection('users').doc(uid).update({
      //     'fcmToken': FieldValue.delete(),
      //   });
      // }

      // ✅ Sign out from Firebase
      await _auth.signOut();
      context.go('/');

      await Future.delayed(const Duration(milliseconds: 300));

      ref.invalidate(pendingGatheringsProvider);
      ref.invalidate(upcomingGatheringsProvider);
      ref.invalidate(previousGatheringsProvider);
      // ref.invalidate(publicGatheringsProvider);
      ref.invalidate(userDetailsProvider);
      ref.invalidate(userDataProvider);
      ref.invalidate(userDataProvider);
      ref.invalidate(messagesProvider);
      ref.invalidate(chatGatheringsProvider);
      ref.invalidate(chatFlagsProvider);
      ref.invalidate(friendsProvider);

      // ✅ Invalidate providers or user-specific streams
      // ref.invalidate(currentUserProvider);
      // ref.invalidate(userDataProvider);
      // ref.invalidate(gatheringListProvider);

      // Add any others you use...

      // ✅ Reset state
      state = AuthState.idle;

      log("✅ Logout successful.");
    } catch (e) {
      log("❌ Logout failed: $e");
    }
  }

  Future<void> deleteAccountFlow(BuildContext context, WidgetRef ref) async {
    // final ok = await showDialog<bool>(
    //       context: context,
    //       builder: (_) => AlertDialog(
    //         title: const Text('Delete account?'),
    //         content: const Text(
    //             'This permanently deletes your profile and closes chats for others. '
    //             'This action cannot be undone.'),
    //         actions: [
    //           TextButton(
    //               onPressed: () => Navigator.pop(context, false),
    //               child: const Text('Cancel')),
    //           FilledButton(
    //               onPressed: () => Navigator.pop(context, true),
    //               child: const Text('Delete')),
    //         ],
    //       ),
    //     ) ??
    //     false;

    // if (!ok) return;

    try {
      await FirebaseFunctions.instance.httpsCallable('deleteAccount').call({});
      // await FirebaseAuth.instance.signOut();
      await _auth.signOut();
      context.go('/');
      await Future.delayed(const Duration(milliseconds: 300));
      log('===invalidating providersss');

      // your existing invalidations
      ref.invalidate(pendingGatheringsProvider);
      ref.invalidate(upcomingGatheringsProvider);
      ref.invalidate(previousGatheringsProvider);
      ref.invalidate(userDetailsProvider);
      ref.invalidate(userDataProvider);
      ref.invalidate(messagesProvider);
      ref.invalidate(chatGatheringsProvider);
      ref.invalidate(chatFlagsProvider);
      ref.invalidate(friendsProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted')),
      );
    } catch (e) {
      log('erroor : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t delete account: $e')),
      );
    }
  }
}

// Riverpod Provider for AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
