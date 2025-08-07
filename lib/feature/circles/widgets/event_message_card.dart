import 'package:connecto/feature/circles/models/group_message_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class EventMessageCard extends StatelessWidget {
  final GroupMessageModel message;
  final bool isMine;

  const EventMessageCard({
    super.key,
    required this.message,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('EEE, MMM d – hh:mm a').format(message.eventDateTime!);
    final titleText = isMine
        ? "You created an event 🎉"
        : "${message.senderName} created an event 🎉";

    return GestureDetector(
      onTap: () {
        context.push('/gathering/gathering-details/${message.eventId}');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xff123331),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titleText,
                style: const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              "${message.eventName} · ${message.eventType}",
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(dateText,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            if (message.eventLocation != null &&
                message.eventLocation!.isNotEmpty)
              Text(message.eventLocation!,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
