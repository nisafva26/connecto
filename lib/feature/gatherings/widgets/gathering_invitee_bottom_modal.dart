import 'dart:developer';

import 'package:connecto/feature/circles/models/circle_model.dart';
import 'package:connecto/feature/circles/screens/circle_list_screen.dart';
import 'package:connecto/feature/circles/widgets/circle_tile.dart';
import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/helper/color_helper.dart';
import 'package:connecto/helper/get_initials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:contacts_service/contacts_service.dart';

class AddInviteegathering extends ConsumerStatefulWidget {
  final List<Map<String, String>> initialFriends;
  final List<CircleModel> initialCircles;
  final List<Map<String, String>> initialContacts;
  const AddInviteegathering({
    super.key,
    this.initialFriends = const [],
    this.initialCircles = const [],
    this.initialContacts = const [],
  });

  @override
  _AddInviteegatheringState createState() => _AddInviteegatheringState();
}

class _AddInviteegatheringState extends ConsumerState<AddInviteegathering> {
  List<Contact> contacts = [];
  List<Contact> filteredContacts = [];
  String? selectedPhoneNumber;
  Contact? selectedContact;
  TextEditingController searchController = TextEditingController();
  Set<Map<String, String>> selectedFriends = {}; // Store both name & phone
  Set<Map<String, String>> selectedContacts = {};

  int _selectedTabIndex = 0; // 0 for Friends, 1 for Circles
  Set<CircleModel> selectedCircles = {};

  @override
  void initState() {
    super.initState();
    selectedFriends = widget.initialFriends.toSet();
    selectedCircles = widget.initialCircles.toSet();
    selectedContacts = widget.initialContacts.toSet();
    requestContactsPermission();
    searchController.addListener(_filterContacts);
  }

  /// Request Contact Permission
  Future<void> requestContactsPermission() async {
    PermissionStatus status = await Permission.contacts.request();
    if (status.isGranted) {
      _fetchContacts();
    } else if (status.isDenied) {
      print("❌ Contacts permission denied");
    } else if (status.isPermanentlyDenied) {
      print("⚠️ Contacts permission permanently denied. Open settings.");
      await openAppSettings();
    }
  }

  /// Fetch contacts
  Future<void> _fetchContacts() async {
    try {
      List<Contact> fetchedContacts = (await FlutterContacts.getContacts(
              withProperties: true))
          .where((c) => c.phones!.isNotEmpty) // Filter contacts without numbers
          .toList();
      setState(() {
        contacts = fetchedContacts;
        filteredContacts = contacts;
      });
    } catch (e) {
      print("Error fetching contacts: $e");
    }
  }

