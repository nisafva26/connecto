// import 'dart:async';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:geolocator/geolocator.dart';

// final locationSharingProvider = StateProvider.autoDispose<bool>((ref) => true);

// Future<void> updateLiveLocation(
//     String gatheringId, String userId, double lat, double lng) async {
//   await FirebaseFirestore.instance
//       .collection('gatherings')
//       .doc(gatheringId)
//       .collection('liveLocations')
//       .doc(userId)
//       .set({
//     'lat': lat,
//     'lng': lng,
//     'updatedAt': FieldValue.serverTimestamp(),
//     'sharing': true
//   }, SetOptions(merge: true));
// }

// class LocationTrackingService {
//   Timer? _timer;

//   void startTracking({
//     required String gatheringId,
//     required DateTime eventDateTime,
//     required String userId,
//     required WidgetRef ref,
//   }) async {
//     bool sharing = ref.read(locationSharingProvider);
//     if (!sharing) return;

//     final oneHourBefore = eventDateTime.subtract(Duration(hours: 1));
//     if (DateTime.now().isBefore(oneHourBefore)) return;

//     _timer?.cancel(); // clear any old timer
//     _timer = Timer.periodic(Duration(seconds: 15), (timer) async {
//       Position position = await Geolocator.getCurrentPosition();

//       final sharing = ref.read(locationSharingProvider);
//       if (!sharing) {
//         timer.cancel();
//         return;
//       }

//       await updateLiveLocation(
//           gatheringId, userId, position.latitude, position.longitude);
//     });
//   }

//   void stopTracking() {
//     _timer?.cancel();
//   }
// }
