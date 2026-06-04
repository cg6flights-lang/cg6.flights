import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/messages/domain/message.dart';
import 'package:cg6_flights/features/messages/domain/message_post.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  return SupabaseMessagesRepository(Supabase.instance.client);
});

abstract class MessagesRepository {
  Future<AppResult<List<Message>>> listInbox(String userId);
  Future<AppResult<List<Message>>> listSent(String userId);
  Stream<AppResult<List<Message>>> watchMessages(String userId);
  Stream<AppResult<List<MessageRead>>> watchMessageReads();
  Stream<AppResult<List<MessagePost>>> watchPosts();
  Stream<AppResult<List<MessagePostComment>>> watchPostComments();
  Stream<AppResult<List<MessagePostRead>>> watchPostReads();

  Future<AppResult<void>> sendMessage({
    required String senderId,
    required String recipientId,
    required String body,
    String subject,
  });

  Future<AppResult<void>> markMessagesRead({
    required String profileId,
    required Iterable<String> messageIds,
  });

  Future<AppResult<void>> createPost({
    required MessagePostScope scope,
    required String body,
    String? unitId,
  });

  Future<AppResult<void>> addPostComment({
    required String postId,
    required String body,
  });

  Future<AppResult<void>> markPostRead({
    required String postId,
    required String profileId,
  });
}

