import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/auth/model/user_model.dart';
import 'package:connecto/feature/circles/screens/circle_list_screen.dart';
import 'package:connecto/feature/dashboard/widgets/common_appbar.dart';
import 'package:connecto/feature/dashboard/widgets/contacts_model.dart';
import 'package:connecto/helper/get_initials.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

String formatDate(DateTime date) {
  return DateFormat('dd-MM-yyyy').format(date);
}

// ✅ Friends Provider
final friendsProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(currentUserId)
      .snapshots()
      .asyncMap((userDoc) async {
    if (!userDoc.exists) return [];

    final List<String> friendIds =
        List<String>.from(userDoc.data()?['friends'] ?? []);
    if (friendIds.isEmpty) return [];

    final friendDocs = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: friendIds)
        .get();

    return friendDocs.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  });
});

final currentUserProvider = StreamProvider.autoDispose<UserModel?>((ref) {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  });
});

final chatFlagsProvider =
    StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final collection = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('chatFlags');

  return collection.snapshots().map((snapshot) {
    final Map<String, dynamic> flags = {};
    for (final doc in snapshot.docs) {
      flags[doc.id] = doc.data(); // doc.id is friendId
    }
    return flags;
  });
});

class BondScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const BondScreen({super.key, this.initialTabIndex = 0});
  @override
  _BondScreenState createState() => _BondScreenState();
}

