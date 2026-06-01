import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/state/timezone_provider.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlightItemDetailDialog extends ConsumerStatefulWidget {
  const FlightItemDetailDialog({
    super.key,
    required this.item,
    required this.operationDate,
    this.canEdit = false,
    this.onEdit,
    required this.onChanged,
  });

  final FlightOrderItem item;
  final DateTime operationDate;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback onChanged;

  @override
  ConsumerState<FlightItemDetailDialog> createState() =>
      _FlightItemDetailDialogState();
}

class _FlightItemDetailDialogState
    extends ConsumerState<FlightItemDetailDialog> {

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final l10n = AppLocalizations.of(context);
    final tz = ref.watch(timezoneProvider);
    final isCancelled = item.cancelled;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.flight, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _aircraftLabel(l10n),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          StatusChip.fromStatus(isCancelled ? 'cancelled' : item.status),
          if (widget.canEdit) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: l10n.t('flightOrders.editItem'),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onEdit?.call();
              },
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mission
              if (item.mission != null && item.mission!.isNotEmpty)
                _sectionLabel(context, l10n.t('flightOrders.mission')),
              if (item.mission != null && item.mission!.isNotEmpty)
                Text(item.mission!, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),

              // Flight data
              _sectionLabel(context, l10n.t('flightOrders.flightLevel')),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (item.eteMinutes != null)
                    _infoRow(Icons.timer_outlined,
                        '${l10n.t("flightOrders.ete")}: ${item.eteMinutes} min'),
                  if (item.flightLevelMin != null)
                    _infoRow(Icons.height, item.flightLevelDisplay),
                  if (item.fuelAmount != null)
                    _infoRow(
                        Icons.local_gas_station_outlined,
                        '${item.fuelAmount} lbs${item.fuelType != null ? " (${item.fuelType})" : ""}'),
                  if (item.scheduledDeparture != null)
                    _infoRow(
                        Icons.schedule_outlined,
                        '${l10n.t("flightOrders.departure")}: ${_formatTime(item.scheduledDeparture!, tz)}'),
                ],
              ),
              const SizedBox(height: 12),

              // Crew
              if (item.crew.isNotEmpty) ...[
                _sectionLabel(context, l10n.t('flightOrders.crew')),
                ...item.crew.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '${c.roleCode}: ${c.crewMemberName ?? "--"}${c.functionCode != null ? " [${c.functionCode}]" : ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    )),
                const SizedBox(height: 12),
              ],

              // Routes
              if (item.routes.isNotEmpty) ...[
                _sectionLabel(context, l10n.t('flightOrders.routes')),
                ...item.routes.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Text(
                            '${r.segmentType == "return" ? "↩" : "↪"} ${r.displayLabel}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
              ],

              // Profiles
              if (item.profiles.isNotEmpty) ...[
                _sectionLabel(context, l10n.t('flightOrders.profiles')),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: item.profiles
                      .map((p) => StatusChip(
                            label:
                                'Perfil ${p.profileNumber}: ${p.description}',
                            color: Colors.teal,
                            size: StatusChipSize.small,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],

              // State events timeline
              if (item.stateEvents.isNotEmpty) ...[
                _sectionLabel(context, l10n.t('flightOrders.stateEvents')),
                const SizedBox(height: 4),
                _stateTimeline(item.stateEvents, tz),
                if (_eventTime(item.stateEvents, 'taxi') != null &&
                    _eventTime(item.stateEvents, 'engine_off') != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _timeChip(
                        l10n.t('flightOrders.totalTime'),
                        _calcDuration(
                            item.stateEvents, 'taxi', 'engine_off'),
                        Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      _timeChip(
                        l10n.t('flightOrders.airTime'),
                        _calcDuration(
                            item.stateEvents, 'takeoff', 'landing'),
                        Theme.of(context).colorScheme.tertiary,
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (!isCancelled && item.status != 'engine_off')
          _canCancel()
              ? OutlinedButton.icon(
                  onPressed: () => _confirmCancel(item, l10n),
                  icon:
                      const Icon(Icons.cancel, size: 16, color: Colors.red),
                  label: Text(l10n.t('flightOrders.cancelFlight'),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.red)),
                )
              : const SizedBox.shrink(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.t('common.cancel')),
        ),
      ],
    );
  }

  String _aircraftLabel(AppLocalizations l10n) {
    final reg = widget.item.aircraftRegistration ?? l10n.t('flightOrders.aircraft');
    final model = widget.item.aircraftModel;
    return model != null && model.isNotEmpty ? '$reg — $model' : reg;
  }

  bool _canCancel() {
    final session = ref.read(sessionControllerProvider);
    return session.can(AppPermission.flightOrdersClose) ||
        session.user?.role?.isGlobal == true;
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _stateTimeline(List<FlightOrderStateEvent> events, int tzOffset) {
    final sorted = [...events]
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    return Column(
      children: sorted.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              StatusChip.fromStatus(e.status, size: StatusChipSize.small),
              const SizedBox(width: 8),
              Text(
                _formatTime(e.occurredAt, tzOffset),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _timeChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  DateTime? _eventTime(
      List<FlightOrderStateEvent> events, String status) {
    return events
        .where((e) => e.status == status)
        .map((e) => e.occurredAt)
        .toList()
        .firstOrNull;
  }

  String _calcDuration(
      List<FlightOrderStateEvent> events, String from, String to) {
    final start = _eventTime(events, from);
    final end = _eventTime(events, to);
    if (start == null || end == null) return '--';
    final diff = end.difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _formatTime(DateTime utc, int tzOffset) =>
      formatTimeWithOffset(utc, tzOffset);

  Future<void> _confirmCancel(
      FlightOrderItem item, AppLocalizations l10n) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('flightOrders.cancelFlight')),
        content: TextFormField(
          controller: reasonCtrl,
          decoration: InputDecoration(
            labelText: l10n.t('flightOrders.cancelReason'),
            border: const OutlineInputBorder(),
          ),
          maxLines: 2,
          validator: (v) =>
              (v == null || v.trim().isEmpty)
                  ? l10n.t('validation.required')
                  : null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.t('flightOrders.cancelFlight')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final result = await ref
          .read(flightOrdersRepositoryProvider)
          .cancelItem(itemId: item.id, reason: reasonCtrl.text.trim());

      if (!mounted) return;

      switch (result) {
        case AppSuccess<void>():
          widget.onChanged();
        case AppFailure<void>(error: final error):
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}
