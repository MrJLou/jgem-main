class UserActivityLog {
  final int? id;
  final String userId;
  final String actionDescription;
  final String? targetRecordId;
  final String? targetTable;
  final DateTime timestamp;
  final String? details; // Can store JSON string for additional context

  UserActivityLog({
    this.id,
    required this.userId,
    required this.actionDescription,
    this.targetRecordId,
    this.targetTable,
    required this.timestamp,
    this.details,
  });

  factory UserActivityLog.fromJson(Map<String, dynamic> json) {
    return UserActivityLog(
      id: json['id'] as int?,
      userId: json['userId'] as String,
      actionDescription: json['actionDescription'] as String,
      targetRecordId: json['targetRecordId'] as String?,
      targetTable: json['targetTable'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      details: json['details'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'actionDescription': actionDescription,
      'targetRecordId': targetRecordId,
      'targetTable': targetTable,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
    };
  }
}
