import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/audit/domain/audit_log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  return SupabaseAuditRepository(Supabase.instance.client);
});

abstract class AuditRepository {
  Future<AppResult<List<AuditLog>>> listAuditLogs({
    String? unitId,
    DateTime? fromDate,
    DateTime? toDate,
    String? resourceType,
    String? result,
  });
}

class SupabaseAuditRepository implements AuditRepository {
  SupabaseAuditRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppResult<List<AuditLog>>> listAuditLogs({
    String? unitId,
    DateTime? fromDate,
    DateTime? toDate,
    String? resourceType,
    String? result,
  }) async {
    try {
      // 2-month retention window
      final twoMonthsAgo = DateTime.now().subtract(const Duration(days: 60));

      var filter = _client
          .from('audit_logs')
          .select('*')
          .gte('created_at', twoMonthsAgo.toIso8601String());

      if (unitId != null) {
        filter = filter.eq('actor_unit_id', unitId);
      }

      if (fromDate != null) {
        filter = filter.gte('created_at', fromDate.toIso8601String());
      }
      if (toDate != null) {
        final endOfDay =
            DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);
        filter = filter.lte('created_at', endOfDay.toIso8601String());
      }

      if (resourceType != null && resourceType.isNotEmpty) {
        filter = filter.eq('resource_type', resourceType);
      }

      if (result != null && result.isNotEmpty) {
        filter = filter.eq('result', result);
      }

      final rows = await filter.order('created_at', ascending: false).limit(500);
      return AppSuccess(
        rows
            .map<AuditLog>(
              (row) => AuditLog.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'AUDIT_LOAD_FAILED',
          message: 'No se pudo cargar el registro de auditoría.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }
}
