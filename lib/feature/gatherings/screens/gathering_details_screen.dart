import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/common_widgets/continue_button.dart';
import 'package:connecto/feature/gatherings/models/gathering_model.dart';
import 'package:connecto/feature/gatherings/services/location_manager.dart';
import 'package:connecto/feature/gatherings/services/mapbox_eta.dart';
import 'package:connecto/feature/gatherings/widgets/custom_marker.dart';
import 'package:connecto/helper/eta.dart';
import 'package:connecto/helper/get_initials.dart';
import 'package:connecto/helper/toast_alert.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
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

  map.PointAnnotationManager? _participantAnnotationManager;
  bool _mapReady = false;
  StreamSubscription? _participantSub;
  Timer? etaTimer;
  Map<String, int> inviteeETAs = {};

  @override
  void dispose() {
    _mapReady = false;
    etaTimer?.cancel();
    etaTimer = null;
    _participantAnnotationManager?.deleteAll();
    _participantAnnotationManager = null;
    _participantSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void _setupParticipantListener() async {
      if (!_mapReady || _participantAnnotationManager == null || !mounted) {
        log('=======reutrning==== not mounted=====');
      }

      final ByteData userIcon =
          await rootBundle.load('assets/images/location_marker.png');
      final Uint8List userImage = userIcon.buffer.asUint8List();

      final participantCollection = FirebaseFirestore.instance
          .collection('activeGatherings')
          .doc(widget.gatheringId)
          .collection('participants');

      await _participantSub?.cancel();

      _participantSub =
          participantCollection.snapshots().listen((snapshot) async {
        if (!_mapReady || !mounted) return;

        try {
          await _participantAnnotationManager!.deleteAll();

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

            await _participantAnnotationManager!.create(
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

    Future<Position> getCurrentPosition() async {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          throw Exception("Location permission not granted");
        }
      }

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    }

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

    return Scaffold(
      backgroundColor: Color(0xff001311),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(66),
        child: gatheringAsync.when(data: (gathering) {
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
                          "${DateFormat('h a').format(gathering.dateTime)} - ${DateFormat('dd MMM yyyy').format(gathering.dateTime)}",
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
                  ],
                ),
                IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.arrow_back,
                      color: Colors.transparent,
                    )),
              ],
            ),
          );
        }, error: (err, _) {
          return SizedBox();
        }, loading: () {
          return SizedBox();
        }),
      ),
      body: gatheringAsync.when(
        data: (gathering) {
          final now = DateTime.now();
          final eventCutoffTime = gathering.dateTime.add(Duration(minutes: 30));

          // ❌ Don't fetch location or run timers after cutoff
          if (now.isAfter(eventCutoffTime)) {
            debugPrint(
                "📵 Location updates stopped: Event has passed + buffer.");
          } else {
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

              for (final doc in snapshot.docs) {
                final data = doc.data();
                final userId = doc.id;
                final lat = data['lat'];
                final lng = data['lng'];

                // final eta = await calculateETA(
                //   lat,
                //   lng,
                //   gathering.location.lat,
                //   gathering.location.lng,
                // );
                // newEtas[userId] = eta;

                final eta = await calculateMapboxETA(
                  userLat: lat,
                  userLng: lng,
                  eventLat: gathering.location.lat,
                  eventLng: gathering.location.lng,
                );

                newEtas[userId] = eta;
              }

              setState(() {
                inviteeETAs = newEtas;
              });
            });
          }

          final uid = FirebaseAuth.instance.currentUser!.uid;
          final isHost = uid == gathering.hostId;
          final myStatus = gathering.invitees[uid]?.status ?? 'pending';

          isSharing = gathering.invitees[uid]?.sharing ?? true;

          final inviteeEntries = gathering.invitees.entries.toList();

          // log('my status : ${gathering.invitees[uid]?.status}');
          // log('current uid : $uid : host id : ${gathering.hostId}');

          return SingleChildScrollView(
            child: Container(
              height: MediaQuery.of(context).size.height,
              child: Stack(
                children: [
                  Container(
                    height: 300,
                    // color: Colors.yellow,
                    width: MediaQuery.of(context).size.width,
                    child: map.MapWidget(
                        key: ValueKey("map-${gathering.id}"),
                        styleUri: map.MapboxStyles.DARK,
                        cameraOptions: map.CameraOptions(
                          center: map.Point(
                            coordinates: map.Position(
                              gathering.location.lng,
                              gathering.location.lat,
                            ),
                          ),
                          zoom: 5,
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

                          _participantAnnotationManager = await mapController
                              .annotations
                              .createPointAnnotationManager();

                          _mapReady = true;

                          _setupParticipantListener();
                        }),
                  ),
                  Positioned.fill(
                    top: 250,
                    child: Container(
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
                          Center(
                            child: Opacity(
                              opacity: 0.30,
                              child: Container(
                                width: 79,
                                height: 5,
                                decoration: ShapeDecoration(
                                  color: const Color(0xFFE7E7E7),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(2.50),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 50,
                          ),
                          Expanded(
                            child: ListView(
                              // padding: EdgeInsets.all(20),
                              // physics: NeverScrollableScrollPhysics(),
                              children: [
                                // SizedBox(height: 50),
                                Text(
                                  "Description",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 11),
                                Text(
                                  gathering.name,
                                  style: TextStyle(
                                    color: Color(0xff99a1a0),
                                    fontSize: 16,
                                    fontFamily: 'SFPRO',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
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
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          color: Colors.white),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              gathering.location.name,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            SizedBox(
                                              height: 6,
                                            ),
                                            Text(
                                              gathering.location.address,
                                              maxLines: 3,
                                              style: TextStyle(
                                                color: const Color(0xFFC4C4C4),
                                                fontSize: 13,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w400,
                                                letterSpacing: -0.32,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          // final Position pos =
                                          //     await getCurrentPosition();
                                          // log(pos.toString());

                                          // final ByteData userIcon =
                                          //     await rootBundle.load(
                                          //         'assets/images/location_marker.png');
                                          // final Uint8List userImage =
                                          //     userIcon.buffer.asUint8List();

                                          // final participantCollection =
                                          //     FirebaseFirestore.instance
                                          //         .collection(
                                          //             'activeGatherings')
                                          //         .doc(gathering.id)
                                          //         .collection('participants');

                                          // participantCollection
                                          //     .snapshots()
                                          //     .listen((snapshot) async {
                                          //   for (final doc in snapshot.docs) {
                                          //     final data = doc.data();
                                          //     final userLat = data['lat'];
                                          //     final userLng = data['lng'];

                                          //     final eta = calculateETA(
                                          //       userLat,
                                          //       userLng,
                                          //       gathering.location.lat,
                                          //       gathering.location.lng,
                                          //     );

                                          //     calculateMapboxETA(
                                          //       userLat: userLat,
                                          //       userLng: userLng,
                                          //       eventLat:
                                          //           gathering.location.lat,
                                          //       eventLng:
                                          //           gathering.location.lng,
                                          //     );

                                          //     log('user lang : $userLng  - lt :$userLat');

                                          //     // annotationManager?.deleteAll();

                                          //     await annotationManager?.create(
                                          //       map.PointAnnotationOptions(
                                          //         geometry: map.Point(
                                          //           coordinates: map.Position(
                                          //               userLng, userLat),
                                          //         ),
                                          //         image: userImage,
                                          //       ),
                                          //     );
                                          //   }
                                          // });
                                        },
                                        child: Text("Directions →",
                                            style: TextStyle(
                                              color: const Color(0xFF03FFE2),
                                              fontSize: 14,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w600,
                                              height: 1.43,
                                            )),
                                      )
                                    ],
                                  ),
                                ),
                                if (myStatus == 'accepted') ...[
                                  SizedBox(height: 24),
                                  SwitchListTile(
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
                                        style: TextStyle(color: Colors.white)),
                                    activeColor: Colors.greenAccent,
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
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics:
                                      NeverScrollableScrollPhysics(), // let parent scroll
                                  itemCount: inviteeEntries.length,
                                  separatorBuilder: (context, index) => Divider(
                                    color: Color(0xff2b3c3a),
                                    thickness: 0.5,
                                    height: 20,
                                  ),
                                  itemBuilder: (context, index) {
                                    final entry = inviteeEntries[index];
                                    final userId = entry.key;
                                    final invitee = entry.value;

                                    final eta = inviteeETAs[userId];

                                    String label = invitee.name;
                                    if (userId == currentUserId) {
                                      label += ' (You)';
                                    }

                                    return Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: Colors.white,
                                          child: Text(
                                            getInitials(invitee.name),
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              label,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            invitee.host
                                                ? Text(
                                                    'Organiser',
                                                    style: TextStyle(
                                                      color: const Color(
                                                          0xFF58616A),
                                                      fontSize: 14,
                                                      fontFamily: 'Inter',
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                  )
                                                : Text(
                                                    invitee.status == 'pending'
                                                        ? 'Request sent'
                                                        : 'Accepted',
                                                    style: TextStyle(
                                                      color: const Color(
                                                          0xFF58616A),
                                                      fontSize: 14,
                                                      fontFamily: 'Inter',
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                  ),
                                          ],
                                        ),
                                        Spacer(),
                                        if (eta != null) ...[
                                          const SizedBox(width: 12),
                                          Icon(Icons.directions_walk,
                                              size: 14, color: Colors.grey),
                                          Text(
                                            "$eta min",
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                              fontFamily: 'Inter',
                                            ),
                                          )
                                        ]
                                      ],
                                    );
                                  },
                                ),
                                SizedBox(
                                  height: 63,
                                ),

                                // RSVP Buttons (Only if not host and status is pending)
                                !isHost && myStatus == 'pending'
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(
                                                horizontal: 0, vertical: 16)
                                            .copyWith(top: 0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () => _handleRSVP(
                                                    'rejected', context),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Color(0xffE4425F),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text("Reject"),
                                                    SizedBox(
                                                      width: 8,
                                                    ),
                                                    Icon(
                                                      Icons.close,
                                                      color: Colors.black,
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () => _handleRSVP(
                                                    'accepted', context),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Color(0xFF03FFE2),
                                                  foregroundColor: Colors.black,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text("Accept"),
                                                    SizedBox(
                                                      width: 8,
                                                    ),
                                                    Icon(
                                                      Icons.check,
                                                      color: Colors.black,
                                                    )
                                                  ],
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      )
                                    : ContinueButton(
                                        onPressed: () {
                                          context.pop();
                                        },
                                        text: 'Send ping',
                                      ),
                                SizedBox(
                                  height: 100,
                                ),

                                // Container(height: 800,color: Colors.blue,)
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading gathering: $err')),
      ),
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
