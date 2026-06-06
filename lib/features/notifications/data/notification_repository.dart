import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/notifications/domain/notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return SupabaseNotificationRepository(Supabase.instance.client);
});

abstract class NotificationRepository {
  Stream<AppResult<List<AppNotification>>> watchNotifications();
  Future<AppResult<int>> getUnreadCount();
  Future<AppResult<void>> markAsRead(String id);
  Future<AppResult<void>> markAllAsRead(Iterable<String> ids);
}

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);
  final SupabaseClient _client;

  @override
  Stream<AppResult<List<AppNotification>>> watchNotifications() async* {
    try {
      final stream = _client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(100);

      await for (final rows in stream) {
        yield AppSuccess(
          rows.map((r) => AppNotification.fromJson(Map<String, dynamic>.from(r))).toList(),
        );
      }
    } catch (_) {
      yield const AppFailure(AppError(code: 'NOTIF_LOAD_FAILED', message: 'No se pudo cargar notificaciones.', category: AppErrorCategory.data, severity: AppErrorSeverity.high));
    }
  }

  @override
  Future<AppResult<int>> getUnreadCount() async {
    try {
      final response = await _client
          .from('notifications')
          .select('id')
          .filter('read_at', 'is', null);
      return AppSuccess((response as List).length);
    } catch (_) {
      return const AppSuccess(0);
    }
  }

  @override
  Future<AppResult<void>> markAsRead(String id) async {
    try {
      await _client.from('notifications').update({
        'read_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      return const AppSuccess(null);
    } catch (_) {
      return const AppFailure(AppError(code: 'NOTIF_MARK_FAILED', message: 'No se pudo marcar como leída.', category: AppErrorCategory.data, severity: AppErrorSeverity.low));
    }
  }

  @override
  Future<AppResult<void>> markAllAsRead(Iterable<String> ids) async {
    if (ids.isEmpty) return const AppSuccess(null);
    try {
      final now = DateTime.now().toIso8601String();
      await _client.from('notifications').update({
        'read_at': now,
      }).inFilter('id', ids.toList());
      return const AppSuccess(null);
    } catch (_) {
      return const AppFailure(AppError(code: 'NOTIF_MARK_FAILED', message: 'No se pudo marcar como leídas.', category: AppErrorCategory.data, severity: AppErrorSeverity.low));
    }
  }
}
