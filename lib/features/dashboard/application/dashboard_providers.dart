import 'package:cg6_flights/core/errors/app_error.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/aircraft/data/aircraft_repository.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft.dart';
import 'package:cg6_flights/features/aircraft/domain/operational_data_point.dart';
import 'package:cg6_flights/features/audit/data/audit_repository.dart';
import 'package:cg6_flights/features/audit/domain/audit_log.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/features/messages/data/messages_repository.dart';
import 'package:cg6_flights/features/messages/domain/message_post.dart';
import 'package:cg6_flights/features/units/data/units_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _todayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final todayFlightsProvider = FutureProvider<AppResult<List<FlightOrderItem>>>((
  ref,
) {
  final repo = ref.read(flightOrdersRepositoryProvider);
  return repo.listFlightsByDate(date: ref.watch(_todayProvider));
});

final aircraftStatusProvider =
    FutureProvider<
      ({int total, int operational, int inoperative, int maintenance})
    >((ref) async {
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

class DashboardAircraftUnitKpi {
  const DashboardAircraftUnitKpi({
    required this.unitCode,
    required this.total,
    required this.operational,
    required this.inoperative,
  });

  final String unitCode;
  final int total;
  final int operational;
  final int inoperative;

  int get operationalPct => total > 0 ? (operational / total * 100).round() : 0;
}

class DashboardAircraftKpiStats {
  const DashboardAircraftKpiStats({
    required this.total,
    required this.operational,
    required this.inoperative,
    required this.units,
  });

  final int total;
  final int operational;
  final int inoperative;
  final List<DashboardAircraftUnitKpi> units;

  int get operationalPct => total > 0 ? (operational / total * 100).round() : 0;
}

final aircraftKpiProvider = FutureProvider<DashboardAircraftKpiStats>((
  ref,
) async {
  final aircraftRepo = ref.read(aircraftRepositoryProvider);
  final unitsRepo = ref.read(unitsRepositoryProvider);

  final aircraftResult = await aircraftRepo.listAircraft();
  final unitsResult = await unitsRepo.listUnits();

  final aircraft = switch (aircraftResult) {
    AppSuccess<List<Aircraft>>(data: final list) =>
      list.where((a) => a.active).toList(),
    _ => <Aircraft>[],
  };

  final unitLabels = switch (unitsResult) {
    AppSuccess(data: final units) => {
      for (final unit in units.where((u) => u.active))
        unit.id: unit.code.isNotEmpty ? unit.code : unit.name,
    },
    _ => <String, String>{},
  };

  final byUnit = <String, List<Aircraft>>{};
  for (final aircraft in aircraft) {
    byUnit.putIfAbsent(aircraft.unitId, () => []).add(aircraft);
  }

  final unitStats = byUnit.entries.map((entry) {
    final unitAircraft = entry.value;
    final operational = unitAircraft
        .where((aircraft) => aircraft.status == 'operational')
        .length;
    final inoperative = unitAircraft.length - operational;
    return DashboardAircraftUnitKpi(
      unitCode: unitLabels[entry.key] ?? 'S/U',
      total: unitAircraft.length,
      operational: operational,
      inoperative: inoperative,
    );
  }).toList()..sort((a, b) => a.unitCode.compareTo(b.unitCode));

  final operational = aircraft
      .where((aircraft) => aircraft.status == 'operational')
      .length;

  return DashboardAircraftKpiStats(
    total: aircraft.length,
    operational: operational,
    inoperative: aircraft.length - operational,
    units: unitStats,
  );
});

class DashboardFleetUnitGroup {
  const DashboardFleetUnitGroup({required this.unitCode, required this.models});

  final String unitCode;
  final List<DashboardFleetModelGroup> models;

  Iterable<Aircraft> get aircraft => models.expand((model) => model.aircraft);
  int get total => aircraft.length;
  int get operational =>
      aircraft.where((item) => item.status == 'operational').length;
  int get inoperative => total - operational;
}

class DashboardFleetModelGroup {
  const DashboardFleetModelGroup({required this.model, required this.aircraft});

  final String model;
  final List<Aircraft> aircraft;
}

final dashboardFleetProvider = FutureProvider<List<DashboardFleetUnitGroup>>((
  ref,
) async {
  final aircraftRepo = ref.read(aircraftRepositoryProvider);
  final unitsRepo = ref.read(unitsRepositoryProvider);

  final aircraftResult = await aircraftRepo.listAircraft();
  final unitsResult = await unitsRepo.listUnits();

  final aircraft = switch (aircraftResult) {
    AppSuccess<List<Aircraft>>(data: final list) =>
      list.where((item) => item.active).toList(),
    _ => <Aircraft>[],
  };

  final unitLabels = switch (unitsResult) {
    AppSuccess(data: final units) => {
      for (final unit in units.where((unit) => unit.active))
        unit.id: unit.code.isNotEmpty ? unit.code : unit.name,
    },
    _ => <String, String>{},
  };

  final byUnit = <String, List<Aircraft>>{};
  for (final aircraft in aircraft) {
    byUnit.putIfAbsent(aircraft.unitId, () => []).add(aircraft);
  }

  final unitGroups = byUnit.entries.map((entry) {
    final byModel = <String, List<Aircraft>>{};
    for (final aircraft in entry.value) {
      byModel.putIfAbsent(aircraft.model, () => []).add(aircraft);
    }

    final models = byModel.entries.map((modelEntry) {
      final aircraft = [...modelEntry.value]
        ..sort((a, b) => a.tailNumber.compareTo(b.tailNumber));
      return DashboardFleetModelGroup(
        model: modelEntry.key,
        aircraft: aircraft,
      );
    }).toList()..sort((a, b) => a.model.compareTo(b.model));

    return DashboardFleetUnitGroup(
      unitCode: unitLabels[entry.key] ?? 'S/U',
      models: models,
    );
  }).toList()..sort((a, b) => a.unitCode.compareTo(b.unitCode));

  return unitGroups;
});

final recentActivityProvider = FutureProvider<AppResult<List<AuditLog>>>((ref) {
  final repo = ref.read(auditRepositoryProvider);
  return repo.listAuditLogs();
});

// ── New: operational curve for the operability chart widget ──────────

final operationalCurveProvider =
    FutureProvider<AppResult<List<OperationalDataPoint>>>((ref) {
      final session = ref.watch(sessionControllerProvider);
      final unitId = session.user?.unitId;
      if (unitId == null) {
        return const AppFailure(
          AppError(
            code: 'NO_UNIT',
            message: 'Sin unidad asignada',
            category: AppErrorCategory.validation,
            severity: AppErrorSeverity.low,
          ),
        );
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
