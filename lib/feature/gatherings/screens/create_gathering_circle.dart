import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/auth/model/user_model.dart';
import 'package:connecto/feature/circles/models/circle_model.dart';
import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/feature/gatherings/data/acitivity_data.dart';
import 'package:connecto/feature/gatherings/providers/gathering_provider.dart';
import 'package:connecto/feature/gatherings/screens/select_location_screen.dart';
import 'package:connecto/feature/gatherings/widgets/gathering_invitee_bottom_modal.dart';
import 'package:connecto/helper/color_helper.dart';
import 'package:connecto/helper/date_helper.dart' as date;
import 'package:connecto/helper/get_initials.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_indicator/loading_indicator.dart';

class CreateGatheringCircleScreen extends ConsumerStatefulWidget {
  final PlacesSearchResult? place;
  final String? initialActivity;
  final List<UserModel>? registeredUsers;
  final List<Map<String, String>>? unregisteredUsers;
  CreateGatheringCircleScreen({
    this.place,
    this.initialActivity,
    this.registeredUsers,
    this.unregisteredUsers,
  });
  @override
  _CreateGatheringCircleScreenState createState() =>
      _CreateGatheringCircleScreenState();
}

class _CreateGatheringCircleScreenState
    extends ConsumerState<CreateGatheringCircleScreen> {
  final TextEditingController gatheringNameController = TextEditingController();
  final TextEditingController activityTypeController = TextEditingController();
  final TextEditingController dateTimeController = TextEditingController();

  bool isRecurring = false;
  int maxPublicParticipants = 10; // default value
  DateTime? selectedDateTime;
  bool isPublic = false; // add this state variable

  List<Map<String, dynamic>> selectedInvitees = []; // {id: "", name: ""}

  PlacesSearchResult? selectedPlace;

  List<Map<String, String>> selectedFriends = [];
  List<Map<String, String>> selectedContacts = [];
  List<CircleModel> selectedCircles = [];

  String? selectedPhotoRef = '';

  final List<Map<String, dynamic>> activities = activityList;

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
      final photoRef = result.photos.first.photoReference;

      setState(() {
        selectedPlace = result;
        selectedPhotoRef = photoRef;
      });
    }
  }

  Future<void> updateChatFlagsForGathering({
    required List<String> inviteeIds,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final firestore = FirebaseFirestore.instance;

    // 🔹 First: update current user's chatFlags for all invitees
    for (final inviteeId in inviteeIds) {
      if (inviteeId == uid) continue;

      await firestore
          .collection('users')
          .doc(uid)
          .collection('chatFlags')
          .doc(inviteeId)
          .set({
        'lastActivity': FieldValue.serverTimestamp(),
        'hasPendingGathering': true,
        'latestPingFromFriend': false, // You sent the request
        'latestPingFrom': uid,
        'isChatOpened': false,
        'lastPingText': "",
      }, SetOptions(merge: true));
    }

    // 🔹 Now: update each invitee's chatFlags with sender info
    for (final inviteeId in inviteeIds) {
      if (inviteeId == uid) continue;

      await firestore
          .collection('users')
          .doc(inviteeId)
          .collection('chatFlags')
          .doc(uid)
          .set({
        'lastActivity': FieldValue.serverTimestamp(),
        'hasPendingGathering': true,
        'latestPingFromFriend': true, // They received the request
        'latestPingFrom': uid,
        'isChatOpened': false,
        'lastPingText': "",
      }, SetOptions(merge: true));
    }
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
  void initState() {
    // TODO: implement initState
    super.initState();
    selectedPlace = widget.place; // ✅ assign place to selectedPlace
    selectedActivity = widget.initialActivity;

    if (widget.registeredUsers != null) {
      selectedFriends = widget.registeredUsers!
          .map((user) => {"id": user.id, "name": user.fullName})
          .toList();
    }

    if (widget.unregisteredUsers != null) {
      selectedContacts = widget.unregisteredUsers!
          .map((contact) => {
                "phoneNumber": contact['phoneNumber'] ?? "",
                "fullName": contact['fullName'] ?? ""
              })
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gatheringState = ref.watch(createGatheringProvider);
    log('gathering state : ${gatheringState.status}');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (gatheringState.status == CreateGatheringStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🎉 Gathering created!")),
        );

        // context.pop(); // Pop after success
        // ref.invalidate(chatGatheringsProvider(widget.friendID));

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

    void openInviteModal() async {
      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        // backgroundColor: Colors.transparent,
        builder: (_) => AddInviteegathering(
          initialFriends: selectedFriends,
          initialCircles: selectedCircles,
          initialContacts: selectedContacts,
        ),
      );

      if (result != null) {
        setState(() {
          selectedFriends =
              List<Map<String, String>>.from(result['selectedFriends'] ?? []);
          selectedContacts =
              List<Map<String, String>>.from(result['selectedContacts'] ?? []);
          selectedCircles =
              List<CircleModel>.from(result['selectedCircles'] ?? []);
        });

        log('selected friends : ${selectedFriends}');
        log('selected contacts : ${selectedContacts}');
      }
    }

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
                      : Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                height: 160,
                                fit: BoxFit.cover,
                                width: MediaQuery.sizeOf(context).width,
                                imageUrl:
                                    'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${selectedPlace!.photos[0].photoReference}&key=$googleApiKey',
                                placeholder: (context, url) =>
                                    Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) =>
                                    Icon(Icons.error),
                              ),
                            ),
                            SizedBox(
                              height: 24,
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on, color: Colors.white),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      if (selectedPlace?.formattedAddress !=
                                          null)
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
                                    color:
                                        Theme.of(context).colorScheme.primary)
                              ],
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              if (selectedCircles.isEmpty &&
                  selectedContacts.isEmpty &&
                  selectedFriends.isEmpty) ...[
                Text("Invite friends & circles",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xffF2F2F2),
                        fontFamily: "Inter")),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    openInviteModal();
                  },
                  child: Container(
                    width: MediaQuery.sizeOf(context).width,
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Color(0xff091F1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.person_add, color: Color(0xFF03FFE2)),
                        SizedBox(height: 12),
                        Text(
                          selectedInvitees.isEmpty
                              ? 'Add invites'
                              : '${selectedInvitees.length} invitee(s) selected',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'SFPRO',
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],

              if (selectedFriends.isNotEmpty || selectedCircles.isNotEmpty)
                buildSelectedInviteesList(),

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

              Container(
                 decoration: BoxDecoration(
                    color: Color(0xff091F1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 8),
                child: SwitchListTile(
                  value: isPublic,
                  onChanged: (val) {
                    setState(() {
                      isPublic = val;
                    });
                  },
                  title: Text("Make Gathering Public",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xffF2F2F2),
                          fontFamily: "Inter")),
                  subtitle: Row(
                    children: [
                      Icon(
                        Icons.info,
                        size: 12,
                      ),
                      SizedBox(
                        width: 7,
                      ),
                      Text(
                        'Allow other people to join your gathering',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontFamily: "Inter"),
                      ),
                    ],
                  ),
                  activeColor: Color(0xFF03FFE2),
                  // tileColor: Color(0xff091F1E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              if (isPublic) ...[
                SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final selected = await showModalBottomSheet<int>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => _buildNumberPickerSheet(),
                    );

                    if (selected != null) {
                      setState(() {
                        maxPublicParticipants = selected;
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Color(0xff091F1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Max Public Participants",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          "$maxPublicParticipants",
                          style: TextStyle(
                            color: Color(0xFF03FFE2),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
              ],
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
                  // final inviteeIds = [
                  //   widget.friendID
                  // ]; // Replace with actual selection

                  final location = {
                    "name": selectedPlace!.name,
                    "address": selectedPlace!.formattedAddress ?? "",
                    "lat": selectedPlace!.geometry!.location.lat,
                    "lng": selectedPlace!.geometry!.location.lng,
                  };

                  // final invitees = [
                  //   {"id": widget.friendID, "name": widget.friend.fullName},
                  // ];

                  try {
                    final allInvitees = [
                      ...selectedFriends, // each item: { "id": "...", "name": "..." }
                      for (final circle in selectedCircles)
                        ...circle.registeredUsers.map((user) => {
                              "id": user.id,
                              "name": user.fullName,
                              "phoneNumber": user.phoneNumber
                            })
                    ];

                    List<Map<String, String>> normalizedContacts =
                        selectedContacts.map((contact) {
                      final phone = contact['phoneNumber'] ?? '';
                      final name = contact['fullName'] ?? '';
                      final normalizedPhone =
                          phone.replaceAll(RegExp(r'[^\d+]'), '');
                      return {
                        'fullName': name,
                        'phoneNumber': normalizedPhone,
                      };
                    }).toList();
                    await ref
                        .read(createGatheringProvider.notifier)
                        .createGathering(
                            gatheringName: name,
                            eventType: eventType,
                            dateTime: date,
                            isRecurring: isRecurring,
                            recurrenceType: recurrenceType,
                            location: location,
                            inviteesWithNames: allInvitees,
                            hostName: currentUser!.fullName,
                            allContacts: normalizedContacts,
                            isPublic: isPublic,
                            maxPublicParticipants: maxPublicParticipants,
                            photoRef: selectedPhotoRef!);

                    // updateChatFlagForGathering(friendId: widget.friendID);
                    final allInviteeIds =
                        allInvitees.map((e) => e['id']!).toList();

                    await updateChatFlagsForGathering(
                        inviteeIds: allInviteeIds);

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
                child: gatheringState.status == CreateGatheringStatus.loading
                    ? Center(
                        child: Container(
                          height: 40,
                          child: LoadingIndicator(
                            indicatorType: Indicator.ballBeat,
                            colors: [Colors.black],
                          ),
                        ),
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

  Widget _buildNumberPickerSheet() {
    int tempValue = maxPublicParticipants;

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Color(0xFF091F1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Expanded(
            child: CupertinoPicker(
              backgroundColor: Color(0xFF091F1E),
              itemExtent: 40,
              scrollController:
                  FixedExtentScrollController(initialItem: tempValue - 1),
              onSelectedItemChanged: (index) {
                tempValue = index + 1;
              },
              children: List.generate(
                  50,
                  (index) => Text(
                        '${index + 1}',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      )),
            ),
          ),
          CupertinoButton(
            child: Text("Done", style: TextStyle(color: Color(0xFF03FFE2))),
            onPressed: () {
              Navigator.of(context).pop(tempValue);
            },
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget buildSelectedInviteesList() {
    final totalCount = selectedFriends.length + selectedCircles.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SizedBox(height: 12),
        Row(
          children: [
            Text(
              'Invite friends & circles ($totalCount)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            Spacer(),
            TextButton(
              onPressed: () async {
                final result = await showModalBottomSheet<Map<String, dynamic>>(
                  context: context,
                  isScrollControlled: true,
                  // backgroundColor: Colors.transparent,
                  builder: (_) => AddInviteegathering(
                    initialFriends: selectedFriends,
                    initialCircles: selectedCircles,
                    initialContacts: selectedContacts,
                  ),
                );

                if (result != null) {
                  setState(() {
                    selectedFriends = List<Map<String, String>>.from(
                        result['selectedFriends'] ?? []);

                    selectedContacts = List<Map<String, String>>.from(
                        result['selectedContacts'] ?? []);
                    selectedCircles =
                        List<CircleModel>.from(result['selectedCircles'] ?? []);
                  });

                  log('selected contacts : $selectedContacts');
                }
              },
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16, color: Color(0xFF03FFE2)),
                  SizedBox(width: 6),
                  Text("Edit",
                      style: TextStyle(color: Color(0xFF03FFE2), fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        ...selectedFriends.map((f) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(getInitials(f['name']!)),
              ),
              title: Text(f['name']!, style: TextStyle(color: Colors.white)),
            )),
        ...selectedContacts.map((f) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(getInitials(f['fullName']!)),
              ),
              title:
                  Text(f['fullName']!, style: TextStyle(color: Colors.white)),
            )),
        ...selectedCircles.map((c) => ListTile(
              leading: CircleAvatar(
                backgroundColor: hexToColor(c.circleColor),
                child: Icon(Icons.groups, color: Colors.white),
              ),
              title: Text(c.circleName, style: TextStyle(color: Colors.white)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group, size: 18, color: Colors.white70),
                  SizedBox(width: 4),
                  Text('${c.registeredUsers.length}',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            )),
      ],
    );
  }
}

String getPlacePhotoUrl(String photoReference) {
  String? apiKey = dotenv.env['GOOGLE_API_KEY'];
  return 'https://maps.googleapis.com/maps/api/place/photo'
      '?maxwidth=400'
      '&photoreference=$photoReference'
      '&key=$apiKey';
}
