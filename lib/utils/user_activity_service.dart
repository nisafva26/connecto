import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserActivityService with WidgetsBindingObserver {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void updateUserStatus(bool isActive) async {
    String? userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _db.collection('users').doc(userId).update({
        'isActive': isActive,
        'lastActive': DateTime.now(), // ✅ Set last active
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      updateUserStatus(true); // ✅ Set active when app is opened
    } else {
      updateUserStatus(false); // ❌ Set inactive when app is closed
    }
  }
}
