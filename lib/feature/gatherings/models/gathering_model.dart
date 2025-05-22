import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/phone_number.dart';

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
  final String id;
  final String phoneNumber;

  InviteeModel(
      {required this.status,
      required this.host,
      this.respondedAt,
      required this.name,
      required this.sharing,
      required this.id,
      required this.phoneNumber});

  factory InviteeModel.fromMap(Map<String, dynamic> map, String key) {
    // log('invite map : ${map.toString()}');
    return InviteeModel(
        status: map['status'] ?? 'pending',
        host: map['host'] ?? false,
        name: map['name'] ?? '',
        respondedAt: map['respondedAt'] != null
            ? (map['respondedAt'] as Timestamp).toDate()
            : null,
        sharing: map['sharing'] ?? true,
        id: key,
        phoneNumber: map['phoneNumber'] ?? '');
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

class NonRegisteredInviteeModel {
  final String name;
  final String phone;
  final String status;
  final String inviteLink;

  NonRegisteredInviteeModel({
    required this.name,
    required this.phone,
    required this.status,
    required this.inviteLink,
  });

  factory NonRegisteredInviteeModel.fromMap(Map<String, dynamic> map) {
    return NonRegisteredInviteeModel(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      status: map['status'] ?? 'invited',
      inviteLink: map['inviteLink'] ?? '',
    );
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
  final Map<String, NonRegisteredInviteeModel> nonRegisteredInvitees;
  final bool isPublic;
  final Map<dynamic, InviteeModel> joinedPublicUsers;
  final int maxPublicParticipants;
  final String? photoRef;

  GatheringModel(
      {required this.id,
      required this.name,
      required this.eventType,
      required this.hostId,
      required this.isRecurring,
      required this.recurrenceType,
      required this.dateTime,
      required this.status,
      required this.location,
      required this.invitees,
      required this.nonRegisteredInvitees,
      required this.isPublic,
      required this.joinedPublicUsers,
      required this.maxPublicParticipants,
      required this.photoRef});

  factory GatheringModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final inviteesMap = (data['invitees'] as Map<String, dynamic>);
    final nonRegisteredMap =
        (data['nonRegisteredInvitees'] ?? {}) as Map<String, dynamic>;

    final joinedPublicUsersMap =
        (data['joinedPublicUsers'] ?? {}) as Map<dynamic, dynamic>;
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
          (key, value) => MapEntry(key, InviteeModel.fromMap(value, key)),
        ),
        nonRegisteredInvitees: nonRegisteredMap.map(
          (key, value) =>
              MapEntry(key, NonRegisteredInviteeModel.fromMap(value)),
        ),
        isPublic: data['isPublic'] ?? false,
        joinedPublicUsers: joinedPublicUsersMap.map(
          (key, value) => MapEntry(key, InviteeModel.fromMap(value, key)),
        ),
        maxPublicParticipants: data['maxPublicParticipants'] ?? 0,
        photoRef: data['photoRef'] ?? '');
  }

  factory GatheringModel.fromMap(Map<String, dynamic> map, String docId) {
    final inviteesMap = Map<String, InviteeModel>.fromEntries(
      (map['invitees'] as Map).entries.map(
            (e) => MapEntry(e.key, InviteeModel.fromMap(e.value, e.key)),
          ),
    );

    final nonRegisteredMap =
        (map['nonRegisteredInvitees'] ?? {}) as Map<String, dynamic>;
    final nonRegisteredInvitees = nonRegisteredMap.map(
      (key, value) => MapEntry(key, NonRegisteredInviteeModel.fromMap(value)),
    );

    final joinedPublicGatheringMap =
        (map['joinedPublicUsers'] ?? {}) as Map<dynamic, dynamic>;
    final joinedPublicGatheringInvitees = joinedPublicGatheringMap.map(
      (key, value) => MapEntry(key, InviteeModel.fromMap(value, key)),
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
        nonRegisteredInvitees: nonRegisteredInvitees,
        isPublic: false,
        joinedPublicUsers: joinedPublicGatheringInvitees,
        maxPublicParticipants: map['maxPublicParticipants'] ?? 0,
        photoRef: map['photoRef'] ?? '');
  }
}