class SupabaseMessagesRepository implements MessagesRepository {
  SupabaseMessagesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppResult<List<Message>>> listInbox(String userId) async {
    try {
      final rows = await _client
          .from('messages')
          .select()
          .eq('recipient_id', userId)
          .order('created_at', ascending: false)
          .limit(100);
      return AppSuccess(
        rows
            .map<Message>(
              (row) => Message.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
    } catch (_) {
      return AppFailure(_loadError());
    }
  }

  @override
  Future<AppResult<List<Message>>> listSent(String userId) async {
    try {
      final rows = await _client
          .from('messages')
          .select()
          .eq('sender_id', userId)
          .order('created_at', ascending: false)
          .limit(100);
      return AppSuccess(
        rows
            .map<Message>(
              (row) => Message.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
    } catch (_) {
      return AppFailure(_loadError());
    }
  }

  @override
  Stream<AppResult<List<Message>>> watchMessages(String userId) async* {
    if (userId.isEmpty) {
      yield const AppSuccess(<Message>[]);
      return;
    }
    try {
      final stream = _client
          .from('messages')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: true)
          .limit(500);

      await for (final rows in stream) {
        yield AppSuccess(
          rows
              .map<Message>(
                (row) => Message.fromJson(Map<String, dynamic>.from(row)),
              )
              .toList(),
        );
      }
    } catch (_) {
      yield AppFailure<List<Message>>(_loadError());
    }
  }

  @override
  Stream<AppResult<List<MessageRead>>> watchMessageReads() async* {
    try {
      final stream = _client
          .from('message_reads')
          .stream(primaryKey: ['id'])
          .order('read_at', ascending: true)
          .limit(1000);

      await for (final rows in stream) {
        yield AppSuccess(
          rows
              .map<MessageRead>(
                (row) => MessageRead.fromJson(Map<String, dynamic>.from(row)),
              )
              .toList(),
        );
      }
    } catch (_) {
      yield AppFailure<List<MessageRead>>(_loadError());
    }
  }

  @override
  Stream<AppResult<List<MessagePost>>> watchPosts() async* {
    try {
      final stream = _client
          .from('message_posts')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(150);

      await for (final rows in stream) {
        yield AppSuccess(
          rows
              .map<MessagePost>(
                (row) => MessagePost.fromJson(Map<String, dynamic>.from(row)),
              )
              .toList(),
        );
      }
    } catch (_) {
      yield AppFailure<List<MessagePost>>(_loadError());
    }
  }

  @override
  Stream<AppResult<List<MessagePostComment>>> watchPostComments() async* {
    try {
      final stream = _client
          .from('message_post_comments')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: true)
          .limit(1000);

      await for (final rows in stream) {
        yield AppSuccess(
          rows
              .map<MessagePostComment>(
                (row) =>
                    MessagePostComment.fromJson(Map<String, dynamic>.from(row)),
              )
              .toList(),
        );
      }
    } catch (_) {
      yield AppFailure<List<MessagePostComment>>(_loadError());
    }
  }

  @override
  Stream<AppResult<List<MessagePostRead>>> watchPostReads() async* {
    try {
      final stream = _client
          .from('message_post_reads')
          .stream(primaryKey: ['id'])
          .order('read_at', ascending: true)
          .limit(1000);

      await for (final rows in stream) {
        yield AppSuccess(
          rows
              .map<MessagePostRead>(
                (row) =>
                    MessagePostRead.fromJson(Map<String, dynamic>.from(row)),
              )
              .toList(),
        );
      }
    } catch (_) {
      yield AppFailure<List<MessagePostRead>>(_loadError());
    }
  }

  @override
  Future<AppResult<void>> sendMessage({
    required String senderId,
    required String recipientId,
    required String body,
    String subject = 'Chat',
  }) async {
    try {
      await _client.from('messages').insert({
        'sender_id': senderId,
        'recipient_id': recipientId,
        'unit_id': null,
        'subject': subject.trim().isEmpty ? 'Chat' : subject.trim(),
        'body': body.trim(),
      });
      return const AppSuccess(null);
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'MESSAGE_SEND_FAILED',
          message: 'No se pudo enviar el mensaje.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> markMessagesRead({
    required String profileId,
    required Iterable<String> messageIds,
  }) async {
    final ids = messageIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return const AppSuccess(null);

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client.from('message_reads').upsert([
        for (final id in ids)
          {'message_id': id, 'profile_id': profileId, 'read_at': now},
      ], onConflict: 'message_id,profile_id');
      return const AppSuccess(null);
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'MESSAGE_READ_FAILED',
          message: 'No se pudo marcar el mensaje como visto.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.medium,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> createPost({
    required MessagePostScope scope,
    required String body,
    String? unitId,
  }) {
    return _invokeManagePost({
      'action': 'create_post',
      'scope': scope.key,
      'unit_id': unitId,
      'body': body.trim(),
    });
  }

  @override
  Future<AppResult<void>> addPostComment({
    required String postId,
    required String body,
  }) {
    return _invokeManagePost({
      'action': 'add_comment',
      'post_id': postId,
      'body': body.trim(),
    });
  }

  @override
  Future<AppResult<void>> markPostRead({
    required String postId,
    required String profileId,
  }) async {
    if (postId.isEmpty || profileId.isEmpty) return const AppSuccess(null);

    try {
      await _client.from('message_post_reads').upsert({
        'post_id': postId,
        'profile_id': profileId,
        'read_at': DateTime.now().toIso8601String(),
      }, onConflict: 'post_id,profile_id');
      return const AppSuccess(null);
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'MESSAGE_POST_READ_FAILED',
          message: 'No se pudo confirmar la lectura.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.medium,
        ),
      );
    }
  }

  Future<AppResult<void>> _invokeManagePost(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(
        'manage-message-post',
        body: body,
      );
      final data = response.data;
      if (data is Map && data['ok'] == true) return const AppSuccess(null);
      return AppFailure(_errorFromBody(data));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'MESSAGE_POST_SAVE_FAILED',
          message: 'No se pudo procesar la publicación.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  AppError _errorFromBody(Object? body) {
    if (body is Map && body['error'] is Map) {
      final error = body['error'] as Map;
      return AppError(
        code: error['code']?.toString() ?? 'SYSTEM_UNEXPECTED',
        message: error['message']?.toString() ?? 'Operacion no completada.',
        category: AppErrorCategory.system,
        severity: AppErrorSeverity.high,
      );
    }
    return const AppError(
      code: 'SYSTEM_UNEXPECTED',
      message: 'Operacion no completada.',
      category: AppErrorCategory.system,
      severity: AppErrorSeverity.high,
    );
  }

  AppError _loadError() {
    return const AppError(
      code: 'MESSAGES_LOAD_FAILED',
      message: 'No se pudo cargar los mensajes.',
      category: AppErrorCategory.data,
      severity: AppErrorSeverity.high,
    );
  }
}
