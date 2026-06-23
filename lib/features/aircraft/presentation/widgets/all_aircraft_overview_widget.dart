import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft_flight_hours.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../aircraft_providers.dart';
import 'daily_section_widgets.dart';

class AllAircraftOverview extends ConsumerStatefulWidget {
  const AllAircraftOverview({
    super.key,
    required this.units,
    required this.aircraftByUnit,
  });

  final List<UnitOption> units;
  final Map<String, List<Aircraft>> aircraftByUnit;

  @override
  ConsumerState<AllAircraftOverview> createState() =>
      _AllAircraftOverviewState();
}

class _AllAircraftOverviewState extends ConsumerState<AllAircraftOverview> {
  int _unitIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hoursAsync = ref.watch(aircraftFlightHoursProvider(null));
    final hours = switch (hoursAsync.asData?.value) {
      AppSuccess<List<AircraftFlightHours>>(data: final list) => list,
      _ => <AircraftFlightHours>[],
    };
    final hoursByAircraft = {for (final h in hours) h.aircraftId: h};
    final aircraft = [
      for (final unit in widget.units)
        ...widget.aircraftByUnit[unit.id] ?? const [],
    ];
    final total = aircraft.length;
    final operational = aircraft.where((a) => a.status == 'operational').length;
    final inoperative = total - operational;
    final realHours = hours.fold<double>(0, (sum, h) => sum + h.realHours);
    final plannedHours = hours.fold<double>(
      0,
      (sum, h) => sum + h.plannedHours,
    );
    final maxIndex = widget.units.isEmpty ? 0 : widget.units.length - 1;
    final currentIndex = _unitIndex.clamp(0, maxIndex);
    final currentUnit = widget.units.isEmpty
        ? null
        : widget.units[currentIndex];
    final currentAircraft = <Aircraft>[
      if (currentUnit != null)
        ...(widget.aircraftByUnit[currentUnit.id] ?? const <Aircraft>[]),
    ]..sort((a, b) => a.displayTailNumber.compareTo(b.displayTailNumber));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.t('aircraft.dailyReport'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            l10n
                                .t('aircraft.unitsVisible')
                                .replaceAll(
                                  '{count}',
                                  '${widget.units.length}',
                                ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 720;
                    final cards = [
                      DailyStatCard(
                        label: l10n.t('aircraft.total'),
                        value: '$total',
                        color: theme.colorScheme.primary,
                      ),
                      DailyStatCard(
                        label: l10n.t('aircraft.operational'),
                        value: '$operational',
                        footer: total > 0
                            ? '${operational * 100 ~/ total}%'
                            : '0%',
                        color: StatusColors.aircraft['operational']!,
                      ),
                      DailyStatCard(
                        label: l10n.t('aircraft.inoperative'),
                        value: '$inoperative',
                        footer: total > 0
                            ? '${inoperative * 100 ~/ total}%'
                            : '0%',
                        color: StatusColors.aircraft['inoperative']!,
                      ),
                      DailyStatCard(
                        label: l10n.t('aircraft.hours.engineOff'),
                        value: '${realHours.toStringAsFixed(1)}h',
                        footer:
                            '${l10n.t('aircraft.hours.ov')}: ${plannedHours.toStringAsFixed(1)}h',
                        color: Colors.blue,
                      ),
                    ];
                    if (narrow) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final card in cards)
                            SizedBox(width: 160, child: card),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          Expanded(child: cards[i]),
                          if (i != cards.length - 1) const SizedBox(width: 8),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (currentUnit != null) ...[
          DailyUnitPager(
            units: widget.units,
            currentIndex: currentIndex,
            onPrevious: currentIndex == 0
                ? null
                : () => setState(() => _unitIndex = currentIndex - 1),
            onNext: currentIndex >= maxIndex
                ? null
                : () => setState(() => _unitIndex = currentIndex + 1),
            onSelect: (index) => setState(() => _unitIndex = index),
          ),
          const SizedBox(height: 10),
          DailyUnitSection(
            unit: currentUnit,
            aircraft: currentAircraft,
            hoursByAircraft: hoursByAircraft,
          ),
        ],
      ],
    );
  }
}
