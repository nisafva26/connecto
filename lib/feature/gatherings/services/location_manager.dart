import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final locationManagerProvider =
    Provider<LocationManager>((ref) => LocationManager(ref));

class LocationManager {
  final Ref ref;
  Timer? _timer;

  LocationManager(this.ref);

  StreamSubscription<Position>? _positionSubscription;


  void start(String gatheringId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final gatheringDoc =
        FirebaseFirestore.instance.collection('gatherings').doc(gatheringId);

    bool _hasStartedTracking = false;

    gatheringDoc.snapshots().listen((doc) async {
      final data = doc.data();
      if (data == null) return;

      final inviteeMap = data['invitees'] as Map<String, dynamic>;
      final sharing = inviteeMap[uid]?['sharing'] ?? true;

      log("🔁 Inside LocationManager - Sharing: $sharing");

      final lat = data['location']['lat'];
      final lng = data['location']['lng'];

      if (!sharing) {
        stop(); // Turned off by user
        log("⛔ Sharing disabled by user");
        _hasStartedTracking = false;
        return;
      }

      // Get event start time
      final timestamp = data['dateTime'] as Timestamp?;
      if (timestamp == null) {
        log("⚠️ No dateTime found in gathering");
        return;
      }

      final eventTime = timestamp.toDate();
      final now = DateTime.now();
      final diff = eventTime.difference(now);

      log('🕐 Time until event: $diff');

      // Start tracking if within 1 hour
      if (!_hasStartedTracking && diff <= Duration(hours: 1)) {
        _hasStartedTracking = true;
        log('✅ Tracking started');
        _startLiveTracking(gatheringId, uid, eventTime, lat, lng);
      }
    });
  }

  Future<bool> _checkPermissions() async {
    // Check if location service is enabled

    LocationPermission permission;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      log("⚠️ Location services are disabled. Opening location settings...");
      await Geolocator.openLocationSettings(); // Prompt to enable
    }

    permission = await Geolocator.checkPermission();
    log("🔐 Current permission status: $permission");

    if (permission == LocationPermission.denied) {
      log("❗ Permission denied. Requesting permission...");
      permission = await Geolocator.requestPermission();
      log("📥 New permission status after request: $permission");
      if (permission == LocationPermission.denied) {
        log("🚫 Permission still denied. Opening app settings...");
        await Geolocator
            .openAppSettings(); // Suggest user to go to app settings
      }
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      log("🚫 Permission permanently denied. Opening app settings...");
      await Geolocator.openAppSettings();
      return false;
    }

    // iOS typically returns whileInUse even if always permission is needed
    if (permission == LocationPermission.whileInUse) {
      log("⚠️ Permission granted as 'whileInUse'. Background tracking may not work on iOS.");
      // optional: show a dialog explaining background location importance
      return true;
    }

    log("✅ All permissions granted (Always). Proceeding...");

    return true;
  }

  void _startLiveTracking(
    String gatheringId,
    String userId,
    DateTime eventTime,
    double eventLat,
    double eventLng,
  ) async {
    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      log('[LocationManager] Location permission denied.');
      return;
    }

    _positionSubscription?.cancel(); // Cancel existing subscription

    _positionSubscription = Geolocator.getPositionStream(
            // locationSettings: const LocationSettings(
            //   accuracy: LocationAccuracy.high,
            //   distanceFilter: 20, // Minimum distance in meters to trigger update
            // ),
            locationSettings: Platform.isAndroid
                ? AndroidSettings()
                : AppleSettings(distanceFilter: 100))
        .listen((position) async {
      final now = DateTime.now();
      // Stop after event + 30 min
      if (now.isAfter(eventTime.add(Duration(minutes: 30)))) {
        log("🛑 Event ended 30 mins ago. Stopping tracking.");
        stop();
        return;
      }

      // Stop if user is within 100 meters of venue
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        eventLat,
        eventLng,
      );

      if (distance < 300) {
          log("✅ User has reached venue. Stopping tracking.");
      final gatheringDoc =
          FirebaseFirestore.instance.collection('gatherings').doc(gatheringId);

      // Update the user's invitee status to 'arrived' with a timestamp
      await gatheringDoc.update({
        'invitees.$userId.arrivalStatus': 'arrived',
        'invitees.$userId.arrivalTimestamp': Timestamp.now(),
      });
        stop();
        return;
      }
      log('[LocationManager] Sending live position: ${position.latitude}, ${position.longitude}');
      final activeRef = FirebaseFirestore.instance
          .collection('activeGatherings')
          .doc(gatheringId)
          .collection('participants')
          .doc(userId);

      await activeRef.set({
        'lat': position.latitude,
        'lng': position.longitude,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));
    });
  }

  void stop() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  
}
