import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/auth/screens/login_screen.dart';
import 'package:connecto/my_app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> logout(WidgetRef ref) async {
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

    // ✅ Invalidate providers or user-specific streams
    // ref.invalidate(currentUserProvider);
    // ref.invalidate(userDataProvider);
    // ref.invalidate(gatheringListProvider);
    // ref.invalidate(chatListProvider);
    // Add any others you use...

    // ✅ Reset state
    state = AuthState.idle;

    log("✅ Logout successful.");
  } catch (e) {
    log("❌ Logout failed: $e");
  }
}



}

// Riverpod Provider for AuthNotifier
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
