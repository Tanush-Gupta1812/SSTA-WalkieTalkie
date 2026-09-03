class Member {
  final String userId;
  final String displayName;
  final bool isOnline;
  final String? joinedAt;

  Member({
    required this.userId,
    required this.displayName,
    this.isOnline = false,
    this.joinedAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      isOnline: json['is_online'] as bool? ?? false,
      joinedAt: json['joined_at'] as String?,
    );
  }

  Member copyWith({
    String? userId,
    String? displayName,
    bool? isOnline,
    String? joinedAt,
  }) {
    return Member(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      isOnline: isOnline ?? this.isOnline,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}