class _BondScreenState extends ConsumerState<BondScreen> {
  int _selectedTabIndex = 0; // 0 for Friends, 1 for Circles

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
    _checkPendingGatheringsIfNeeded();
  }

  Future<void> _checkPendingGatheringsIfNeeded() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (!(userDoc.data()?['hasCheckedPendingGatherings'] ?? false)) {
      await handlePendingGatheringsAfterRegistration(
        userId: uid,
        fullName: userDoc.data()?['fullName'] ?? 'User',
        phoneNumber: userDoc.data()?['phoneNumber'],
      );

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'hasCheckedPendingGatherings': true,
      });
    }
  }

  //one time function for newly regstered users to check wheterh they have any gahtering request in line
  Future<void> handlePendingGatheringsAfterRegistration({
    required String userId,
    required String phoneNumber,
    required String fullName,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final gatheringsCollection = firestore.collection('gatherings');

    // Query all gatherings that include this phone in nonRegisteredInvitees
    final query = await gatheringsCollection
        .where('nonRegisteredInvitees.$phoneNumber', isGreaterThan: {}).get();

    for (final doc in query.docs) {
      final gatheringId = doc.id;
      final gatheringData = doc.data();

      final gatheringRef = gatheringsCollection.doc(gatheringId);

      // Step 1: Remove from nonRegisteredInvitees map
      await gatheringRef.update({
        'nonRegisteredInvitees.$phoneNumber': FieldValue.delete(),
        'invitees.$userId': {
          'status': 'pending',
          'host': false,
          'name': fullName,
        },
      });

      // Step 2: Remove from subcollection nonRegisteredInvitees
      await gatheringRef
          .collection('nonRegisteredInvitees')
          .doc(phoneNumber)
          .delete();

      // Step 3: Add to invitees subcollection
      await gatheringRef.collection('invitees').doc(userId).set({
        'name': fullName,
        'status': 'pending',
        'host': false,
        'sharing': true,
      });

      // Step 4: Update user's gathering list
      await firestore.collection('users').doc(userId).set({
        'gatherings': {
          gatheringId: true,
        },
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsList = ref.watch(friendsProvider);
    ref.watch(currentUserProvider);
    log('passed initial tab index : ${widget.initialTabIndex}');

    final flags = ref.watch(chatFlagsProvider).value ?? {};

    Future<String> getOrCreateChatId(String userId, String friendId) async {
      FirebaseFirestore.instance.collection('chats');

      // // 🔹 Search for an existing chat
      // final querySnapshot =
      //     await chatRef.where('members', arrayContains: userId).get();

      // for (var doc in querySnapshot.docs) {
      //   List members = doc['members'];
      //   if (members.contains(friendId)) {
      //     log('friend ID : $friendId');
      //     log('array contains friend ID , chat exist , returnnig chat id ${doc.id}');

      //     return doc.id; // ✅ Chat already exists, return chatId
      //   }
      // }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      // ✅ Check if chat already exists in the user's document
      if (userDoc.exists && userDoc.data()!.containsKey('chats')) {
        Map<String, dynamic> chats = userDoc.data()!['chats'];

        if (chats.containsKey(friendId)) {
          log('✅ Found chat ID in user document: ${chats[friendId]}');
          return chats[friendId]; // Return existing chat ID immediately
        }
      }

      // log('chat doesnt exist');

      // // 🔹 No existing chat, create a new one
      // final newChatRef = chatRef.doc(); // 🔹 Firestore auto-generates ID

      // await newChatRef.set({
      //   'members': [userId, friendId],
      //   'lastMessage': {'text': '', 'timestamp': FieldValue.serverTimestamp()},
      //   'createdAt': FieldValue.serverTimestamp(),
      // });

      // return newChatRef.id; // ✅ Return new chatId

      // ❌ Chat doesn't exist, create a new chat
      log('🚀 Creating new chat...');
      final newChatRef = FirebaseFirestore.instance.collection('chats').doc();
      final newChatId = newChatRef.id;

      await newChatRef.set({
        'chatId': newChatId,
        'participants': [userId, friendId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });

      // ✅ Update both users' `chats` field
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'chats.$friendId': newChatId,
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(friendId)
          .update({
        'chats.$userId': newChatId,
      });

      log('✅ Chat created with ID: $newChatId');
      return newChatId;
    }

    Future<void> markChatFlagsAsSeen(String friendId) async {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chatFlags')
          .doc(friendId);

      await docRef.update({
        'isChatOpened': true,
      });
    }

    return Scaffold(
      backgroundColor: Color(0xff001311),
      appBar: CommonAppBar(),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Color(0xff091F1E)),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => setState(() => _selectedTabIndex = 0),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedTabIndex == 0
                              ? Theme.of(context).colorScheme.secondary
                              : Color(0xff091F1E),
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
                        onPressed: () => setState(() => _selectedTabIndex = 1),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedTabIndex == 1
                              ? Theme.of(context).colorScheme.secondary
                              : Color(0xff091F1E),
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
            ),
            SizedBox(height: 28),

            // ✅ Fetching Friends List
            _selectedTabIndex == 0
                ? Expanded(
                    child: friendsList.when(
                      data: (friends) {
                        if (friends.isEmpty) {
                          return Center(
                            child: Column(
                              // mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 90,
                                ),
                                Container(
                                  width: 126,
                                  height: 47,
                                  decoration: BoxDecoration(
                                      color: Color(0xff091F1E),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Center(
                                    child: Text(
                                      'Its lonely out here',
                                      style: TextStyle(
                                          wordSpacing: -1,
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 29,
                                ),
                                Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                      image: DecorationImage(
                                          image: AssetImage(
                                              'assets/images/avatar.png')),
                                      shape: BoxShape.circle,
                                      color: Colors.white),
                                ),
                                SizedBox(height: 21),
                                Text('You have 0 friends',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontFamily: "Inter",
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                                SizedBox(height: 21),
                                SizedBox(
                                  width: 216,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final selectedContact =
                                          await showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => AddFriendModal(),
                                      );

                                      if (selectedContact != null) {
                                        print(
                                            "Friend selected: $selectedContact");
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF03FFE2),
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                    child: Text('Add a friend',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter')),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        friends.sort((a, b) {
                          final aTime =
                              flags[a.id]?['lastActivity'] ?? Timestamp(0, 0);
                          final bTime =
                              flags[b.id]?['lastActivity'] ?? Timestamp(0, 0);
                          return (bTime as Timestamp)
                              .compareTo(aTime as Timestamp);
                        });

                        return ListView.separated(
                          separatorBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Divider(
                                color: Color(0xff2b3c3a),
                                height: .5,
                              ),
                            );
                          },
                          itemCount: friends.length,
                          padding: EdgeInsets.all(0),
                          itemBuilder: (context, index) {
                            final friend = friends[index];

                            final bool showIndicator =
                                flags[friend.id]?['isChatOpened'] == false &&
                                    flags[friend.id]?['latestPingFromFriend'] ==
                                        true;

                            return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: InkWell(
                                  onTap: () async {
                                    // final selectedPing =
                                    //     await context.push('/bond/select-ping');

                                    // Mark flags as seen before navigating
                                    if (flags[friend.id] != null) {
                                      log('====flags exists====');

                                      markChatFlagsAsSeen(friend.id);
                                    } else {
                                      log('====flags doesnt exists====');
                                    }

                                    String chatId = await getOrCreateChatId(
                                        FirebaseAuth.instance.currentUser!.uid,
                                        friend.id);

                                    context.go(
                                      '/bond/chat/$chatId',
                                      extra: {
                                        'friendId': friend.id,
                                        'friendName': friend.fullName,
                                        'friendProfilePic': friend.id,
                                        'friend': friend
                                      },
                                    );
                                  },
                                  child: Container(
                                    height: 71,
                                    // color: Colors.yellow,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 4,
                                          ),
                                          Container(
                                            height: 50,
                                            width: 50,
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                // image: DecorationImage(
                                                //     image: NetworkImage(
                                                //         'https://plus.unsplash.com/premium_photo-1689568126014-06fea9d5d341?fm=jpg&q=60&w=3000&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxzZWFyY2h8MXx8cHJvZmlsZXxlbnwwfHwwfHx8MA%3D%3D'),
                                                //     fit: BoxFit.cover),
                                                color: Colors.white),
                                            child: Center(
                                                child: Text(
                                              getInitials(friend.fullName),
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700),
                                            )),
                                          ),
                                          SizedBox(
                                            width: 29,
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            // mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(friend.fullName,
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              SizedBox(
                                                height: 5,
                                              ),

                                              Text(flags[friend.id] == null
                                                  ? ""
                                                  : buildSubtext(
                                                      flags[friend.id],
                                                      friend.id,
                                                      FirebaseAuth.instance
                                                          .currentUser!.uid))

                                              // Text(
                                              //   flags[friend.id]?[
                                              //               'hasPendingGathering'] ==
                                              //           true
                                              //       ? 'New gathering request'
                                              //       : flags[friend.id]?[
                                              //                   'latestPingFromFriend'] ==
                                              //               true
                                              //           ? 'Ping received'
                                              //           : friend.isActive
                                              //               ? 'Online'
                                              //               : 'Last seen: ${formatDate(friend.lastActive)}',
                                              //   style: TextStyle(
                                              //       color: Color(0xff58616A)),
                                              // ),
                                            ],
                                          ),
                                          Spacer(),
                                          // Column(
                                          //   children: [
                                          //     Align(
                                          //       alignment: Alignment.center,
                                          //       child: Icon(Icons.chevron_right,
                                          //           color: Color(0xff58616A)),
                                          //     ),
                                          //   ],
                                          // )

                                          Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (showIndicator)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.tealAccent,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Text(
                                                    "1",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ),
                                              SizedBox(height: 6),
                                              Icon(Icons.chevron_right,
                                                  color: Color(0xff58616A)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ));
                          },
                        );
                      },
                      loading: () => Center(
                          child:
                              CircularProgressIndicator(color: Colors.white)),
                      error: (e, stack) {
                        log(e.toString());
                        return Center(
                            child: Text('Error loading friends $e',
                                style: TextStyle(color: Colors.red)));
                      },
                    ),
                  )
                : CircleListScreen(),

            SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: _selectedTabIndex == 1
          ? SizedBox()
          : FloatingActionButton(
              backgroundColor: Color(0xFF03FFE2),
              shape: CircleBorder(),
              onPressed: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => AddFriendModal(),
                );
              },
              child: Icon(Icons.add, size: 20),
            ),
    );
  }

  String buildSubtext(
    Map<String, dynamic> flag,
    String friendId,
    String currentUserId,
  ) {
    final hasGathering = flag['hasPendingGathering'] == true;
    final latestPingFromFriend = flag['latestPingFromFriend'] == true;
    final lastPingText = flag['lastPingText'] ?? "";

    // ✅ Prioritize gathering status
    if (hasGathering) {
      return latestPingFromFriend
          ? "New gathering request"
          : "You sent a gathering request";
    }

    // ✅ Then check for ping
    if (flag['latestPingFrom'] != null) {
      return latestPingFromFriend ? "Ping received" : "You sent a ping";
    }

    // ✅ Fallback to last ping text
    if (lastPingText.isNotEmpty) {
      return lastPingText;
    }

    return ""; // No info
  }
}
