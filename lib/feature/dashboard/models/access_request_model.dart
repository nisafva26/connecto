import 'package:cloud_firestore/cloud_firestore.dart';

class AccessRequestModel {
  
  final String id;
  final String fullName;
  final String requesterPhone;
  final String email;
  final String status;

  AccessRequestModel({
    required this.id,
    required this.fullName,
    required this.requesterPhone,
    required this.email,
    required this.status,
  });

  factory AccessRequestModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AccessRequestModel(
      id: doc.id,
      fullName: data['fullName'] ?? '',
      requesterPhone: data['requesterPhone'] ?? '',
      email: data['email'] ?? '',
      status: data['status'] ?? 'pending',
    );
  }
}
