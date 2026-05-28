import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/flight_orders/application/flight_order_pdf_service.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a PDF for a flight order with item data', () async {
    final service = FlightOrderPdfService();
    final order = FlightOrder(
      id: 'order-1',
      unitId: 'unit-1',
      unitName: 'Base Aerea Las Palmas',
      operationDate: DateTime(2026, 5, 26),
      status: 'approved',
      orderNumber: '049',
      createdAt: DateTime(2026, 5, 26),
      updatedAt: DateTime(2026, 5, 26),
    );
    final item = FlightOrderItem(
      id: 'item-1',
      flightOrderId: order.id,
      aircraftId: 'aircraft-1',
      aircraftRegistration: 'FAP-468',
      mission: 'NAV',
      eteMinutes: 78,
      fuelAmount: 53,
      fuelType: 'lbs',
      scheduledDeparture: DateTime(2026, 5, 26, 9),
      createdAt: DateTime(2026, 5, 26),
      updatedAt: DateTime(2026, 5, 26),
      routes: [
        const FlightOrderRoute(
          id: 'route-1',
          flightOrderItemId: 'item-1',
          originLabel: 'LP',
          destinationLabel: 'SO',
        ),
      ],
      crew: const [
        FlightOrderCrew(
          id: 'crew-1',
          flightOrderItemId: 'item-1',
          crewMemberId: 'crew-member-1',
          roleCode: 'PC',
          crewMemberName: 'BARAHONA',
          crewMemberCallsign: 'TRACKER',
          functionCode: 'PM',
        ),
      ],
      profiles: const [
        FlightOrderProfile(
          id: 'profile-1',
          flightOrderId: 'order-1',
          profileNumber: 1,
          description: 'TAKE OFF RWY 20 / ASC 9000',
        ),
      ],
    );

    final result = await service.buildFlightOrderPdf(
      order: order,
      items: [item],
      orderProfiles: const [],
    );

    switch (result) {
      case AppSuccess(data: final bytes):
        expect(bytes.length, greaterThan(1000));
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      case AppFailure(error: final error):
        fail(error.message);
    }
  });
}
