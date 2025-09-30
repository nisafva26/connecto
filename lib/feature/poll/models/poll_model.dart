import 'package:cloud_firestore/cloud_firestore.dart';

/// Poll lifecycle
enum PollStatus { open, closed, archived }

PollStatus _statusFromString(String s) {
  switch (s) {
    case 'closed':
      return PollStatus.closed;
    case 'archived':
      return PollStatus.archived;
    default:
      return PollStatus.open;
  }
}

String _statusToString(PollStatus s) {
  switch (s) {
    case PollStatus.closed:
      return 'closed';
    case PollStatus.archived:
      return 'archived';
    case PollStatus.open:
    default:
      return 'open';
  }
}

/// Location option inside a poll
class PollLocation {
  final String id;
  final String name;
  final String address;
  final String img; // photoRef or any image URL
  final double lat;
  final double lng;

  const PollLocation({
    required this.id,
    required this.name,
    required this.address,
    required this.img,
    required this.lat,
    required this.lng,
  });

  factory PollLocation.fromMap(Map<String, dynamic> m) => PollLocation(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        address: m['address'] as String? ?? '',
        img: m['img'] as String? ?? '',
        lat: (m['lat'] ?? 0).toDouble(),
        lng: (m['lng'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'img': img,
        'lat': lat,
        'lng': lng,
      };
}

/// Time option inside a poll
class PollTimeSlot {
  final String id;
  final String label; // UI-friendly (e.g., "7–9:30pm, Mon Jun 20")
  final DateTime start;
  final DateTime end;

  const PollTimeSlot({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
  });

  factory PollTimeSlot.fromMap(Map<String, dynamic> m) => PollTimeSlot(
        id: m['id'] as String,
        label: m['label'] as String? ?? '',
        start: (m['start'] as Timestamp).toDate(),
        end: (m['end'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
      };
}

/// Document stored at /circles/{circleId}/polls/{pollId}
class Poll {
  final String id;
  final String circleId;
  final String title;
  final String activity;
  final String createdBy;
  final DateTime createdAt;
  final DateTime closesAt;
  final DateTime? closedAt;                 // 👈 NEW
  final PollStatus status;

  final List<PollLocation> locations;
  final List<PollTimeSlot> timeSlots;

  /// server-maintained counts
  final Map<String, int> countLocation;     // {locId: votes}
  final Map<String, int> countTime;         // {timeId: votes}

  /// winners filled by server on close
  final String? winnerLocationId;
  final String? winnerTimeSlotId;

  /// early-close conditions
  final List<String> requiredVoters;        // 👈 NEW (snapshot at creation)
  final double? minQuorum;                  // 👈 NEW (0..1), optional

  const Poll({
    required this.id,
    required this.circleId,
    required this.title,
    required this.activity,
    required this.createdBy,
    required this.createdAt,
    required this.closesAt,
    required this.closedAt,
    required this.status,
    required this.locations,
    required this.timeSlots,
    required this.countLocation,
    required this.countTime,
    required this.requiredVoters,
    required this.minQuorum,
    this.winnerLocationId,
    this.winnerTimeSlotId,
  });

  bool get isOpen => status == PollStatus.open && DateTime.now().isBefore(closesAt);

  factory Poll.fromDoc(DocumentSnapshot d) {
    final m = d.data()! as Map<String, dynamic>;
    final counts = (m['counts'] ?? {}) as Map<String, dynamic>;
    final winners = (m['winners'] ?? {}) as Map<String, dynamic>;
    return Poll(
      id: d.id,
      circleId: m['circleId'] as String,
      title: m['title'] as String? ?? '',
      activity: m['activity'] as String? ?? '',
      createdBy: m['createdBy'] as String,
      createdAt: (m['createdAt'] as Timestamp).toDate(),
      closesAt: (m['closesAt'] as Timestamp).toDate(),
      closedAt: (m['closedAt'] is Timestamp) ? (m['closedAt'] as Timestamp).toDate() : null, // 👈
      status: _statusFromString(m['status'] as String? ?? 'open'),
      locations: (m['locations'] as List)
          .map((e) => PollLocation.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      timeSlots: (m['timeSlots'] as List)
          .map((e) => PollTimeSlot.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      countLocation:
          Map<String, int>.from((counts['location'] ?? <String, int>{})),
      countTime: Map<String, int>.from((counts['time'] ?? <String, int>{})),
      winnerLocationId: winners['locationId'] as String?,
      winnerTimeSlotId: winners['timeSlotId'] as String?,
      requiredVoters:
          (m['requiredVoters'] as List?)?.map((e) => e.toString()).toList() ?? const [], // 👈
      minQuorum: (m['minQuorum'] is num) ? (m['minQuorum'] as num).toDouble() : null,     // 👈
    );
  }

  Map<String, dynamic> toMap() => {
        'circleId': circleId,
        'title': title,
        'activity': activity,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'closesAt': Timestamp.fromDate(closesAt),
        if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),     // 👈
        'status': _statusToString(status),
        'locations': locations.map((e) => e.toMap()).toList(),
        'timeSlots': timeSlots.map((e) => e.toMap()).toList(),
        'counts': {
          'location': countLocation,
          'time': countTime,
        },
        'winners': {
          if (winnerLocationId != null) 'locationId': winnerLocationId,
          if (winnerTimeSlotId != null) 'timeSlotId': winnerTimeSlotId,
        },
        'requiredVoters': requiredVoters,   // 👈
        if (minQuorum != null) 'minQuorum': minQuorum, // 👈
      };

  Poll copyWith({
    PollStatus? status,
    DateTime? closedAt,
    String? winnerLocationId,
    String? winnerTimeSlotId,
    Map<String, int>? countLocation,
    Map<String, int>? countTime,
    List<String>? requiredVoters,
    double? minQuorum,
  }) =>
      Poll(
        id: id,
        circleId: circleId,
        title: title,
        activity: activity,
        createdBy: createdBy,
        createdAt: createdAt,
        closesAt: closesAt,
        closedAt: closedAt ?? this.closedAt,
        status: status ?? this.status,
        locations: locations,
        timeSlots: timeSlots,
        countLocation: countLocation ?? this.countLocation,
        countTime: countTime ?? this.countTime,
        requiredVoters: requiredVoters ?? this.requiredVoters,
        minQuorum: minQuorum ?? this.minQuorum,
        winnerLocationId: winnerLocationId ?? this.winnerLocationId,
        winnerTimeSlotId: winnerTimeSlotId ?? this.winnerTimeSlotId,
      );
}

/// One doc per user at /circles/{circleId}/polls/{pollId}/votes/{uid}
class PollVote {
  final String locationId;
  final String timeSlotId;
  final DateTime votedAt;

  const PollVote({
    required this.locationId,
    required this.timeSlotId,
    required this.votedAt,
  });

  factory PollVote.fromDoc(DocumentSnapshot d) {
    final m = d.data()! as Map<String, dynamic>;
    return PollVote(
      locationId: m['selectedLocationId'] as String,
      timeSlotId: m['selectedTimeSlotId'] as String,
      votedAt: (m['votedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'selectedLocationId': locationId,
        'selectedTimeSlotId': timeSlotId,
        'votedAt': Timestamp.fromDate(votedAt),
      };
}
