import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';

void showAddFriendModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Ensures modal takes full height if needed
    backgroundColor: Colors.transparent,
    builder: (context) => AddFriendModal(),
  );
}

class AddFriendModal extends StatefulWidget {
  @override
  _AddFriendModalState createState() => _AddFriendModalState();
}

class _AddFriendModalState extends State<AddFriendModal> {
  List<Contact> contacts = [];
  List<Contact> filteredContacts = [];
  String? selectedPhoneNumber;
  Contact? selectedContact;
  TextEditingController searchController = TextEditingController();

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
      List<Contact> fetchedContacts = (await ContactsService.getContacts())
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
            contact.phones!.isNotEmpty ? contact.phones!.first.value! : '';
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
    if (selectedPhoneNumber != null) {
      print("✅ Friend added: $selectedPhoneNumber");
      // Navigator.pop(context,selectedPhoneNumber);
      Navigator.pop(context);
      context.go(
          '/bond/friend-details/${Uri.encodeComponent(selectedContact!.displayName!)}/${selectedPhoneNumber}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a contact")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // final friendsList = ref.watch(friendsProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.7, // Takes 70% of the screen height
      minChildSize: 0.5, // Minimum height (50% of screen)
      maxChildSize: 0.9, // Maximum height (90% of screen)
      builder: (context, scrollController) {
        return Container(
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                                  color: Colors.tealAccent[700], fontSize: 16)),
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
                                  color: Colors.tealAccent[700], fontSize: 16)),
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
              Expanded(
                child: filteredContacts.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(
                            color: Colors.tealAccent[700]))
                    : Container(
                        padding: EdgeInsets.only(top: 15),
                        color: Color(0xff001311),
                        child: ListView.separated(
                          separatorBuilder: (context, index) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Divider(
                                color: Color(0xff2b3c3a),
                                height: .7,
                              ),
                            );
                          },
                          controller: scrollController,
                          itemCount: filteredContacts.length,
                          itemBuilder: (context, index) {
                            final contact = filteredContacts[index];
                            final phone = contact.phones!.isNotEmpty
                                ? contact.phones!.first.value
                                : "No Number";
                            final isSelected = phone == selectedPhoneNumber;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  selectedPhoneNumber = phone;
                                  selectedContact = contact;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.tealAccent.withOpacity(0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ListTile(
                                  contentPadding:
                                      EdgeInsets.only(left: 28, right: 23),
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.grey[800],
                                    child: contact.avatar != null &&
                                            contact.avatar!.isNotEmpty
                                        ? ClipOval(
                                            child:
                                                Image.memory(contact.avatar!))
                                        : Text(contact.initials(),
                                            style:
                                                TextStyle(color: Colors.white)),
                                  ),
                                  title: Text(
                                    contact.displayName ?? "No Name",
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 16),
                                  ),
                                  subtitle: Text(
                                    phone!,
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 14),
                                  ),
                                  trailing: isSelected
                                      ? Icon(Icons.radio_button_checked,
                                          color: Colors.tealAccent[700])
                                      : Icon(Icons.radio_button_unchecked,
                                          color: Colors.white54),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
