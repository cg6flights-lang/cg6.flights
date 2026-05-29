import 'dart:async';

import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
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
  static const _states = ['waiting', 'taxi', 'takeoff', 'landing', 'engine_off'];
  static const _nextState = {
    'waiting': 'taxi',
    'taxi': 'takeoff',
    'takeoff': 'landing',
    'landing': 'engine_off',
  };
  static const _stateIcons = {
    'waiting': Icons.schedule,
    'taxi': Icons.directions_car,
    'takeoff': Icons.flight_takeoff,
    'landing': Icons.flight_land,
    'engine_off': Icons.power_settings_new,
  };

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final l10n = AppLocalizations.of(context);
    final isCancelled = item.cancelled;
    final nextState = _nextState[item.status];

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
                        '${l10n.t("flightOrders.departure")}: ${_formatTime(item.scheduledDeparture!)}'),
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

              // Mini stepper
              _sectionLabel(context, l10n.t('flightOrders.status')),
              const SizedBox(height: 4),
              _miniStepper(item),
              const SizedBox(height: 12),

              // State events timeline
              if (item.stateEvents.isNotEmpty) ...[
                _sectionLabel(context, l10n.t('flightOrders.stateEvents')),
                const SizedBox(height: 4),
                _stateTimeline(item.stateEvents),
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
        if (!isCancelled && nextState != null)
          FilledButton.icon(
            onPressed: () => _advanceState(item.id, nextState),
            icon: Icon(_stateIcons[nextState] ?? Icons.arrow_forward, size: 16),
            label: Text(_stateLabel(nextState, l10n),
                style: const TextStyle(fontSize: 12)),
          ),
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

  Widget _miniStepper(FlightOrderItem item) {
    final currentIdx = _states.indexOf(item.status);
    final isCancelled = item.cancelled;

    return Row(
      children: [
        for (int i = 0; i < _states.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= currentIdx && !isCancelled
                    ? _stepperColor(_states[i])
                    : Colors.grey.shade200,
              ),
            ),
          _miniDot(_states[i], i < currentIdx, i == currentIdx, item),
        ],
      ],
    );
  }

  Color _stepperColor(String status) {
    return switch (status) {
      'waiting' => Colors.grey,
      'taxi' => Colors.blue,
      'takeoff' => Colors.orange,
      'landing' => Colors.teal,
      'engine_off' => Colors.green,
      _ => Colors.grey,
    };
  }

  Widget _miniDot(
      String status, bool completed, bool active, FlightOrderItem item) {
    final color =
        item.cancelled ? Colors.red : _stepperColor(status);
    final hasEvent = item.stateEvents.any((e) => e.status == status);

    return Tooltip(
      message: _stepperLabel(status),
      child: Container(
        width: active ? 16 : 12,
        height: active ? 16 : 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: completed || hasEvent
              ? color
              : active
                  ? color.withValues(alpha: 0.2)
                  : Colors.grey.shade100,
          border: Border.all(
            color: active || completed || hasEvent
                ? color
                : Colors.grey.shade300,
            width: active ? 2 : 1,
          ),
        ),
        child: completed || hasEvent
            ? const Icon(Icons.check, size: 8, color: Colors.white)
            : active
                ? Icon(Icons.circle, size: 6, color: color)
                : null,
      ),
    );
  }

  String _stepperLabel(String status) {
    return switch (status) {
      'waiting' => 'Espera',
      'taxi' => 'Taxeo',
      'takeoff' => 'Despegue',
      'landing' => 'Aterrizaje',
      'engine_off' => 'Motor Apagado',
      _ => status,
    };
  }

  Widget _stateTimeline(List<FlightOrderStateEvent> events) {
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
                _formatTime(e.occurredAt),
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

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}';
  }

  String _stateLabel(String state, AppLocalizations l10n) {
    return switch (state) {
      'taxi' => l10n.t('flightOrders.taxi'),
      'takeoff' => l10n.t('flightOrders.takeoff'),
      'landing' => l10n.t('flightOrders.landing'),
      'engine_off' => l10n.t('flightOrders.engineOff'),
      _ => state,
    };
  }

  Future<void> _advanceState(String itemId, String nextStatus) async {
    final result = await ref
        .read(flightOrdersRepositoryProvider)
        .advanceItemState(itemId, nextStatus);

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
