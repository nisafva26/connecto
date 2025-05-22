import 'package:flutter/material.dart';
// import 'package:contacts_service/contacts_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactsPage extends StatefulWidget {
  @override
  _ContactsPageState createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Contact> contacts = [];

  @override
  void initState() {
    super.initState();
    requestContactsPermission();
  }

  Future<void> requestContactsPermission() async {
    PermissionStatus status = await Permission.contacts.request();

    if (status.isGranted) {
      print("✅ Contacts permission granted");
      getContacts();
    } else if (status.isDenied) {
      print("❌ Contacts permission denied");
    } else if (status.isPermanentlyDenied) {
      print("⚠️ Contacts permission permanently denied. Open settings.");
      await openAppSettings();
    }
  }

  Future<void> getContacts() async {
    try {
      List<Contact> _contacts = await FlutterContacts.getContacts(withProperties: true);
      setState(() {
        contacts = _contacts;
      });
    } catch (e) {
      print("Error fetching contacts: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Contacts")),
      body: contacts.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(contacts[index].displayName ?? "No Name"),
                  subtitle: Text(contacts[index].phones?.isNotEmpty == true
                      ? contacts[index].phones!.first.number!
                      : "No Number"),
                );
              },
            ),
    );
  }
}
