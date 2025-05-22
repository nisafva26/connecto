import 'dart:developer';

import 'package:connecto/common_widgets/continue_button.dart';
import 'package:connecto/feature/bond_score/models/bond_score_model.dart';
import 'package:connecto/helper/get_initials.dart';
import 'package:flutter/material.dart';

class BondBadgesSection extends StatelessWidget {
  final BondScoreModel bond;
  final String currentUserId;
  final String friendId;
  final String friendName;
  final String currentUserName;

  BondBadgesSection({
    super.key,
    required this.bond,
    required this.currentUserId,
    required this.friendId,
    required this.friendName,
    required this.currentUserName,
  });

  void showBadgeModal(
    BuildContext context,
    String label,
    IconData icon,
    int progress,
    int required,
    String progressLabel,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101F1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.black,
                child: Icon(icon, size: 36, color: Colors.tealAccent),
              ),
              const SizedBox(height: 16),
              Text(label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 12),
              Text(
                _getDescription(label),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child:
                    Text(progressLabel, style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (progress / required).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "$progress of $required $progressLabel".toLowerCase(),
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  child: ContinueButton(
                      text: 'Okay',
                      onPressed: () {
                        Navigator.pop(context);
                      })),
            ],
          ),
        );
      },
    );
  }

  final Map<String, String> progressLabelMap = {
    "fast_responder": "Pings sent",
    "mr_caring": "Pings sent",
    "event_planner": "Gatherings hosted",
    "always_on_time": "On-time arrivals",
  };

  String _getDescription(String key) {
    switch (key.toLowerCase()) {
      case "mr_caring":
        return "You get this badge if you have sent at least 20 good morning pings in 30 days";
      case "fast_responder":
        return "Send 10 pings to earn this badge.";
      case "event_planner":
        return "Host 3 gatherings to unlock this badge.";
      case "always_on_time":
        return "Be on time to 3 gatherings to get this badge.";
      default:
        return "Earn this badge by being awesome.";
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeDefinitions = [
      {"key": "always_on_time", "label": "Always On time", "icon": Icons.timer},
      {
        "key": "event_planner",
        "label": "Event Planner",
        "icon": Icons.calendar_today
      },
      {
        "key": "fast_responder",
        "label": "Fast responder",
        "icon": Icons.fast_forward
      },
      {
        "key": "mr_caring",
        "label": "Mr. Caring",
        "icon": Icons.favorite_border
      },
    ];

    Widget buildUserBadgeRow(String userId, String userName) {
      final earned = bond.badges[userId] ?? [];
      final progressMap = bond.badgeProgress[userId] ?? {};

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding:
            const EdgeInsets.only(left: 12, top: 16, bottom: 20, right: 23),
        decoration: BoxDecoration(
          color: const Color(0xFF101F1E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white,
                  child: Text(
                    getInitials(userName),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  userName,
                  style: const TextStyle(
                    color: Color(0xFFEFF1F5),
                    fontSize: 16,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  "${earned.length} Badge${earned.length == 1 ? '' : 's'}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                )
              ],
            ),
            const SizedBox(height: 15),
            Opacity(
              opacity: 0.05,
              child: Container(
                
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 1,
                      strokeAlign: BorderSide.strokeAlignCenter,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 19),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: badgeDefinitions.map((badge) {
                final key = badge['key'] as String;
                final label = badge['label'] as String;
                final icon = badge['icon'] as IconData;
                final isEarned = earned.contains(key);
                final count = progressMap[key]?.count ?? 0;
                final required = progressMap[key]?.required ?? 10;

                log("user : $userName - progress : $progressMap");
                final progressLabel = progressLabelMap[key] ?? "Progress";

                return GestureDetector(
                  onTap: () => showBadgeModal(
                      context, label, icon, count, required, progressLabel),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor:
                            isEarned ? Color(0xFF001311) : Colors.transparent,
                        child: Icon(
                          icon,
                          size: 24,
                          color: isEarned
                              ? Colors.tealAccent
                              : Colors.tealAccent.withOpacity(0.2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: isEarned
                              ? Colors.white
                              : Colors.white.withOpacity(0.2),
                          fontSize: 12,
                        ),
                      )
                    ],
                  ),
                );
              }).toList(),
            )
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text("Badges",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              )),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              buildUserBadgeRow(currentUserId, currentUserName),
              buildUserBadgeRow(friendId, friendName),
            ],
          ),
        )
      ],
    );
  }
}
