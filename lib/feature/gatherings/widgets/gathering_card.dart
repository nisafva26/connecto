import 'dart:developer';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/gatherings/models/gathering_model.dart';
import 'package:connecto/feature/gatherings/widgets/gathering_card_background.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

final googleApiKey = dotenv.env['GOOGLE_API_KEY'];

class GatheringCard extends StatelessWidget {
  final GatheringModel gathering;
  final bool isPending;

  const GatheringCard({
    super.key,
    required this.gathering,
    required this.isPending,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = const Color(0xffE6E7E9);
    final subtitleColor = const Color(0xff9DA5A5);

    // Figma says: Linear Gradient • 80%
    // So we apply 0.8 (≈CC) alpha to both endpoints.
    final cDark = const Color(0xFF001311).withOpacity(0.80);
    final cLight = const Color(0xFF3C8885).withOpacity(0.80);
    // List<String> inviteeNames = gathering.invitees.values.map((e) => e.name).toList();
    List<String> inviteeNames = [
      ...gathering.invitees.values.map((e) => e.name),
      ...gathering.nonRegisteredInvitees.values.map((e) => e.name),
      ...gathering.joinedPublicUsers.values.map((e) => e.name),
    ];

    // log('event time : ${gathering.dateTime}');

    // log('https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${gathering.photoRef}&key=$googleApiKey');

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 0),
      child: Stack(
        children: [
          Card(
            elevation: 0,
            child: Bounceable(
              onTap: () {
                context.push('/gathering/gathering-details/${gathering.id}',
                    extra: gathering);
              },
              child: Container(
                // margin: const EdgeInsets.symmetric(vertical: 12),
                // padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: const Color(0xff10201E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Placeholder image
                    gathering.photoRef!.isEmpty
                        ? Container(
                            height: 160,
                            decoration: BoxDecoration(
                              color: const Color(0xff333333),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12)),
                            child: CachedNetworkImage(
                              height: 160,
                              fit: BoxFit.cover,
                              width: MediaQuery.sizeOf(context).width,
                              imageUrl:
                                  'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${gathering.photoRef}&key=$googleApiKey',
                              placeholder: (context, url) =>
                                  Center(child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) =>
                                  Icon(Icons.error),
                            ),
                          ),
                    // const SizedBox(height: 20),

                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: Stack(
                        children: [

                          Positioned.fill(
                            child: Container(
                              
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter, // light side
                                  end: Alignment.bottomCenter, // dark side
                                  colors: [cLight, cDark],
                                  stops: const [0.0, 1.0],
                                ),
                              ),
                            ),
                          ),
                          

                          // BLOB 1: bottom-left teal glow
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment(
                                        -0.95, 1.05), // slightly outside
                                    radius: 0.95,
                                    colors: [
                                      Color(0x663C8885), // ~40% teal
                                      Color(0x003C8885), // transparent
                                    ],
                                    stops: [0.0, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // BLOB 2: bottom-right aqua glow
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  gradient: RadialGradient(
                                    center:
                                        Alignment(1.05, 0.95), // bottom-right
                                    radius: 0.9,
                                    colors: [
                                      Color(0x664AAEAA), // soft aqua
                                      Color(0x004AAEAA),
                                    ],
                                    stops: [0.0, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // // 1) Base diagonal teal gradient (matches Figma tone)
                          // Positioned.fill(
                          //   child: IgnorePointer(
                          //     child: DecoratedBox(
                          //       decoration: const BoxDecoration(
                          //         gradient: RadialGradient(
                          //           center: Alignment(
                          //               -0.85, 1.05), // slightly out of frame
                          //           radius: 0.65,
                          //           colors: [
                          //             Color(0xFF3C8884), // inner glow
                          //             Color(0x003C8884), // fade to transparent
                          //           ],
                          //           stops: [0.0, 1.0],
                          //         ),
                          //       ),
                          //     ),
                          //   ),
                          // ),

                          // // 2) Glow blob — bottom-right (aqua)
                          // Positioned.fill(
                          //   child: IgnorePointer(
                          //     child: DecoratedBox(
                          //       decoration: const BoxDecoration(
                          //         gradient: RadialGradient(
                          //           center: Alignment(
                          //               1.05, 0.95), // bottom-right corner
                          //           radius: 0.9,
                          //           colors: [
                          //             Color(
                          //                 0x664AAEAA), // softer than solid to avoid wash-out
                          //             Color(0x004AAEAA),
                          //           ],
                          //           stops: [0.0, 1.0],
                          //         ),
                          //       ),
                          //     ),
                          //   ),
                          // ),

                          // Your content
                          Container(
                            // keep a light inner shadow feel
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x26000000), // 15% black
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0)
                                  .copyWith(top: 24, bottom: 24),
                              child: Column(
                                children: [
                                  // Title
                                  Row(
                                    children: [
                                      Expanded(
                                        // flex: 4,
                                        child: Text(
                                          gathering.name,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontFamily: 'SFPRO',
                                            fontWeight: FontWeight.w700,
                                            height: 1.38,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 20,
                                      ),
                                      // Spacer(),
                                      gathering.status=='cancelled'? Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: ShapeDecoration(
                                                color: Colors.red,
                                                shape: RoundedRectangleBorder(
                                                  side: BorderSide(
                                                    width: 1,
                                                    color:
                                                         Colors.red,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Cancelled',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontFamily: 'Inter',
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      height: 1.50,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ):
                                      isPending
                                          ? Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: ShapeDecoration(
                                                color: const Color(0xFFFFF9EB),
                                                shape: RoundedRectangleBorder(
                                                  side: BorderSide(
                                                    width: 1,
                                                    color:
                                                        const Color(0xFFFEDE88),
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    'Pending',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: const Color(
                                                          0xFFB54707),
                                                      fontSize: 12,
                                                      fontFamily: 'Inter',
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      height: 1.50,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : _buildTimeStatus(
                                              gathering.dateTime, context)
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          color: subtitleColor, size: 18),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          gathering.location.name,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: subtitleColor,
                                            overflow: TextOverflow.ellipsis,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Time row
                                  Row(
                                    children: [
                                      Icon(Icons.access_time,
                                          color: subtitleColor, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        "${formatTime(gathering.dateTime)} – ${formatDate(gathering.dateTime)}",
                                        style: TextStyle(
                                          color: subtitleColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  //             const SizedBox(height: 4),

                                  // // Dynamic label for status like Today, Starts soon, etc.
                                  //             _buildTimeStatus(gathering.dateTime),
                                  const SizedBox(height: 14),

                                  // Invitees stacked
                                  buildInviteeAvatars(inviteeNames),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )

                    // Location row
                    // ClipRRect(
                    //   borderRadius: const BorderRadius.only(
                    //     bottomLeft: Radius.circular(12),
                    //     bottomRight: Radius.circular(12),
                    //   ),
                    //   child: Container(
                    //     decoration: BoxDecoration(
                    //       borderRadius: const BorderRadius.only(
                    //         bottomLeft: Radius.circular(12),
                    //         bottomRight: Radius.circular(12),
                    //       ),
                    //     ),
                    //     child: Stack(
                    //       children: [
                    //         Positioned(
                    //           bottom: -70,
                    //           left: -50,
                    //           child: Container(
                    //             width: 150,
                    //             height: 150,
                    //             decoration: const BoxDecoration(
                    //               shape: BoxShape.circle,
                    //               // color: Colors.white
                    //               gradient: RadialGradient(
                    //                 colors: [
                    //                   Color(0xFF3C8884), // teal glow
                    //                   Colors.transparent,
                    //                 ],
                    //                 radius: 1.0,
                    //               ),
                    //             ),
                    //           ),
                    //         ),
                    //         Positioned(
                    //           bottom: -40,
                    //           right: -20,
                    //           child: Center(
                    //             child: Container(
                    //               width: 123,
                    //               height: 123,
                    //               decoration: BoxDecoration(
                    //                 shape: BoxShape.circle,
                    //                 color: Colors.white,
                    //                 gradient: RadialGradient(
                    //                   colors: [
                    //                     Color(0xFF4AAEAA), // aqua glow
                    //                     Colors.transparent,
                    //                   ],
                    //                   radius: 1.0,
                    //                 ),
                    //               ),
                    //             ),
                    //           ),
                    //         ),
                    //         ClipRRect(
                    //           borderRadius: const BorderRadius.only(
                    //             bottomLeft: Radius.circular(12),
                    //             bottomRight: Radius.circular(12),
                    //           ),
                    //           child: BackdropFilter(
                    //             filter: ImageFilter.blur(
                    //                 sigmaX: 15, sigmaY: 15), // 🔹 Frosted blur
                    //             child: Container(
                    //               decoration: BoxDecoration(
                    //                 boxShadow: [
                    //                   BoxShadow(
                    //                     color: Color(0x3F000000),
                    //                     blurRadius: 4,
                    //                     offset: Offset(0, 4),
                    //                     spreadRadius: 0,
                    //                   )
                    //                 ],
                    //                 gradient: LinearGradient(
                    //                   begin: Alignment.bottomCenter,
                    //                   end: Alignment.topCenter,
                    //                   colors: [
                    //                     const Color(0xFF00332E).withOpacity(
                    //                         0.85), // deep teal bottom
                    //                     const Color(0xFF3C8884)
                    //                         .withOpacity(0.65), // teal mid
                    //                     const Color(0xFF4AAEAA).withOpacity(
                    //                         0.40), // light aqua top
                    //                   ],
                    //                 ),

                    //                 // gradient: LinearGradient(
                    //                 //   begin: Alignment(0.50, 1.00),
                    //                 //   end: Alignment(0.50, 0.00),
                    //                 //   colors: [

                    //                 //     const Color(0xFF091F1E),
                    //                 //     const Color(0xFF0F4A47)

                    //                 //   ],
                    //                 // ),
                    //                 borderRadius: const BorderRadius.only(
                    //                   bottomLeft: Radius.circular(12),
                    //                   bottomRight: Radius.circular(12),
                    //                 ),
                    //               ),
                    //               child:
                    //               Padding(
                    //                 padding: const EdgeInsets.all(16.0)
                    //                     .copyWith(top: 24, bottom: 24),
                    //                 child: Column(
                    //                   children: [
                    //                     // Title
                    //                     Row(
                    //                       children: [
                    //                         Expanded(
                    //                           // flex: 4,
                    //                           child: Text(
                    //                             gathering.name,
                    //                             style: TextStyle(
                    //                               color: Colors.white,
                    //                               fontSize: 16,
                    //                               fontFamily: 'SFPRO',
                    //                               fontWeight: FontWeight.w700,
                    //                               height: 1.38,
                    //                             ),
                    //                           ),
                    //                         ),
                    //                         SizedBox(
                    //                           width: 20,
                    //                         ),
                    //                         // Spacer(),
                    //                         isPending
                    //                             ? Container(
                    //                                 padding: const EdgeInsets
                    //                                     .symmetric(
                    //                                     horizontal: 8,
                    //                                     vertical: 2),
                    //                                 decoration: ShapeDecoration(
                    //                                   color: const Color(
                    //                                       0xFFFFF9EB),
                    //                                   shape:
                    //                                       RoundedRectangleBorder(
                    //                                     side: BorderSide(
                    //                                       width: 1,
                    //                                       color: const Color(
                    //                                           0xFFFEDE88),
                    //                                     ),
                    //                                     borderRadius:
                    //                                         BorderRadius
                    //                                             .circular(16),
                    //                                   ),
                    //                                 ),
                    //                                 child: Row(
                    //                                   mainAxisSize:
                    //                                       MainAxisSize.min,
                    //                                   mainAxisAlignment:
                    //                                       MainAxisAlignment
                    //                                           .start,
                    //                                   crossAxisAlignment:
                    //                                       CrossAxisAlignment
                    //                                           .center,
                    //                                   children: [
                    //                                     Text(
                    //                                       'Pending',
                    //                                       textAlign:
                    //                                           TextAlign.center,
                    //                                       style: TextStyle(
                    //                                         color: const Color(
                    //                                             0xFFB54707),
                    //                                         fontSize: 12,
                    //                                         fontFamily: 'Inter',
                    //                                         fontWeight:
                    //                                             FontWeight.w500,
                    //                                         height: 1.50,
                    //                                       ),
                    //                                     ),
                    //                                   ],
                    //                                 ),
                    //                               )
                    //                             : _buildTimeStatus(
                    //                                 gathering.dateTime, context)
                    //                       ],
                    //                     ),
                    //                     const SizedBox(height: 14),
                    //                     Row(
                    //                       children: [
                    //                         Icon(Icons.location_on,
                    //                             color: subtitleColor, size: 18),
                    //                         const SizedBox(width: 6),
                    //                         Expanded(
                    //                           child: Text(
                    //                             gathering.location.name,
                    //                             maxLines: 1,
                    //                             style: TextStyle(
                    //                               color: subtitleColor,
                    //                               overflow:
                    //                                   TextOverflow.ellipsis,
                    //                               fontSize: 14,
                    //                               fontWeight: FontWeight.w400,
                    //                             ),
                    //                           ),
                    //                         ),
                    //                       ],
                    //                     ),
                    //                     const SizedBox(height: 6),

                    //                     // Time row
                    //                     Row(
                    //                       children: [
                    //                         Icon(Icons.access_time,
                    //                             color: subtitleColor, size: 18),
                    //                         const SizedBox(width: 6),
                    //                         Text(
                    //                           "${formatTime(gathering.dateTime)} – ${formatDate(gathering.dateTime)}",
                    //                           style: TextStyle(
                    //                             color: subtitleColor,
                    //                             fontSize: 14,
                    //                             fontWeight: FontWeight.w400,
                    //                           ),
                    //                         ),
                    //                       ],
                    //                     ),
                    //                     //             const SizedBox(height: 4),

                    //                     // // Dynamic label for status like Today, Starts soon, etc.
                    //                     //             _buildTimeStatus(gathering.dateTime),
                    //                     const SizedBox(height: 14),

                    //                     // Invitees stacked
                    //                     buildInviteeAvatars(inviteeNames),
                    //                   ],
                    //                 ),
                    //               ),
                    //             ),
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ),
          //  Positioned(
          //       top: 150, // sits right at the bottom of image
          //       left: 0,
          //       right: 0,
          //       child: ClipRRect(
          //         borderRadius: const BorderRadius.only(
          //           bottomLeft: Radius.circular(12),
          //           bottomRight: Radius.circular(12),
          //         ),
          //         child: BackdropFilter(
          //           filter: ImageFilter.blur(sigmaX: 0, sigmaY: 12),
          //           child: Container(
          //             height: 20,
          //             decoration: BoxDecoration(
          //               gradient: LinearGradient(
          //                 begin: Alignment.topCenter,
          //                 end: Alignment.bottomCenter,
          //                 colors: [
          //                   Colors.white.withOpacity(0.2),
          //                   Colors.transparent,
          //                 ],
          //               ),
          //             ),
          //           ),
          //         ),
          //       ),
          //     ),
        ],
      ),
    );
  }

  Widget buildInviteeAvatars(List<String> names) {
    const double avatarSize = 24;
    const double overlap = 20;

    List<Widget> avatars = [];

    final showNames = names.take(9).toList();
    final remaining = names.length - showNames.length;

    for (int i = 0; i < showNames.length; i++) {
      avatars.add(Positioned(
        left: i * overlap.toDouble(),
        child: CircleAvatar(
          radius: avatarSize / 2,
          backgroundColor: Colors.white,
          child: Text(
            getInitials(showNames[i]),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ));
    }

    if (remaining > 0) {
      avatars.add(Positioned(
        left: showNames.length * overlap.toDouble(),
        child: CircleAvatar(
          radius: avatarSize / 2,
          backgroundColor: Colors.white,
          child: Text("+$remaining",
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ));
    }

    return SizedBox(
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: avatars,
      ),
    );
  }

  String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return parts[0][0].toUpperCase() + parts[1][0].toUpperCase();
  }

  String formatDate(DateTime dateTime) =>
      DateFormat('dd MMM yyyy').format(dateTime);

  String formatTime(DateTime dateTime) =>
      DateFormat('h:mm a').format(dateTime).toUpperCase();

  Widget _buildTimeStatus(DateTime eventTime, BuildContext context) {
    final now = DateTime.now();
    final start = eventTime;
    final end =
        eventTime.add(Duration(minutes: 60)); // ⏱️ Event duration = 1 hour
    String label;
    Color bgColor;

    if (now.isBefore(start)) {
      final diff = start.difference(now);
      label = 'Starts in ${formatDuration(diff)}';
      bgColor = Theme.of(context).colorScheme.secondary;
    } else if (now.isAfter(start) && now.isBefore(end)) {
      label = 'Ongoing';
      bgColor = Theme.of(context).colorScheme.primary;
    } else {
      label = 'Event ended';
      bgColor = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: ShapeDecoration(
        color: bgColor,
        shape: RoundedRectangleBorder(
          // side: BorderSide(width: 1, color: Colors.white),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: label == 'Event ended' ? Colors.white : Color(0xFF243443),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
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
}
