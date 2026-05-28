import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final unitsRepositoryProvider = Provider<UnitsRepository>((ref) {
  return SupabaseUnitsRepository(Supabase.instance.client);
});

abstract class UnitsRepository {
  Future<AppResult<List<UnitOption>>> listUnits();

  Future<AppResult<void>> saveUnit({
    String? unitId,
    required String code,
    required String name,
    required bool active,
  });

  Future<AppResult<void>> deactivateUnit(String unitId);
}

class SupabaseUnitsRepository implements UnitsRepository {
  SupabaseUnitsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppResult<List<UnitOption>>> listUnits() async {
    try {
      final rows = await _client
          .from('units')
          .select('id,code,name,active')
          .order('active', ascending: false)
          .order('name');
      return AppSuccess(
        rows
            .map<UnitOption>(
              (row) => UnitOption.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'DATA_UNITS_LOAD_FAILED',
          message: 'No se pudo cargar unidades.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> saveUnit({
    String? unitId,
    required String code,
    required String name,
    required bool active,
  }) async {
    final action = unitId == null ? 'create' : 'update';
    return _manageUnit(
      action: action,
      unitId: unitId,
      code: code,
      name: name,
      active: active,
    );
  }

  @override
  Future<AppResult<void>> deactivateUnit(String unitId) {
    return _manageUnit(action: 'deactivate', unitId: unitId);
  }

  Future<AppResult<void>> _manageUnit({
    required String action,
    String? unitId,
    String? code,
    String? name,
    bool? active,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'manage-unit',
        body: {
          'action': action,
          'unit_id': unitId,
          'code': code,
          'name': name,
          'active': active,
        },
      );
      final body = response.data;
      if (body is Map && body['ok'] == true) {
        return const AppSuccess(null);
      }
      return AppFailure(_errorFromBody(body));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNIT_SAVE_FAILED',
          message: 'No se pudo guardar la unidad.',
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
