class AppNotification {
  const AppNotification({
    required this.id,
    this.recipientId,
    this.unitId,
    required this.title,
    required this.body,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String? recipientId;
  final String? unitId;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      recipientId: json['recipient_id']?.toString(),
      unitId: json['unit_id']?.toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
