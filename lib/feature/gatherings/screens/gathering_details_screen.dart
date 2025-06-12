import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/common_widgets/continue_button.dart';
import 'package:connecto/feature/circles/controller/circle_notifier.dart';
import 'package:connecto/feature/circles/models/circle_model.dart';
import 'package:connecto/feature/circles/models/circle_state.dart';
import 'package:connecto/feature/dashboard/screens/bonds_screen.dart';
import 'package:connecto/feature/gatherings/models/gathering_model.dart';
import 'package:connecto/feature/gatherings/providers/public_gathering_provider.dart';
import 'package:connecto/feature/gatherings/screens/select_location_screen.dart';
import 'package:connecto/feature/gatherings/services/location_manager.dart';
import 'package:connecto/feature/gatherings/services/mapbox_eta.dart';
import 'package:connecto/feature/gatherings/widgets/custom_marker.dart';
import 'package:connecto/feature/gatherings/widgets/gathering_invitee_bottom_modal.dart';
import 'package:connecto/feature/gatherings/widgets/gathering_invitee_list_widget.dart';
import 'package:connecto/feature/gatherings/widgets/travel_status.dart';
import 'package:connecto/helper/get_initials.dart';
import 'package:connecto/helper/open_maps.dart';
import 'package:connecto/helper/toast_alert.dart';
import 'package:connecto/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as map;

// final singleGatheringProvider =
//     FutureProvider.family<GatheringModel, String>((ref, gatheringId) async {
//   final doc = await FirebaseFirestore.instance
//       .collection('gatherings')
//       .doc(gatheringId)
//       .get();

//   return GatheringModel.fromDoc(doc);
// });

final singleGatheringProvider =
    StreamProvider.family<GatheringModel, String>((ref, gatheringId) {
  return FirebaseFirestore.instance
      .collection('gatherings')
      .doc(gatheringId)
      .snapshots()
      .map((doc) => GatheringModel.fromDoc(doc));
});

class GatheringDetailsScreen extends ConsumerStatefulWidget {
  final String gatheringId;
  const GatheringDetailsScreen({super.key, required this.gatheringId});

  @override
  ConsumerState<GatheringDetailsScreen> createState() =>
      _GatheringDetailsScreenState();
}

