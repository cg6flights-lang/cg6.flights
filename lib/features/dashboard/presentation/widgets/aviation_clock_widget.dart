import 'dart:async';
import 'dart:math' as math;

import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/state/timezone_provider.dart';
import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AviationClockMode { zulu, local }

class ZuluClockWidget extends StatelessWidget {
  const ZuluClockWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const AviationClockWidget(
      configId: 'zulu_clock',
      mode: AviationClockMode.zulu,
      accentColor: Color(0xFF7CE7FF),
    );
  }
}

class RomeoClockWidget extends ConsumerWidget {
  const RomeoClockWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AviationClockWidget(
      configId: 'romeo_clock',
      mode: AviationClockMode.local,
      offsetHours: ref.watch(timezoneProvider),
      accentColor: const Color(0xFFE6FF72),
    );
  }
}

class AviationClockWidget extends ConsumerStatefulWidget {
  const AviationClockWidget({
    super.key,
    required this.configId,
    required this.mode,
    required this.accentColor,
    this.offsetHours = 0,
  });

  final String configId;
  final AviationClockMode mode;
  final Color accentColor;
  final int offsetHours;

  @override
  ConsumerState<AviationClockWidget> createState() =>
      _AviationClockWidgetState();
}

class _AviationClockWidgetState extends ConsumerState<AviationClockWidget> {
  late DateTime _nowUtc;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _nowUtc = DateTime.now().toUtc();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _nowUtc = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = DashboardWidgetConfig.byId(widget.configId)!;
    final clockTime = widget.mode == AviationClockMode.zulu
        ? _nowUtc
        : _nowUtc.add(Duration(hours: widget.offsetHours));
    final l10n = AppLocalizations.of(context);
    final title = widget.mode == AviationClockMode.zulu
        ? l10n.t('dashboard.widget.zuluClock')
        : l10n.t('dashboard.widget.romeoClock');
    final zoneLabel = widget.mode == AviationClockMode.zulu
        ? l10n.t('dashboard.clock.utc')
        : (widget.offsetHours == -5
              ? 'UTC-5'
              : '${l10n.t('dashboard.clock.local')} · ${_offsetLabel(widget.offsetHours)}');

    return DashboardWidgetWrapper(
      config: config,
      child: _ClockPanel(
        title: title,
        zoneLabel: zoneLabel,
        time: clockTime,
        palette: _ClockPalette.resolve(
          context,
          mode: widget.mode,
          darkAccentColor: widget.accentColor,
        ),
      ),
    );
  }
}

class _ClockPanel extends StatelessWidget {
  const _ClockPanel({
    required this.title,
    required this.zoneLabel,
    required this.time,
    required this.palette,
  });

  final String title;
  final String zoneLabel;
  final DateTime time;
  final _ClockPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.panelColor,
          gradient: palette.panelGradient,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.borderColor),
          boxShadow: [
            BoxShadow(
              color: palette.shadowColor,
              blurRadius: palette.shadowBlur,
              spreadRadius: palette.shadowSpread,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 82,
                child: CustomPaint(
                  painter: _AnalogClockPainter(time: time, palette: palette),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$title · $zoneLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.titleColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatTime(time),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: palette.digitalColor,
                          fontSize: 31,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                          shadows: palette.digitalShadows,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(time),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: palette.dateColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalogClockPainter extends CustomPainter {
  const _AnalogClockPainter({required this.time, required this.palette});

  final DateTime time;
  final _ClockPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final dialPaint = Paint()
      ..color = palette.dialColor
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = palette.ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final glowPaint = Paint()
      ..color = palette.dialGlowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, palette.dialGlowBlur);

    canvas.drawCircle(center, radius - 2, glowPaint);
    canvas.drawCircle(center, radius - 4, dialPaint);
    canvas.drawCircle(center, radius - 7, ringPaint);

    for (var i = 0; i < 60; i++) {
      final angle = (i / 60) * math.pi * 2 - math.pi / 2;
      final major = i % 5 == 0;
      final inner = radius - (major ? 18 : 13);
      final outer = radius - 9;
      final paint = Paint()
        ..color = major ? palette.majorTickColor : palette.minorTickColor
        ..strokeWidth = major ? 2.4 : 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        center + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        paint,
      );
    }

    final hourAngle =
        ((time.hour % 12) + time.minute / 60) / 12 * math.pi * 2 - math.pi / 2;
    final minuteAngle =
        (time.minute + time.second / 60) / 60 * math.pi * 2 - math.pi / 2;
    final secondAngle = time.second / 60 * math.pi * 2 - math.pi / 2;

    _drawHand(
      canvas,
      center,
      hourAngle,
      radius * 0.43,
      palette.hourHandColor,
      4.2,
    );
    _drawHand(
      canvas,
      center,
      minuteAngle,
      radius * 0.67,
      palette.minuteHandColor,
      3,
    );
    _drawHand(
      canvas,
      center,
      secondAngle,
      radius * 0.72,
      palette.secondHandColor,
      1.8,
    );
    _drawHand(
      canvas,
      center,
      secondAngle + math.pi,
      radius * 0.18,
      palette.secondHandColor,
      1.8,
    );

    canvas.drawCircle(center, 4.4, Paint()..color = palette.centerOuterColor);
    canvas.drawCircle(center, 2.2, Paint()..color = palette.centerInnerColor);
  }

  void _drawHand(
    Canvas canvas,
    Offset center,
    double angle,
    double length,
    Color color,
    double strokeWidth,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      center + Offset(math.cos(angle) * length, math.sin(angle) * length),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AnalogClockPainter oldDelegate) {
    return oldDelegate.time.second != time.second ||
        oldDelegate.palette != palette;
  }
}

