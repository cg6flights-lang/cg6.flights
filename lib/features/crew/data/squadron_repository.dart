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
  Future<AppResult<void>> updateSquadronName({
    required String squadronId,
    required String name,
  });
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
}
