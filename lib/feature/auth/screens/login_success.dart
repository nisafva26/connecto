import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/auth/screens/user_details_screen.dart';

import 'package:connecto/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SuccessScreen extends StatefulWidget {
  @override
  _SuccessScreenState createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _checkUserExists();
  }

  // void _checkUserExists() async {
  //   User? user = _auth.currentUser;
  //   if (user == null) return;

  //   DocumentSnapshot userDoc =
  //       await _firestore.collection('users').doc(user.uid).get();

  //   await Future.delayed(Duration(seconds: 2)); // Simulate loading time

  //   if (userDoc.exists) {
  //     // Navigator.pushReplacement(
  //     //   context,
  //     //   MaterialPageRoute(
  //     //       builder: (context) => HomeScreen(
  //     //             user: user,
  //     //           )),
  //     // );
  //     context.go('/home');
  //   } else {
  //     // Navigator.pushReplacement(
  //     //   context,
  //     //   MaterialPageRoute(builder: (context) => UserDetailsScreen()),
  //     // );

  //     context.go('/user-details');
  //   }
  // }

  void _checkUserExists() async {
  User? user = _auth.currentUser;
  if (user == null) return;

  DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

  await Future.delayed(Duration(seconds: 2)); // Simulate loading time

  if (!mounted) return; // Check if the widget is still in the tree

  if (userDoc.exists) {
    context.go('/bond');
  } else {
    context.go('/user-details');
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF001311),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 80),
            SizedBox(height: 20),
            Text("Passcode Accepted",
                style: TextStyle(color: Colors.white, fontSize: 22)),
            SizedBox(height: 10),
            Text("Redirecting...",
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
