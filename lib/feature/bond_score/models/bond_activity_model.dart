import 'package:cloud_firestore/cloud_firestore.dart';

class BondActivityModel {
  final String userId;
  final String type; // ping, on_time_arrival, gathering_created
  final int value;
  final int? bonus;
  final DateTime createdAt;

  BondActivityModel({
    required this.userId,
    required this.type,
    required this.value,
    this.bonus,
    required this.createdAt,
  });

  factory BondActivityModel.fromJson(Map<String, dynamic> json) {
    return BondActivityModel(
      userId: json['userId'],
      type: json['type'],
      value: json['value'],
      bonus: json['bonus'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }
}
