import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';

enum LedFlightTone { normal, success, warning, critical, muted }

class LedFlightRow {
  const LedFlightRow({
    required this.time,
    required this.unit,
    required this.tail,
    required this.destination,
    required this.eta,
    required this.statusKey,
    required this.tone,
  });

  final String time;
  final String unit;
  final String tail;
  final String destination;
  final String eta;
  final String statusKey;
  final LedFlightTone tone;
}

class FlightLedBoardPresenter {
  const FlightLedBoardPresenter();

  List<LedFlightRow> rows(List<FlightOrderItem> flights, {
    DateTime? now,
    int tzOffset = -5,
  }) {
    final currentTime = now ?? DateTime.now();
    final sortedFlights = [...flights]
      ..sort((a, b) {
        final ga = _group(a);
        final gb = _group(b);
        if (ga != gb) return ga.compareTo(gb);
        // Same group → most recent event first
        final ta = _mostRecentEventTime(a);
        final tb = _mostRecentEventTime(b);
        if (ta != null && tb != null) return tb.compareTo(ta);
        if (ta != null) return -1;
        if (tb != null) return 1;
        return _baseTime(a).compareTo(_baseTime(b));
      });

    return [
      for (final flight in sortedFlights)
        LedFlightRow(
          time: _timeText(_baseTime(flight), tzOffset),
          unit: _unitText(flight),
          tail: _tailText(flight),
          destination: _destinationText(flight),
          eta: _etaText(flight, tzOffset),
          statusKey: _statusKey(flight, currentTime),
          tone: _tone(flight, currentTime),
        ),
    ];
  }

  int _group(FlightOrderItem flight) {
    // Active flights (before landing) → top
    if (flight.status == 'waiting' ||
        flight.status == 'taxi' ||
        flight.status == 'takeoff') {
      return 0;
    }
    // Finished/terminal → bottom (landing, engine_off, cancelled)
    return 1;
  }

  DateTime? _mostRecentEventTime(FlightOrderItem flight) {
    if (flight.stateEvents.isEmpty) return null;
    return flight.stateEvents
        .map((e) => e.occurredAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  DateTime _baseTime(FlightOrderItem flight) {
    if (flight.scheduledDeparture != null) return flight.scheduledDeparture!;
    if (flight.stateEvents.isEmpty) return flight.createdAt;

    final events = [...flight.stateEvents]
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return events.last.occurredAt;
  }

  String _timeText(DateTime localTime, int tzOffset) {
    // Data is already in local time (Peru), offset already applied by caller
    return '${localTime.hour.toString().padLeft(2, '0')}:'
        '${localTime.minute.toString().padLeft(2, '0')}';
  }

  String _unitText(FlightOrderItem flight) {
    final name = (flight.unitName ?? '').trim();
    if (name.isEmpty) return '----';

    final compact = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (compact.length <= 5 && compact.toUpperCase() == compact) {
      return compact;
    }

    final words = name
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .where((word) => !{'DE', 'DEL'}.contains(word.toUpperCase()))
        .toList();
    if (words.length >= 2) {
      return words.map((word) => word.substring(0, 1)).join().toUpperCase();
    }

    return name.substring(0, name.length > 4 ? 4 : name.length).toUpperCase();
  }

  String _tailText(FlightOrderItem flight) {
    return _truncate(
      (flight.aircraftRegistration ?? '------').toUpperCase(),
      8,
    );
  }

  String _destinationText(FlightOrderItem flight) {
    final outbound = flight.routes
        .where((route) => route.segmentType == 'outbound')
        .firstOrNull;
    final selectedRoute =
        outbound ?? (flight.routes.isNotEmpty ? flight.routes.last : null);
    // Priority 1: ICAO code from routes table
    final icao = selectedRoute?.destinationIcao;
    if (icao != null && icao.isNotEmpty) return icao.toUpperCase();
    // Priority 2: destinationLabel
    final label = selectedRoute?.destinationLabel;
    if (label != null && label.isNotEmpty && label != '--') {
      return _truncate(label.toUpperCase(), 6);
    }
    return '--';
  }

  String _etaText(FlightOrderItem flight, int tzOffset) {
    // Already landed → show actual landing time
    if (flight.status == 'landing' || flight.status == 'engine_off') {
      final landingEvent = flight.stateEvents
          .where((e) => e.status == 'landing')
          .firstOrNull;
      if (landingEvent != null) {
        return _timeText(landingEvent.occurredAt, tzOffset);
      }
    }
    // Not landed → show ETA projection
    if (flight.eteMinutes != null) {
      final eta = _baseTime(flight).add(Duration(minutes: flight.eteMinutes!));
      return _timeText(eta, tzOffset);
    }
    return '--:--';
  }

  String _statusKey(FlightOrderItem flight, DateTime now) {
    if (flight.cancelled) return 'flights.ledStatusCancelled';
    if (flight.status == 'waiting' &&
        flight.scheduledDeparture != null &&
        flight.scheduledDeparture!.isBefore(now)) {
      return 'flights.ledStatusDelayed';
    }

    return switch (flight.status) {
      'waiting' || 'taxi' => 'flights.ledStatusWaiting',
      'takeoff' => 'flights.ledStatusTakeoff',
      'landing' => 'flights.ledStatusLanding',
      'engine_off' => 'flights.ledStatusComplete',
      _ => 'flights.ledStatusUnknown',
    };
  }

  LedFlightTone _tone(FlightOrderItem flight, DateTime now) {
    if (flight.cancelled) return LedFlightTone.critical;
    if (flight.status == 'waiting' &&
        flight.scheduledDeparture != null &&
        flight.scheduledDeparture!.isBefore(now)) {
      return LedFlightTone.warning;
    }

    return switch (flight.status) {
      'waiting' || 'taxi' => LedFlightTone.warning,
      'takeoff' || 'landing' => LedFlightTone.success,
      'engine_off' => LedFlightTone.muted,
      _ => LedFlightTone.normal,
    };
  }

  String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
}
