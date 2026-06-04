class MessageRead {
  const MessageRead({
    required this.id,
    required this.messageId,
    required this.profileId,
    required this.readAt,
  });

  final String id;
  final String messageId;
  final String profileId;
  final DateTime readAt;

  factory MessageRead.fromJson(Map<String, dynamic> json) {
    return MessageRead(
      id: json['id']?.toString() ?? '',
      messageId: json['message_id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      readAt:
          DateTime.tryParse(json['read_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

enum MessagePostScope {
  global,
  unit;

  String get key => switch (this) {
    MessagePostScope.global => 'global',
    MessagePostScope.unit => 'unit',
  };

  static MessagePostScope fromKey(String? key) {
    return switch (key) {
      'unit' => MessagePostScope.unit,
      _ => MessagePostScope.global,
    };
  }
}

class MessagePost {
  const MessagePost({
    required this.id,
    required this.authorId,
    required this.scope,
    this.unitId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final MessagePostScope scope;
  final String? unitId;
  final String body;
  final DateTime createdAt;

  factory MessagePost.fromJson(Map<String, dynamic> json) {
    return MessagePost(
      id: json['id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      scope: MessagePostScope.fromKey(json['scope']?.toString()),
      unitId: json['unit_id']?.toString(),
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  String get shortTime =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
}

class MessagePostComment {
  const MessagePostComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String body;
  final DateTime createdAt;

  factory MessagePostComment.fromJson(Map<String, dynamic> json) {
    return MessagePostComment(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class MessagePostRead {
  const MessagePostRead({
    required this.id,
    required this.postId,
    required this.profileId,
    required this.readAt,
  });

  final String id;
  final String postId;
  final String profileId;
  final DateTime readAt;

  factory MessagePostRead.fromJson(Map<String, dynamic> json) {
    return MessagePostRead(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      readAt:
          DateTime.tryParse(json['read_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
