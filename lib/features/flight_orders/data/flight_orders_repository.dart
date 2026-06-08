import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final flightOrdersRepositoryProvider = Provider<FlightOrdersRepository>((ref) {
  return SupabaseFlightOrdersRepository(Supabase.instance.client);
});

abstract class FlightOrdersRepository {
  Future<AppResult<List<FlightOrder>>> listFlightOrders();
  Future<AppResult<List<FlightOrderItem>>> listItems(String flightOrderId);
  Future<AppResult<FlightOrder>> manageFlightOrder({
    String? flightOrderId,
    required String action,
    String? unitId,
    String? operationDate,
    List<Map<String, dynamic>>? items,
  });
  Future<AppResult<void>> advanceItemState(String itemId, String nextStatus);
  Future<AppResult<void>> cancelItem({
    required String itemId,
    required String reason,
  });
  Future<AppResult<FlightOrderItem>> addItem({
    required String flightOrderId,
    required Map<String, dynamic> item,
  });
  Future<AppResult<FlightOrderItem>> updateItem({
    required String flightOrderId,
    required String itemId,
    required Map<String, dynamic> item,
  });
  Future<AppResult<FlightOrderProfile>> addOrderProfile({
    required String flightOrderId,
    required String description,
  });
  Future<AppResult<void>> removeOrderProfile(String profileId);
  Future<AppResult<List<FlightOrderProfile>>> listOrderProfiles(
    String flightOrderId,
  );
  Future<AppResult<void>> deleteFlightOrder(String flightOrderId);
  Future<AppResult<List<FlightOrderItem>>> listFlightsByDate({
    required DateTime date,
    String? unitId,
  });
  Future<AppResult<List<FlightOrderItem>>> listItemsByAircraft({
    required String aircraftId,
    required DateTime from,
    required DateTime to,
  });
}

