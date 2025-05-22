import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class JoinPublicGatheringState {
  final bool isLoading;
  final bool isSuccess;
  final String? errorMessage;

  JoinPublicGatheringState({
    this.isLoading = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  factory JoinPublicGatheringState.initial() => JoinPublicGatheringState();
  factory JoinPublicGatheringState.loading() => JoinPublicGatheringState(isLoading: true);
  factory JoinPublicGatheringState.success() => JoinPublicGatheringState(isSuccess: true);
  factory JoinPublicGatheringState.error(String message) => JoinPublicGatheringState(errorMessage: message);
}


class JoinPublicGatheringNotifier extends StateNotifier<JoinPublicGatheringState> {
  JoinPublicGatheringNotifier() : super(JoinPublicGatheringState.initial());

  Future<void> joinPublicGathering({
    required String gatheringId,
    required String userId,
    required String userFullName,
    required String userPhoneNumber,
  }) async {
    try {
      state = JoinPublicGatheringState.loading();
      final firestore = FirebaseFirestore.instance;

      final gatheringRef = firestore.collection('gatherings').doc(gatheringId);
      final userRef = firestore.collection('users').doc(userId);

      // 1. Update joinedPublicUsers map field
      await gatheringRef.update({
        'joinedPublicUsers.$userId': {
          'host': false,
          'name': userFullName,
          'phoneNumber': userPhoneNumber,
          'sharing': true,
          'status': 'accepted',
        }
      });

      // 2. Add into subcollection
      await gatheringRef.collection('joinedPublicUsers').doc(userId).set({
        'host': false,
        'name': userFullName,
        'phoneNumber': userPhoneNumber,
        'sharing': true,
        'status': 'accepted',
      });

      // 3. Update user doc
      await userRef.set({
        'gatherings': {gatheringId: true}
      }, SetOptions(merge: true));

      state = JoinPublicGatheringState.success();
    } catch (e) {
      state = JoinPublicGatheringState.error(e.toString());
    }
  }

  void reset() {
    state = JoinPublicGatheringState.initial();
  }
}

final joinPublicGatheringProvider = StateNotifierProvider<JoinPublicGatheringNotifier, JoinPublicGatheringState>(
  (ref) => JoinPublicGatheringNotifier(),
);

