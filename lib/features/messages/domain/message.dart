class Message {
  final String id;
  final String senderId;
  final String? senderName;
  final String? senderEmail;
  final String? senderPhone;
  final String? senderRole;
  final String? recipientId;
  final String? recipientName;
  final String? recipientEmail;
  final String? recipientPhone;
  final String? recipientRole;
  final String? unitId;
  final String? unitName;
  final String subject;
  final String body;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.senderId,
    this.senderName,
    this.senderEmail,
    this.senderPhone,
    this.senderRole,
    this.recipientId,
    this.recipientName,
    this.recipientEmail,
    this.recipientPhone,
    this.recipientRole,
    this.unitId,
    this.unitName,
    required this.subject,
    required this.body,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final senderProfile = json['sender'];
    final recipientProfile = json['recipient'];
    final unit = json['unit'];
    return Message(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: senderProfile is Map
          ? senderProfile['display_name']?.toString()
          : null,
      senderEmail: senderProfile is Map
          ? senderProfile['email']?.toString()
          : null,
      senderPhone: senderProfile is Map
          ? senderProfile['phone']?.toString()
          : null,
      senderRole: senderProfile is Map
          ? senderProfile['role']?.toString()
          : null,
      recipientId: json['recipient_id']?.toString(),
      recipientName: recipientProfile is Map
          ? recipientProfile['display_name']?.toString()
          : null,
      recipientEmail: recipientProfile is Map
          ? recipientProfile['email']?.toString()
          : null,
      recipientPhone: recipientProfile is Map
          ? recipientProfile['phone']?.toString()
          : null,
      recipientRole: recipientProfile is Map
          ? recipientProfile['role']?.toString()
          : null,
      unitId: json['unit_id']?.toString(),
      unitName: unit is Map ? unit['name']?.toString() : null,
      subject: json['subject']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender_id': senderId,
    'recipient_id': recipientId,
    'unit_id': unitId,
    'subject': subject,
    'body': body,
    'created_at': createdAt.toIso8601String(),
  };

  bool isFrom(String userId) => senderId == userId;

  bool get isUnitMessage => unitId != null && recipientId == null;

  String conversationKey(String userId) {
    if (isUnitMessage) return 'unit:$unitId';
    return 'user:${counterpartId(userId) ?? 'unknown'}';
  }

  String? counterpartId(String userId) {
    if (senderId == userId) return recipientId;
    return senderId;
  }

  String counterpartName(String userId) {
    if (isUnitMessage) return unitName ?? 'Unidad';
    if (senderId == userId) {
      return recipientName ?? _shortId(recipientId);
    }
    return senderName ?? _shortId(senderId);
  }

  String? counterpartEmail(String userId) =>
      senderId == userId ? recipientEmail : senderEmail;

  String? counterpartPhone(String userId) =>
      senderId == userId ? recipientPhone : senderPhone;

  String? counterpartRole(String userId) =>
      senderId == userId ? recipientRole : senderRole;

  String get shortTime =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

  String get preview => body.length > 96 ? '${body.substring(0, 96)}...' : body;

  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'CG';
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return '$first$last'.toUpperCase();
  }

  String _shortId(String? value) {
    if (value == null || value.isEmpty) return '--';
    return value.length <= 8 ? value : value.substring(0, 8);
  }
}
