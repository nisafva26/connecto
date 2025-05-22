import 'dart:developer';

import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/helper/get_initials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:contacts_service/contacts_service.dart';

class AddCircleModal extends ConsumerStatefulWidget {
  const AddCircleModal({super.key});

  @override
  _AddCircleModalState createState() => _AddCircleModalState();
}

class _AddCircleModalState extends ConsumerState<AddCircleModal> {
  List<Contact> contacts = [];
  List<Contact> filteredContacts = [];
  String? selectedPhoneNumber;
  Contact? selectedContact;
  TextEditingController searchController = TextEditingController();
  Set<Map<String, String>> selectedFriends = {}; // Store both name & phone
  Set<Map<String, String>> selectedContacts = {};

  @override
  void initState() {
    super.initState();
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
            contact.phones!.isNotEmpty ? contact.phones!.first.number : '';
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
    // if (selectedPhoneNumber != null) {
    //   print("✅ Friend added: $selectedPhoneNumber");
    //   // Navigator.pop(context,selectedPhoneNumber);
    //   context.go(
    //       '/bond/friend-details/${Uri.encodeComponent(selectedContact!.displayName!)}/${selectedPhoneNumber}');
    // } else {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text("Please select a contact")),
    //   );
    // }
    if (selectedContacts.isEmpty && selectedFriends.isEmpty) {
      log('please select friends');
    } else {
      // Navigator.pop(context);
      Navigator.pop(context);
      context.go('/bond/create-circle', extra: {
        'selectedUsers': [...selectedFriends, ...selectedContacts],
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsList = ref.watch(friendsProvider);
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: .95, // Takes 70% of the screen height
        minChildSize: 0.8, // Minimum height (50% of screen)
        maxChildSize: .95, // Maximum height (90% of screen)
        builder: (context, scrollController) {
          return SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xff091F1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
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
                        SizedBox(height: 18),
                      ],
                    ),
                  ),

                  /// 📞 Contact List
                  ///

                  filteredContacts.isEmpty
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
                                      final isSelected = selectedFriends.any(
                                          (f) =>
                                              f['phoneNumber'] ==
                                              friend.phoneNumber);
                                      return InkWell(
                                        onTap: () {
                                          _toggleFriendSelection(
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
                                            friend.fullName ?? "No Name",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16),
                                          ),
                                          subtitle: Text(
                                            friend.phoneNumber!,
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
                              SizedBox(
                                height: 16,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
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
                                      ? contact.phones!.first.number
                                      : "No Number";
                                  final isSelected = selectedContacts
                                      .any((c) => c['phoneNumber'] == phone);

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
                                        borderRadius: BorderRadius.circular(8),
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
                                              color: Colors.grey, fontSize: 14),
                                        ),
                                        trailing: Checkbox(
                                          value: isSelected,
                                          onChanged: (bool? value) {
                                            _toggleSelectionContact(
                                                contact.displayName!, phone);
                                          },
                                          activeColor: Color(0xff03FFE2),
                                          side:
                                              WidgetStateBorderSide.resolveWith(
                                            (states) => BorderSide(
                                                width: 1.0,
                                                color: Color(0xff233443)),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
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
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _toggleSelectionContact(String name, String phone) {
    setState(() {
      final isSelected = selectedContacts.any((c) => c['phoneNumber'] == phone);

      if (isSelected) {
        selectedContacts.removeWhere((c) => c['phoneNumber'] == phone);
      } else {
        selectedContacts.add({'fullName': name, 'phoneNumber': phone});
      }
    });
  }

  void _toggleFriendSelection(String name, String phone) {
    setState(() {
      final isSelected = selectedFriends.any((f) => f['phoneNumber'] == phone);

      if (isSelected) {
        selectedFriends.removeWhere((f) => f['phoneNumber'] == phone);
      } else {
        selectedFriends.add({'fullName': name, 'phoneNumber': phone});
      }
    });
  }
}
