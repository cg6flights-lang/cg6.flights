import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlightOrder', () {
    test('parses happy-path fields', () {
      final o = FlightOrder.fromJson({
        'id': 'o1',
        'unit_id': 'u1',
        'operation_date': '2026-06-01',
        'status': 'submitted',
        'order_number': 'OV-001',
        'units': {'name': 'Grupo 51'},
        'items_count': 4,
        'created_at': '2026-05-01T00:00:00Z',
        'updated_at': '2026-05-02T00:00:00Z',
      });
      expect(o.id, 'o1');
      expect(o.unitId, 'u1');
      expect(o.operationDate.year, 2026);
      expect(o.operationDate.month, 6);
      expect(o.operationDate.day, 1);
      expect(o.status, 'submitted');
      expect(o.orderNumber, 'OV-001');
      expect(o.unitName, 'Grupo 51');
      expect(o.itemsCount, 4);
    });

    test('defaults status to draft and parses unit_name when units map absent', () {
      final o = FlightOrder.fromJson({
        'id': 'o',
        'unit_id': 'u',
        'operation_date': '2026-06-01',
        'unit_name': 'Otra Unidad',
      });
      expect(o.status, 'draft');
      expect(o.unitName, 'Otra Unidad');
    });

    test('items_count parsed from string', () {
      final o = FlightOrder.fromJson({
        'id': 'o',
        'unit_id': 'u',
        'operation_date': '2026-06-01',
        'items_count': '7',
      });
      expect(o.itemsCount, 7);
    });

    group('hasObservations', () {
      test('true only when draft with submittedAt', () {
        expect(
          FlightOrder.fromJson({
            'id': 'o',
            'unit_id': 'u',
            'operation_date': '2026-06-01',
            'status': 'draft',
            'submitted_at': '2026-06-01T10:00:00Z',
          }).hasObservations,
          isTrue,
        );
        expect(
          FlightOrder.fromJson({
            'id': 'o',
            'unit_id': 'u',
            'operation_date': '2026-06-01',
            'status': 'draft',
          }).hasObservations,
          isFalse,
        );
        expect(
          FlightOrder.fromJson({
            'id': 'o',
            'unit_id': 'u',
            'operation_date': '2026-06-01',
            'status': 'submitted',
            'submitted_at': '2026-06-01T10:00:00Z',
          }).hasObservations,
          isFalse,
        );
      });
    });

    group('effectiveStatus', () {
      test('observed collapses to draft', () {
        expect(
          FlightOrder.fromJson({
            'id': 'o',
            'unit_id': 'u',
            'operation_date': '2026-06-01',
            'status': 'observed',
          }).effectiveStatus,
          'draft',
        );
      });

      test('other statuses pass through', () {
        for (final s in ['draft', 'submitted', 'approved', 'closed']) {
          expect(
            FlightOrder.fromJson({
              'id': 'o',
              'unit_id': 'u',
              'operation_date': '2026-06-01',
              'status': s,
            }).effectiveStatus,
            s,
          );
        }
      });
    });

    test('toJson serializes operation_date as YYYY-MM-DD', () {
      final o = FlightOrder(
        id: 'o',
        unitId: 'u',
        operationDate: DateTime.utc(2026, 6, 1),
        status: 'draft',
        createdAt: DateTime.utc(2026, 5, 1),
        updatedAt: DateTime.utc(2026, 5, 2),
        orderNumber: 'OV-001',
      );
      final json = o.toJson();
      expect(json['operation_date'], '2026-06-01');
      expect(json['order_number'], 'OV-001');
      expect(json['unit_id'], 'u');
    });
  });

  group('FlightOrderItem', () {
    test('parses happy-path fields with nested aircraft map', () {
      final item = FlightOrderItem.fromJson({
        'id': 'i1',
        'flight_order_id': 'o1',
        'aircraft_id': 'a1',
        'mission': 'Entrenamiento',
        'flight_level_min': 100,
        'flight_level_max': 200,
        'ete_minutes': 90,
        'fuel_amount': 500.5,
        'fuel_type': 'JP-8',
        'status': 'waiting',
        'flight_type': 'prdi',
        'shift': 'I',
        'aircraft': {'registration': 'FAP-101', 'model': 'C-90'},
      });
      expect(item.id, 'i1');
      expect(item.aircraftId, 'a1');
      expect(item.mission, 'Entrenamiento');
      expect(item.flightLevelMin, 100);
      expect(item.flightLevelMax, 200);
      expect(item.eteMinutes, 90);
      expect(item.fuelAmount, 500.5);
      expect(item.fuelType, 'JP-8');
      expect(item.status, 'waiting');
      expect(item.flightType, 'prdi');
      expect(item.shift, 'I');
      expect(item.aircraftRegistration, 'FAP-101');
      expect(item.aircraftModel, 'C-90');
    });

    test('aircraft registration falls back to tail_number then aircraft_registration', () {
      expect(
        FlightOrderItem.fromJson({
          'id': 'i',
          'flight_order_id': 'o',
          'aircraft_id': 'a',
          'aircraft': {'tail_number': 'FAP-202'},
        }).aircraftRegistration,
        'FAP-202',
      );
      expect(
        FlightOrderItem.fromJson({
          'id': 'i',
          'flight_order_id': 'o',
          'aircraft_id': 'a',
          'aircraft_registration': 'FAP-303',
        }).aircraftRegistration,
        'FAP-303',
      );
    });

    test('defaults status to waiting and flight_type to normal', () {
      final item = FlightOrderItem.fromJson({
        'id': 'i',
        'flight_order_id': 'o',
        'aircraft_id': 'a',
      });
      expect(item.status, 'waiting');
      expect(item.flightType, 'normal');
    });

    group('flightLevelDisplay', () {
      FlightOrderItem itemWith({int? min, int? max}) => FlightOrderItem.fromJson({
        'id': 'i',
        'flight_order_id': 'o',
        'aircraft_id': 'a',
        'flight_level_min': min,
        'flight_level_max': max,
      });

      test('placeholder when min is null', () {
        expect(itemWith().flightLevelDisplay, '--');
      });
      test('single value when only min', () {
        expect(itemWith(min: 100).flightLevelDisplay, '100 fts');
      });
      test('range when min and max differ', () {
        expect(itemWith(min: 100, max: 200).flightLevelDisplay, '100 - 200 fts');
      });
      test('single value when min equals max', () {
        expect(itemWith(min: 150, max: 150).flightLevelDisplay, '150 fts');
      });
    });

    group('isDelayed', () {
      test('true when waiting and scheduled departure is in the past', () {
        final item = FlightOrderItem.fromJson({
          'id': 'i',
          'flight_order_id': 'o',
          'aircraft_id': 'a',
          'status': 'waiting',
          'scheduled_departure': '2020-01-01T00:00:00Z',
        });
        expect(item.isDelayed, isTrue);
      });

      test('false when scheduled departure is in the future', () {
        final item = FlightOrderItem.fromJson({
          'id': 'i',
          'flight_order_id': 'o',
          'aircraft_id': 'a',
          'status': 'waiting',
          'scheduled_departure': '2999-01-01T00:00:00Z',
        });
        expect(item.isDelayed, isFalse);
      });

      test('false when not waiting even if departure is in the past', () {
        final item = FlightOrderItem.fromJson({
          'id': 'i',
          'flight_order_id': 'o',
          'aircraft_id': 'a',
          'status': 'approved',
          'scheduled_departure': '2020-01-01T00:00:00Z',
        });
        expect(item.isDelayed, isFalse);
      });

      test('false when waiting but there is no scheduled departure', () {
        final item = FlightOrderItem.fromJson({
          'id': 'i',
          'flight_order_id': 'o',
          'aircraft_id': 'a',
          'status': 'waiting',
        });
        expect(item.isDelayed, isFalse);
      });
    });
  });

  group('FlightOrderRoute', () {
    test('parses direct coordinates and segment fields', () {
      final r = FlightOrderRoute.fromJson({
        'id': 'r1',
        'flight_order_item_id': 'i1',
        'segment_order': 2,
        'segment_type': 'inbound',
        'origin_label': 'SPJC',
        'origin_lat': -12.0,
        'origin_lng': -77.0,
        'destination_label': 'SPZO',
        'destination_lat': -16.0,
        'destination_lng': -71.0,
      });
      expect(r.id, 'r1');
      expect(r.segmentOrder, 2);
      expect(r.segmentType, 'inbound');
      expect(r.originLat, -12.0);
      expect(r.destinationLat, -16.0);
    });

    test('falls back to origin_route/destination_route master coordinates', () {
      final r = FlightOrderRoute.fromJson({
        'id': 'r',
        'flight_order_item_id': 'i',
        'origin_route': {
          'latitude': '-12.5',
          'longitude': '-77.5',
          'airport_name': 'Lima',
          'icao_code': 'SPJC',
        },
        'destination_route': {
          'latitude': '-16.5',
          'longitude': '-71.5',
          'airport_name': 'Arequipa',
          'icao_code': 'SPZO',
        },
      });
      expect(r.originRouteLat, -12.5);
      expect(r.originRouteLng, -77.5);
      expect(r.originLat, -12.5);
      expect(r.originRouteName, 'Lima');
      expect(r.originIcao, 'SPJC');
      expect(r.destinationIcao, 'SPZO');
    });

    group('display labels', () {
      test('originDisplay prefers the airport route name over the label', () {
        final r = FlightOrderRoute.fromJson({
          'id': 'r',
          'flight_order_item_id': 'i',
          'origin_type': 'airport',
          'origin_route': {'airport_name': 'Aeropuerto Lima'},
          'origin_label': 'SPJC',
        });
        expect(r.originDisplay, 'Aeropuerto Lima');
      });

      test('originDisplay falls back to label when not an airport', () {
        final r = FlightOrderRoute.fromJson({
          'id': 'r',
          'flight_order_item_id': 'i',
          'origin_type': 'custom',
          'origin_label': 'Punto X',
        });
        expect(r.originDisplay, 'Punto X');
      });

      test('originDisplay is placeholder when nothing is set', () {
        final r = FlightOrderRoute.fromJson({
          'id': 'r',
          'flight_order_item_id': 'i',
          'origin_type': 'airport',
        });
        expect(r.originDisplay, '--');
      });

      test('displayLabel joins origin and destination', () {
        final r = FlightOrderRoute.fromJson({
          'id': 'r',
          'flight_order_item_id': 'i',
          'origin_type': 'custom',
          'origin_label': 'A',
          'destination_type': 'custom',
          'destination_label': 'B',
        });
        expect(r.displayLabel, 'A → B');
      });
    });
  });

  group('FlightOrderCrew', () {
    test('builds the full name from the nested crew_member map', () {
      final c = FlightOrderCrew.fromJson({
        'id': 'cc1',
        'flight_order_item_id': 'i1',
        'crew_member_id': 'cm1',
        'role_code': 'PC',
        'crew_member': {'grade': 'Alf', 'first_name': 'Juan', 'last_name': 'Perez'},
      });
      expect(c.id, 'cc1');
      expect(c.crewMemberId, 'cm1');
      expect(c.roleCode, 'PC');
      expect(c.crewMemberName, 'Alf Juan Perez');
    });

    test('defaults role_code to PC and handles missing name parts', () {
      final c = FlightOrderCrew.fromJson({
        'id': 'cc',
        'flight_order_item_id': 'i',
        'crew_member_id': 'cm',
        'crew_member': {'first_name': 'Solo'},
      });
      expect(c.roleCode, 'PC');
      expect(c.crewMemberName, 'Solo');
    });

    test('returns placeholder when crew_member has no name parts', () {
      final c = FlightOrderCrew.fromJson({
        'id': 'cc',
        'flight_order_item_id': 'i',
        'crew_member_id': 'cm',
        'crew_member': {},
      });
      expect(c.crewMemberName, '--');
    });
  });

  group('FlightOrderProfile', () {
    test('profileLabel returns roman numerals within range', () {
      expect(profile(1).profileLabel, 'I');
      expect(profile(2).profileLabel, 'II');
      expect(profile(4).profileLabel, 'IV');
      expect(profile(12).profileLabel, 'XII');
    });

    test('profileLabel falls back to the number when out of range', () {
      expect(profile(0).profileLabel, '0');
      expect(profile(21).profileLabel, '21');
    });

    test('fromJson defaults profile_number to 1', () {
      expect(
        FlightOrderProfile.fromJson({'id': 'p', 'flight_order_id': 'o'}).profileNumber,
        1,
      );
    });
  });
}

FlightOrderProfile profile(int n) => FlightOrderProfile.fromJson({
  'id': 'p',
  'flight_order_id': 'o',
  'profile_number': n,
});
