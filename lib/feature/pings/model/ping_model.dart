class PingModel {
  final String id;
  final String name;
  final List<int> pattern; // Vibration sequence
  final bool isCustom; // True if user-created
  final DateTime createdAt;

  PingModel({
    required this.id,
    required this.name,
    required this.pattern,
    required this.isCustom,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'pattern': pattern,
      'isCustom': isCustom,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PingModel.fromMap(Map<String, dynamic> map, String id) {
    return PingModel(
      id: id,
      name: map['name'],
      pattern: List<int>.from(map['pattern'] ?? []),
      isCustom: map['isCustom'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
