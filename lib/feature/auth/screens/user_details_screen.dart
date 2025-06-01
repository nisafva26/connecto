import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// // State management using Riverpod
// final userDetailsProvider = StateNotifierProvider<UserDetailsNotifier, UserDetailsState>(
//   (ref) => UserDetailsNotifier(),
// );

// class UserDetailsState {
//   final String name;
//   final String dob;
//   final String gender;
//   final bool isLoading;

//   UserDetailsState({
//     this.name = '',
//     this.dob = '',
//     this.gender = '',
//     this.isLoading = false,
//   });

//   UserDetailsState copyWith({String? name, String? dob, String? gender, bool? isLoading}) {
//     return UserDetailsState(
//       name: name ?? this.name,
//       dob: dob ?? this.dob,
//       gender: gender ?? this.gender,
//       isLoading: isLoading ?? this.isLoading,
//     );
//   }
// }

// class UserDetailsNotifier extends StateNotifier<UserDetailsState> {
//   UserDetailsNotifier() : super(UserDetailsState());

//   void updateName(String name) {
//     state = state.copyWith(name: name);
//   }

//   void updateDob(String dob) {
//     state = state.copyWith(dob: dob);
//   }

//   void updateGender(String gender) {
//     state = state.copyWith(gender: gender);
//   }

//   Future<void> saveUserDetails() async {
//     state = state.copyWith(isLoading: true);
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;

//     await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
//       'name': state.name,
//       'dob': state.dob,
//       'gender': state.gender,
//       'phone': user.phoneNumber,
//     });

//     state = state.copyWith(isLoading: false);
//   }
// }

// class UserDetailsScreen extends ConsumerWidget {
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final userDetails = ref.watch(userDetailsProvider);
//     final userNotifier = ref.read(userDetailsProvider.notifier);

//     return Scaffold(
//       backgroundColor: Color(0xFF001311),
//       body: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const SizedBox(height: 80),
//             const Text(
//               "Tell us about you",
//               style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
//             ),
//             const SizedBox(height: 10),
//             const Text(
//               "Please enter your phone number then we will send OTP to verify you.",
//               style: TextStyle(fontSize: 14, color: Colors.grey),
//             ),
//             const SizedBox(height: 30),

//             // Full Name Input
//             TextField(
//               style: TextStyle(color: Colors.white),
//               decoration: InputDecoration(
//                 labelText: "Full name",
//                 labelStyle: TextStyle(color: Colors.grey),
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey)),
//               ),
//               onChanged: userNotifier.updateName,
//             ),
//             const SizedBox(height: 20),

//             // Date of Birth Input
//             TextField(
//               style: TextStyle(color: Colors.white),
//               readOnly: true,
//               controller: TextEditingController(text: userDetails.dob),
//               decoration: InputDecoration(
//                 labelText: "Date of birth",
//                 labelStyle: TextStyle(color: Colors.grey),
//                 suffixIcon: Icon(Icons.calendar_today, color: Colors.grey),
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey)),
//               ),
//               onTap: () async {
//                 DateTime? pickedDate = await showDatePicker(
//                   context: context,
//                   initialDate: DateTime.now(),
//                   firstDate: DateTime(1900),
//                   lastDate: DateTime.now(),
//                 );
//                 if (pickedDate != null) {
//                   userNotifier.updateDob("${pickedDate.day}-${pickedDate.month}-${pickedDate.year}");
//                 }
//               },
//             ),
//             const SizedBox(height: 20),

//             // Gender Selection
//             Row(
//               children: [
//                 Expanded(
//                   child: GestureDetector(
//                     onTap: () => userNotifier.updateGender("Male"),
//                     child: Container(
//                       height: 50,
//                       decoration: BoxDecoration(
//                         color: userDetails.gender == "Male" ? Color(0xFF03FFE2) : Colors.transparent,
//                         border: Border.all(color: Colors.grey),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Center(
//                         child: Text(
//                           "Male",
//                           style: TextStyle(
//                             color: userDetails.gender == "Male" ? Colors.black : Colors.white,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 20),
//                 Expanded(
//                   child: GestureDetector(
//                     onTap: () => userNotifier.updateGender("Female"),
//                     child: Container(
//                       height: 50,
//                       decoration: BoxDecoration(
//                         color: userDetails.gender == "Female" ? Color(0xFF03FFE2) : Colors.transparent,
//                         border: Border.all(color: Colors.grey),
//                         borderRadius: BorderRadius.circular(8),
//                       ),
//                       child: Center(
//                         child: Text(
//                           "Female",
//                           style: TextStyle(
//                             color: userDetails.gender == "Female" ? Colors.black : Colors.white,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 30),

