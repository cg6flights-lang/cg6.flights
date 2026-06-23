import 'package:cg6_flights/features/aircraft/domain/aircraft.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft_flight_hours.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Aircraft', () {
    test('parses a full json with happy-path fields', () {
      final a = Aircraft.fromJson({
        'id': 'a1',
        'unit_id': 'u1',
        'tail_number': 'FAP-101',
        'model': 'C-90',
        'manufacturer': 'Beechcraft',
        'status': 'operational',
        'active': true,
        'serial_number': 'SN-1',
        'year': 2010,
        'display_registration': 'FAP',
        'squadron_id': 's1',
      });
      expect(a.id, 'a1');
      expect(a.unitId, 'u1');
      expect(a.tailNumber, 'FAP-101');
      expect(a.model, 'C-90');
      expect(a.manufacturer, 'Beechcraft');
      expect(a.status, 'operational');
      expect(a.active, isTrue);
      expect(a.year, 2010);
      expect(a.isOperational, isTrue);
    });

    test('defaults status to operational and active to false when missing', () {
      final a = Aircraft.fromJson({'id': 'a2'});
      expect(a.status, 'operational');
      expect(a.active, isFalse);
      expect(a.isOperational, isTrue);
      expect(a.displayRegistration, 'FAP');
    });

    test('isOperational is false for non-operational status', () {
      final a = Aircraft.fromJson({'id': 'a3', 'status': 'maintenance'});
      expect(a.isOperational, isFalse);
    });

    test('parses squadronIds from a squadron_ids list', () {
      final a = Aircraft.fromJson({
        'id': 'a4',
        'squadron_ids': ['s1', 's2'],
      });
      expect(a.squadronIds, ['s1', 's2']);
    });

    test('parses squadronIds from aircraft_squadrons junction rows', () {
      final a = Aircraft.fromJson({
        'id': 'a5',
        'aircraft_squadrons': [
          {'squadron_id': 's1'},
          {'squadron_id': 's2'},
          {'squadron_id': ''}, // filtered out
        ],
      });
      expect(a.squadronIds, ['s1', 's2']);
    });

    test('parses squadronName from the flight_squadrons map', () {
      final a = Aircraft.fromJson({
        'id': 'a6',
        'flight_squadrons': {'name': 'Escuadrón Alpha'},
      });
      expect(a.squadronName, 'Escuadrón Alpha');
    });

    test('parses lastFlightAt and daysWithoutFlying', () {
      final a = Aircraft.fromJson({
        'id': 'a7',
        'last_flight_at': '2026-06-01T10:00:00Z',
        'days_without_flying': '3',
      });
      expect(a.lastFlightAt, DateTime.utc(2026, 6, 1, 10));
      expect(a.daysWithoutFlying, 3);
    });

    group('displayTailNumber', () {
      test('returns tailNumber by default (FAP)', () {
        final a = Aircraft.fromJson({'id': 'a', 'tail_number': 'FAP-101'});
        expect(a.displayTailNumber, 'FAP-101');
      });

      test('returns obTailNumber when displayRegistration is OB and present', () {
        final a = Aircraft.fromJson({
          'id': 'a',
          'tail_number': 'FAP-101',
          'ob_tail_number': 'OB-202',
          'display_registration': 'OB',
        });
        expect(a.displayTailNumber, 'OB-202');
      });

      test('falls back to tailNumber when OB is selected but ob number is empty', () {
        final a = Aircraft.fromJson({
          'id': 'a',
          'tail_number': 'FAP-101',
          'ob_tail_number': '',
          'display_registration': 'OB',
        });
        expect(a.displayTailNumber, 'FAP-101');
      });

      test('falls back to tailNumber when OB is selected but ob number is null', () {
        final a = Aircraft.fromJson({
          'id': 'a',
          'tail_number': 'FAP-101',
          'display_registration': 'OB',
        });
        expect(a.displayTailNumber, 'FAP-101');
      });
    });

    test('toJson serializes the editable subset of fields', () {
      final a = Aircraft(
        id: 'a1',
        unitId: 'u1',
        tailNumber: 'FAP-101',
        model: 'C-90',
        manufacturer: 'Beechcraft',
        status: 'operational',
        active: true,
        serialNumber: 'SN-1',
        year: 2010,
        displayRegistration: 'FAP',
      );
      final json = a.toJson();
      expect(json['unit_id'], 'u1');
      expect(json['tail_number'], 'FAP-101');
      expect(json['model'], 'C-90');
      expect(json['manufacturer'], 'Beechcraft');
      expect(json['serial_number'], 'SN-1');
      expect(json['year'], 2010);
      expect(json['status'], 'operational');
      expect(json['display_registration'], 'FAP');
      expect(json.containsKey('ob_tail_number'), isFalse);
    });
  });

  group('AircraftFlightHours', () {
    test('parses numeric fields including string-encoded numbers', () {
      final h = AircraftFlightHours.fromJson({
        'aircraft_id': 'a1',
        'tail_number': 'FAP-101',
        'model': 'C-90',
        'status': 'operational',
        'real_hours': '120.5',
        'planned_hours': '100',
        'flight_count': '8',
      });
      expect(h.realHours, 120.5);
      expect(h.plannedHours, 100);
      expect(h.flightCount, 8);
      expect(h.diffHours, 20.5);
      expect(h.isOperational, isTrue);
    });

    test('defaults to zeros when numeric fields are missing', () {
      final h = AircraftFlightHours.fromJson({'aircraft_id': 'a1'});
      expect(h.realHours, 0);
      expect(h.plannedHours, 0);
      expect(h.flightCount, 0);
      expect(h.diffHours, 0);
    });

    test('diffHours is negative when planned exceeds real', () {
      final h = AircraftFlightHours.fromJson({
        'aircraft_id': 'a1',
        'real_hours': 50,
        'planned_hours': 80,
      });
      expect(h.diffHours, -30);
    });

    test('isOperational reflects the status string', () {
      final op = AircraftFlightHours.fromJson({
        'aircraft_id': 'a1',
        'status': 'operational',
      });
      final down = AircraftFlightHours.fromJson({
        'aircraft_id': 'a2',
        'status': 'maintenance',
      });
      expect(op.isOperational, isTrue);
      expect(down.isOperational, isFalse);
    });
  });
}
