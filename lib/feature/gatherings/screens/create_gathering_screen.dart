import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/auth/model/user_model.dart';
import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/feature/gatherings/providers/chat_gathering_provider.dart';
import 'package:connecto/feature/gatherings/providers/gathering_provider.dart';
import 'package:connecto/feature/gatherings/screens/select_location_screen.dart';
import 'package:connecto/helper/date_helper.dart' as date;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateGatheringScreen extends ConsumerStatefulWidget {
  final String friendID;
  UserModel friend;

  CreateGatheringScreen(
      {super.key, required this.friendID, required this.friend});
  @override
  _CreateGatheringScreenState createState() => _CreateGatheringScreenState();
}

class _CreateGatheringScreenState extends ConsumerState<CreateGatheringScreen> {
  final TextEditingController gatheringNameController = TextEditingController();
  final TextEditingController activityTypeController = TextEditingController();
  final TextEditingController dateTimeController = TextEditingController();

  bool isRecurring = false;
  DateTime? selectedDateTime;
  String? selectedPhotoRef = '';

  PlacesSearchResult? selectedPlace;

  final List<Map<String, dynamic>> activities = [
    {"name": "Football", "icon": Icons.sports_soccer},
    {"name": "Birthday", "icon": Icons.celebration},
    {"name": "Desert", "icon": Icons.terrain},
    {"name": "Padel Tennis", "icon": Icons.sports_tennis},
    {"name": "Coffee", "icon": Icons.local_cafe},
    {"name": "Other", "icon": Icons.group},
  ];

  String? selectedActivity;

  void _openLocationSelector() async {
    final result = await showModalBottomSheet<PlacesSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddLocationScreen(
          eventType: selectedActivity == "Other"
              ? activityTypeController.text
              : selectedActivity ?? ''),
    );

