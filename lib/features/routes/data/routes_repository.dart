import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/routes/domain/route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final routesRepositoryProvider = Provider<RoutesRepository>((ref) {
  return SupabaseRoutesRepository(Supabase.instance.client);
});

abstract class RoutesRepository {
  Future<AppResult<List<Route>>> listRoutes();

  Future<AppResult<void>> saveRoute({
    String? routeId,
    required String airportName,
    required String category,
    String? icaoCode,
    String? iataCode,
    required String country,
    required String city,
    double? latitude,
    double? longitude,
  });

  Future<AppResult<void>> deactivateRoute(String routeId);
}

class SupabaseRoutesRepository implements RoutesRepository {
  SupabaseRoutesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AppResult<List<Route>>> listRoutes() async {
    try {
      final rows = await _client
          .from('routes')
          .select(
            'id,airport_name,category,icao_code,iata_code,country,city,latitude,longitude,active',
          )
          .eq('active', true)
          .order('airport_name');
      return AppSuccess(
        rows
            .map<Route>(
              (row) => Route.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList(),
      );
    } catch (_) {
      return const AppFailure(
        AppError(
          code: 'SYSTEM_UNEXPECTED',
          message: 'No se pudo cargar rutas.',
          category: AppErrorCategory.data,
          severity: AppErrorSeverity.high,
        ),
      );
    }
  }

  @override
  Future<AppResult<void>> saveRoute({
    String? routeId,
    required String airportName,
    required String category,
    String? icaoCode,
    String? iataCode,
    required String country,
    required String city,
    double? latitude,
    double? longitude,
  }) async {
    final action = routeId == null ? 'create' : 'update';
    return _manageRoute(
      action: action,
      routeId: routeId,
      airportName: airportName,
      category: category,
      icaoCode: icaoCode,
      iataCode: iataCode,
      country: country,
      city: city,
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  Future<AppResult<void>> deactivateRoute(String routeId) {
    return _manageRoute(action: 'deactivate', routeId: routeId);
  }

  Future<AppResult<void>> _manageRoute({
    required String action,
    String? routeId,
    String? airportName,
    String? category,
    String? icaoCode,
    String? iataCode,
    String? country,
    String? city,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'manage-route',
        body: {
          'action': action,
          'route_id': routeId,
          'airport_name': airportName,
          'category': category,
          'icao_code': icaoCode,
          'iata_code': iataCode,
          'country': country,
          'city': city,
          'latitude': latitude,
          'longitude': longitude,
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
          message: 'No se pudo guardar la ruta.',
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
