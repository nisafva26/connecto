class UserModel {
  String id;
  String fullName;
  DateTime dob;
  String gender;
  String phoneNumber;
  List<String> friends;
  DateTime lastActive;
  bool isActive;

  UserModel({
    required this.id,
    required this.fullName,
    required this.dob,
    required this.gender,
    required this.phoneNumber,
    required this.friends,
    required this.lastActive,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'dob': dob.toIso8601String(),
      'gender': gender,
      'phoneNumber': phoneNumber,
      'friends': friends,
      'lastActive': lastActive.toIso8601String(),
      'isActive': isActive,
    };
  }

  static UserModel fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      fullName: map['fullName'],
      dob: DateTime.parse(map['dob']),
      gender: map['gender'],
      phoneNumber: map['phoneNumber'],
      friends: List<String>.from(map['friends'] ?? []),
      lastActive: DateTime.parse(map['lastActive'] ?? DateTime.now().toIso8601String()),
      isActive: map['isActive'] ?? false,
    );
  }
}
