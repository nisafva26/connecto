import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String name;
  final double lat;
  final double lng;
  final String address;

  LocationModel({
    required this.name,
    required this.lat,
    required this.lng,
    required this.address,
  });

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      name: map['name'],
      lat: map['lat'],
      lng: map['lng'],
      address: map['address'] ?? '',
    );
  }
}

class InviteeModel {
  final String status; // pending / accepted
  final bool host;
  final DateTime? respondedAt;
  final String name;
  final bool sharing;

  InviteeModel(
      {required this.status,
      required this.host,
      this.respondedAt,
      required this.name,
      required this.sharing});

  factory InviteeModel.fromMap(Map<String, dynamic> map) {
    // log('invite map : ${map.toString()}');
    return InviteeModel(
      status: map['status'] ?? 'pending',
      host: map['host'] ?? false,
      name: map['name'] ?? '',
      respondedAt: map['respondedAt'] != null
          ? (map['respondedAt'] as Timestamp).toDate()
          : null,
      sharing: map['sharing'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'host': host,
      'name': name,
      'sharing': sharing,
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!)
    };
  }
}

class GatheringModel {
  final String id;
  final String name;
  final String eventType;
  final String hostId;
  final bool isRecurring;
  final String recurrenceType;
  final DateTime dateTime;
  final String status;
  final LocationModel location;
  final Map<String, InviteeModel> invitees;

  GatheringModel({
    required this.id,
    required this.name,
    required this.eventType,
    required this.hostId,
    required this.isRecurring,
    required this.recurrenceType,
    required this.dateTime,
    required this.status,
    required this.location,
    required this.invitees,
  });

  factory GatheringModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final inviteesMap = (data['invitees'] as Map<String, dynamic>);
    return GatheringModel(
      id: doc.id,
      name: data['name'],
      eventType: data['eventType'],
      hostId: data['hostId'],
      isRecurring: data['isRecurring'],
      recurrenceType: data['recurrenceType'],
      dateTime: (data['dateTime'] as Timestamp).toDate(),
      status: data['status'],
      location: LocationModel.fromMap(data['location']),
      invitees: inviteesMap.map(
        (key, value) => MapEntry(key, InviteeModel.fromMap(value)),
      ),
    );
  }

  factory GatheringModel.fromMap(Map<String, dynamic> map, String docId) {
    final inviteesMap = Map<String, InviteeModel>.fromEntries(
      (map['invitees'] as Map).entries.map(
            (e) => MapEntry(e.key, InviteeModel.fromMap(e.value)),
          ),
    );

    return GatheringModel(
      id: docId,
      name: map['name'] ?? '',
      eventType: map['eventType'] ?? '',
      hostId: map['hostId'] ?? '',
      isRecurring: map['isRecurring'] ?? false,
      recurrenceType: map['recurrenceType'] ?? '',
      dateTime: (map['dateTime'] as Timestamp).toDate(),
      status: map['status'] ?? '',
      location: LocationModel.fromMap(map['location']),
      invitees: inviteesMap,
    );
  }
}
