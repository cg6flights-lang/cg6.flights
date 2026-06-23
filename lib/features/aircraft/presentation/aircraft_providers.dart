import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/aircraft/data/aircraft_repository.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft_flight_hours.dart';
import 'package:cg6_flights/features/aircraft/domain/operational_data_point.dart';
import 'package:cg6_flights/features/crew/data/squadron_repository.dart';
import 'package:cg6_flights/features/crew/domain/squadron.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/features/units/data/units_repository.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// All aircraft-feature state extracted from `aircraft_page.dart` so the
/// extracted widgets can consume the same providers.
final aircraftListProvider = FutureProvider<AppResult<List<Aircraft>>>((
  ref,
) async {
  final repo = ref.read(aircraftRepositoryProvider);
  return repo.listAircraft();
});

final aircraftUnitsProvider = FutureProvider<List<UnitOption>>((ref) async {
  final result = await ref.read(unitsRepositoryProvider).listUnits();
  return switch (result) {
    AppSuccess<List<UnitOption>>(data: final list) =>
      list.where((u) => u.active).toList(),
    _ => <UnitOption>[],
  };
});

class AircraftCurveParams {
  const AircraftCurveParams({required this.unitId, required this.granularity});
  final String unitId;
  final String granularity;

  @override
  bool operator ==(Object other) =>
      other is AircraftCurveParams &&
      other.unitId == unitId &&
      other.granularity == granularity;

  @override
  int get hashCode => Object.hash(unitId, granularity);
}

final selectedAircraftUnitProvider =
    NotifierProvider<AircraftUnitNotifier, String?>(AircraftUnitNotifier.new);

class AircraftUnitNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = (state == id ? null : id);
}

class AircraftSquadronNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = (state == id ? null : id);
}

final selectedAircraftSquadronProvider =
    NotifierProvider<AircraftSquadronNotifier, String?>(
      AircraftSquadronNotifier.new,
    );

const gru51Id = '4317c6f3-e530-4b9c-a898-1f765ceaafb2';

final aircraftSquadronsProvider = FutureProvider<List<FlightSquadron>>((
  ref,
) async {
  final result = await ref.read(squadronRepositoryProvider).listSquadrons();
  return switch (result) {
    AppSuccess<List<FlightSquadron>>(data: final list) => list,
    _ => <FlightSquadron>[],
  };
});

class AircraftOrdersParams {
  const AircraftOrdersParams({
    required this.aircraftId,
    required this.from,
    required this.to,
  });

  final String aircraftId;
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is AircraftOrdersParams &&
      other.aircraftId == aircraftId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(aircraftId, from, to);
}

final aircraftOrdersProvider =
    FutureProvider.family<
      AppResult<List<FlightOrderItem>>,
      AircraftOrdersParams
    >((ref, params) {
      return ref
          .read(flightOrdersRepositoryProvider)
          .listItemsByAircraft(
            aircraftId: params.aircraftId,
            from: params.from,
            to: params.to,
          );
    });

final aircraftFlightHoursProvider =
    FutureProvider.family<AppResult<List<AircraftFlightHours>>, String?>(
      (ref, unitId) =>
          ref.read(aircraftRepositoryProvider).getFlightHours(unitId: unitId),
    );

final aircraftOperationalCurveProvider =
    FutureProvider.family<
      AppResult<List<OperationalDataPoint>>,
      AircraftCurveParams
    >((ref, params) async {
      final repo = ref.read(aircraftRepositoryProvider);
      return repo.getOperationalCurve(
        unitId: params.unitId,
        granularity: params.granularity,
      );
    });
