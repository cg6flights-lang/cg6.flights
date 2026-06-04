import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/state/timezone_provider.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/aircraft/data/aircraft_repository.dart';
import 'package:cg6_flights/features/aircraft/domain/operational_data_point.dart';
import 'package:cg6_flights/features/audit/data/audit_repository.dart';
import 'package:cg6_flights/features/audit/domain/audit_log.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/features/messages/data/messages_repository.dart';
import 'package:cg6_flights/features/messages/domain/message_post.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _todayProvider = Provider<DateTime>((ref) {
  final tz = ref.watch(timezoneProvider);
  final now = toLocalTime(DateTime.now(), tz);
  return DateTime(now.year, now.month, now.day);
});

final todayFlightsProvider =
    FutureProvider<AppResult<List<FlightOrderItem>>>((ref) {
  final repo = ref.read(flightOrdersRepositoryProvider);
  return repo.listFlightsByDate(date: ref.watch(_todayProvider));
});

final aircraftStatusProvider =
    FutureProvider<({int total, int operational, int inoperative, int maintenance})>((ref) async {
  final repo = ref.read(aircraftRepositoryProvider);
  final result = await repo.listAircraft();
  if (result case AppSuccess(data: final aircraft)) {
    final active = aircraft.where((a) => a.active).toList();
    return (
      total: active.length,
      operational: active.where((a) => a.status == 'operational').length,
      inoperative: active.where((a) => a.status == 'inoperative').length,
      maintenance: active.where((a) => a.status == 'maintenance').length,
    );
  }
  return (total: 0, operational: 0, inoperative: 0, maintenance: 0);
});

final recentActivityProvider =
    FutureProvider<AppResult<List<AuditLog>>>((ref) {
  final repo = ref.read(auditRepositoryProvider);
  return repo.listAuditLogs();
});

// ── New: operational curve for the operability chart widget ──────────

final operationalCurveProvider =
    FutureProvider<AppResult<List<OperationalDataPoint>>>((ref) {
  final session = ref.watch(sessionControllerProvider);
  final unitId = session.user?.unitId;
  if (unitId == null) {
    return const AppFailure(AppError(
      code: 'NO_UNIT',
      message: 'Sin unidad asignada',
      category: AppErrorCategory.validation,
      severity: AppErrorSeverity.low,
    ));
  }
  final repo = ref.read(aircraftRepositoryProvider);
  return repo.getOperationalCurve(unitId: unitId);
});

// ── New: recent posts stream for the notifications widget ────────────

final recentPostsProvider =
    StreamProvider.autoDispose<AppResult<List<MessagePost>>>((ref) {
  final repo = ref.read(messagesRepositoryProvider);
  return repo.watchPosts();
});

