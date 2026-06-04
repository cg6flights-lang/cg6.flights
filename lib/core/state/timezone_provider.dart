import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Timezone offset from UTC in hours. Default: Peru UTC-5.
final timezoneProvider = NotifierProvider<TimezoneController, int>(
  TimezoneController.new,
);

/// The timezone where data is stored (Peru = UTC-5).
/// DB values are in this local time, NOT UTC.
const _sourceOffset = -5;

class TimezoneController extends Notifier<int> {
  @override
  int build() => -5; // Peru UTC-5

  void setOffset(int offset) => state = offset;
}

/// Available timezones for the settings UI.
const availableTimezones = [
  ('Lima, Perú (UTC-5)', -5),
  ('Bogotá, Colombia (UTC-5)', -5),
  ('Ciudad de México (UTC-6)', -6),
  ('Santiago, Chile (UTC-4)', -4),
  ('Buenos Aires, Argentina (UTC-3)', -3),
  ('Madrid, España (UTC+1)', 1),
  ('UTC', 0),
];

/// Converts a local DateTime (Peru timezone) to the configured timezone.
/// Input is assumed to be in Peru local time (UTC-5), NOT UTC.
DateTime toLocalTime(DateTime localTime, int configuredOffset) {
  // Convert from source (Peru UTC-5) to UTC, then to configured timezone
  // localPeru + 5 = UTC, then UTC + configuredOffset = target
  // Net: localPeru + (configuredOffset - sourceOffset)
  return localTime.add(Duration(hours: configuredOffset - _sourceOffset));
}

/// Formats a local DateTime (Peru timezone) as HH:MM in the configured timezone.
String formatTimeWithOffset(DateTime? localTime, int configuredOffset) {
  if (localTime == null) return '--:--';
  final target = toLocalTime(localTime, configuredOffset);
  return '${target.hour.toString().padLeft(2, "0")}:${target.minute.toString().padLeft(2, "0")}';
}

