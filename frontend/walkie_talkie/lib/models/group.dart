class Group {
  final String id;
  final String name;
  final String joinToken;
  final int memberCount;
  final String? createdAt;

  Group({
    required this.id,
    required this.name,
    required this.joinToken,
    required this.memberCount,
    this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      joinToken: json['join_token'] as String,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'join_token': joinToken,
      'member_count': memberCount,
      'created_at': createdAt,
    };
  }
}
