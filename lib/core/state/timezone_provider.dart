import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Timezone offset from UTC in hours. Default: Peru UTC-5.
final timezoneProvider = NotifierProvider<TimezoneController, int>(
  TimezoneController.new,
);

class TimezoneController extends Notifier<int> {
  @override
  int build() => -5; // Peru UTC-5

  void setOffset(int offset) => state = offset;
}

/// Available timezones for the settings UI.
/// Uses index as unique key, offset as value.
const availableTimezones = [
  ('Lima, Perú (UTC-5)', -5),
  ('Bogotá, Colombia (UTC-5)', -5),
  ('Ciudad de México (UTC-6)', -6),
  ('Santiago, Chile (UTC-4)', -4),
  ('Buenos Aires, Argentina (UTC-3)', -3),
  ('Madrid, España (UTC+1)', 1),
  ('UTC', 0),
];

/// Converts a UTC DateTime to the configured timezone offset.
DateTime toLocalTime(DateTime utc, int offsetHours) {
  return utc.add(Duration(hours: offsetHours));
}

/// Formats a UTC DateTime as HH:MM in the configured timezone.
String formatTimeWithOffset(DateTime? utc, int offset) {
  if (utc == null) return '--:--';
  final local = utc.add(Duration(hours: offset));
  return '${local.hour.toString().padLeft(2, "0")}:${local.minute.toString().padLeft(2, "0")}';
}

