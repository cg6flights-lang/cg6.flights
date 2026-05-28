import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft.dart';
import 'package:cg6_flights/features/aircraft/domain/operational_data_point.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final aircraftRepositoryProvider = Provider<AircraftRepository>((ref) {
  return SupabaseAircraftRepository(Supabase.instance.client);
});

abstract class AircraftRepository {
  Future<AppResult<List<Aircraft>>> listAircraft();

  Future<AppResult<void>> saveAircraft({
    String? aircraftId,
    required String unitId,
    required String tailNumber,
    required String model,
    required String manufacturer,
    String? serialNumber,
    int? year,
    required String status,
    String? inoperativeReason,
  });

  Future<AppResult<void>> deactivateAircraft(String aircraftId);

  Future<AppResult<List<OperationalDataPoint>>> getOperationalCurve({
    required String unitId,
    String granularity = 'month',
    int monthsLookback = 12,
  });
}

class SupabaseAircraftRepository implements AircraftRepository {
  SupabaseAircraftRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppResult<List<Aircraft>>> listAircraft() async {
    try {
      final rows = await _client
          .from('aircraft')
          .select(
            'id,unit_id,tail_number,model,manufacturer,serial_number,year,status,active,inoperative_reason',
          )
          .eq('active', true)
          .order('tail_number');
      return AppSuccess(
        rows
            .map<Aircraft>(
              (row) => Aircraft.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo cargar aeronaves.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> saveAircraft({
    String? aircraftId,
    required String unitId,
    required String tailNumber,
    required String model,
    required String manufacturer,
    String? serialNumber,
    int? year,
    required String status,
    String? inoperativeReason,
  }) async {
    final action = aircraftId == null ? 'create' : 'update';
    return _manageAircraft(
      action: action,
      aircraftId: aircraftId,
      unitId: unitId,
      tailNumber: tailNumber,
      model: model,
      manufacturer: manufacturer,
      serialNumber: serialNumber,
      year: year,
      status: status,
      inoperativeReason: inoperativeReason,
    );
  }

  @override
  Future<AppResult<void>> deactivateAircraft(String aircraftId) {
    return _manageAircraft(action: 'deactivate', aircraftId: aircraftId);
  }

  @override
  Future<AppResult<List<OperationalDataPoint>>> getOperationalCurve({
    required String unitId,
    String granularity = 'month',
    int monthsLookback = 12,
  }) async {
    try {
      final rows = await _client.rpc('get_operational_curve', params: {
        'p_unit_id': unitId,
        'p_granularity': granularity,
        'p_months_lookback': monthsLookback,
      });
      return AppSuccess(
        (rows as List)
            .map<OperationalDataPoint>(
              (row) => OperationalDataPoint.fromJson(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList(),
      );
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo cargar la curva de operatividad.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.low,
        ),
      );
    }
  }

  Future<AppResult<void>> _manageAircraft({
    required String action,
    String? aircraftId,
    String? unitId,
    String? tailNumber,
    String? model,
    String? manufacturer,
    String? serialNumber,
    int? year,
    String? status,
    String? inoperativeReason,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'manage-aircraft',
        body: {
          'action': action,
          'aircraft_id': aircraftId,
          'unit_id': unitId,
          'tail_number': tailNumber,
          'model': model,
          'manufacturer': manufacturer,
          'serial_number': serialNumber,
          'year': year,
          'status': status,
          'inoperative_reason': inoperativeReason,
        },
      );
      final body = response.data;
      if (body is Map && body['ok'] == true) {
        return const AppSuccess(null);
      }
      return AppFailure(_errorFromBody(body));
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo guardar la aeronave.',
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
        category: _categoryFromWire(error['category']?.toString()),
        severity: _severityFromWire(error['severity']?.toString()),
      );
    }
    return const AppError(
      code: 'SYSTEM_UNEXPECTED',
      message: 'Operacion no completada.',
      category: AppErrorCategory.system,
      severity: AppErrorSeverity.high,
    );
  }

  AppErrorCategory _categoryFromWire(String? value) {
    return switch (value) {
      'AUTH' => AppErrorCategory.auth,
      'AUTHORIZATION' => AppErrorCategory.authorization,
      'VALIDATION' => AppErrorCategory.validation,
      'BUSINESS_RULE' => AppErrorCategory.businessRule,
      'DATA' => AppErrorCategory.data,
      'NETWORK' => AppErrorCategory.network,
      'STORAGE' => AppErrorCategory.storage,
      'REALTIME' => AppErrorCategory.realtime,
      'EXPORT' => AppErrorCategory.export,
      _ => AppErrorCategory.system,
    };
  }

  AppErrorSeverity _severityFromWire(String? value) {
    return switch (value) {
      'low' => AppErrorSeverity.low,
      'medium' => AppErrorSeverity.medium,
      'critical' => AppErrorSeverity.critical,
      _ => AppErrorSeverity.high,
    };
  }
}
