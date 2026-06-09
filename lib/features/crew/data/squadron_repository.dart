import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/crew/domain/squadron.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final squadronRepositoryProvider = Provider<SquadronRepository>((ref) {
  return SupabaseSquadronRepository(Supabase.instance.client);
});

abstract class SquadronRepository {
  Future<AppResult<List<FlightSquadron>>> listSquadrons({String? unitId});
  Future<AppResult<List<FlightSquadron>>> listAllSquadrons({String? unitId});
  Future<AppResult<void>> updateSquadronName({
    required String squadronId,
    required String name,
  });
  Future<AppResult<FlightSquadron>> createSquadron({
    required String unitId,
    required String name,
  });
  Future<AppResult<void>> toggleSquadron(String squadronId);
}

class SupabaseSquadronRepository implements SquadronRepository {
  SupabaseSquadronRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<AppResult<List<FlightSquadron>>> listSquadrons({String? unitId}) async {
    try {
      var query = _client.from('flight_squadrons').select('*').eq('active', true);
      if (unitId != null) query = query.eq('unit_id', unitId);
      final rows = await query.order('display_order');
      return AppSuccess(
        (rows as List<dynamic>)
            .map((r) => FlightSquadron.fromJson(Map<String, dynamic>.from(r)))
            .toList(),
      );
    } catch (_) {
      return const AppFailure(
        AppError(code: 'SQUADRON_LOAD_FAILED', message: 'No se pudieron cargar los escuadrones.', category: AppErrorCategory.data, severity: AppErrorSeverity.low),
      );
    }
  }

  @override
  Future<AppResult<void>> updateSquadronName({
    required String squadronId,
    required String name,
  }) async {
    try {
      await _client.from('flight_squadrons').update({'name': name, 'updated_at': DateTime.now().toIso8601String()}).eq('id', squadronId);
      return const AppSuccess(null);
    } catch (_) {
      return const AppFailure(
        AppError(code: 'SQUADRON_UPDATE_FAILED', message: 'No se pudo actualizar el escuadrón.', category: AppErrorCategory.data, severity: AppErrorSeverity.high),
      );
    }
  }

  @override
  Future<AppResult<List<FlightSquadron>>> listAllSquadrons({String? unitId}) async {
    try {
      var query = _client.from('flight_squadrons').select('*');
      if (unitId != null) query = query.eq('unit_id', unitId);
      final rows = await query.order('display_order');
      return AppSuccess(
        (rows as List<dynamic>)
            .map((r) => FlightSquadron.fromJson(Map<String, dynamic>.from(r)))
            .toList(),
      );
    } catch (_) {
      return const AppFailure(
        AppError(code: 'SQUADRON_LOAD_FAILED', message: 'No se pudieron cargar los escuadrones.', category: AppErrorCategory.data, severity: AppErrorSeverity.low),
      );
    }
  }

  @override
  Future<AppResult<FlightSquadron>> createSquadron({
    required String unitId,
    required String name,
  }) async {
    try {
      final maxOrder = await _client.from('flight_squadrons').select('display_order').eq('unit_id', unitId).order('display_order', ascending: false).limit(1);
      final nextOrder = (maxOrder is List && maxOrder.isNotEmpty ? (maxOrder.first as Map)['display_order'] as int? : 0) ?? 0;
      final row = await _client.from('flight_squadrons').insert({
        'unit_id': unitId,
        'name': name,
        'display_order': nextOrder + 1,
        'active': true,
      }).select('*').single();
      return AppSuccess(FlightSquadron.fromJson(Map<String, dynamic>.from(row)));
    } catch (_) {
      return const AppFailure(
        AppError(code: 'SQUADRON_CREATE_FAILED', message: 'No se pudo crear el escuadrón.', category: AppErrorCategory.data, severity: AppErrorSeverity.high),
      );
    }
  }

  @override
  Future<AppResult<void>> toggleSquadron(String squadronId) async {
    try {
      final current = await _client.from('flight_squadrons').select('active').eq('id', squadronId).single();
      final newActive = !(current['active'] as bool);
      await _client.from('flight_squadrons').update({'active': newActive, 'updated_at': DateTime.now().toIso8601String()}).eq('id', squadronId);
      return const AppSuccess(null);
    } catch (_) {
      return const AppFailure(
        AppError(code: 'SQUADRON_TOGGLE_FAILED', message: 'No se pudo cambiar el estado del escuadrón.', category: AppErrorCategory.data, severity: AppErrorSeverity.high),
      );
    }
  }
}
