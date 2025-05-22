
import 'package:connecto/feature/dashboard/controller/friend_details_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FriendDetailsScreen extends ConsumerStatefulWidget {
  final String name;
  final String phoneNumber;

  FriendDetailsScreen({required this.name, required this.phoneNumber});

  @override
  _FriendDetailsScreenState createState() => _FriendDetailsScreenState();
}

class _FriendDetailsScreenState extends ConsumerState<FriendDetailsScreen> {
  String? selectedRelationship = '';
  Map<String, bool> automatedMessages = {
    "Send good morning":
        false, // "The app automatically lets Annette know you're awake."
    "Send good night":
        false, // "The app lets Annette know that you have slept off."
    "Send ‘I’m here’ messages":
        false, // "The app sends automated messages when you have left your house or reached an event destination."
  };

  Map<String, bool> locationOptions = {
    "Location is on": false, // "The app lets your friend know where you are."
    "Send updates for events":
        false, // "The app sends location updates to Annette when you have accepted an invite."
  };

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(friendDetailsProvider.notifier)
          .checkFriendDetails(widget.phoneNumber);
    });
  }

  @override
  Widget build(BuildContext context) {
    final friendState = ref.watch(friendDetailsProvider);
    return Scaffold(
      backgroundColor: Color(0xFF001311), // Background Color
      appBar: AppBar(
        backgroundColor: Color(0xFF001311),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Add Friend",
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _saveFriendDetails,
            child: Text(
              "Add",
              style: TextStyle(color: Colors.tealAccent[700], fontSize: 16),
            ),
          )
        ],
      ),
      body: friendState.isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ListView(
                children: [
                  // Friend Profile
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white10,
                        child:
                            Icon(Icons.person, size: 40, color: Colors.white),
                      ),
                      SizedBox(height: 10),
                      Text(
                        widget.name,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        widget.phoneNumber,
                        style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                            fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Relationship Selection
                  Text("Relationship",
                      style: TextStyle(
                          fontSize: 14,
                          fontFamily: "Inter",
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  SizedBox(
                    height: 8,
                  ),
                  Text("${widget.name} will not be seeing this",
                      style: TextStyle(
                          fontSize: 14,
                          fontFamily: "Inter",
                          // color: Colors.white,
                          fontWeight: FontWeight.w400)),
                  SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _relationshipButton("Relative"),
                      _relationshipButton("Partner"),
                      _relationshipButton("Son"),
                      _relationshipButton("Daughter"),
                      _relationshipButton("Friend"),
                      _relationshipButton("Colleague"),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Automated Messages
                  Text("Automated messages",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  SizedBox(height: 16),
                  ...automatedMessages.entries
                      .map((entry) => _checkboxTile(entry.key, true)),

                  SizedBox(height: 24),

                  // Location Sharing
                  Text("Location",
                      style: TextStyle(
                          fontSize: 14,
                          // height: 20/14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  SizedBox(height: 16),
                  ...locationOptions.entries
                      .map((entry) => _checkboxTile(entry.key, false)),

                  SizedBox(height: 30),

                  // Add Friend Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        friendState.isFriendAlreadyAdded
                            ? null
                            : await ref
                                .read(friendDetailsProvider.notifier)
                                .addFriend(selectedRelationship ?? "Friend");

                        context.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF03FFE2),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: friendState.isButtonLoading
                          ? CircularProgressIndicator()
                          : Text(
                              friendState.isFriendAlreadyAdded
                                  ? "Already added"
                                  : friendState.isUserInDB
                                      ? "Add Friend"
                                      : "Invite",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // Relationship Selection Button
  Widget _relationshipButton(String title) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedRelationship = title;
        });
      },
      child: Container(
        width: (MediaQuery.of(context).size.width - 60) / 2,
        height: 50,
        decoration: BoxDecoration(
          color: Color(0xff091F1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selectedRelationship == title
                  ? Colors.tealAccent[700]!
                  : Color(0xff082523),
              width: 2),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  // Automated Message and Location Checkboxes
  Widget _checkboxTile(String title, bool isAutomatedMessage) {
    String subText = isAutomatedMessage
        ? (title == "Send good morning"
            ? "The app automatically lets Annette know you're awake."
            : title == "Send good night"
                ? "The app lets Annette know that you have slept off."
                : "The app sends automated messages when you have left your house or reached an event destination.")
        : (title == "Location is on"
            ? "The app lets your friend know where you are."
            : "The app sends location updates to Annette when you have accepted an invite.");

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isAutomatedMessage) {
            automatedMessages[title] = !(automatedMessages[title] ?? false);
          } else {
            locationOptions[title] = !(locationOptions[title] ?? false);
          }
        });
      },
      child: Container(
        // height: 92,
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xff091F1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: (isAutomatedMessage
                          ? automatedMessages[title]
                          : locationOptions[title]) ??
                      false
                  ? Colors.tealAccent[700]!
                  : Colors.transparent,
              width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.message, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 4),
                  Text(subText,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Inter',
                      ))
                ],
              ),
            ),
            Icon(
                (isAutomatedMessage
                            ? automatedMessages[title]
                            : locationOptions[title]) ??
                        false
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: Colors.tealAccent[700],
                size: 20),
          ],
        ),
      ),
    );
  }

  void _saveFriendDetails() {
    context.pop(); // Close the screen after saving details
  }
}
