import 'dart:async';

import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/state/timezone_provider.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/features/flights/application/flight_led_board_presenter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _ledProvider =
    FutureProvider.family<AppResult<List<FlightOrderItem>>, DateTime>((
  ref,
  date,
) {
  final repo = ref.read(flightOrdersRepositoryProvider);
  return repo.listFlightsByDate(date: date);
});

class FlightLedBoard extends ConsumerStatefulWidget {
  const FlightLedBoard({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  ConsumerState<FlightLedBoard> createState() => _FlightLedBoardState();
}

class _FlightLedBoardState extends ConsumerState<FlightLedBoard> {
  late DateTime _selectedDate;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _dateLabel(DateTime d) {
    const months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  void _changeDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    // Don't allow going past today
    if (newDate.isAfter(_today)) return;
    setState(() => _selectedDate = newDate);
    _refresh();
  }

  Widget _dateNavButton(IconData icon, VoidCallback? onPressed) {
    final active = onPressed != null;
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: 16),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          foregroundColor: active ? _yellow : _offText,
        ),
      ),
    );
  }

  static const _bg = Color(0xFF050606);
  static const _panel = Color(0xFF0A0D0A);
  static const _panelEdge = Color(0xFF1A1F1C);
  static const _grid = Color(0xFF253027);
  static const _yellow = Color(0xFFFFD21A);
  static const _yellowGlow = Color(0xFFFFE766);
  static const _green = Color(0xFF46FF7A);
  static const _amber = Color(0xFFFFB000);
  static const _red = Color(0xFFFF3B30);
  static const _offText = Color(0xFF1C221C);

  final _presenter = const FlightLedBoardPresenter();
  bool _powerOn = true;
  DateTime _now = DateTime.now();
  DateTime _lastRefresh = DateTime.now();
  Timer? _clock;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _autoRefresh?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_powerOn || !mounted) return;
      _refresh();
    });
  }

  void _refresh() {
    setState(() => _lastRefresh = DateTime.now());
    ref.invalidate(_ledProvider(_selectedDate));
  }

  void _togglePower() {
    setState(() => _powerOn = !_powerOn);
    if (_powerOn) {
      _refresh();
      _startAutoRefresh();
    } else {
      _autoRefresh?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.15,
                    colors: [Color(0xFF0B0F0B), Color(0xFF020303)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              top: 56,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
                child: _powerOn ? _liveDisplay(l10n) : _offDisplay(l10n),
              ),
            ),
            Positioned(
              top: 12,
              left: 18,
              child: IconButton(
                tooltip: l10n.t('common.back'),
                icon: const Icon(Icons.close, color: Colors.white38, size: 24),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: 14,
              right: 22,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _topPill(
                    label: _powerOn
                        ? l10n.t('flights.ledPowerOn')
                        : l10n.t('flights.ledPowerOff'),
                    icon: Icons.power_settings_new,
                    color: _powerOn ? _green : Colors.white38,
                    onTap: _togglePower,
                  ),
                  const SizedBox(width: 10),
                  _topPill(
                    label: l10n.t('common.retry'),
                    icon: Icons.refresh,
                    color: _yellow,
                    onTap: _powerOn ? _refresh : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveDisplay(AppLocalizations l10n) {
    final flightsAsync = ref.watch(_ledProvider(_selectedDate));

    return flightsAsync.when(
      loading: () => _displayShell(
        child: _centerMessage(l10n.t('common.loading'), _amber),
      ),
      error: (error, stackTrace) => _displayShell(
        child: _centerMessage(l10n.t('flights.ledConnectionError'), _red),
      ),
      data: (result) {
        final flights = switch (result) {
          AppSuccess<List<FlightOrderItem>>(data: final list) => list,
          AppFailure<List<FlightOrderItem>>() => <FlightOrderItem>[],
        };
        final tz = ref.watch(timezoneProvider);
        final rows = _presenter.rows(flights, now: _now, tzOffset: tz);

        return _displayShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _displayHeader(l10n, rows.length),
              const SizedBox(height: 14),
              Expanded(child: _gridArea(rows, l10n)),
              const SizedBox(height: 12),
              _displayFooter(l10n),
            ],
          ),
        );
      },
    );
  }

  Widget _offDisplay(AppLocalizations l10n) {
    return _displayShell(
      powerOn: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.power_settings_new, size: 46, color: _offText),
            const SizedBox(height: 18),
            Text(
              l10n.t('flights.ledOff'),
              textAlign: TextAlign.center,
              style: _mono(
                color: _offText,
                size: 28,
                weight: FontWeight.w800,
                spacing: 4,
                glow: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _displayShell({required Widget child, bool powerOn = true}) {
    final borderColor = powerOn ? _yellow.withValues(alpha: 0.5) : _grid;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _panelEdge,
        border: Border.all(color: const Color(0xFF343B36), width: 2),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 28,
            spreadRadius: 4,
          ),
          if (powerOn)
            BoxShadow(
              color: _yellow.withValues(alpha: 0.18),
              blurRadius: 42,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: powerOn ? _panel : const Color(0xFF030403),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LedSurfacePainter(powerOn: powerOn),
                  ),
                ),
                Padding(padding: const EdgeInsets.all(18), child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _displayHeader(AppLocalizations l10n, int count) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final title = Text(
          l10n.t('flights.ledTitle'),
          maxLines: compact ? 3 : 1,
          overflow: TextOverflow.ellipsis,
          style: _mono(
            color: _yellow,
            size: compact ? 14 : 18,
            weight: FontWeight.w800,
            spacing: compact ? 1 : 1.2,
          ),
        );
        final canGoForward = _selectedDate.isBefore(_today);
        final dateNav = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dateNavButton(Icons.chevron_left, () => _changeDate(-1)),
            const SizedBox(width: 4),
            SizedBox(
              width: 130,
              child: Text(
                _dateLabel(_selectedDate),
                textAlign: TextAlign.center,
                style: _mono(
                  color: _yellow,
                  size: 13,
                  weight: FontWeight.w800,
                  spacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 4),
            _dateNavButton(Icons.chevron_right,
                canGoForward ? () => _changeDate(1) : null),
          ],
        );
        final meta = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _liveBadge(l10n),
            const SizedBox(width: 18),
            Text(
              '${l10n.t('flights.ledFlights')}: $count',
              overflow: TextOverflow.ellipsis,
              style: _mono(
                color: _yellowGlow,
                size: compact ? 12 : 13,
                weight: FontWeight.w700,
                spacing: 1,
              ),
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _grid.withValues(alpha: 0.8)),
            ),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 12),
                    Row(children: [dateNav, const SizedBox(width: 12), meta]),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    dateNav,
                    const SizedBox(width: 20),
                    meta,
                  ],
                ),
        );
      },
    );
  }

  Widget _liveBadge(AppLocalizations l10n) {
    final active = _now.second.isEven;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedOpacity(
          opacity: active ? 1 : 0.35,
          duration: const Duration(milliseconds: 220),
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _green.withValues(alpha: 0.9), blurRadius: 8),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          l10n.t('flights.ledLive'),
          style: _mono(
            color: _green,
            size: 12,
            weight: FontWeight.w800,
            spacing: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _gridArea(List<LedFlightRow> rows, AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth < 940
            ? 940.0
            : constraints.maxWidth;

        if (rows.isEmpty) {
          return SizedBox(
            width: constraints.maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: constraints.maxWidth,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: gridWidth, child: _gridHeader(l10n)),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: _emptyRows(l10n),
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: gridWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _gridHeader(l10n),
                Expanded(child: _rowsViewport(rows, l10n)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _gridHeader(AppLocalizations l10n) {
    return _gridRow(
      time: l10n.t('flights.ledColTime'),
      unit: l10n.t('flights.ledColUnit'),
      tail: l10n.t('flights.ledColTail'),
      destination: l10n.t('flights.ledColDestination'),
      takeoff: l10n.t('flights.ledColTakeoff'),
      eta: l10n.t('flights.ledColEta'),
      landing: l10n.t('flights.ledColLanding'),
      observation: l10n.t('flights.ledColObservation'),
      color: _yellow,
      size: 13,
      weight: FontWeight.w800,
      header: true,
    );
  }

  Widget _rowsViewport(List<LedFlightRow> rows, AppLocalizations l10n) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: rows.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        color: _grid.withValues(alpha: 0.45),
      ),
      itemBuilder: (context, index) {
        final row = rows[index];
        final toneColor = _toneColor(row.tone);
        return _gridRow(
          time: row.time,
          unit: row.unit,
          tail: row.tail,
          destination: row.destination,
          takeoff: row.takeoff,
          eta: row.eta,
          landing: row.landing,
          observation: l10n.t(row.statusKey),
          color: toneColor,
          observationColor: toneColor,
          size: 24,
          weight: FontWeight.w700,
          blink: index == 0,
        );
      },
    );
  }

  Widget _emptyRows(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            l10n.t('flights.ledNoFlights'),
            textAlign: TextAlign.center,
            style: _mono(
              color: _amber,
              size: 24,
              weight: FontWeight.w800,
              spacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _gridRow({
    required String time,
    required String unit,
    required String tail,
    required String destination,
    required String takeoff,
    required String eta,
    required String landing,
    required String observation,
    required Color color,
    Color? observationColor,
    required double size,
    required FontWeight weight,
    bool header = false,
    bool blink = false,
  }) {
    final style = _mono(color: color, size: size, weight: weight);
    final observationStyle = _mono(
      color: observationColor ?? color,
      size: size,
      weight: FontWeight.w800,
    );
    final verticalPadding = header ? 11.0 : 13.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: verticalPadding),
      decoration: BoxDecoration(
        border: Border(
          bottom: header
              ? BorderSide(color: _yellow.withValues(alpha: 0.45), width: 1)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text(time, style: style)),
          Expanded(flex: 1, child: Text(unit, style: style)),
          Expanded(flex: 1, child: Text(tail, style: style)),
          Expanded(flex: 1, child: Text(destination, style: style)),
          Expanded(flex: 1, child: Text(takeoff, style: style)),
          Expanded(flex: 1, child: Text(eta, style: style)),
          Expanded(flex: 1, child: Text(landing, style: style)),
          Expanded(
            flex: 1,
            child: blink
                ? AnimatedOpacity(
                    opacity: _now.second.isEven ? 1 : 0.35,
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      observation,
                      overflow: TextOverflow.ellipsis,
                      style: observationStyle,
                    ),
                  )
                : Text(
                    observation,
                    overflow: TextOverflow.ellipsis,
                    style: observationStyle,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _displayFooter(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _grid.withValues(alpha: 0.8))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${l10n.t('flights.ledLastUpdated')}: ${_timeLabel(_lastRefresh)}',
              style: _mono(
                color: _yellow.withValues(alpha: 0.65),
                size: 12,
                weight: FontWeight.w700,
                spacing: 1,
                glow: false,
              ),
            ),
          ),
          Text(
            '${l10n.t('flights.ledRefresh')}: 60s',
            style: _mono(
              color: _yellow.withValues(alpha: 0.65),
              size: 12,
              weight: FontWeight.w700,
              spacing: 1,
              glow: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _centerMessage(String text, Color color) {
    return Center(
      child: Text(
        text.toUpperCase(),
        textAlign: TextAlign.center,
        style: _mono(
          color: color,
          size: 24,
          weight: FontWeight.w800,
          spacing: 3,
        ),
      ),
    );
  }

  Widget _topPill({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: onTap == null ? 0.04 : 0.09),
          border: Border.all(color: color.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: _mono(
                  color: color,
                  size: 11,
                  weight: FontWeight.w800,
                  spacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _toneColor(LedFlightTone tone) {
    return switch (tone) {
      LedFlightTone.success => _green,
      LedFlightTone.warning => _amber,
      LedFlightTone.critical => _red,
      LedFlightTone.muted => _yellow.withValues(alpha: 0.65),
      LedFlightTone.normal => _yellow,
    };
  }

  TextStyle _mono({
    required Color color,
    required double size,
    required FontWeight weight,
    double spacing = 1.1,
    bool glow = true,
  }) {
    return TextStyle(
      color: color,
      fontSize: size,
      fontFamily: 'monospace',
      fontWeight: weight,
      letterSpacing: spacing,
      height: 1.05,
      shadows: glow
          ? [
              Shadow(color: color.withValues(alpha: 0.75), blurRadius: 10),
              Shadow(color: color.withValues(alpha: 0.45), blurRadius: 3),
            ]
          : null,
    );
  }

  String _timeLabel(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}:'
        '${date.second.toString().padLeft(2, '0')}';
  }
}

class _LedSurfacePainter extends CustomPainter {
  const _LedSurfacePainter({required this.powerOn});

  final bool powerOn;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = (powerOn ? const Color(0xFFFFD21A) : const Color(0xFF1C221C))
          .withValues(alpha: powerOn ? 0.055 : 0.035);
    for (var y = 3.0; y < size.height; y += 7) {
      for (var x = 3.0; x < size.width; x += 7) {
        canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
      }
    }

    final linePaint = Paint()
      ..color = Colors.black.withValues(alpha: powerOn ? 0.12 : 0.22)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LedSurfacePainter oldDelegate) {
    return oldDelegate.powerOn != powerOn;
  }
}