class SupabaseFlightOrdersRepository implements FlightOrdersRepository {
  SupabaseFlightOrdersRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppResult<List<FlightOrder>>> listFlightOrders() async {
    try {
      final rows = await _client
          .from('flight_orders')
          .select('*, units(name), flight_order_items(count)')
          .order('operation_date', ascending: false)
          .limit(100);

      final orders = (rows as List<dynamic>)
          .where((r) => (r as Map<String, dynamic>)['deleted_at'] == null)
          .map((r) {
        final json = r as Map<String, dynamic>;
        final itemsData = json['flight_order_items'] as List<dynamic>?;
        if (itemsData != null && itemsData.isNotEmpty) {
          final first = itemsData.first as Map<String, dynamic>?;
          if (first != null && first['count'] != null) {
            json['items_count'] = first['count'];
          }
        }
        return FlightOrder.fromJson(json);
      }).toList();

      return AppSuccess(orders);
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudieron cargar las órdenes de vuelo.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<FlightOrderItem>>> listItems(
    String flightOrderId,
  ) async {
    try {
      final rows = await _client
          .from('flight_order_items')
          .select('*')
          .eq('flight_order_id', flightOrderId)
          .order('created_at');

      final baseItems = (rows as List<dynamic>)
          .map((r) => FlightOrderItem.fromJson(r as Map<String, dynamic>))
          .toList();

      if (baseItems.isEmpty) return AppSuccess(baseItems);

      final itemIds = baseItems.map((i) => i.id).toList();

      // Batch load related data
      final results = await Future.wait([
        _client
            .from('aircraft')
            .select('id, tail_number, model')
            .inFilter('id', baseItems.map((i) => i.aircraftId).toList()),
        _client
            .from('flight_order_routes')
            .select(
              '*, origin_route:origin_route_id(airport_name, icao_code, latitude, longitude), destination_route:destination_route_id(airport_name, icao_code, latitude, longitude)',
            )
            .inFilter('flight_order_item_id', itemIds),
        _client
            .from('flight_order_crew')
            .select(
              '*, crew_member:crew_member_id(grade,first_name,last_name,callsign)',
            )
            .inFilter('flight_order_item_id', itemIds),
        _client
            .from('flight_order_state_events')
            .select('*')
            .inFilter('flight_order_item_id', itemIds),
      ]);

      final aircraftRows = results[0] as List<dynamic>;
      final routeRows = results[1] as List<dynamic>;
      final crewRows = results[2] as List<dynamic>;
      final eventRows = results[3] as List<dynamic>;

      final aircraftMap = <String, Map<String, dynamic>>{};
      for (final a in aircraftRows) {
        final m = a as Map<String, dynamic>;
        aircraftMap[m['id'].toString()] = m;
      }

      final items = baseItems.map((item) {
        final ac = aircraftMap[item.aircraftId];
        final itemRoutes = routeRows
            .where(
              (r) =>
                  (r as Map<String, dynamic>)['flight_order_item_id']
                      .toString() ==
                  item.id,
            )
            .map((r) => FlightOrderRoute.fromJson(r as Map<String, dynamic>))
            .toList();
        final itemCrew = crewRows
            .where(
              (c) =>
                  (c as Map<String, dynamic>)['flight_order_item_id']
                      .toString() ==
                  item.id,
            )
            .map((c) => FlightOrderCrew.fromJson(c as Map<String, dynamic>))
            .toList();
        final itemEvents = eventRows
            .where(
              (e) =>
                  (e as Map<String, dynamic>)['flight_order_item_id']
                      .toString() ==
                  item.id,
            )
            .map(
              (e) => FlightOrderStateEvent.fromJson(e as Map<String, dynamic>),
            )
            .toList();

        return item.copyWith(
          aircraftRegistration: ac?['tail_number']?.toString(),
          aircraftModel: ac?['model']?.toString(),
          routes: itemRoutes,
          crew: itemCrew,
          stateEvents: itemEvents,
        );
      }).toList();

      return AppSuccess(items);
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudieron cargar los ítems de la orden.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<FlightOrderItem>>> listFlightsByDate({
    required DateTime date,
    String? unitId,
  }) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // 1. Get flight orders for the date (only approved/closed/reopened)
      var query = _client
          .from('flight_orders')
          .select(
            'id, order_number, unit_id, status, units(name, code, acronym)',
          )
          .eq('operation_date', dateStr)
          .inFilter('status', ['approved', 'closed', 'reopened']);

      if (unitId != null) {
        query = query.eq('unit_id', unitId);
      }

      final orderRows = await query;
      if (orderRows.isEmpty) return const AppSuccess([]);

      final orders = <String, Map<String, dynamic>>{};
      for (final o in orderRows) {
        final m = Map<String, dynamic>.from(o);
        orders[m['id'].toString()] = m;
      }

      // 2. Get all items for these orders
      final orderIds = orders.keys.toList();
      final itemRows = await _client
          .from('flight_order_items')
          .select('*')
          .inFilter('flight_order_id', orderIds)
          .order('created_at');

      final baseItems = (itemRows as List)
          .map((r) => FlightOrderItem.fromJson(r as Map<String, dynamic>))
          .toList();

      if (baseItems.isEmpty) return const AppSuccess([]);

      final itemIds = baseItems.map((i) => i.id).toList();

      // 3. Batch load related data (same pattern as listItems)
      final results = await Future.wait([
        _client
            .from('aircraft')
            .select('id, tail_number, model')
            .inFilter('id', baseItems.map((i) => i.aircraftId).toList()),
        _client
            .from('flight_order_routes')
            .select(
              '*, origin_route:origin_route_id(airport_name, icao_code, latitude, longitude), destination_route:destination_route_id(airport_name, icao_code, latitude, longitude)',
            )
            .inFilter('flight_order_item_id', itemIds),
        _client
            .from('flight_order_crew')
            .select(
              '*, crew_member:crew_member_id(grade,first_name,last_name,callsign)',
            )
            .inFilter('flight_order_item_id', itemIds),
        _client
            .from('flight_order_state_events')
            .select('*')
            .inFilter('flight_order_item_id', itemIds),
      ]);

      final aircraftRows = results[0] as List<dynamic>;
      final routeRows = results[1] as List<dynamic>;
      final crewRows = results[2] as List<dynamic>;
      final eventRows = results[3] as List<dynamic>;

      final aircraftMap = <String, Map<String, dynamic>>{};
      for (final a in aircraftRows) {
        final m = a as Map<String, dynamic>;
        aircraftMap[m['id'].toString()] = m;
      }

      final items = baseItems.map((item) {
        final ac = aircraftMap[item.aircraftId];
        final order = orders[item.flightOrderId];
        final itemRoutes = routeRows
            .where(
              (r) =>
                  (r as Map<String, dynamic>)['flight_order_item_id']
                      .toString() ==
                  item.id,
            )
            .map((r) => FlightOrderRoute.fromJson(r as Map<String, dynamic>))
            .toList();
        final itemCrew = crewRows
            .where(
              (c) =>
                  (c as Map<String, dynamic>)['flight_order_item_id']
                      .toString() ==
                  item.id,
            )
            .map((c) => FlightOrderCrew.fromJson(c as Map<String, dynamic>))
            .toList();
        final itemEvents = eventRows
            .where(
              (e) =>
                  (e as Map<String, dynamic>)['flight_order_item_id']
                      .toString() ==
                  item.id,
            )
            .map(
              (e) => FlightOrderStateEvent.fromJson(e as Map<String, dynamic>),
            )
            .toList();

        return item.copyWith(
          aircraftRegistration: ac?['tail_number']?.toString(),
          aircraftModel: ac?['model']?.toString(),
          orderNumber: order?['order_number']?.toString(),
          unitId: order?['unit_id']?.toString(),
          unitName: (order?['units'] is Map)
              ? ((order!['units'] as Map)['acronym']?.toString() ??
                    (order['units'] as Map)['code']?.toString() ??
                    (order['units'] as Map)['name']?.toString())
              : null,
          orderStatus: order?['status']?.toString(),
          routes: itemRoutes,
          crew: itemCrew,
          stateEvents: itemEvents,
        );
      }).toList();

      return AppSuccess(items);
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudieron cargar los vuelos.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<FlightOrderItem>>> listItemsByAircraft({
    required String aircraftId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final fromStr = _dateOnly(from);
      final toStr = _dateOnly(to);

      final orderRows = await _client
          .from('flight_orders')
          .select(
            'id, order_number, unit_id, status, operation_date, units(name, code, acronym)',
          )
          .gte('operation_date', fromStr)
          .lte('operation_date', toStr)
          .order('operation_date', ascending: false);

      if (orderRows.isEmpty) return const AppSuccess([]);

      final orders = <String, Map<String, dynamic>>{};
      for (final o in orderRows) {
        final m = Map<String, dynamic>.from(o);
        orders[m['id'].toString()] = m;
      }

      final itemRows = await _client
          .from('flight_order_items')
          .select('*')
          .eq('aircraft_id', aircraftId)
          .inFilter('flight_order_id', orders.keys.toList())
          .order('created_at');

      final baseItems = (itemRows as List)
          .map((r) => FlightOrderItem.fromJson(r as Map<String, dynamic>))
          .toList();

      if (baseItems.isEmpty) return const AppSuccess([]);

      final itemIds = baseItems.map((i) => i.id).toList();
      final routeRows = await _client
          .from('flight_order_routes')
          .select(
            '*, origin_route:origin_route_id(airport_name, icao_code, latitude, longitude), destination_route:destination_route_id(airport_name, icao_code, latitude, longitude)',
          )
          .inFilter('flight_order_item_id', itemIds);

      final items =
          baseItems.map((item) {
            final order = orders[item.flightOrderId];
            final itemRoutes = (routeRows as List)
                .where(
                  (r) =>
                      (r as Map<String, dynamic>)['flight_order_item_id']
                          .toString() ==
                      item.id,
                )
                .map(
                  (r) => FlightOrderRoute.fromJson(r as Map<String, dynamic>),
                )
                .toList();

            return item.copyWith(
              orderNumber: order?['order_number']?.toString(),
              operationDate: order?['operation_date'] != null
                  ? DateTime.tryParse(order!['operation_date'].toString())
                  : null,
              unitId: order?['unit_id']?.toString(),
              unitName: (order?['units'] is Map)
                  ? ((order!['units'] as Map)['acronym']?.toString() ??
                        (order['units'] as Map)['code']?.toString() ??
                        (order['units'] as Map)['name']?.toString())
                  : null,
              orderStatus: order?['status']?.toString(),
              routes: itemRoutes,
            );
          }).toList()..sort((a, b) {
            final aDate =
                a.operationDate ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                b.operationDate ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

      return AppSuccess(items);
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudieron cargar las órdenes relacionadas.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  String _dateOnly(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  FlightOrderItem _parseItem(Map<String, dynamic> json) {
    final item = FlightOrderItem.fromJson(json);

    final routes =
        (json['routes'] as List<dynamic>?)
            ?.map((r) => FlightOrderRoute.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];
    final crew =
        (json['crew'] as List<dynamic>?)
            ?.map((c) => FlightOrderCrew.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];
    final profiles = <FlightOrderProfile>[];
    final profileIds = <String>[];
    final rawProfiles = json['profiles'] as List<dynamic>?;
    if (rawProfiles != null) {
      for (final p in rawProfiles) {
        final map = p as Map<String, dynamic>;
        final profileData = map['profile'] as Map<String, dynamic>?;
        if (profileData != null) {
          profiles.add(FlightOrderProfile.fromJson(profileData));
          profileIds.add(profileData['id'].toString());
        }
      }
    }

    final stateEvents =
        (json['state_events'] as List<dynamic>?)
            ?.map(
              (e) => FlightOrderStateEvent.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        [];

    return item.copyWith(
      routes: routes,
      crew: crew,
      profiles: profiles,
      profileIds: profileIds,
      stateEvents: stateEvents,
    );
  }

  @override
  Future<AppResult<FlightOrder>> manageFlightOrder({
    String? flightOrderId,
    required String action,
    String? unitId,
    String? operationDate,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final body = <String, dynamic>{
        'action': action,
        'flight_order_id': ?flightOrderId,
        'unit_id': ?unitId,
        'operation_date': ?operationDate,
        'items': ?items,
      };

      final response = await _client.functions.invoke(
        'manage-flight-order',
        body: body,
      );

      if (response.data is Map && (response.data as Map)['ok'] == true) {
        final data = (response.data as Map)['data'] as Map<String, dynamic>;
        return AppSuccess(FlightOrder.fromJson(data));
      }

      return AppFailure(_errorFromBody(response.data));
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo procesar la orden de vuelo.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> advanceItemState(
    String itemId,
    String nextStatus,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'manage-flight-order',
        body: {
          'action': 'advance_state',
          'item_id': itemId,
          'next_status': nextStatus,
        },
      );

      if (response.data is Map && (response.data as Map)['ok'] == true) {
        return const AppSuccess(null);
      }

      return AppFailure(_errorFromBody(response.data));
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo actualizar el estado.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> cancelItem({
    required String itemId,
    required String reason,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'manage-flight-order',
        body: {
          'action': 'cancel_item',
          'item_id': itemId,
          'cancel_reason': reason,
        },
      );

      if (response.data is Map && (response.data as Map)['ok'] == true) {
        return const AppSuccess(null);
      }

      return AppFailure(_errorFromBody(response.data));
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo cancelar el vuelo.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<FlightOrderItem>> addItem({
    required String flightOrderId,
    required Map<String, dynamic> item,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'manage-flight-order',
        body: {
          'action': 'add_item',
          'flight_order_id': flightOrderId,
          'item': item,
        },
      );

      final body = response.data;
      if (body is Map && body['ok'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        return AppSuccess(_parseItem(data));
      }

      return AppFailure(_errorFromBody(body));
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo agregar el vuelo.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<FlightOrderItem>> updateItem({
    required String flightOrderId,
    required String itemId,
    required Map<String, dynamic> item,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'manage-flight-order',
        body: {
          'action': 'update_item',
          'flight_order_id': flightOrderId,
          'item_id': itemId,
          'item': item,
        },
      );

      final body = response.data;
      if (body is Map && body['ok'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        return AppSuccess(_parseItem(data));
      }

      return AppFailure(_errorFromBody(body));
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo actualizar el vuelo.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<FlightOrderProfile>> addOrderProfile({
    required String flightOrderId,
    required String description,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'manage-flight-order',
        body: {
          'action': 'add_profile',
          'flight_order_id': flightOrderId,
          'description': description,
        },
      );

      final body = response.data;
      if (body is Map && body['ok'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        return AppSuccess(FlightOrderProfile.fromJson(data));
      }

      return AppFailure(_errorFromBody(body));
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo agregar el perfil.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> removeOrderProfile(String profileId) async {
    try {
      await _client
          .from('flight_order_profiles')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', profileId);
      return const AppSuccess(null);
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo eliminar el perfil.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<List<FlightOrderProfile>>> listOrderProfiles(
    String flightOrderId,
  ) async {
    try {
      final rows = await _client
          .from('flight_order_profiles')
          .select('*')
          .eq('flight_order_id', flightOrderId)
          .order('profile_number');

      final profiles = (rows as List<dynamic>)
          .where((r) => (r as Map<String, dynamic>)['deleted_at'] == null)
          .map((r) => FlightOrderProfile.fromJson(r as Map<String, dynamic>))
          .toList();

      return AppSuccess(profiles);
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudieron cargar los perfiles.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> deleteFlightOrder(String flightOrderId) async {
    try {
      await _client
          .from('flight_orders')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', flightOrderId);
      return const AppSuccess(null);
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo borrar la orden de vuelo.',
          category: AppErrorCategory.system,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  AppError _errorFromBody(Object? body) {
    if (body is Map) {
      final error = body['error'];
      if (error is Map) {
        return AppError(
          code: error['code']?.toString() ?? 'SYSTEM_UNEXPECTED',
          message: error['message']?.toString() ?? 'Error desconocido.',
          category: _categoryFromWire(error['category']?.toString()),
          severity: _severityFromWire(error['severity']?.toString()),
        );
      }
    }
    return const AppError(
      code: 'SYSTEM_UNEXPECTED',
      message: 'Error desconocido.',
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
