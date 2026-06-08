import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft.dart';
import 'package:cg6_flights/features/dashboard/application/dashboard_providers.dart';
import 'package:cg6_flights/features/dashboard/domain/dashboard_widget_config.dart';
import 'package:cg6_flights/features/dashboard/presentation/widgets/dashboard_widget_base.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FleetStatusWidget extends ConsumerWidget {
  const FleetStatusWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleetAsync = ref.watch(dashboardFleetProvider);

    final child = fleetAsync.when(
      loading: () =>
          const _Centered(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) =>
          const _Centered(child: Icon(Icons.error_outline, size: 20)),
      data: (groups) => _FleetBoard(groups: groups),
    );

    return DashboardWidgetWrapper(
      config: DashboardWidgetConfig.byId('fleet')!,
      child: child,
    );
  }
}

class _FleetBoard extends StatelessWidget {
  const _FleetBoard({required this.groups});

  final List<DashboardFleetUnitGroup> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (groups.isEmpty) {
      return _Centered(
        child: Text(
          l10n.t('dashboard.fleet.empty'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final group in groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FleetUnitBlock(group: group),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FleetUnitBlock extends StatelessWidget {
  const _FleetUnitBlock({required this.group});

  final DashboardFleetUnitGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final operationalAircraft =
        group.aircraft
            .where((aircraft) => aircraft.status == 'operational')
            .toList()
          ..sort((a, b) {
            final byModel = _fleetAircraftCode(
              a,
            ).compareTo(_fleetAircraftCode(b));
            if (byModel != 0) return byModel;
            return a.tailNumber.compareTo(b.tailNumber);
          });

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            group.unitCode,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          if (operationalAircraft.isEmpty)
            Text(
              l10n.t('dashboard.fleet.noOperational'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final aircraft in operationalAircraft)
                  _FleetAircraftCell(
                    unitCode: group.unitCode,
                    aircraft: aircraft,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _FleetAircraftCell extends StatelessWidget {
  const _FleetAircraftCell({required this.unitCode, required this.aircraft});

  final String unitCode;
  final Aircraft aircraft;

  @override
  Widget build(BuildContext context) {
    final color = StatusColors.aircraft['operational']!;

    return InkWell(
      onTap: () => _showFleetAircraftDialog(
        context,
        unitCode: unitCode,
        aircraft: aircraft,
      ),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        constraints: const BoxConstraints(minWidth: 46, minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(
          aircraft.displayTailNumber,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

String _fleetAircraftCode(Aircraft aircraft) {
  final model = aircraft.model.trim();
  final manufacturer = aircraft.manufacturer.trim();
  if (manufacturer.isEmpty) return model;
  final lowerModel = model.toLowerCase();
  final lowerManufacturer = manufacturer.toLowerCase();
  if (!lowerModel.startsWith(lowerManufacturer)) return model;
  final code = model.substring(manufacturer.length).trim();
  return code.isEmpty ? model : code;
}

void _showFleetAircraftDialog(
  BuildContext context, {
  required String unitCode,
  required Aircraft aircraft,
}) {
  final l10n = AppLocalizations.of(context);
  final isOperational = aircraft.status == 'operational';
  final color = isOperational
      ? StatusColors.aircraft['operational']!
      : StatusColors.aircraft['inoperative']!;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(aircraft.displayTailNumber)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: color.withValues(alpha: 0.1),
            ),
            child: Text(
              isOperational
                  ? l10n.t('aircraft.operational')
                  : l10n.t('aircraft.inoperative'),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FleetDetailRow(label: l10n.t('aircraft.unit'), value: unitCode),
            _FleetDetailRow(
              label: l10n.t('aircraft.model'),
              value: aircraft.model,
            ),
            _FleetDetailRow(
              label: l10n.t('aircraft.manufacturer'),
              value: aircraft.manufacturer,
            ),
            if (aircraft.year != null)
              _FleetDetailRow(
                label: l10n.t('aircraft.year'),
                value: aircraft.year.toString(),
              ),
            if (aircraft.serialNumber?.isNotEmpty == true)
              _FleetDetailRow(
                label: l10n.t('aircraft.serialNumber'),
                value: aircraft.serialNumber!,
              ),
            if (!isOperational) ...[
              const SizedBox(height: 8),
              Text(
                aircraft.inoperativeReason?.trim().isNotEmpty == true
                    ? aircraft.inoperativeReason!.trim()
                    : l10n.t('aircraft.noInoperativeReason'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.t('common.close')),
        ),
      ],
    ),
  );
}

class _FleetDetailRow extends StatelessWidget {
  const _FleetDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Center(child: child),
  );
}
