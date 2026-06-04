import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/calendar/domain/calendar_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return SupabaseCalendarRepository(Supabase.instance.client);
});

abstract class CalendarRepository {
  Future<AppResult<List<CalendarEvent>>> listEvents({
    required DateTime from,
    required DateTime to,
  });

  Future<AppResult<void>> saveEvent({
    String? eventId,
    required String title,
    String? description,
    String? location,
    required CalendarEventType eventType,
    required CalendarEventStatus status,
    required DateTime startsAt,
    required DateTime endsAt,
  });

  Future<AppResult<void>> deleteEvent(String eventId);

  Future<AppResult<void>> updateEventStatus({
    required String eventId,
    required CalendarEventStatus status,
  });
}

class SupabaseCalendarRepository implements CalendarRepository {
  SupabaseCalendarRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppResult<List<CalendarEvent>>> listEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows = await _client
          .from('calendar_events')
          .select(
            'id,title,description,location,event_type,status,starts_at,ends_at,created_by,created_at',
          )
          .lte('starts_at', to.toUtc().toIso8601String())
          .gte('ends_at', from.toUtc().toIso8601String())
          .order('starts_at');

      return AppSuccess(
        rows
            .map<CalendarEvent>(
              (row) => CalendarEvent.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'CALENDAR_EVENTS_LOAD_FAILED',
          message: 'No se pudo cargar el calendario.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> saveEvent({
    String? eventId,
    required String title,
    String? description,
    String? location,
    required CalendarEventType eventType,
    required CalendarEventStatus status,
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    return _invokeManageEvent({
      'action': eventId == null ? 'create' : 'update',
      'event_id': eventId,
      'title': title.trim(),
      'description': description?.trim(),
      'location': location?.trim(),
      'event_type': eventType.key,
      'status': status.key,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<AppResult<void>> deleteEvent(String eventId) {
    return _invokeManageEvent({'action': 'delete', 'event_id': eventId});
  }

  @override
  Future<AppResult<void>> updateEventStatus({
    required String eventId,
    required CalendarEventStatus status,
  }) {
    return _invokeManageEvent({
      'action': 'status',
      'event_id': eventId,
      'status': status.key,
    });
  }

  Future<AppResult<void>> _invokeManageEvent(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(
        'manage-calendar-event',
        body: body,
      );
      final data = response.data;
      if (data is Map && data['ok'] == true) return const AppSuccess(null);
      return AppFailure(_errorFromBody(data));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'CALENDAR_EVENT_SAVE_FAILED',
          message: 'No se pudo guardar la actividad.',
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
}
