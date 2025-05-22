class BadgeProgress {
  final int count;
  final int required;

  BadgeProgress({required this.count, required this.required});

  factory BadgeProgress.fromJson(Map<String, dynamic> json) {
    return BadgeProgress(
      count: json['count'] ?? 0,
      required: json['required'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'count': count,
        'required': required,
      };
}