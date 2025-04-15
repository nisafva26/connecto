import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ Model for Friend Details State

class FriendDetailsState {
  final bool isUserInDB;
  final bool isFriendAlreadyAdded;
  final bool isLoading;
  final bool isButtonLoading;
  final String friendID;

  FriendDetailsState({
    this.isUserInDB = false,
    this.isFriendAlreadyAdded = false,
    this.isLoading = true,
    this.isButtonLoading = false,
    this.friendID = '',
  });

  FriendDetailsState copyWith({
    bool? isUserInDB,
    bool? isFriendAlreadyAdded,
    bool? isLoading,
    bool? isButtonLoading,
    String? friendID,
  }) {
    return FriendDetailsState(
      isUserInDB: isUserInDB ?? this.isUserInDB,
      isFriendAlreadyAdded: isFriendAlreadyAdded ?? this.isFriendAlreadyAdded,
      isLoading: isLoading ?? this.isLoading,
      isButtonLoading: isButtonLoading ?? this.isButtonLoading,
      friendID: friendID ?? this.friendID,
    );
  }
}

// ✅ Riverpod Notifier
class FriendDetailsNotifier extends StateNotifier<FriendDetailsState> {
  FriendDetailsNotifier() : super(FriendDetailsState());

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ✅ Normalize phone number
  String normalizePhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), ''); // Keep only numbers and +
  }

  // ✅ Fetch Friend Data
  Future<void> checkFriendDetails(String phoneNumber) async {
    state = state.copyWith(isLoading: true);
    String formattedPhone = normalizePhoneNumber(phoneNumber);
    log("🔍 Searching Firestore for: $formattedPhone");

    final snapshot = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: formattedPhone)
        .get();

    if (snapshot.docs.isNotEmpty) {
      String friendId = snapshot.docs.first.id;

      state = state.copyWith(
        isUserInDB: true,
        friendID: friendId,
      );

      log("✅ Friend exists: $friendId");
      checkIfAlreadyAdded(friendId);
    } else {
      state = state.copyWith(isUserInDB: false, friendID: '');
      log("❌ Friend not in DB.");
    }

    state = state.copyWith(isLoading: false);
  }

  // ✅ Check if the friend is already added
  Future<void> checkIfAlreadyAdded(String friendId) async {
    String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final userDoc =
        await _firestore.collection('users').doc(currentUserId).get();
    if (userDoc.exists) {
      List<dynamic> friendsList = userDoc.data()?['friends'] ?? [];
      state =
          state.copyWith(isFriendAlreadyAdded: friendsList.contains(friendId));
    }
  }

  // ✅ Add Friend
  Future<void> addFriend(String relationship) async {
    if (state.friendID.isEmpty || _auth.currentUser == null) return;

    state = state.copyWith(isButtonLoading: true);

    String currentUserId = _auth.currentUser!.uid;
    String friendId = state.friendID;

    List<String> sortedIds = [currentUserId, friendId]..sort();
    String friendshipId = sortedIds.join("_");

    final friendshipRef =
        _firestore.collection('friendships').doc(friendshipId);
    final userARef = _firestore.collection('users').doc(currentUserId);
    final userBRef = _firestore.collection('users').doc(friendId);

    final friendshipDoc = await friendshipRef.get();
    if (friendshipDoc.exists) return;

    await friendshipRef.set({
      'userA': currentUserId,
      'userB': friendId,
      'relationship': relationship,
      'automatedMessages': {
        'sendGoodMorning': false,
        'sendGoodNight': false,
        'sendHereMessages': false
      },
      'locationOptions': {'locationIsOn': false, 'sendUpdatesForEvents': false},
      'createdAt': FieldValue.serverTimestamp(),
    });

    await userARef.update({
      'friends': FieldValue.arrayUnion([friendId])
    });
    await userBRef.update({
      'friends': FieldValue.arrayUnion([currentUserId])
    });

    state = state.copyWith(isFriendAlreadyAdded: true);
    state = state.copyWith(isButtonLoading: false);
    log("✅ Friend added successfully!");

  //     // ✅ Refresh the friend provider
  // ref.invalidate(friendProvider);

  // // ✅ Navigate back to the BondScreen
  // context.pop();

  }
}

// ✅ Riverpod Provider
final friendDetailsProvider =
    StateNotifierProvider<FriendDetailsNotifier, FriendDetailsState>((ref) {
  return FriendDetailsNotifier();
});
