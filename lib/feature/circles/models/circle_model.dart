
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connecto/feature/auth/model/user_model.dart';


class CircleModel {
  final String id;
  final String circleName;
  final String circleColor;
  final List<UserModel> registeredUsers; // ✅ Now stores full user details
  final List<Map<String, String>> unregisteredUsers; // [{fullName, phoneNumber}]
  final DateTime? createdAt;

  CircleModel({
    required this.id,
    required this.circleName,
    required this.circleColor,
    required this.registeredUsers,
    required this.unregisteredUsers,
    this.createdAt,
  });

  /// ✅ Factory method to fetch registered users dynamically
  static Future<CircleModel> fromFirestore(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final List<String> registeredUserIds = List<String>.from(data['registeredUsers'] ?? []);

    /// ✅ Fetch only required users from Firestore
    final userDocs = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: registeredUserIds)
        .get();

    List<UserModel> registeredUsers = userDocs.docs.map((doc) {
      return UserModel.fromMap(doc.data(), doc.id);
    }).toList();

    return CircleModel(
      id: doc.id,
      circleName: data['circleName'] ?? '',
      circleColor: data['circleColor'] ?? '000000', // Default black
      registeredUsers: registeredUsers,
      unregisteredUsers: List<Map<String, String>>.from(
          (data['unregisteredUsers'] as List<dynamic>? ?? [])
              .map((e) => Map<String, String>.from(e))),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