    if (result != null) {
      final photoRef = selectedPlace!.photos.first.photoReference;
      setState(() {
        selectedPlace = result;
        selectedPhotoRef = photoRef;
      });
    }
  }

  Future<void> updateChatFlagForGathering({
    required String friendId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final firestore = FirebaseFirestore.instance;

    // Update for current user (sender)
    await firestore
        .collection('users')
        .doc(uid)
        .collection('chatFlags')
        .doc(friendId)
        .set({
      'lastActivity': FieldValue.serverTimestamp(),
      'hasPendingGathering': true,
      'latestPingFromFriend': false, // You sent the request
      'latestPingFrom': uid,
      'lastPingText': "", // Optional
    }, SetOptions(merge: true));

    // Update for receiver (friend)
    await firestore
        .collection('users')
        .doc(friendId)
        .collection('chatFlags')
        .doc(uid)
        .set({
      'lastActivity': FieldValue.serverTimestamp(),
      'hasPendingGathering': true,
      'latestPingFromFriend': true, // Friend received the request
      'latestPingFrom': uid,
      'lastPingText': "", // Optional
    }, SetOptions(merge: true));
  }

  bool isGatheringFormValid() {
    if (gatheringNameController.text.trim().isEmpty) return false;

    if (selectedActivity == null) return false;

    if (selectedActivity == "Other" &&
        activityTypeController.text.trim().isEmpty) {
      return false;
    }

    if (selectedDateTime == null) return false;

    if (selectedPlace == null || selectedPlace!.geometry == null) return false;

    // You can also validate invitees if needed
    // if (inviteeIds.isEmpty) return false;

    return true;
  }

  @override
  Widget build(BuildContext context) {
    log('friend id : ${widget.friendID}');

    final gatheringState = ref.watch(createGatheringProvider);
    log('gathering state : ${gatheringState.status}');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (gatheringState.status == CreateGatheringStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🎉 Gathering created!")),
        );

        // context.pop(); // Pop after success
        ref.invalidate(chatGatheringsProvider(widget.friendID));

        // ref.read(chatGatheringsProvider(widget.friendID));

        ref.read(createGatheringProvider.notifier).reset(); // Reset state
      } else if (gatheringState.status == CreateGatheringStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(gatheringState.errorMessage.toString())),
        );
        ref
            .read(createGatheringProvider.notifier)
            .reset(); // Optional: reset error
      }
    });

    return Scaffold(
      backgroundColor: Color(0xff001311),
      appBar: AppBar(
        backgroundColor: Color(0xff08201e),
        surfaceTintColor: Color(0xff08201e),
        title: Text("Create gathering"),
        titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: "Inter",
            color: Color(0xffE6E7E9)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Text("Activity",
                  style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400)),
              SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                itemCount: activities.length,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 182 / 104,
                ),
                itemBuilder: (context, index) {
                  String activity = activities[index]['name'];
                  bool isSelected = selectedActivity == activity;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedActivity = activity;
                        if (activity != "Other") {
                          activityTypeController.clear();
                        }
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Color(0xff091F1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Color(0xFF03FFE2)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(activities[index]['icon'],
                              color: Color(0xFF03FFE2)),
                          SizedBox(height: 8),
                          Text(
                            activity,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'SFPRO'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // SizedBox(height: 24),
              if (selectedActivity == "Other")
                _buildTextField("Enter activity type", activityTypeController,
                    "Activity type"),
              SizedBox(height: 12),
              _buildTextField("Enter Gathering name", gatheringNameController,
                  "Gathering name"),
              SizedBox(height: 12),
              // _buildTextField(
              //     "DD-MM-YYYY  -  HH:MM", dateTimeController, "Date & Time",
              //     suffixIcon: Icon(Icons.calendar_today)),
              _buildDateTimeField(),

              SizedBox(height: 24),
              Text(
                'Add location ',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xffF2F2F2),
                    fontFamily: "Inter"),
              ),
              SizedBox(
                height: 10,
              ),
              GestureDetector(
                onTap: _openLocationSelector,
                child: Container(
                  // height: 76,
                  width: MediaQuery.sizeOf(context).width,
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Color(0xff091F1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: selectedPlace == null
                      ? Column(
                          children: [
                            CircleAvatar(
                                radius: 10,
                                child: Icon(
                                  Icons.add,
                                  size: 20,
                                )),
                            SizedBox(
                              height: 6,
                            ),
                            Text(
                              'Add location',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: 'SFPRO',
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.12,
                              ),
                            )
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedPlace?.name ?? "Add location",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(
                                    height: 6,
                                  ),
                                  if (selectedPlace?.formattedAddress != null)
                                    Text(
                                      selectedPlace!.formattedAddress!,
                                      style: TextStyle(
                                        color: Color(0xFFC4C4C4),
                                        fontSize: 13,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: -0.32,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Icon(Icons.edit,
                                color: Theme.of(context).colorScheme.primary)
                          ],
                        ),
                ),
              ),
              // SizedBox(height: 16),
              // Row(
              //   children: [
              //     Switch(
              //       value: isRecurring,
              //       onChanged: (val) {
              //         setState(() {
              //           isRecurring = val;
              //         });
              //       },
              //       activeColor: Color(0xFF03FFE2),
              //     ),
              //     Text("Make a recurring gathering",
              //         style: TextStyle(color: Colors.white)),
              //   ],
              // ),
              // if (isRecurring)
              //   Padding(
              //     padding: const EdgeInsets.only(left: 12),
              //     child: Text("Make it daily, weekly or monthly",
              //         style: TextStyle(color: Colors.grey, fontSize: 12)),
              //   ),
              // Spacer(),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final currentUser = ref.read(currentUserProvider).value;
                  if (!isGatheringFormValid()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text("Please fill all required fields")),
                    );
                    return;
                  }

                  final name = gatheringNameController.text.trim();
                  final eventType = selectedActivity == "Other"
                      ? activityTypeController.text.trim()
                      : selectedActivity!;
                  final isRecurring = this.isRecurring;
                  final recurrenceType = isRecurring ? "weekly" : "";
                  final date = selectedDateTime!;
// Replace with actual selection

                  final location = {
                    "name": selectedPlace!.name,
                    "address": selectedPlace!.formattedAddress ?? "",
                    "lat": selectedPlace!.geometry!.location.lat,
                    "lng": selectedPlace!.geometry!.location.lng,
                  };

                  final invitees = [
                    {
                      "id": widget.friendID,
                      "name": widget.friend.fullName,
                      "phoneNumber": widget.friend.phoneNumber
                    },
                  ];

                  try {
                    await ref
                        .read(createGatheringProvider.notifier)
                        .createGathering(
                            gatheringName: name,
                            eventType: eventType,
                            dateTime: date,
                            isRecurring: isRecurring,
                            recurrenceType: recurrenceType,
                            location: location,
                            inviteesWithNames: invitees,
                            hostName: currentUser!.fullName,
                            photoRef: selectedPhotoRef!);

                    updateChatFlagForGathering(friendId: widget.friendID);

                    Navigator.pop(context);
                  } catch (e) {
                    log('Error: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Something went wrong")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF03FFE2),
                  foregroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: gatheringState == CreateGatheringStatus.loading
                    ? CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : Text("Create gathering  →"),
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      String hint, TextEditingController controller, String header,
      {Widget? suffixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xffF2F2F2),
              fontFamily: "Inter"),
        ),
        SizedBox(
          height: 6,
        ),
        TextField(
          controller: controller,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Color(0xff091F1E),
            // border: OutlineInputBorder(

            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xff0E3735), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF03FFE2), width: 2),
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Date & Time",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xffF2F2F2),
            fontFamily: "Inter",
          ),
        ),
        SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            DateTime now = DateTime.now();
            showCupertinoModalPopup(
              context: context,
              builder: (_) => Container(
                height: 400,
                decoration: BoxDecoration(
                  color: Color(0xFF091F1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 300,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.dateAndTime,
                        initialDateTime: selectedDateTime != null &&
                                selectedDateTime!.isAfter(now)
                            ? selectedDateTime
                            : now.add(Duration(
                                minutes: 1)), // ⬅ make sure it's after now
                        minimumDate: now,
                        maximumDate: DateTime(2100),
                        use24hFormat: false,
                        onDateTimeChanged: (DateTime newDateTime) {
                          setState(() {
                            selectedDateTime = newDateTime;
                            dateTimeController.text =
                                "${date.formatDate(newDateTime)} - ${date.formatTime(newDateTime)}";
                          });
                        },
                      ),
                    ),
                    CupertinoButton(
                      child: Text("Done",
                          style: TextStyle(color: Color(0xFF03FFE2))),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  ],
                ),
              ),
            );
          },
          child: AbsorbPointer(
            child: TextField(
              controller: dateTimeController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "DD-MM-YYYY  -  HH:MM",
                hintStyle: TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Color(0xff091F1E),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xff0E3735), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF03FFE2), width: 2),
                ),
                suffixIcon: Icon(Icons.calendar_today),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