  /// Filter contacts based on search input
  void _filterContacts() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredContacts = contacts.where((contact) {
        String name = contact.displayName?.toLowerCase() ?? '';
        String number =
            contact.phones!.isNotEmpty ? contact.phones!.first.number! : '';
        return name.contains(query) || number.contains(query);
      }).toList();
    });
  }

  /// Close the modal without adding a friend
  void _cancel() {
    Navigator.pop(context);
  }

  /// Add friend logic (modify as needed)
  void _addFriend() {
    if (selectedContacts.isEmpty &&
        selectedFriends.isEmpty &&
        selectedCircles.isEmpty) {
      log('please select from your friends or circles');
    } else {
      log('before pop selected contacts : $selectedContacts');
      Navigator.pop(context, {
        'selectedFriends': [...selectedFriends],
        'selectedCircles': selectedCircles.toList(),
        'selectedContacts': selectedContacts.toList()
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsList = ref.watch(friendsProvider);
    final circlesAsync = ref.watch(circlesProvider);
    return DraggableScrollableSheet(
      initialChildSize: .7, // Takes 70% of the screen height
      minChildSize: 0.5, // Minimum height (50% of screen)
      maxChildSize: .95, // Maximum height (90% of screen)
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xff001311), // Solid background
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                /// 🔹 Top Bar with Cancel & Add Buttons
                Container(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Color(0xff091F1E),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _cancel,
                            child: Text("Cancel",
                                style: TextStyle(
                                    color: Colors.tealAccent[700],
                                    fontSize: 16)),
                          ),
                          Text("Add Friend",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: _addFriend,
                            child: Text("Add",
                                style: TextStyle(
                                    color: Colors.tealAccent[700],
                                    fontSize: 16)),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Color(0xFF0D2E2D)),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    setState(() => _selectedTabIndex = 0),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedTabIndex == 0
                                      ? Theme.of(context).colorScheme.secondary
                                      : Color(0xFF0D2E2D),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Friends',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: _selectedTabIndex == 1
                                            ? FontWeight.w400
                                            : FontWeight.w700,
                                        color: _selectedTabIndex == 0
                                            ? Color(0xff243443)
                                            : Color(0xffAAB0B7))),
                              ),
                            ),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    setState(() => _selectedTabIndex = 1),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedTabIndex == 1
                                      ? Theme.of(context).colorScheme.secondary
                                      : Color(0xFF0D2E2D),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text('Circles',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: _selectedTabIndex == 1
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                        color: _selectedTabIndex == 1
                                            ? Color(0xff243443)
                                            : Color(0xffAAB0B7))),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedTabIndex == 0) ...[
                        SizedBox(
                          height: 15,
                        ),

                        /// 🔍 Search Bar
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Color(0xFF001311),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.tealAccent[700]!),
                          ),
                          child: TextField(
                            controller: searchController,
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              icon: Icon(Icons.search, color: Colors.white54),
                              hintText: "Search for a friend",
                              hintStyle: TextStyle(color: Colors.white54),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 18),
                    ],
                  ),
                ),

                /// 📞 Contact List
                ///

                _selectedTabIndex == 0
                    ? filteredContacts.isEmpty
                        ? Center(
                            child: CircularProgressIndicator(
                                color: Colors.tealAccent[700]))
                        : Container(
                            padding: EdgeInsets.only(top: 15),
                            color: Color(0xff001311),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 20)
                                          .copyWith(top: 20),
                                  child: Text(
                                    'Select from friends',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white),
                                  ),
                                ),
                                SizedBox(
                                  height: 16,
                                ),
                                friendsList.when(
                                  data: (data) {
                                    return ListView.separated(
                                      separatorBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          child: Divider(
                                            color: Color(0xff2b3c3a),
                                            height: .7,
                                          ),
                                        );
                                      },
                                      itemCount: data.length,
                                      physics: NeverScrollableScrollPhysics(),
                                      shrinkWrap: true,
                                      itemBuilder: (context, index) {
                                        final friend = data[index];
                                        final isSelected = selectedFriends
                                            .any((f) => f['id'] == friend.id);
                                        return InkWell(
                                          onTap: () {
                                            _toggleFriendSelection(
                                                friend.id,
                                                friend.fullName,
                                                friend.phoneNumber);
                                          },
                                          child: ListTile(
                                            contentPadding: EdgeInsets.only(
                                                left: 28, right: 23),
                                            leading: CircleAvatar(
                                              backgroundColor: Colors.grey[800],
                                              child:
                                                  //  contact.avatar != null &&
                                                  //         contact.avatar!.isNotEmpty
                                                  //     ? ClipOval(
                                                  //         child: Image.memory(
                                                  //             contact.avatar!))
                                                  //     :
                                                  Text(
                                                      getInitials(
                                                          friend.fullName),
                                                      style: TextStyle(
                                                          color: Colors.white)),
                                            ),
                                            title: Text(
                                              friend.fullName,
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16),
                                            ),
                                            subtitle: Text(
                                              friend.phoneNumber,
                                              style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 14),
                                            ),
                                            trailing: Checkbox(
                                              value: isSelected,
                                              activeColor: Color(0xff03FFE2),
                                              side: WidgetStateBorderSide
                                                  .resolveWith(
                                                (states) => BorderSide(
                                                    width: 1.0,
                                                    color: Color(0xff233443)),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        5), // ✅ Make it round
                                              ),
                                              onChanged: (bool? value) {
                                                _toggleFriendSelection(
                                                    friend.id,
                                                    friend.fullName,
                                                    friend.phoneNumber);
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  error: (error, stackTrace) {
                                    return Container();
                                  },
                                  loading: () {
                                    return CircularProgressIndicator();
                                  },
                                ),

                                // SizedBox(
                                //   height: 16,
                                // ),

                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  child: Text(
                                    'Select from contacts',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white),
                                  ),
                                ),
                                SizedBox(
                                  height: 16,
                                ),
                                ListView.separated(
                                  shrinkWrap: true,
                                  separatorBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      child: Divider(
                                        color: Color(0xff2b3c3a),
                                        height: .7,
                                      ),
                                    );
                                  },
                                  controller: scrollController,
                                  itemCount: filteredContacts.length,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    final contact = filteredContacts[index];
                                    final phone = contact.phones!.isNotEmpty
                                        ? contact.phones.first.number
                                        : "No Number";
                                    final isSelected = selectedContacts.any(
                                        (c) =>
                                            c['phoneNumber'] ==
                                            phone.replaceAll(
                                                RegExp(r'[^\d+]'), ''));

                                    return InkWell(
                                      onTap: () {
                                        _toggleSelectionContact(
                                            contact.displayName!, phone);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          // color: isSelected
                                          //     ? Colors.tealAccent.withOpacity(0.2)
                                          //     : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.only(
                                              left: 28, right: 23),
                                          leading: CircleAvatar(
                                            backgroundColor: Colors.grey[800],
                                            child: contact.photoOrThumbnail !=
                                                        null &&
                                                    contact.photoOrThumbnail!
                                                        .isNotEmpty
                                                ? ClipOval(
                                                    child: Image.memory(contact
                                                        .photoOrThumbnail!))
                                                : Text(
                                                    getInitials(
                                                        contact.displayName),
                                                    style: TextStyle(
                                                        color: Colors.white)),
                                          ),
                                          title: Text(
                                            contact.displayName ?? "No Name",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16),
                                          ),
                                          subtitle: Text(
                                            phone!,
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 14),
                                          ),
                                          trailing: Checkbox(
                                            value: isSelected,
                                            onChanged: (bool? value) {
                                              _toggleSelectionContact(
                                                  contact.displayName!, phone);
                                            },
                                            activeColor: Color(0xff03FFE2),
                                            side: WidgetStateBorderSide
                                                .resolveWith(
                                              (states) => BorderSide(
                                                  width: 1.0,
                                                  color: Color(0xff233443)),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      5), // ✅ Make it round
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          )
                    : circlesAsync.when(
                        data: (circles) {
                          return Container(
                            color: Color(0xff001311),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 20),
                              child: ListView(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                children: [
                                  ...circles.map((circle) {
                                    final isSelected = selectedCircles
                                        .any((c) => c.id == circle.id);
                                    return buildCircleTile(
                                      circle: circle,
                                      isSelected: isSelected,
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            selectedCircles.removeWhere(
                                                (c) => c.id == circle.id);
                                          } else {
                                            selectedCircles.add(circle);
                                          }
                                        });
                                      },
                                    );
                                  })
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () =>
                            Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(
                            child: Text("Error loading circles",
                                style: TextStyle(color: Colors.red))),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleFriendSelection(String id, String name, String phoneNumber) {
    setState(() {
      final isSelected = selectedFriends.any((f) => f['id'] == id);

      if (isSelected) {
        selectedFriends.removeWhere((f) => f['id'] == id);
      } else {
        selectedFriends
            .add({'id': id, 'name': name, 'phoneNumber': phoneNumber});
      }
    });
  }

  void _toggleSelectionContact(String name, String phone) {
    final normalizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    log('normalised number : $normalizedPhone');

    setState(() {
      final isSelected = selectedContacts.any(
        (c) =>
            c['phoneNumber']?.replaceAll(RegExp(r'[^\d+]'), '') ==
            normalizedPhone,
      );
      log('is selected ? $isSelected');

      if (isSelected) {
        selectedContacts.removeWhere(
          (c) =>
              c['phoneNumber']?.replaceAll(RegExp(r'[^\d+]'), '') ==
              normalizedPhone,
        );
      } else {
        selectedContacts.add({
          'fullName': name,
          'phoneNumber': normalizedPhone, // 🔁 Store normalized form
        });
      }
    });
  }
}

Widget buildCircleTile({
  required CircleModel circle,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  final backgroundColor = hexToColor(circle.circleColor);
  final fontColor =
      backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  final displayedUsers = circle.registeredUsers.take(4).toList();
  final remainingCount = circle.registeredUsers.length - displayedUsers.length;

  return GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 🔹 Circle Name & Radial Selector
          Row(
            children: [
              Text(
                circle.circleName,
                style: TextStyle(
                  color: fontColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),

              /// 🔘 Radial Radio Button
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: fontColor, width: 2),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: fontColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
          SizedBox(height: 32),

          /// 👥 Circle Members
          Row(
            children: [
              for (var user in displayedUsers)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: fontColor.withOpacity(0.2),
                    child: Text(
                      getInitials(user.fullName),
                      style: TextStyle(
                        color: fontColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (remainingCount > 0)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: fontColor),
                  ),
                  child: Center(
                    child: Text(
                      '+$remainingCount',
                      style: TextStyle(
                        color: fontColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          )
        ],
      ),
    ),
  );
}
