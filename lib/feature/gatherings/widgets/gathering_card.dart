import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/gatherings/models/gathering_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
    final inviteeNames = gathering.invitees.values.map((e) => e.name).toList();

    log('event time : ${gathering.dateTime}');

    return InkWell(
      onTap: () {
        context.push('/gathering-details/${gathering.id}', extra: gathering);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xff10201E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Placeholder image
            // Container(
            //   height: 180,
            //   decoration: BoxDecoration(
            //     color: const Color(0xff333333),
            //     borderRadius: BorderRadius.circular(12),
            //   ),
            // ),
            // const SizedBox(height: 16),

            // Title
            Text(
              gathering.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'SFPRO',
                fontWeight: FontWeight.w700,
                height: 1.38,
              ),
            ),
            const SizedBox(height: 14),

            // Location row
            Row(
              children: [
                Icon(Icons.location_on, color: subtitleColor, size: 18),
                const SizedBox(width: 6),
                Text(
                  gathering.location.name,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
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
            const SizedBox(height: 14),

            // Invitees stacked
            _buildInviteeAvatars(inviteeNames),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteeAvatars(List<String> names) {
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
}
