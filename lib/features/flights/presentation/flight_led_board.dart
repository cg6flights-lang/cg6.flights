import 'dart:async';

import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _ledProvider =
    FutureProvider.autoDispose<AppResult<List<FlightOrderItem>>>((ref) {
  final repo = ref.read(flightOrdersRepositoryProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return repo.listFlightsByDate(date: today);
});

class FlightLedBoard extends ConsumerStatefulWidget {
  const FlightLedBoard({super.key});

  @override
  ConsumerState<FlightLedBoard> createState() => _FlightLedBoardState();
}

class _FlightLedBoardState extends ConsumerState<FlightLedBoard> {
  bool _powerOn = true;
  Timer? _autoRefresh;

  static const _ledGreen = Color(0xFF39FF14);
  static const _ledAmber = Color(0xFFFFB000);
  static const _ledRed = Color(0xFFFF3333);
  static const _ledBg = Color(0xFF0A0A0A);
  static const _glowGreen = Color(0x2239FF14);
  static const _glowAmber = Color(0x22FFB000);

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_powerOn && mounted) {
        ref.invalidate(_ledProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // LED display area
            Center(
              child: _powerOn ? _ledDisplay() : _offDisplay(),
            ),
            // Power button
            Positioned(
              top: 16,
              right: 24,
              child: _powerButton(),
            ),
            // Close button
            Positioned(
              top: 16,
              left: 24,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _powerButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _powerOn = !_powerOn;
          if (_powerOn) {
            ref.invalidate(_ledProvider);
            _startAutoRefresh();
          } else {
            _autoRefresh?.cancel();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: _powerOn ? _ledGreen.withValues(alpha: 0.5) : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(6),
          color: _powerOn ? _glowGreen : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.power_settings_new,
                size: 16,
                color: _powerOn ? _ledGreen : Colors.white38),
            const SizedBox(width: 8),
            Text(
              _powerOn ? 'ENCENDIDO' : 'APAGADO',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: _powerOn ? _ledGreen : Colors.white38,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── OFF display ─────────────────────────────────────────────────────

  Widget _offDisplay() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _ledBox(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Text(
              'PANTALLA  APAGADA',
              style: TextStyle(
                fontSize: 24,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: Colors.white24,
                letterSpacing: 4,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── ON display ──────────────────────────────────────────────────────

  Widget _ledDisplay() {
    final flightsAsync = ref.watch(_ledProvider);
    final now = DateTime.now();
    const months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
    ];
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Center(
        child: flightsAsync.when(
          loading: () => _ledBox(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('CARGANDO...',
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'monospace',
                    color: _ledAmber,
                    letterSpacing: 4,
                  )),
            ),
          ),
          error: (_, __) => _ledBox(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('ERROR DE CONEXION',
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'monospace',
                    color: _ledRed,
                    letterSpacing: 4,
                  )),
            ),
          ),
          data: (result) {
            final flights = switch (result) {
              AppSuccess<List<FlightOrderItem>>(data: final list) => list,
              AppFailure<List<FlightOrderItem>>() => <FlightOrderItem>[],
            };

            return _ledBox(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──────────────────────────────────
                  _ledHeader('CG6 FLIGHTS — $dateStr'),
                  _ledDivider(),
                  // ── Column titles ────────────────────────────
                  _ledHeader(
                    'HORA     UNIDAD·COLA    DESTINO             ETA    OBSERVACION'),
                  _ledDivider(),
                  // ── Flight rows ──────────────────────────────
                  if (flights.isEmpty)
                    _ledRow('             SIN VUELOS PROGRAMADOS PARA HOY          ')
                  else
                    for (final f in flights) _ledRow(_formatRow(f)),
                  _ledDivider(),
                  // ── Legend ───────────────────────────────────
                  _ledRow('↑ SALIDAS    ↓ LLEGADAS    ≋ EN RUTA    ● ESPERA'),
                  // ── Footer ───────────────────────────────────
                  _ledDivider(),
                  _ledFooter(now),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── LED styling helpers ─────────────────────────────────────────────

  Widget _ledBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ledBg,
        border: Border.all(color: _ledAmber.withValues(alpha: 0.2), width: 1),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
              color: _glowAmber, blurRadius: 40, spreadRadius: 10),
        ],
      ),
      child: child,
    );
  }

  Widget _ledHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          color: _ledAmber,
          letterSpacing: 1.5,
          shadows: [
            Shadow(color: _ledAmber.withValues(alpha: 0.4), blurRadius: 6),
          ],
        ),
      ),
    );
  }

  Widget _ledDivider() {
    return Divider(
      height: 2,
      thickness: 1,
      color: _ledAmber.withValues(alpha: 0.15),
    );
  }

  Widget _ledRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w500,
          color: _ledGreen,
          letterSpacing: 0.5,
          height: 1.4,
          shadows: [
            Shadow(color: _ledGreen.withValues(alpha: 0.2), blurRadius: 4),
          ],
        ),
      ),
    );
  }

  Widget _ledFooter(DateTime now) {
    final timeStr =
        '${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}:${now.second.toString().padLeft(2, "0")}';
    return Text(
      'ACTUALIZADO: $timeStr  |  REFRESCO: 60s',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        fontFamily: 'monospace',
        color: _ledAmber.withValues(alpha: 0.5),
        letterSpacing: 1,
      ),
    );
  }

  // ── Data formatting ─────────────────────────────────────────────────

  String _formatRow(FlightOrderItem f) {
    final time = _formatTime(f);
    final unit = _getUnit(f).padRight(4);
    final tail = (_getTail(f)).padRight(7);
    final dest = _getDest(f).padRight(18);
    final eta = _getEta(f).padRight(6);
    final obs = _getObs(f);
    return '  $time  $unit·$tail  $dest  $eta  $obs';
  }

  String _formatTime(FlightOrderItem f) {
    if (f.scheduledDeparture != null) {
      return '${f.scheduledDeparture!.hour.toString().padLeft(2, "0")}:${f.scheduledDeparture!.minute.toString().padLeft(2, "0")}';
    }
    if (f.stateEvents.isNotEmpty) {
      final sorted = [...f.stateEvents]
        ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      final last = sorted.last;
      return '${last.occurredAt.hour.toString().padLeft(2, "0")}:${last.occurredAt.minute.toString().padLeft(2, "0")}';
    }
    return '--:--';
  }

  String _getUnit(FlightOrderItem f) {
    // Use unit name or fallback to code
    final name = f.unitName ?? '';
    if (name.isNotEmpty) {
      // Try to extract acronym or short code
      final parts = name.split(' ');
      if (parts.length >= 2 &&
          parts.last.length <= 6 &&
          parts.last == parts.last.toUpperCase()) {
        return parts.last;
      }
      return name.substring(0, name.length > 4 ? 4 : name.length);
    }
    return '----';
  }

  String _getTail(FlightOrderItem f) {
    return f.aircraftRegistration ?? '------';
  }

  String _getDest(FlightOrderItem f) {
    // Look for outbound route's destination
    final outbound = f.routes
        .where((r) => r.segmentType == 'outbound')
        .firstOrNull;
    final destLabel = outbound?.destinationLabel;
    if (destLabel != null && destLabel.isNotEmpty) return destLabel;
    // Fallback: use any route destination
    if (f.routes.isNotEmpty) {
      final lastLabel = f.routes.last.destinationLabel;
      if (lastLabel != null && lastLabel.isNotEmpty) return lastLabel;
    }
    return '--';
  }

  String _getEta(FlightOrderItem f) {
    if (f.eteMinutes == null) return '--:--';
    // Calculate ETA from last event or scheduled departure
    DateTime base;
    if (f.stateEvents.isNotEmpty) {
      final sorted = [...f.stateEvents]
        ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
      base = sorted.last.occurredAt;
    } else if (f.scheduledDeparture != null) {
      base = f.scheduledDeparture!;
    } else {
      return '--:--';
    }
    final eta = base.add(Duration(minutes: f.eteMinutes!));
    return '${eta.hour.toString().padLeft(2, "0")}:${eta.minute.toString().padLeft(2, "0")}';
  }

  String _getObs(FlightOrderItem f) {
    if (f.cancelled) return 'CANCELADO ';
    return switch (f.status) {
      'waiting' => 'ESPERA   ',
      'taxi' => 'TAXEO    ',
      'takeoff' => 'DESPEGUE ',
      'landing' => 'ATERRIZAJE',
      'engine_off' => 'COMPLETO ',
      _ => f.status.toUpperCase().padRight(9),
    };
  }
}
