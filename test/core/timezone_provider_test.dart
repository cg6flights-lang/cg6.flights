import 'package:cg6_flights/core/state/timezone_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toLocalTime', () {
    test('shifts UTC time by a negative offset (UTC-5)', () {
      final utc = DateTime.utc(2026, 6, 1, 12, 30);
      final local = toLocalTime(utc, -5);
      expect(local.hour, 7);
      expect(local.minute, 30);
    });

    test('shifts UTC time by a positive offset (UTC+1)', () {
      final utc = DateTime.utc(2026, 6, 1, 12, 30);
      final local = toLocalTime(utc, 1);
      expect(local.hour, 13);
      expect(local.minute, 30);
    });

    test('zero offset keeps the same wall clock', () {
      final utc = DateTime.utc(2026, 6, 1, 9, 5);
      expect(toLocalTime(utc, 0).hour, 9);
      expect(toLocalTime(utc, 0).minute, 5);
    });

    test('crosses midnight when the offset moves the day back', () {
      final utc = DateTime.utc(2026, 6, 1, 2, 0);
      final local = toLocalTime(utc, -5);
      // 02:00 UTC minus 5h = 21:00 of the previous day
      expect(local.hour, 21);
      expect(local.day, 31);
      expect(local.month, 5);
    });
  });

  group('formatTimeWithOffset', () {
    test('returns placeholder for null datetime', () {
      expect(formatTimeWithOffset(null, -5), '--:--');
    });

    test('formats HH:MM with a negative offset', () {
      final utc = DateTime.utc(2026, 6, 1, 12, 30);
      expect(formatTimeWithOffset(utc, -5), '07:30');
    });

    test('formats HH:MM with a positive offset', () {
      final utc = DateTime.utc(2026, 6, 1, 12, 30);
      expect(formatTimeWithOffset(utc, 1), '13:30');
    });

    test('pads single-digit hour and minute', () {
      final utc = DateTime.utc(2026, 6, 1, 6, 5);
      expect(formatTimeWithOffset(utc, 0), '06:05');
    });

    test('zero offset returns the UTC wall clock', () {
      final utc = DateTime.utc(2026, 6, 1, 23, 59);
      expect(formatTimeWithOffset(utc, 0), '23:59');
    });
  });
}
