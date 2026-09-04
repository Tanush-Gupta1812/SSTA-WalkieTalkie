class Transmission {
  final String id;
  final String groupId;
  final String userId;
  final String displayName;
  final double durationSeconds;
  final double timestamp;
  final int sizeBytes;

  Transmission({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.displayName,
    required this.durationSeconds,
    required this.timestamp,
    required this.sizeBytes,
  });

  factory Transmission.fromJson(Map<String, dynamic> json) {
    return Transmission(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String? ?? 'Operator',
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 0.0,
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
      sizeBytes: json['size_bytes'] as int? ?? 0,
    );
  }

  String get timeAgo {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final diff = (now - timestamp).round();
    if (diff < 10) return 'just now';
    if (diff < 60) return '${diff}s ago';
    final mins = (diff / 60).floor();
    if (mins < 60) return '${mins}m ago';
    final hours = (mins / 60).floor();
    return '${hours}h ago';
  }
}
