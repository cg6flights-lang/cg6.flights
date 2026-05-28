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
  Future<AppResult<FlightOrderProfile>> addOrderProfile({
    required String flightOrderId,
    required String description,
  });
  Future<AppResult<void>> removeOrderProfile(String profileId);
  Future<AppResult<List<FlightOrderProfile>>> listOrderProfiles(
      String flightOrderId);
  Future<AppResult<void>> deleteFlightOrder(String flightOrderId);
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

      final orders = (rows as List<dynamic>).map((r) {
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
      return const AppFailure(AppError(
        code: 'SYSTEM_UNEXPECTED',
        message: 'No se pudieron cargar las órdenes de vuelo.',
        category: AppErrorCategory.system,
        severity: AppErrorSeverity.high,
      ));
    }
  }

  @override
  Future<AppResult<List<FlightOrderItem>>> listItems(
      String flightOrderId) async {
    try {
      final rows = await _client
          .from('flight_order_items')
          .select('*')
          .eq('flight_order_id', flightOrderId)
          .order('created_at');

      final items = (rows as List<dynamic>)
          .map((r) => FlightOrderItem.fromJson(r as Map<String, dynamic>))
          .toList();

      return AppSuccess(items);
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (e) {
      print('[DEBUG] listItems basic query failed for $flightOrderId: $e');
      return const AppFailure(AppError(
        code: 'SYSTEM_UNEXPECTED',
        message: 'No se pudieron cargar los ítems de la orden.',
        category: AppErrorCategory.system,
        severity: AppErrorSeverity.high,
      ));
    }
  }

  FlightOrderItem _parseItem(Map<String, dynamic> json) {
    final item = FlightOrderItem.fromJson(json);

    final routes = (json['routes'] as List<dynamic>?)
            ?.map((r) => FlightOrderRoute.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];
    final crew = (json['crew'] as List<dynamic>?)
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

    final stateEvents = (json['state_events'] as List<dynamic>?)
            ?.map((e) =>
                FlightOrderStateEvent.fromJson(e as Map<String, dynamic>))
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

      final response =
          await _client.functions.invoke('manage-flight-order', body: body);

      if (response.data is Map && (response.data as Map)['ok'] == true) {
        final data = (response.data as Map)['data'] as Map<String, dynamic>;
        return AppSuccess(FlightOrder.fromJson(data));
      }

      return AppFailure(_errorFromBody(response.data));
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(AppError(
        code: 'SYSTEM_UNEXPECTED',
        message: 'No se pudo procesar la orden de vuelo.',
        category: AppErrorCategory.system,
        severity: AppErrorSeverity.high,
      ));
    }
  }

  @override
  Future<AppResult<void>> advanceItemState(
      String itemId, String nextStatus) async {
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
      return const AppFailure(AppError(
        code: 'SYSTEM_UNEXPECTED',
        message: 'No se pudo actualizar el estado.',
        category: AppErrorCategory.system,
        severity: AppErrorSeverity.high,
      ));
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
      return const AppFailure(AppError(
        code: 'SYSTEM_UNEXPECTED',
        message: 'No se pudo cancelar el vuelo.',
        category: AppErrorCategory.system,
        severity: AppErrorSeverity.high,
      ));
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
      return const AppFailure(AppError(
        code: 'SYSTEM_UNEXPECTED',
        message: 'No se pudo agregar el vuelo.',
        category: AppErrorCategory.system,
        severity: AppErrorSeverity.high,
      ));
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
      return const AppFailure(AppError(
        code: 'SYSTEM_UNEXPECTED',
        message: 'No se pudo agregar el perfil.',
        category: AppErrorCategory.system,
        severity: AppErrorSeverity.high,
      ));
    }
  }

  @override
  Future<AppResult<void>> removeOrderProfile(String profileId) async {
    try {
      final response = await _client.functions.invoke(
        'manage-flight-order',
        body: {
          'action': 'remove_profile',
          'profile_id': profileId,
        },
      );

      if (response.data is Map && (response.data as Map)['ok'] == true) {
        return const AppSuccess(null);
      }

      return AppFailure(_errorFromBody(response.data));
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(AppError(
        code: 'SYSTEM_UNEXPECTED',
        message: 'No se pudo eliminar el perfil.',
        category: AppErrorCategory.system,
        severity: AppErrorSeverity.high,
      ));
    }
  }

  @override
  Future<AppResult<List<FlightOrderProfile>>> listOrderProfiles(
      String flightOrderId) async {
    try {
      final rows = await _client
          .from('flight_order_profiles')
          .select('*')
          .eq('flight_order_id', flightOrderId)
          .order('profile_number');

      final profiles = (rows as List<dynamic>)
          .map((r) => FlightOrderProfile.fromJson(r as Map<String, dynamic>))
          .toList();

      return AppSuccess(profiles);
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(AppError(
        code: 'SYSTEM_UNEXPECTED',
        message: 'No se pudieron cargar los perfiles.',
        category: AppErrorCategory.system,
        severity: AppErrorSeverity.high,
      ));
    }
  }

  @override
  Future<AppResult<void>> deleteFlightOrder(String flightOrderId) async {
    try {
      final response = await _client.functions.invoke(
        'manage-flight-order',
        body: {
          'action': 'delete',
          'flight_order_id': flightOrderId,
        },
      );

      if (response.data is Map && (response.data as Map)['ok'] == true) {
        return const AppSuccess(null);
      }

      return AppFailure(_errorFromBody(response.data));
    } on FunctionException catch (e) {
      return AppFailure(_errorFromBody(e.details));
    } catch (_) {
      return const AppFailure(AppError(
        code: 'SYSTEM_UNEXPECTED',
        message: 'No se pudo borrar la orden de vuelo.',
        category: AppErrorCategory.system,
        severity: AppErrorSeverity.high,
      ));
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