class _ClockPalette {
  const _ClockPalette({
    required this.panelColor,
    required this.panelGradient,
    required this.borderColor,
    required this.shadowColor,
    required this.shadowBlur,
    required this.shadowSpread,
    required this.titleColor,
    required this.digitalColor,
    required this.digitalShadows,
    required this.dateColor,
    required this.dialColor,
    required this.ringColor,
    required this.dialGlowColor,
    required this.dialGlowBlur,
    required this.majorTickColor,
    required this.minorTickColor,
    required this.hourHandColor,
    required this.minuteHandColor,
    required this.secondHandColor,
    required this.centerOuterColor,
    required this.centerInnerColor,
  });

  final Color panelColor;
  final Gradient? panelGradient;
  final Color borderColor;
  final Color shadowColor;
  final double shadowBlur;
  final double shadowSpread;
  final Color titleColor;
  final Color digitalColor;
  final List<Shadow> digitalShadows;
  final Color dateColor;
  final Color dialColor;
  final Color ringColor;
  final Color dialGlowColor;
  final double dialGlowBlur;
  final Color majorTickColor;
  final Color minorTickColor;
  final Color hourHandColor;
  final Color minuteHandColor;
  final Color secondHandColor;
  final Color centerOuterColor;
  final Color centerInnerColor;

  static _ClockPalette resolve(
    BuildContext context, {
    required AviationClockMode mode,
    required Color darkAccentColor,
  }) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      return _ClockPalette.dark(darkAccentColor);
    }
    return _ClockPalette.light(mode);
  }

  factory _ClockPalette.dark(Color accentColor) {
    return _ClockPalette(
      panelColor: const Color(0xFF071019),
      panelGradient: null,
      borderColor: accentColor.withValues(alpha: 0.28),
      shadowColor: accentColor.withValues(alpha: 0.10),
      shadowBlur: 18,
      shadowSpread: -6,
      titleColor: accentColor,
      digitalColor: const Color(0xFFE9F7FF),
      digitalShadows: const [
        Shadow(color: Color(0xAA5FD7FF), blurRadius: 8),
        Shadow(color: Color(0x665FD7FF), blurRadius: 18),
      ],
      dateColor: Colors.white70,
      dialColor: const Color(0xFF0C1722),
      ringColor: Colors.white.withValues(alpha: 0.88),
      dialGlowColor: accentColor.withValues(alpha: 0.16),
      dialGlowBlur: 10,
      majorTickColor: Colors.white.withValues(alpha: 0.95),
      minorTickColor: Colors.white.withValues(alpha: 0.72),
      hourHandColor: Colors.white,
      minuteHandColor: Colors.white.withValues(alpha: 0.92),
      secondHandColor: Colors.redAccent,
      centerOuterColor: Colors.redAccent,
      centerInnerColor: Colors.white,
    );
  }

  factory _ClockPalette.light(AviationClockMode mode) {
    final isZulu = mode == AviationClockMode.zulu;
    final accent = isZulu ? const Color(0xFF0E5DCB) : const Color(0xFFD9A441);
    final accentStrong = isZulu
        ? const Color(0xFF0846B4)
        : const Color(0xFF9A6A12);
    return _ClockPalette(
      panelColor: const Color(0xFFF8FBFF),
      panelGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF8FBFF), Color(0xFFEAF2FF)],
      ),
      borderColor: const Color(0xFFC9D6E5),
      shadowColor: const Color(0x1A0846B4),
      shadowBlur: 14,
      shadowSpread: -8,
      titleColor: accentStrong,
      digitalColor: const Color(0xFF0846B4),
      digitalShadows: const [Shadow(color: Color(0x220846B4), blurRadius: 5)],
      dateColor: const Color(0xFF4E6082),
      dialColor: Colors.white,
      ringColor: const Color(0xFFC9D6E5),
      dialGlowColor: accent.withValues(alpha: 0.10),
      dialGlowBlur: 8,
      majorTickColor: const Color(0xFF0846B4),
      minorTickColor: const Color(0xFF7A8FAE),
      hourHandColor: const Color(0xFF101820),
      minuteHandColor: const Color(0xFF24384F),
      secondHandColor: accent,
      centerOuterColor: accent,
      centerInnerColor: Colors.white,
    );
  }
}

String _formatTime(DateTime time) {
  return [
    time.hour.toString().padLeft(2, '0'),
    time.minute.toString().padLeft(2, '0'),
    time.second.toString().padLeft(2, '0'),
  ].join(':');
}

String _formatDate(DateTime time) {
  return '${time.day.toString().padLeft(2, '0')}.${time.month.toString().padLeft(2, '0')}.${time.year}';
}

String _offsetLabel(int offsetHours) {
  if (offsetHours == 0) return 'UTC';
  final sign = offsetHours > 0 ? '+' : '-';
  return 'UTC$sign${offsetHours.abs()}';
}
