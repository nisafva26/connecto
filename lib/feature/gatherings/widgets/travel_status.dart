
import 'dart:ui';

class TravelStatus {
  final String label;
  final Color color;

  TravelStatus({required this.label, required this.color});
}


TravelStatus? getInviteeStatus({
  required double distanceInMeters,
  required int? etaInMinutes,
  required DateTime eventTime,
}) {
  if (distanceInMeters < 100) {
    return TravelStatus(label: 'Arrived', color: Color(0xFF2DFFA2));
  }

  if (etaInMinutes != null) {
    final now = DateTime.now();
    final minutesUntilEvent = eventTime.difference(now).inMinutes;

    if (etaInMinutes > minutesUntilEvent) {
      return TravelStatus(label: 'Running late', color: Color(0xFFFF5C5C));
    }
  }

  return null;
}
