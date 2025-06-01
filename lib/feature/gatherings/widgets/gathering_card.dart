import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/gatherings/models/gathering_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
      child: Card(
        elevation: 0,
        child: InkWell(
          onTap: () {
            context.go('/gathering/gathering-details/${gathering.id}',
                extra: gathering);
          },
          child: Container(
            // margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(16),

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
                    : 
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                          height: 160,
                          fit: BoxFit.cover,
                          width: MediaQuery.sizeOf(context).width,
                          
                          imageUrl:
                              'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${gathering.photoRef}&key=$googleApiKey',
                          placeholder: (context, url) =>
                              Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => Icon(Icons.error),
                        ),
                    ),
                const SizedBox(height: 20),

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
                    isPending
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: ShapeDecoration(
                              color: const Color(0xFFFFF9EB),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  width: 1,
                                  color: const Color(0xFFFEDE88),
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Pending',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFFB54707),
                                    fontSize: 12,
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                    height: 1.50,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _buildTimeStatus(gathering.dateTime, context)
                  ],
                ),
                const SizedBox(height: 14),

                // Location row
                Row(
                  children: [
                    Icon(Icons.location_on, color: subtitleColor, size: 18),
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
                    Icon(Icons.access_time, color: subtitleColor, size: 18),
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
