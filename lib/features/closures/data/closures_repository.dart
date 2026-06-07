import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final closuresRepositoryProvider = Provider<ClosuresRepository>((ref) {
  return SupabaseClosuresRepository(Supabase.instance.client);
});

abstract class ClosuresRepository {
  Future<AppResult<List<FlightOrder>>> listPendingClosures({String? unitId});
  Future<AppResult<List<FlightOrder>>> listClosedOrders({String? unitId});
  Future<AppResult<Map<String, dynamic>>> getClosureSummary(String orderId);
  Future<AppResult<void>> closeOrder(String orderId, {String? reason});
  Future<AppResult<void>> reopenOrder(String orderId, {String? reason});
}

class SupabaseClosuresRepository implements ClosuresRepository {
  SupabaseClosuresRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<AppResult<List<FlightOrder>>> listPendingClosures({String? unitId}) async {
    try {
      var query = _client.from('flight_orders').select(
        'id,unit_id,operation_date,status,submitted_at,approved_at,closed_at,'
        'created_by,approved_by,closed_by,created_at,updated_at,'
        'units!inner(code,name)'
      ).eq('status', 'approved');

      if (unitId != null) query = query.eq('unit_id', unitId);

      final rows = await query.order('operation_date', ascending: false);
      // Filter: only show orders where ALL flights are engine_shutdown
      final orders = rows.map<FlightOrder>((r) => FlightOrder.fromJson(Map<String, dynamic>.from(r))).toList();
      final result = <FlightOrder>[];
      for (final order in orders) {
        final flights = await _client.from('flights').select('id').eq('flight_order_id', order.id).eq('closed', false);
        if (flights.isEmpty) continue;
        bool allDone = true;
        for (final f in flights) {
          final lastEvent = await _client.from('flight_status_events').select('status').eq('flight_id', f['id']).order('occurred_at', ascending: false).limit(1).maybeSingle();
          if (lastEvent == null || lastEvent['status'] != 'engine_shutdown') { allDone = false; break; }
        }
        if (allDone) result.add(order);
      }
      return AppSuccess(result);
    } catch (_) {
      return const AppFailure(AppError(code: 'CLOSURES_LOAD_FAILED', message: 'No se pudo cargar cierres pendientes.', category: AppErrorCategory.data, severity: AppErrorSeverity.high));
    }
  }

  @override
  Future<AppResult<List<FlightOrder>>> listClosedOrders({String? unitId}) async {
    try {
      var query = _client.from('flight_orders').select(
        'id,unit_id,operation_date,status,submitted_at,approved_at,closed_at,'
        'created_by,approved_by,closed_by,created_at,updated_at,'
        'units!inner(code,name)'
      ).inFilter('status', ['closed']);

      if (unitId != null) query = query.eq('unit_id', unitId);

      final rows = await query.order('closed_at', ascending: false);
      return AppSuccess(rows.map<FlightOrder>((r) => FlightOrder.fromJson(Map<String, dynamic>.from(r))).toList());
    } catch (_) {
      return const AppFailure(AppError(code: 'CLOSURES_LOAD_FAILED', message: 'No se pudo cargar historico.', category: AppErrorCategory.data, severity: AppErrorSeverity.high));
    }
  }