class _GatheringDetailsScreenState
    extends ConsumerState<GatheringDetailsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // await checkPermissions();
      ref.read(locationManagerProvider).start(widget.gatheringId);
    });
  }

  map.PointAnnotationManager? annotationManager;

  Future<bool> checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();

    log('checking permission : $permission');

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      log('inside cgeck permission denaied , calling again : $permission');
      permission = await Geolocator.requestPermission();
    }

    // ⛔ If still not granted or background not allowed
    if (permission == LocationPermission.whileInUse) {
      // On Android 10+, this means background location will fail
      // Show a dialog or alert suggesting user to manually allow background access
      return false;
    }

    return permission == LocationPermission.always;
  }

  Future<void> handlePostEventETA(GatheringModel gathering) async {
    log('==inside post event eta=====');
    final activeRef = FirebaseFirestore.instance
        .collection('activeGatherings')
        .doc(gathering.id)
        .collection('participants');

    final snapshot = await activeRef.get();

    final newEtas = <String, int>{};
    final travelStatusLocal = <String, TravelStatus?>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final userId = doc.id;
      final lat = data['lat'];
      final lng = data['lng'];

      if (lat != null && lng != null) {
        final eta = await calculateMapboxETA(
          userLat: lat,
          userLng: lng,
          eventLat: gathering.location.lat,
          eventLng: gathering.location.lng,
        );

        final distance = Geolocator.distanceBetween(
          lat,
          lng,
          gathering.location.lat,
          gathering.location.lng,
        );

        travelStatusLocal[userId] = getInviteeStatus(
          distanceInMeters: distance,
          etaInMinutes: eta,
          eventTime: gathering.dateTime,
        );

        newEtas[userId] = eta;

        // ✅ Only for current user: update arrivalStatus if needed
        if (userId == FirebaseAuth.instance.currentUser?.uid) {
          final participantRef = FirebaseFirestore.instance
              .collection('activeGatherings')
              .doc(gathering.id)
              .collection('participants')
              .doc(userId);

          final existing = await participantRef.get();
          final alreadyUpdated = existing.data()?['arrivalStatus'] != null;

          if (!alreadyUpdated &&
              distance < 100 &&
              DateTime.now()
                  .isBefore(gathering.dateTime.add(Duration(minutes: 10)))) {
            await participantRef.update({'arrivalStatus': 'on_time'});
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        inviteeETAs = newEtas;
        travelStatuses = travelStatusLocal;
      });
    }
  }

  Future<void> _handlePostEventLocation(GatheringModel gathering) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final now = DateTime.now();
    final eventTime = gathering.dateTime;

    if (now.isBefore(eventTime.add(Duration(minutes: 30)))) {
      return; // Still within tracking time or too early
    }

    final doc = await FirebaseFirestore.instance
        .collection('activeGatherings')
        .doc(gathering.id)
        .collection('participants')
        .doc(uid)
        .get();

    final data = doc.data();
    if (data == null) return;

    final lastUpdated = (data['lastUpdated'] as Timestamp?)?.toDate();
    final lat = data['lat'] as double?;
    final lng = data['lng'] as double?;

    final isOld =
        lastUpdated == null || now.difference(lastUpdated).inMinutes > 10;

    final isTooFar = lat == null ||
        lng == null ||
        Geolocator.distanceBetween(
              lat,
              lng,
              gathering.location.lat,
              gathering.location.lng,
            ) >
            200; // more than 200m away

    if (isOld || isTooFar) {
      final current = await Geolocator.getCurrentPosition();

      await FirebaseFirestore.instance
          .collection('activeGatherings')
          .doc(gathering.id)
          .collection('participants')
          .doc(uid)
          .set({
        'lat': current.latitude,
        'lng': current.longitude,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));

      log('📍 Post-event location updated manually on reopen');
    }
  }

  bool isSharing = true;
  bool didStartTracking = false;

  map.PointAnnotationManager? participantAnnotationManager;
  bool mapReady = false;
  StreamSubscription? participantSub;
  Timer? etaTimer;
  Map<String, int> inviteeETAs = {};
  Map<String, TravelStatus?> travelStatuses = {};
  bool _hasPostEventEtaRun = false;

  @override
  void dispose() {
    mapReady = false;
    etaTimer?.cancel();
    etaTimer = null;
    participantAnnotationManager?.deleteAll();
    participantAnnotationManager = null;
    participantSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log('gatherin g id : ${widget.gatheringId}');
    Future<void> handlePing(
      BuildContext context,
      WidgetRef ref,
      GatheringModel gathering,
    ) async {
      final circleId = 'gathering_circle_${gathering.id}';
      final firestore = FirebaseFirestore.instance;

      log('🔍 Checking if circle $circleId already exists...');

      // 1. Check if a circle already exists
      final existingCircleDoc =
          await firestore.collection('circles').doc(circleId).get();

      if (existingCircleDoc.exists) {
        log('✅ Circle already exists. Navigating to group chat.');
        final circle = await CircleModel.fromFirestore(existingCircleDoc);
        context.push('/bond/group-chat/$circleId', extra: circle);
        return;
      }

      final List<String> circleColors = [
        '#FF5A5A',
        '#7748E7',
        '#4EA46B',
        '#475AE7',
        '#FFC453',
        '#AD45E7',
      ];
      final randomColor =
          circleColors[math.Random().nextInt(circleColors.length)];

      log('🆕 Circle does not exist. Preparing member list...');

      // 2. Prepare member list from invitees
      final members = [
        ...gathering.invitees.values.map((e) => {
              'fullName': e.name,
              'phoneNumber': e.phoneNumber,
            }),
        ...gathering.nonRegisteredInvitees.values.map((e) => {
              'fullName': e.name,
              'phoneNumber': e.phone,
            }),
      ];

      log('👥 Members for new circle: ${members.map((e) => e['fullName']).join(', ')}');

      // 3. Trigger circle creation
      log('🚀 Creating new circle: $circleId...');
      await ref.read(circleNotifierProvider.notifier).addCircle(
            circleName: gathering.name,
            circleColor: randomColor,
            members: members,
            circleId: circleId,
          );

      // 4. Fetch the newly created circle
      final newCircleDoc =
          await firestore.collection('circles').doc(circleId).get();

      if (newCircleDoc.exists) {
        final circle = await CircleModel.fromFirestore(newCircleDoc);
        log('✅ Circle created successfully. Navigating to group chat.');
        context.push('/bond/group-chat/$circleId', extra: circle);
      } else {
        log('❌ Failed to fetch the newly created circle. Something went wrong.');
      }
    }

    void setupParticipantListener() async {
      if (!mapReady || participantAnnotationManager == null || !mounted) {
        log('=======reutrning==== not mounted=====');
      }

      final ByteData userIcon =
          await rootBundle.load('assets/images/location_marker.png');
      userIcon.buffer.asUint8List();

      final participantCollection = FirebaseFirestore.instance
          .collection('activeGatherings')
          .doc(widget.gatheringId)
          .collection('participants');

      await participantSub?.cancel();

      participantSub =
          participantCollection.snapshots().listen((snapshot) async {
        if (!mapReady || !mounted) return;

        try {
          await participantAnnotationManager!.deleteAll();

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final userLat = data['lat'];
            final userLng = data['lng'];
            final userId = doc.id;

            // Fetch full name of participant from Firestore
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();

            final fullName = userDoc.data()?['fullName'] ?? 'NA';
            final initials = getInitials(fullName);

            final Uint8List customMarker =
                await createMarkerFromInitials(initials);

            log('📍 User Marker from Firestore -> lat: $userLat, lng: $userLng');

            await participantAnnotationManager!.create(
              map.PointAnnotationOptions(
                geometry: map.Point(
                  coordinates: map.Position(userLng, userLat),
                ),
                image: customMarker,
                // iconSize: 1.3,
                // textField: 'ETA',
                // textSize: 12,
                // textColor: 0xffffff,
              ),
            );
          }
        } catch (e, st) {
          log("❌ Error creating user markers: $e", stackTrace: st);
        }
      });
    }

    final gatheringAsync =
        ref.watch(singleGatheringProvider(widget.gatheringId));
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    final userAsync = ref.watch(currentUserProvider);

    Future<void> toggleLocationSharing({
      required String gatheringId,
      required String userId,
      required bool enable,
    }) async {
      final ref =
          FirebaseFirestore.instance.collection('gatherings').doc(gatheringId);

      await ref.update({
        'invitees.$userId.sharing': enable,
      });
    }

    return gatheringAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
        data: (gathering) {
          final now = DateTime.now();
          final eventCutoffTime = gathering.dateTime.add(Duration(minutes: 30));
          final difference = gathering.dateTime.difference(now);
          final isUpcoming = difference.inSeconds > 0;
          final absMinutes = difference.inMinutes.abs();
          final end = gathering.dateTime.add(Duration(minutes: 60));
          final isEnded = now.isAfter(end);

          final canEdit = difference.inMinutes > 180; // ✅ 3 hours = 180 minutes

          // ❌ Don't fetch location or run timers after cutoff
          if (now.isAfter(eventCutoffTime) && !_hasPostEventEtaRun) {
            debugPrint("📵 Running one-time ETA update...");
            //setting for one time run
            _hasPostEventEtaRun = true;
            handlePostEventETA(gathering);
          } else if (_hasPostEventEtaRun == false) {
            // ✅ Call this right after gathering is available

            _handlePostEventLocation(gathering);
            // eta timer

            etaTimer ??= Timer.periodic(Duration(seconds: 5), (_) async {
              if (!mounted) return;

              final activeRef = FirebaseFirestore.instance
                  .collection('activeGatherings')
                  .doc(gathering.id)
                  .collection('participants');

              final snapshot = await activeRef.get();

              final newEtas = <String, int>{};
              final travelStatuslocal = <String, TravelStatus?>{};

              for (final doc in snapshot.docs) {
                final data = doc.data();
                final userId = doc.id;
                final lat = data['lat'];
                final lng = data['lng'];

                final eta = await calculateMapboxETA(
                  userLat: lat,
                  userLng: lng,
                  eventLat: gathering.location.lat,
                  eventLng: gathering.location.lng,
                );

                if (lat != null) {
                  final distance = Geolocator.distanceBetween(
                    lat,
                    lng,
                    gathering.location.lat,
                    gathering.location.lng,
                  );

                  travelStatuslocal[userId] = getInviteeStatus(
                    distanceInMeters: distance,
                    etaInMinutes: eta,
                    eventTime: gathering.dateTime,
                  );
                }

                final distance = Geolocator.distanceBetween(
                  lat,
                  lng,
                  gathering.location.lat,
                  gathering.location.lng,
                );

                newEtas[userId] = eta;

                //updating the arrival status for the current user
                // ✅ Only for current user: update arrivalStatus if needed
                if (userId == FirebaseAuth.instance.currentUser?.uid) {
                  final participantRef = FirebaseFirestore.instance
                      .collection('activeGatherings')
                      .doc(gathering.id)
                      .collection('participants')
                      .doc(userId);

                  final existing = await participantRef.get();
                  final alreadyUpdated =
                      existing.data()?['arrivalStatus'] != null;

                  if (!alreadyUpdated &&
                      distance < 100 &&
                      DateTime.now().isBefore(
                          gathering.dateTime.add(Duration(minutes: 10)))) {
                    await participantRef.update({'arrivalStatus': 'on_time'});
                  }
                }
              }

              setState(() {
                inviteeETAs = newEtas;
                travelStatuses = travelStatuslocal;
              });
            });
          }

          final uid = FirebaseAuth.instance.currentUser!.uid;
          final isHost = uid == gathering.hostId;
          // final myStatus = gathering.invitees[uid]?.status ?? 'pending';
          final invitee = gathering.invitees[uid];
          final publicUser = gathering.joinedPublicUsers[uid];

          String myStatus;

          if (invitee != null) {
            myStatus = invitee.status;
          } else if (publicUser != null) {
            myStatus = publicUser.status;
          } else {
            myStatus = 'none'; // not invited, not joined publicly
          }

          // log('my status : $myStatus');

          isSharing = gathering.invitees[uid]?.sharing ?? true;

          final inviteeEntries = gathering.invitees.entries.toList();
          final nonRegisteredEntries =
              gathering.nonRegisteredInvitees.entries.toList();

          final publicPeopleEntries =
              gathering.joinedPublicUsers.entries.toList();

          final pendingRequests = gathering.joinedPublicUsers.entries
              .where((entry) => entry.value.status == 'pending')
              .toList();

          // log('isPublic ? ${gathering.isPublic}');
          return Scaffold(
            backgroundColor: Color(0xff001311),
            appBar: buildGatheringDetailsAppBAr(gatheringAsync, context,
                isUpcoming, difference, canEdit, isHost, isEnded),
            body:
                // log('my status : ${gathering.invitees[uid]?.status}');
                // log('current uid : $uid : host id : ${gathering.hostId}');

                Container(
              height: MediaQuery.of(context).size.height,
              child: Stack(
                children: [
                  Container(
                    height: 300,
                    // color: Colors.yellow,
                    width: MediaQuery.of(context).size.width,
                    child: map.MapWidget(
                        key: ValueKey("map-${gathering.id}"),
                        // styleUri: map.MapboxStyles.LIGHT,
                        cameraOptions: map.CameraOptions(
                          center: map.Point(
                            coordinates: map.Position(
                              gathering.location.lng,
                              gathering.location.lat,
                            ),
                          ),
                          zoom: 10,
                        ),
                        onMapCreated: (mapController) async {
                          final ByteData bytes = await rootBundle
                              .load('assets/images/map_icon.png');
                          final Uint8List imageData =
                              bytes.buffer.asUint8List();

                          // Event Marker
                          final eventAnnotationManager = await mapController
                              .annotations
                              .createPointAnnotationManager();

                          await eventAnnotationManager.create(
                            map.PointAnnotationOptions(
                              geometry: map.Point(
                                coordinates: map.Position(
                                  gathering.location.lng,
                                  gathering.location.lat,
                                ),
                              ),
                              image: imageData,
                              iconSize: 1.5,
                            ),
                          );

                          participantAnnotationManager = await mapController
                              .annotations
                              .createPointAnnotationManager();

                          mapReady = true;

                          setupParticipantListener();
                        }),
                  ),
                  DraggableScrollableSheet(
                      initialChildSize: 0.7,
                      minChildSize: 0.7,
                      snap: true,
                      expand: true,
                      maxChildSize: 0.85,
                      builder: (context, scrollController) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Color(0xff001311),
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12)
                          // .copyWith(top: 50),
                          ,
                          child: Column(
                            children: [
                              Expanded(
                                child: ListView(
                                  controller: scrollController,
                                  // padding: EdgeInsets.all(20),
                                  // physics: NeverScrollableScrollPhysics(),
                                  children: [
                                    // SizedBox(height: 50),

                                    Center(
                                      child: Opacity(
                                        opacity: 0.30,
                                        child: Container(
                                          width: 79,
                                          height: 5,
                                          decoration: ShapeDecoration(
                                            color: const Color(0xFFE7E7E7),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(2.50),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 30,
                                    ),

                                    // Text(
                                    //   "Description",
                                    //   style: TextStyle(
                                    //     color: Colors.white,
                                    //     fontSize: 16,
                                    //     fontFamily: 'Inter',
                                    //     fontWeight: FontWeight.w500,
                                    //   ),
                                    // ),
                                    // SizedBox(height: 11),
                                    Text(
                                      gathering.name,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(
                                      height: 24,
                                    ),

                                    if (isHost &&
                                        pendingRequests.isNotEmpty) ...[
                                      Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8)
                                                .copyWith(bottom: 0),
                                        child: Text(
                                          "Public Join Requests",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 8,
                                      ),
                                      ...pendingRequests.map((entry) {
                                        final userId = entry.key;
                                        final user = entry.value;

                                        return Card(
                                          color: const Color(0xFF0F2A29),
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 6),
                                          child: Column(
                                            children: [
                                              ListTile(
                                                title: Text(user.name,
                                                    style: const TextStyle(
                                                        color: Colors.white)),
                                                subtitle: Text(user.phoneNumber,
                                                    style: const TextStyle(
                                                        color: Colors.grey)),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 16)
                                                        .copyWith(top: 0),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        onPressed: () async {
                                                          await FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                  'gatherings')
                                                              .doc(gathering.id)
                                                              .update({
                                                            'joinedPublicUsers.$userId.status':
                                                                'accepted',
                                                            'publicJoinCount':
                                                                FieldValue
                                                                    .increment(
                                                                        1),
                                                          });

                                                          if (context.mounted) {
                                                            Fluttertoast.showToast(
                                                                toastLength: Toast
                                                                    .LENGTH_LONG,
                                                                msg:
                                                                    "User request approved!",
                                                                textColor:
                                                                    Colors
                                                                        .black,
                                                                backgroundColor: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .primary);
                                                          }
                                                        },
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              const Color(
                                                                  0xFF03FFE2),
                                                          foregroundColor:
                                                              Colors.black,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      14,
                                                                  vertical: 8),
                                                          textStyle:
                                                              const TextStyle(
                                                                  fontSize: 14),
                                                        ),
                                                        child: const Text(
                                                            'Approve'),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        onPressed: () async {
                                                          await FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                  'gatherings')
                                                              .doc(gathering.id)
                                                              .update({
                                                            'joinedPublicUsers.$userId.status':
                                                                'rejected',
                                                          });

                                                          if (context.mounted) {
                                                            Fluttertoast.showToast(
                                                                toastLength: Toast
                                                                    .LENGTH_LONG,
                                                                msg:
                                                                    "User request rejected !",
                                                                textColor:
                                                                    Colors
                                                                        .black,
                                                                backgroundColor: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .primary);
                                                          }
                                                        },
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Colors.redAccent,
                                                          foregroundColor:
                                                              Colors.white,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      14,
                                                                  vertical: 8),
                                                          textStyle:
                                                              const TextStyle(
                                                                  fontSize: 14),
                                                        ),
                                                        child: const Text(
                                                            'Reject'),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                      SizedBox(height: 24),
                                    ],
                                    Text(
                                      'When?',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    buildTimeContainer(gathering),
                                    SizedBox(height: 24),
                                    Text("Location",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500)),
                                    SizedBox(height: 6),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 16, horizontal: 20),
                                      decoration: BoxDecoration(
                                        color: Color(0xff091F1E),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: CachedNetworkImage(
                                              height: 160,
                                              fit: BoxFit.cover,
                                              width: MediaQuery.sizeOf(context)
                                                  .width,
                                              imageUrl:
                                                  'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${gathering.photoRef}&key=$googleApiKey',
                                              placeholder: (context, url) => Center(
                                                  child:
                                                      CircularProgressIndicator()),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Icon(Icons.error),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 24,
                                          ),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Icon(
                                                Icons.location_on_outlined,
                                                color: Colors.grey,
                                                size: 25,
                                              ),
                                              SizedBox(width: 6),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      gathering.location.name,
                                                      maxLines: 2,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 18,
                                                        fontFamily: 'Inter',
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: 6,
                                                    ),
                                                    Text(
                                                      gathering
                                                          .location.address,
                                                      maxLines: 3,
                                                      style: TextStyle(
                                                        color: const Color(
                                                            0xFFC4C4C4),
                                                        fontSize: 13,
                                                        fontFamily: 'Inter',
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        letterSpacing: -0.32,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            height: 24,
                                          ),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    // Handle Details press
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: Color(
                                                        0xFF001311), // dark background
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 14),
                                                  ),
                                                  child: Text(
                                                    'Details',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontFamily: 'Inter',
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      height: 1.43,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    // Handle Directions press

                                                    openMapsDirections(
                                                        gathering.location.lat,
                                                        gathering.location.lng);
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.white,
                                                    foregroundColor:
                                                        Colors.black,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 14),
                                                  ),
                                                  child: Text(
                                                    'Directions',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontFamily: 'Inter',
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      height: 1.43,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    if (myStatus == 'accepted') ...[
                                      SizedBox(height: 24),
                                      Container(
                                        decoration: ShapeDecoration(
                                          color: const Color(0xFF091F1E),
                                          shape: RoundedRectangleBorder(
                                            side: BorderSide(
                                              width: 1,
                                              color: const Color(0xFF082523),
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: SwitchListTile(
                                          contentPadding: EdgeInsets.only(left: 16,right: 16,top: 8,bottom: 8),
                                          value: isSharing,
                                          onChanged: (value) {
                                            setState(() => isSharing = value);
                                            toggleLocationSharing(
                                              gatheringId: widget.gatheringId,
                                              userId: FirebaseAuth
                                                  .instance.currentUser!.uid,
                                              enable: value,
                                            );
                                          },
                                          title: Text("Share Live Location",
                                              style: TextStyle(
                                                  color: Colors.white)),
                                          activeColor: Colors.greenAccent,
                                        ),
                                      ),
                                    ],

                                    SizedBox(height: 24),
                                    Text(
                                      "Invited (${gathering.invitees.length - 1})",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    SizedBox(height: 24),
                                    GatheringInviteeLsitWidget(
                                      inviteeEntries: inviteeEntries,
                                      inviteeETAs: inviteeETAs,
                                      travelStatuses: travelStatuses,
                                      currentUserId: currentUserId,
                                      gathering: gathering,
                                    ),
                                    if (nonRegisteredEntries.isNotEmpty) ...[
                                      SizedBox(
                                        height: 24,
                                      ),
                                      Text(
                                        "Other contacts - not registered in app (${gathering.nonRegisteredInvitees.length})",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      SizedBox(height: 24),
                                      ListView.separated(
                                        separatorBuilder: (context, index) =>
                                            Divider(
                                          color: Color(0xff2b3c3a),
                                          thickness: 0.5,
                                          height: 20,
                                        ),
                                        shrinkWrap: true,
                                        itemCount: nonRegisteredEntries.length,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemBuilder: (context, index) {
                                          return Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: Colors.white,
                                                child: Text(
                                                  getInitials(
                                                      nonRegisteredEntries[
                                                              index]
                                                          .value
                                                          .name),
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                nonRegisteredEntries[index]
                                                    .value
                                                    .name,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      )
                                    ],

                                    if (publicPeopleEntries.isNotEmpty) ...[
                                      SizedBox(
                                        height: 24,
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            "Public invitees (${gathering.joinedPublicUsers.length})   ",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          Spacer(),
                                          Text(
                                            "${gathering.publicJoinCount}/${gathering.maxPublicParticipants} spots left",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 24),
                                      ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: publicPeopleEntries.length,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemBuilder: (context, index) {
                                          return Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: Colors.white,
                                                child: Text(
                                                  getInitials(
                                                      publicPeopleEntries[index]
                                                          .value
                                                          .name),
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    publicPeopleEntries[index]
                                                        .value
                                                        .name,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontFamily: 'Inter',
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  Text(
                                                    publicPeopleEntries[index]
                                                                .value
                                                                .status ==
                                                            'pending'
                                                        ? 'Host approval pending'
                                                        : publicPeopleEntries[
                                                                index]
                                                            .value
                                                            .status,
                                                    style: TextStyle(
                                                      color: const Color(
                                                          0xFF58616A),
                                                      fontSize: 14,
                                                      fontFamily: 'Inter',
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ],
                                          );
                                        },
                                      )
                                    ],

                                    SizedBox(
                                      height: 53,
                                    ),

                                    // RSVP Buttons (Only if not host and status is pending)
                                    (!isHost &&
                                            (myStatus == 'pending' ||
                                                myStatus == 'none'))
                                        ? SizedBox()
                                        : ContinueButton(
                                            onPressed: () {
                                              handlePing(
                                                  context, ref, gathering);
                                            },
                                            text: 'Send ping',
                                          ),
                                    SizedBox(
                                      height: 200,
                                    ),

                                    // Container(height: 800,color: Colors.blue,)
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                ],
              ),
            ),
            bottomNavigationBar: Builder(
              builder: (context) {
                if (!isHost &&
                    myStatus == 'pending' &&
                    gathering.isPublic == false) {
                  // 🛎️ Case 1: Invited user (pending)
                  return Container(
                    decoration: BoxDecoration(
                        color: Color(0xFF091F1E),
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16).copyWith(bottom: 30),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _handleRSVP('rejected', context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFFE3415E),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Reject"),
                                  SizedBox(width: 8),
                                  Icon(Icons.close, color: Colors.black),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _handleRSVP('accepted', context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF03FFE2),
                                foregroundColor: Colors.black,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Accept"),
                                  SizedBox(width: 8),
                                  Icon(Icons.check, color: Colors.black),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (!isHost &&
                    myStatus == 'none' &&
                    gathering.isPublic &&
                    (gathering.publicJoinCount) <
                        (gathering.maxPublicParticipants)) {
                  final joinState = ref.watch(joinPublicGatheringProvider);
                  log('join gathering state : $joinState');

                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                      color: Color(0xFF091F1E),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16)),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: joinState.isLoading
                            ? null
                            : () async {
                                await ref
                                    .read(joinPublicGatheringProvider.notifier)
                                    .joinPublicGathering(
                                      gatheringId: gathering.id,
                                      userId: FirebaseAuth
                                          .instance.currentUser!.uid,
                                      userFullName: userAsync.value!.fullName,
                                      userPhoneNumber: FirebaseAuth
                                          .instance.currentUser!.phoneNumber!,
                                    );
                                // After join, maybe refresh or show snackbar

                                // 🎯 After successful join, show success snackbar
                                if (context.mounted &&
                                    joinState ==
                                        JoinPublicGatheringState.success()) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '🎉 You have joined the gathering!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF03FFE2),
                          foregroundColor: Colors.black,
                          disabledBackgroundColor:
                              Colors.grey, // optional for disabled state
                        ),
                        child: joinState.isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text("Join Gathering →"),
                      ),
                    ),
                  );
                } else if (!isHost &&
                    myStatus == 'none' &&
                    gathering.isPublic &&
                    (gathering.publicJoinCount) >=
                        (gathering.maxPublicParticipants)) {
                  final joinState = ref.watch(joinPublicGatheringProvider);
                  log('No spots available');

                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20)
                        .copyWith(bottom: 30),
                    decoration: BoxDecoration(
                      color: Color(0xFF091F1E),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16)),
                    ),
                    child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor:
                                Colors.grey, // optional for disabled state
                          ),
                          child: Text("No more public slots available",
                              style: TextStyle(color: Colors.white)),
                        )),
                  );
                } else if (!isHost &&
                    myStatus == 'pending' &&
                    gathering.isPublic) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 20)
                            .copyWith(bottom: 30),
                    decoration: const BoxDecoration(
                      color: Color(0xFF091F1E),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: null, // Disabled
                        icon: const Icon(Icons.hourglass_top_rounded,
                            color: Colors.black),
                        label: const Text(
                          "Request Sent. Awaiting Approval",
                          style: TextStyle(color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          disabledBackgroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  );
                } else {
                  // 🔔 Case 3: Host or already accepted/joined → No bottom bar
                  return SizedBox.shrink();
                }
              },
            ),
          );
        });
  }

  Container buildTimeContainer(GatheringModel gathering) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: ShapeDecoration(
        color: const Color(0xFF091F1E),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 1,
            color: const Color(0xFF082523),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 6,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Opacity(
                  opacity: 0.60,
                  child: Container(
                    width: 22,
                    height: 22,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(),
                    child: Icon(
                      Icons.access_time,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(gathering.dateTime),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Opacity(
                      opacity: 0.60,
                      child: Text(
                        DateFormat('h:mm a').format(gathering.dateTime),
                        style: TextStyle(
                          color: const Color(0xFFC4C4C4),
                          fontSize: 13,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.32,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSize buildGatheringDetailsAppBAr(
      AsyncValue<GatheringModel> gatheringAsync,
      BuildContext context,
      bool isUpcoming,
      Duration difference,
      bool canEdit,
      bool isHost,
      bool isEnded) {
    return PreferredSize(
      preferredSize: Size.fromHeight(96),
      child: gatheringAsync.when(data: (gathering) {
        log('gathering state : ${gathering.status}');
        return SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                  onPressed: () {
                    context.pop();
                  },
                  icon: Icon(Icons.arrow_back)),
              // Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    gathering.eventType,
                    style: TextStyle(
                      color: const Color(0xFFE6E7E9),
                      fontSize: 18,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      height: 1.33,
                    ),
                  ),
                  // SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.white,
                        size: 15,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "${DateFormat('h:mm a').format(gathering.dateTime)} - ${DateFormat('dd MMM yyyy').format(gathering.dateTime)}",
                        style: TextStyle(
                          color: Color(0xff9da5a5),
                          fontSize: 14,
                          fontFamily: 'SFPRO',
                          fontWeight: FontWeight.w400,
                          height: 1.57,
                        ),
                      )
                    ],
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Row(
                    children: [
                      if (isUpcoming)
                        Text(
                          'Starts in ${formatDuration(difference)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        )
                      else
                        Text(
                          'Started ${formatDuration(difference)} ago',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      SizedBox(width: 8),
                      if (gathering.status == 'confirmed')
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(0xFF03FFE2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Confirmed',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      if (gathering.status == 'ended')
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Event completed',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () async {
                  if (canEdit && isHost) {
                    context.go(
                      '/gathering/edit',
                      extra: gathering, // 🔁 Pass your full model here
                    );
                  }
                },
                icon: Icon(
                  Icons.edit,
                  color: canEdit && isHost ? Colors.white : Colors.transparent,
                ),
              ),
            ],
          ),
        );
      }, error: (err, _) {
        return SizedBox();
      }, loading: () {
        return SizedBox();
      }),
    );
  }

  void _handleRSVP(String status, BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final timestamp = Timestamp.now();

    final gatheringRef = FirebaseFirestore.instance
        .collection('gatherings')
        .doc(widget.gatheringId);

    final inviteeSubRef = gatheringRef.collection('invitees').doc(uid);

    await gatheringRef.update({
      "invitees.$uid.status": status,
      "invitees.$uid.respondedAt": Timestamp.now(),
    });

    // 🔹 Update subcollection
    await inviteeSubRef.set({
      "status": status,
      "respondedAt": timestamp,
    }, SetOptions(merge: true));

    // showTopAlert(context, "You have accepted the invite");
    // Show success
    TopAlertOverlay.show(context, "You have accepted the invite");

    // You can also trigger chatFlag update or show snackbar here

    // Optional: Close screen after RSVP
    // Navigator.pop(context);
  }
}

String formatDuration(Duration diff) {
  final totalMinutes = diff.inMinutes.abs();
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  } else {
    return '${minutes}m';
  }
}



  // TextButton(
                                          //   onPressed: () async {
                                          //     openMapsDirections(
                                          //         gathering.location.lat,
                                          //         gathering.location.lng);
                                          //   },
                                          //   child: Text("Directions →",
                                          //       style: TextStyle(
                                          //         color:
                                          //             const Color(0xFF03FFE2),
                                          //         fontSize: 14,
                                          //         fontFamily: 'Inter',
                                          //         fontWeight: FontWeight.w600,
                                          //         height: 1.43,
                                          //       )),
                                          // )
