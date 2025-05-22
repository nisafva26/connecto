import 'dart:developer';

import 'package:connecto/feature/bond_score/models/badge_model.dart';

class BondScoreModel {
  final String bondId;
  final int totalPoints;
  final int level;
  final int? nextLevelThreshold;
  final Map<String, int> userPoints;
  final Map<String, List<String>> badges;
  final Map<String, Map<String, BadgeProgress>> badgeProgress;

  BondScoreModel({
    required this.bondId,
    required this.totalPoints,
    required this.level,
    this.nextLevelThreshold,
    required this.userPoints,
    required this.badges,
    required this.badgeProgress,
  });

  factory BondScoreModel.fromJson(String id, Map<String, dynamic> json) {
    log("Parsing BondScoreModel for bondId: $id");
    // Extract flattened badges
    final badges = <String, List<String>>{};
    final badgeProgress = <String, Map<String, BadgeProgress>>{};

    for (final entry in json.entries) {
      if (entry.key.startsWith('badges.')) {
        final userId = entry.key.split('badges.').last;
        final value = entry.value;
        if (value is List) {
          badges[userId] = List<String>.from(value);
        }
      }

      // Handle badgeProgress.* keys
      if (entry.key.startsWith('badgeProgress.')) {
        final userId = entry.key.split('badgeProgress.').last;
        final badgeMap = Map<String, dynamic>.from(entry.value);
        badgeProgress[userId] = badgeMap.map((badgeKey, badgeValue) =>
            MapEntry(badgeKey, BadgeProgress.fromJson(badgeValue)));
      }
    }

    return BondScoreModel(
      bondId: id,
      totalPoints: json['totalPoints'] ?? 0,
      level: json['level'] ?? 1,
      nextLevelThreshold: json['nextLevelThreshold'],
      userPoints: Map<String, int>.from(json['userPoints'] ?? {}),
      badges: badges,
      badgeProgress: badgeProgress,
    );
  }
}