//             // Continue Button
//             SizedBox(
//               width: double.infinity,
//               height: 50,
//               child: ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Color(0xFF03FFE2),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                 ),
//                 onPressed: userDetails.isLoading ? null : () async {
//                   await userNotifier.saveUserDetails();
//                   // Navigate to next screen
//                 },
//                 child: userDetails.isLoading
//                     ? CircularProgressIndicator(color: Colors.black)
//                     : Text("Continue →", style: TextStyle(color: Colors.black, fontSize: 16)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:connecto/common_widgets/continue_button.dart';
import 'package:connecto/feature/auth/controller/user_details_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class UserDetailsScreen extends ConsumerStatefulWidget {
  @override
  _UserDetailsScreenState createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends ConsumerState<UserDetailsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  DateTime? _selectedDate;
  String _selectedGender = ''; // Default gender

  @override
  @override
  Widget build(BuildContext context) {
    final status = ref.watch(userDetailsStateProvider);

    ref.listen<UserDetailsState>(userDetailsStateProvider, (_, status) async {
      if (status == UserDetailsState.success) {
        User user = FirebaseAuth.instance.currentUser!;
        // Navigator.pushReplacement(
        //     context,
        //     MaterialPageRoute(
        //       builder: (context) => HomeScreen(user: user),
        //     ));

        context.go('/discover');
      } else if (status == UserDetailsState.error) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving user details.')));
        // ref.read(userDetailsProvider.notifier).clearStatus(); // Reset the status
      }
    });

    log('status : $status');
    return Scaffold(
      backgroundColor: Color(0xFF001311), // Dark theme background
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tell us about you",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      height: 50 / 40),
                ),
                SizedBox(height: 30),
                Text(
                  'Full Name',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xfff2f2f2)),
                ),
                SizedBox(
                  height: 6,
                ),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    fillColor: Color(0xff091F1E),
                    filled: true,

                    // labelText: 'Full name',
                    labelStyle: TextStyle(color: Colors.tealAccent[700]),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xff0E3735)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.tealAccent[700]!, width: 1),
                    ),
                  ),
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                      fontSize: 16),
                ),
                SizedBox(height: 23),
                Text(
                  'Date of birth',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xfff2f2f2)),
                ),
                SizedBox(
                  height: 6,
                ),
                TextField(
                  style: TextStyle(color: Colors.white),
                  readOnly: true,
                  controller: dateController,
                  decoration: InputDecoration(
                    fillColor: Color(0xff091F1E),
                    filled: true,
                    hintText: 'DD-MM-YYYY',
                    hintStyle: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[500],
                        fontSize: 16),
                    // labelText: "Date of birth",
                    labelStyle: TextStyle(color: Colors.grey),
                    suffixIcon: Icon(Icons.calendar_today,
                        color: Theme.of(context).colorScheme.primary),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xff0E3735)),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xff0E3735))),
                  ),
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    dateController.text = pickedDate == null
                        ? ''
                        : DateFormat('dd-MM-yyyy').format(pickedDate);
                    if (pickedDate != null) {
                      setState(() {
                        _selectedDate = pickedDate;
                      });
                    }
                  },
                ),
                SizedBox(
                  height: 23,
                ),
                Text(
                  'Gender',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xfff2f2f2)),
                ),
                SizedBox(
                  height: 6,
                ),
                Row(
                  spacing: 8,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _genderButton('Male')),
                    Expanded(child: _genderButton('Female')),
                  ],
                ),
                // Spacer(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ContinueButton(onPressed: _saveUserDetails),
      ),
    );
  }

  Widget _genderButton(String gender) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
        });
      },
      child: Container(
        height: 129,
        decoration: BoxDecoration(
          color: Color(0xff091F1E),
          border: Border.all(
              color: _selectedGender == gender
                  ? Theme.of(context).colorScheme.primary
                  : Color(0xff082523)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              gender == 'Male'
                  ? SvgPicture.asset('assets/images/male.svg')
                  : SvgPicture.asset('assets/images/female.svg'),
              SizedBox(
                height: 8,
              ),
              Text(
                gender,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveUserDetails() {
    log('fullname : ${_nameController.text}');
    log('dob : ${_selectedDate ?? ''}');
    log('gender : $_selectedGender');

    if (_selectedDate != null &&
        _nameController.text.isNotEmpty &&
        _selectedGender.isNotEmpty) {
      log('can proceeddd');
      ref.read(userDetailsProvider.notifier).setUserDetails(
            _nameController.text,
            _selectedDate!,
            _selectedGender,
          );
      ref.read(userDetailsProvider.notifier).saveUserDetailsToFirestore();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all the details ")),
      );
    }
  }
}
