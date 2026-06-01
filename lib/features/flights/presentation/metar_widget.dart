import 'dart:async';

import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/features/flights/application/metar_provider.dart';
import 'package:cg6_flights/features/flights/domain/metar_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MetarWidget extends ConsumerStatefulWidget {
  const MetarWidget({super.key, required this.icaoCodes});

  final List<String> icaoCodes;

  @override
  ConsumerState<MetarWidget> createState() => _MetarWidgetState();
}

class _MetarWidgetState extends ConsumerState<MetarWidget> {
  String? _selectedIcao;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-select first ICAO
    if (widget.icaoCodes.isNotEmpty) {
      _selectedIcao = widget.icaoCodes.first;
    }
    _refreshTimer = Timer.periodic(const Duration(hours: 1), (_) {
      if (mounted && _selectedIcao != null) {
        ref.invalidate(metarByIcaoProvider(_selectedIcao!));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MetarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.icaoCodes.isEmpty) {
      _selectedIcao = null;
      return;
    }
    if (_selectedIcao == null || !widget.icaoCodes.contains(_selectedIcao)) {
      _selectedIcao = widget.icaoCodes.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.icaoCodes.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surfaceContainerLow,
            theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _icaoSelector(theme),
          const SizedBox(width: 10),
          if (_selectedIcao != null)
            Expanded(child: _metarData(_selectedIcao!, theme)),
        ],
      ),
    );
  }

  Widget _icaoSelector(ThemeData theme) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 38),
      tooltip: '',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (icao) => setState(() => _selectedIcao = icao),
      itemBuilder: (_) => widget.icaoCodes
          .map(
            (icao) => PopupMenuItem<String>(
              value: icao,
              child: Row(
                children: [
                  Icon(
                    _selectedIcao == icao
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                    color: _selectedIcao == icao
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    icao,
                    style: TextStyle(
                      fontWeight: _selectedIcao == icao
                          ? FontWeight.w800
                          : FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.28),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 15,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                _selectedIcao ?? '--',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metarData(String icao, ThemeData theme) {
    final metarAsync = ref.watch(metarByIcaoProvider(icao));

    final child = metarAsync.when(
      loading: () => const _MetarLoadingDots(key: ValueKey('metar-loading')),
      error: (error, stackTrace) =>
          _NoMetarData(key: ValueKey('metar-error-$icao')),
      data: (metar) => metar == null
          ? _NoMetarData(key: ValueKey('metar-empty-$icao'))
          : _MetarSummary(
              key: ValueKey('metar-${metar.icao}-${metar.raw}'),
              metar: metar,
              onTap: () => _openDetailModal(context, metar),
            ),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0.03, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: child,
    );
  }

  void _openDetailModal(BuildContext context, MetarData metar) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            _MetarCategoryPulse(category: metar.flightCategory, size: 12),
            const SizedBox(width: 10),
            Text(
              metar.icao,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            _MetarCategoryBadge(category: metar.flightCategory),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RawReportBlock(label: 'METAR', value: metar.raw),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WeatherChip(
                      icon: Icons.thermostat,
                      label: l10n.t('flights.metar.temp'),
                      value: metar.tempDisplay,
                    ),
                    _WeatherChip(
                      icon: Icons.water_drop_outlined,
                      label: l10n.t('flights.metar.dewpoint'),
                      value: metar.dewpoint != null
                          ? '${metar.dewpoint!.toStringAsFixed(0)}°C'
                          : '--',
                    ),
                    _WeatherChip(
                      icon: Icons.air,
                      label: l10n.t('flights.metar.wind'),
                      value: metar.windDisplay,
                    ),
                    _WeatherChip(
                      icon: Icons.visibility_outlined,
                      label: l10n.t('flights.metar.visibility'),
                      value: metar.visDisplay,
                    ),
                    _WeatherChip(
                      icon: Icons.speed,
                      label: 'QNH',
                      value: metar.qnhDisplay,
                    ),
                    if (metar.observationTime != null)
                      _WeatherChip(
                        icon: Icons.schedule,
                        label: l10n.t('flights.metar.observedAt'),
                        value:
                            '${metar.observationTime!.hour.toString().padLeft(2, "0")}:${metar.observationTime!.minute.toString().padLeft(2, "0")}Z',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final tafAsync = ref.watch(tafByIcaoProvider(metar.icao));
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: tafAsync.when(
                        loading: () => const Padding(
                          key: ValueKey('taf-loading'),
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: _MetarLoadingDots()),
                        ),
                        error: (error, stackTrace) => const SizedBox.shrink(),
                        data: (tafs) {
                          if (tafs.isEmpty) return const SizedBox.shrink();
                          return Column(
                            key: const ValueKey('taf-data'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final taf in tafs)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _RawReportBlock(
                                    label: 'TAF',
                                    value: taf.raw,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.t('common.close')),
          ),
        ],
      ),
    );
  }
}

class _MetarSummary extends StatelessWidget {
  const _MetarSummary({super.key, required this.metar, required this.onTap});

  final MetarData metar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _MetarCategoryPulse(category: metar.flightCategory),
              const SizedBox(width: 8),
              _WeatherChip(
                icon: Icons.thermostat,
                label: '',
                value: metar.tempDisplay,
                dense: true,
              ),
              const SizedBox(width: 6),
              _WeatherChip(
                icon: Icons.air,
                label: '',
                value: metar.windDisplay,
                dense: true,
              ),
              const SizedBox(width: 6),
              _WeatherChip(
                icon: Icons.visibility_outlined,
                label: '',
                value: metar.visDisplay,
                dense: true,
              ),
              const SizedBox(width: 6),
              _WeatherChip(
                icon: Icons.speed,
                label: '',
                value: metar.qnhDisplay,
                dense: true,
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.open_in_new,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoMetarData extends StatelessWidget {
  const _NoMetarData({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 6),
        Text(
          l10n.t('flights.metar.noData'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MetarLoadingDots extends StatefulWidget {
  const _MetarLoadingDots({super.key});

  @override
  State<_MetarLoadingDots> createState() => _MetarLoadingDotsState();
}

class _MetarLoadingDotsState extends State<_MetarLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            _AnimatedDot(controller: _controller, index: i),
        ],
      ),
    );
  }
}

class _AnimatedDot extends StatelessWidget {
  const _AnimatedDot({required this.controller, required this.index});

  final AnimationController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    const size = 7.0;
    final delay = index * 0.25;
    final alpha = Tween<double>(begin: 0.28, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, delay + 0.4, curve: Curves.easeInOut),
      ),
    );
    final scale = Tween<double>(begin: 0.68, end: 1.16).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, delay + 0.4, curve: Curves.easeInOut),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => Transform.scale(
          scale: scale.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: alpha.value),
            ),
            child: const SizedBox(width: size, height: size),
          ),
        ),
      ),
    );
  }
}

class _MetarCategoryPulse extends StatefulWidget {
  const _MetarCategoryPulse({required this.category, this.size = 8});

  final String? category;
  final double size;

  @override
  State<_MetarCategoryPulse> createState() => _MetarCategoryPulseState();
}

class _MetarCategoryPulseState extends State<_MetarCategoryPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(widget.category);
    return SizedBox(
      width: widget.size * 2.5,
      height: widget.size * 2.5,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = Curves.easeOut.transform(_controller.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size + (widget.size * 1.4 * pulse),
                height: widget.size + (widget.size * 1.4 * pulse),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.22 * (1 - pulse)),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetarCategoryBadge extends StatelessWidget {
  const _MetarCategoryBadge({required this.category});

  final String? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _categoryColor(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        category ?? '--',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _WeatherChip extends StatelessWidget {
  const _WeatherChip({
    required this.icon,
    required this.label,
    required this.value,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 13 : 15, color: foreground),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _RawReportBlock extends StatelessWidget {
  const _RawReportBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.14),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

Color _categoryColor(String? category) {
  return switch (category) {
    'VFR' => Colors.green,
    'MVFR' => Colors.blue,
    'IFR' => Colors.red,
    'LIFR' => Colors.purple,
    _ => Colors.grey,
  };
}
