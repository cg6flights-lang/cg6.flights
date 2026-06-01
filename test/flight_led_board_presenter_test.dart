import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/features/flights/application/flight_led_board_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds LED rows with unit tail, destination, eta and status', () {
    final presenter = FlightLedBoardPresenter();
    final item = FlightOrderItem(
      id: 'item-1',
      flightOrderId: 'order-1',
      aircraftId: 'aircraft-1',
      aircraftRegistration: 'FAP-468',
      unitName: 'GRU6',
      mission: 'NAV',
      eteMinutes: 78,
      scheduledDeparture: DateTime.utc(2026, 5, 30, 14), // 14 UTC = 09 Lima
      status: 'takeoff',
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
      routes: const [
        FlightOrderRoute(
          id: 'route-1',
          flightOrderItemId: 'item-1',
          segmentType: 'outbound',
          originLabel: 'LP',
          destinationLabel: 'SO',
        ),
      ],
    );

    final rows = presenter.rows([item], now: DateTime.utc(2026, 5, 30, 13)); // 13 UTC = 08 Lima

    expect(rows, hasLength(1));
    expect(rows.single.time, '09:00');
    expect(rows.single.unit, 'GRU6');
    expect(rows.single.tail, 'FAP-468');
    expect(rows.single.destination, 'SO');
    expect(rows.single.eta, '10:18');
    expect(rows.single.statusKey, 'flights.ledStatusTakeoff');
    expect(rows.single.tone, LedFlightTone.success);
  });

  test('marks waiting flights past scheduled departure as delayed', () {
    final presenter = FlightLedBoardPresenter();
    final item = FlightOrderItem(
      id: 'item-1',
      flightOrderId: 'order-1',
      aircraftId: 'aircraft-1',
      unitName: 'Base Aerea Las Palmas',
      scheduledDeparture: DateTime.utc(2026, 5, 30, 13), // 13 UTC = 08 Lima
      status: 'waiting',
      createdAt: DateTime.utc(2026, 5, 30),
      updatedAt: DateTime.utc(2026, 5, 30),
    );

    final rows = presenter.rows([item], now: DateTime.utc(2026, 5, 30, 13, 30)); // 13:30 UTC = 08:30 Lima

    expect(rows.single.unit, 'BALP');
    expect(rows.single.tail, '------');
    expect(rows.single.statusKey, 'flights.ledStatusDelayed');
    expect(rows.single.tone, LedFlightTone.warning);
  });
}
