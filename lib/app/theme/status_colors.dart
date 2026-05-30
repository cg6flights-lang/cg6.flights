import 'package:flutter/material.dart';

/// Shared status color mappings used across the app.
///
/// Single source of truth for all status colors — used by [StatusChip],
/// [OrderStepper], and flight item cards.
class StatusColors {
  StatusColors._();

  // ── Flight order statuses ──────────────────────────────────────────

  static const Map<String, Color> flightOrder = {
    'draft': Colors.grey,
    'submitted': Colors.blue,
    'observed': Colors.orange,
    'approved': Colors.green,
    'closed': Colors.red,
    'reopened': Colors.purple,
  };

  // ── Flight item (vuelo) statuses ───────────────────────────────────

  static const Map<String, Color> flightItem = {
    'waiting': Colors.grey,
    'taxi': Colors.blue,
    'takeoff': Colors.orange,
    'landing': Colors.teal,
    'engine_off': Colors.green,
    'cancelled': Colors.red,
  };

  // ── Aircraft statuses ──────────────────────────────────────────────

  static const Map<String, Color> aircraft = {
    'operational': Colors.green,
    'inoperative': Colors.red,
    'maintenance': Colors.orange,
  };

  // ── Unified lookup ─────────────────────────────────────────────────

  /// Returns the color for any known status string, searching across all
  /// categories. Defaults to [Colors.grey] if unknown.
  static Color of(String status) {
    return flightOrder[status] ??
        flightItem[status] ??
        aircraft[status] ??
        Colors.grey;
  }

  // ── Delayed-specific ───────────────────────────────────────────────

  /// Accent color for delayed flights (overlays on the waiting status).
  static const Color delayed = Colors.amber;
}
