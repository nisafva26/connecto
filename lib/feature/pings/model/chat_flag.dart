import 'package:cloud_firestore/cloud_firestore.dart';

class ChatFlag {
  final bool latestPingFromFriend;
  final bool hasPendingGathering;
  final DateTime? lastActivity;
  final String senderID;
  final String lastMessage;

  ChatFlag({
    required this.latestPingFromFriend,
    required this.hasPendingGathering,
    required this.lastActivity,
    required this.senderID,
    required this.lastMessage,
  });

  factory ChatFlag.fromMap(Map<String, dynamic> map) {
    return ChatFlag(
      latestPingFromFriend: map['latestPingFromFriend'] ?? false,
      hasPendingGathering: map['hasPendingGathering'] ?? false,
      lastActivity: (map['lastActivity'] as Timestamp?)?.toDate(),
      senderID: map['latestPingFrom'] ?? '',
      lastMessage: map['lastPingText'] ?? '',
    );
  }
}
