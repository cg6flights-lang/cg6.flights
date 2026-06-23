import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/state/timezone_provider.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft.dart';
import 'package:cg6_flights/features/aircraft/domain/aircraft_flight_hours.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../aircraft_providers.dart';
import 'aircraft_widgets.dart';

/// Aircraft detail dialog and its related-orders/hours widgets.

void showAircraftDetail(
  BuildContext context,
  Aircraft aircraft, {
  required bool canManage,
  required void Function(Aircraft) onEdit,
}) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: EdgeInsets.zero,
      titlePadding: EdgeInsets.zero,
      content: SizedBox(
        width: 640,
        child: _DetailContent(
          aircraft: aircraft,
          canManage: canManage,
          onEdit: onEdit,
        ),
      ),
    ),
  );
}

class _DetailContent extends ConsumerStatefulWidget {
  const _DetailContent({
    required this.aircraft,
    required this.canManage,
    required this.onEdit,
  });

  final Aircraft aircraft;
  final bool canManage;
  final void Function(Aircraft) onEdit;

  @override
  ConsumerState<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends ConsumerState<_DetailContent> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 30));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final aircraft = widget.aircraft;
    final isOp = aircraft.status == 'operational';
    final color = isOp ? Colors.green : Colors.red;
    final hoursAsync = ref.watch(aircraftFlightHoursProvider(aircraft.unitId));
    final ordersAsync = ref.watch(
      aircraftOrdersProvider(
        AircraftOrdersParams(aircraftId: aircraft.id, from: _from, to: _to),
      ),
    );
    final hours = switch (hoursAsync.asData?.value) {
      AppSuccess(data: final h) => h,
      _ => <AircraftFlightHours>[],
    };
    final ac = hours.where((h) => h.aircraftId == aircraft.id).firstOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isOp ? Icons.check_circle : Icons.error,
                      size: 24,
                      color: color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        aircraft.displayTailNumber,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (widget.canManage) ...[
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onEdit(aircraft);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: l10n.t('aircraft.edit'),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: color.withValues(alpha: 0.1),
                      ),
                      child: Text(
                        isOp ? 'Operativa' : 'Inoperativa',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${aircraft.manufacturer} ${aircraft.model}${aircraft.year != null ? ' · ${aircraft.year}' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (aircraft.serialNumber != null)
                  Text(
                    '${l10n.t('aircraft.detail.serial')}: ${aircraft.serialNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (!isOp && aircraft.inoperativeReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.t('aircraft.detail.reason')}: ${aircraft.inoperativeReason}',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (ac != null) ...[
            Row(
              children: [
                Expanded(
                  child: _HrCard(
                    l10n.t('aircraft.hours.real'),
                    '${ac.realHours.toStringAsFixed(1)}h',
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HrCard(
                    l10n.t('aircraft.hours.planned'),
                    '${ac.plannedHours.toStringAsFixed(1)}h',
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HrCard(
                    l10n.t('aircraft.hours.flights'),
                    '${ac.flightCount}',
                    theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              ac.diffHours >= 0
                  ? l10n
                        .t('aircraft.hours.more')
                        .replaceAll(
                          '{hours}',
                          ac.diffHours.abs().toStringAsFixed(1),
                        )
                  : l10n
                        .t('aircraft.hours.less')
                        .replaceAll(
                          '{hours}',
                          ac.diffHours.abs().toStringAsFixed(1),
                        ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: ac.diffHours >= 0 ? Colors.red : Colors.green,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _RelatedOrdersSection(
            from: _from,
            to: _to,
            ordersAsync: ordersAsync,
            onChangeFrom: () => _pickDate(isFrom: true),
            onChangeTo: () => _pickDate(isFrom: false),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final current = isFrom ? _from : _to;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = DateTime(selected.year, selected.month, selected.day);
        if (_from.isAfter(_to)) _to = _from;
      } else {
        _to = DateTime(selected.year, selected.month, selected.day);
        if (_to.isBefore(_from)) _from = _to;
      }
    });
  }
}

class _RelatedOrdersSection extends StatelessWidget {
  const _RelatedOrdersSection({
    required this.from,
    required this.to,
    required this.ordersAsync,
    required this.onChangeFrom,
    required this.onChangeTo,
  });

  final DateTime from;
  final DateTime to;
  final AsyncValue<AppResult<List<FlightOrderItem>>> ordersAsync;
  final VoidCallback onChangeFrom;
  final VoidCallback onChangeTo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.t('aircraft.relatedOrders'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onChangeFrom,
              icon: const Icon(Icons.date_range_outlined, size: 16),
              label: Text(
                '${l10n.t('aircraft.from')}: ${_formatAircraftDate(from)}',
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onChangeTo,
              icon: const Icon(Icons.event_outlined, size: 16),
              label: Text(
                '${l10n.t('aircraft.to')}: ${_formatAircraftDate(to)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ordersAsync.when(
          loading: () => Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => _RelatedOrdersState(
            message: l10n.t('aircraft.relatedOrdersFailed'),
          ),
          data: (result) => switch (result) {
            AppSuccess<List<FlightOrderItem>>(data: final items) =>
              items.isEmpty
                  ? _RelatedOrdersState(
                      message: l10n.t('aircraft.noRelatedOrders'),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _RelatedOrderCard(item: item),
                          ),
                      ],
                    ),
            AppFailure<List<FlightOrderItem>>() => _RelatedOrdersState(
              message: l10n.t('aircraft.relatedOrdersFailed'),
            ),
          },
        ),
      ],
    );
  }
}

class _RelatedOrdersState extends StatelessWidget {
  const _RelatedOrdersState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _RelatedOrderCard extends ConsumerWidget {
  const _RelatedOrderCard({required this.item});

  final FlightOrderItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tz = ref.watch(timezoneProvider);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.orderNumber ?? item.flightOrderId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SmallMetaChip(
                label: item.operationDate != null
                    ? _formatAircraftDate(item.operationDate!)
                    : '--',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SmallMetaChip(
                label:
                    '${l10n.t('aircraft.orderStatus')}: ${_labelOrDash(item.orderStatus)}',
              ),
              SmallMetaChip(
                label:
                    '${l10n.t('aircraft.itemStatus')}: ${_labelOrDash(item.status)}',
              ),
              SmallMetaChip(
                label:
                    '${l10n.t('aircraft.etd')}: ${formatTimeWithOffset(item.scheduledDeparture, tz)}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${l10n.t('aircraft.mission')}: ${_labelOrDash(item.mission)}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            '${l10n.t('aircraft.route')}: ${_routeSummary(item)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatAircraftDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _labelOrDash(String? value) {
  if (value == null || value.trim().isEmpty) return '--';
  return value;
}

String _routeSummary(FlightOrderItem item) {
  if (item.routes.isEmpty) return '--';
  final route = item.routes.first;
  final origin = route.originIcao ?? route.originRouteName ?? route.originLabel;
  final destination =
      route.destinationIcao ??
      route.destinationRouteName ??
      route.destinationLabel;
  return '${_labelOrDash(origin)} - ${_labelOrDash(destination)}';
}

class _HrCard extends StatelessWidget {
  const _HrCard(this.label, this.value, this.color);
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      color: color.withValues(alpha: 0.05),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}