  @override
  Future<AppResult<Map<String, dynamic>>> getClosureSummary(String orderId) async {
    try {
      // Get flights with their items
      final flights = await _client.from('flights').select(
        'id,aircraft_id,route_id,actual_total_minutes,actual_air_minutes,'
        'aircraft(tail_number,model),routes(origin,destination)'
      ).eq('flight_order_id', orderId).eq('closed', false);

      // Get status events per flight
      final summary = <String, dynamic>{
        'totalFlights': flights.length,
        'totalMinutes': 0,
        'aircraft': <String, dynamic>{},
        'crew': <String, dynamic>{},
        'models': <String, dynamic>{},
        'details': <Map<String, dynamic>>[],
      };

      for (final f in flights) {
        final flightId = f['id'];
        final tailNumber = f['aircraft']?['tail_number']?.toString() ?? 'N/A';
        final model = f['aircraft']?['model']?.toString() ?? 'N/A';
        final origin = f['routes']?['origin']?.toString() ?? '';
        final dest = f['routes']?['destination']?.toString() ?? '';

        // Get actual times from status events
        final events = await _client.from('flight_status_events')
          .select('status,occurred_at').eq('flight_id', flightId).order('occurred_at');

        int minutes = 0;
        if (events.length >= 2) {
          final first = DateTime.parse(events.first['occurred_at']);
          final last = DateTime.parse(events.last['occurred_at']);
          minutes = last.difference(first).inMinutes;
        }

        summary['totalMinutes'] = (summary['totalMinutes'] as int) + minutes;

        // By aircraft
        final acKey = tailNumber;
        if (summary['aircraft'][acKey] == null) summary['aircraft'][acKey] = {'minutes': 0, 'flights': 0, 'model': model};
        summary['aircraft'][acKey]['minutes'] += minutes;
        summary['aircraft'][acKey]['flights'] += 1;

        // By model
        if (summary['models'][model] == null) summary['models'][model] = {'minutes': 0, 'flights': 0};
        summary['models'][model]['minutes'] += minutes;
        summary['models'][model]['flights'] += 1;

        // Get crew for this flight
        final crewRows = await _client.from('flight_crew').select(
          'crew_member_id,function_code,crew_members(first_name,last_name,crew_category)'
        ).eq('flight_id', flightId);

        for (final c in crewRows) {
          final name = '${c['crew_members']?['first_name'] ?? ''} ${c['crew_members']?['last_name'] ?? ''}'.trim();
          final role = c['function_code']?.toString() ?? c['crew_members']?['crew_category']?.toString() ?? '';
          if (summary['crew'][name] == null) summary['crew'][name] = {'minutes': 0, 'flights': 0, 'role': role};
          summary['crew'][name]['minutes'] += minutes;
          summary['crew'][name]['flights'] += 1;
        }

        (summary['details'] as List).add({
          'tailNumber': tailNumber, 'model': model, 'origin': origin, 'dest': dest,
          'minutes': minutes,
          'crew': crewRows.map((c) => '${c['crew_members']?['first_name'] ?? ''} ${c['crew_members']?['last_name'] ?? ''}'.trim()).toList(),
        });
      }

      return AppSuccess(summary);
    } catch (_) {
      return const AppFailure(AppError(code: 'SUMMARY_LOAD_FAILED', message: 'No se pudo cargar el resumen.', category: AppErrorCategory.data, severity: AppErrorSeverity.high));
    }
  }

  @override
  Future<AppResult<void>> closeOrder(String orderId, {String? reason}) async {
    try {
      final response = await _client.functions.invoke('manage-closure', body: {
        'action': 'close', 'flight_order_id': orderId, 'reason': reason ?? '',
      });
      final body = response.data;
      if (body is Map && body['ok'] == true) return const AppSuccess(null);
      return AppFailure(_errorFromBody(body));
    } catch (_) {
      return const AppFailure(AppError(code: 'CLOSURE_FAILED', message: 'No se pudo cerrar la OV.', category: AppErrorCategory.system, severity: AppErrorSeverity.high));
    }
  }

  @override
  Future<AppResult<void>> reopenOrder(String orderId, {String? reason}) async {
    try {
      final response = await _client.functions.invoke('manage-closure', body: {
        'action': 'reopen', 'flight_order_id': orderId, 'reason': reason ?? '',
      });
      final body = response.data;
      if (body is Map && body['ok'] == true) return const AppSuccess(null);
      return AppFailure(_errorFromBody(body));
    } catch (_) {
      return const AppFailure(AppError(code: 'REOPEN_FAILED', message: 'No se pudo reabrir la OV.', category: AppErrorCategory.system, severity: AppErrorSeverity.high));
    }
  }

  AppError _errorFromBody(Object? body) {
    if (body is Map && body['error'] is Map) {
      final e = body['error'] as Map;
      return AppError(code: e['code']?.toString() ?? 'SYSTEM_UNEXPECTED', message: e['message']?.toString() ?? 'Operacion no completada.', category: AppErrorCategory.system, severity: AppErrorSeverity.high);
    }
    return const AppError(code: 'SYSTEM_UNEXPECTED', message: 'Operacion no completada.', category: AppErrorCategory.system, severity: AppErrorSeverity.high);
  }
}
