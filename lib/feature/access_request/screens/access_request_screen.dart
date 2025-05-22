import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:loading_indicator/loading_indicator.dart';
import 'package:lottie/lottie.dart';

final accessRequestStreamProvider =
    StreamProvider.family<DocumentSnapshot?, String>(
  (ref, phoneNumber) {
    return FirebaseFirestore.instance
        .collection('accessRequests')
        .doc(phoneNumber)
        .snapshots();
  },
);

final requestedPhoneProvider = StateProvider<String?>((ref) => null);

class AccessRequestScreen extends ConsumerStatefulWidget {
  const AccessRequestScreen({super.key});

  @override
  ConsumerState<AccessRequestScreen> createState() =>
      _AccessRequestScreenState();
}

class _AccessRequestScreenState extends ConsumerState<AccessRequestScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  String _fullPhone = '';
  bool _isLoading = false;
  bool _isSubmitted = false;

  Future<void> _submitAccessRequest() async {
    final phone = _fullPhone;
    final email = _emailController.text.trim();

    if (phone.isEmpty ||
        !phone.startsWith('+') ||
        email.isEmpty ||
        !email.contains('@')) {
      Fluttertoast.showToast(msg: "Please enter valid phone and email.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docRef =
          FirebaseFirestore.instance.collection('accessRequests').doc(phone);
      final doc = await docRef.get();

      if (doc.exists) {
        final status = doc['status'];
        if (status == 'approved') {
          final container = ProviderScope.containerOf(context, listen: false);
          container.read(requestedPhoneProvider.notifier).state = phone;

          Fluttertoast.showToast(
              msg: "Access already approved! Redirecting...");
          Future.delayed(const Duration(seconds: 2), () {
            context.go(
                Uri(path: '/', queryParameters: {'phone': phone}).toString());
          });
          return;
        } else if (status == 'pending') {
          Fluttertoast.showToast(
            msg: "You've already requested access. Please wait for approval.",
          );
          setState(() => _isSubmitted = true);
          return;
        }
      }

      // Submit new request if not exists or was previously rejected (optional check)
      await docRef.set({
        'phoneNumber': phone,
        'email': email,
        'status': 'pending',
        'fullName': nameController.text,
        'requestedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _isSubmitted = true);
    } catch (e) {
      log(e.toString());
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessDocAsync = ref.watch(accessRequestStreamProvider(_fullPhone));

    accessDocAsync.whenData((doc) {
      if (doc != null && doc['status'] == 'approved') {
        Future.microtask(() {
          log('can redirect : $_fullPhone');

          final container = ProviderScope.containerOf(context, listen: false);
          container.read(requestedPhoneProvider.notifier).state = _fullPhone;

          Fluttertoast.showToast(
            msg: "Access approved! Redirecting in 1 second...",
          );

          Future.delayed(Duration(seconds: 1), () {
            context.go(Uri(path: '/', queryParameters: {'phone': _fullPhone})
                .toString());
          });
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xff001311),
      // appBar: AppBar(
      //   backgroundColor: Colors.transparent,
      //   title: const Text("Request Access"),
      // ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isSubmitted
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF03FFE2),
                        size: 100,
                      ),
                      SizedBox(height: 24),
                      Text(
                        "Access Request Sent",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Thank you for your interest in Connecto.\nYou'll be notified once your request is approved.",
                        style: TextStyle(
                          color: Color(0xFF9DA5A5),
                          fontSize: 16,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SizedBox(
                      //   height: 50,
                      // ),
                      Container(
                          height: 118,
                          width: 118,
                          child: Lottie.asset(
                              'assets/lottie/mobile_notification.json')),
                      Text("Connecto",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 50 / 40)),
                      const SizedBox(height: 12),
                      // const Text(
                      //   "Request early access to Connecto by entering your details below. Be among the first to experience a more intentional way to connect.",
                      //   style: TextStyle(
                      //     color: Color(0xFF9DA5A5),
                      //     fontSize: 16,
                      //     // fontStyle: FontStyle.italic,
                      //   ),
                      //   textAlign: TextAlign.center,
                      // ),
                      // 📝 Subtitle
                      const Text(
                        "Request early access to Connecto by entering your details below. "
                        "Be among the first to experience a more intentional way to connect.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF9DA5A5),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      IntlPhoneField(
                        controller: _phoneController,
                        disableLengthCheck: true,
                        style: const TextStyle(color: Colors.white),
                        initialCountryCode: 'IN',
                        onChanged: (phone) {
                          _fullPhone = phone.completeNumber;
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Color(0xFF091F1E),
                          labelText: 'Phone Number',
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          labelStyle: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w400),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.white24, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Color(0xFF03FFE2), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 13, horizontal: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Color(0xFF091F1E),
                          labelText: 'Full Name',
                          hintText: 'Full Name',
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          labelStyle: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w400),
                          hintStyle: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w400),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.white24, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Color(0xFF03FFE2), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 13, horizontal: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Color(0xFF091F1E),
                          labelText: 'Email address',
                          hintText: 'Email address',
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          labelStyle: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w400),
                          hintStyle: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w400),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Colors.white24, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: Color(0xFF03FFE2), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 13, horizontal: 16),
                        ),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitAccessRequest,
                        style: ElevatedButton.styleFrom(
                          maximumSize: Size(double.infinity, 50),
                          minimumSize: Size(double.infinity, 50),
                          backgroundColor: const Color(0xFF03FFE2),
                          foregroundColor: Colors.black,
                          // padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        child: _isLoading
                            ? Container(
                                height: 40,
                                child: LoadingIndicator(
                                  indicatorType: Indicator.ballBeat,
                                  colors: [Colors.black],
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Request Early Access"),
                                  SizedBox(
                                    width: 5,
                                  ),
                                  Icon(Icons.lock)
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
