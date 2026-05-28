import 'dart:async';

import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/features/flight_orders/presentation/flight_item_form_dialog.dart';
import 'package:cg6_flights/shared/widgets/order_stepper.dart';
import 'package:cg6_flights/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlightOrderDetailPanel extends ConsumerWidget {
  const FlightOrderDetailPanel({
    super.key,
    required this.order,
    required this.items,
    required this.canCreate,
    required this.canReview,
    required this.onStateChanged,
    required this.onOrderChanged,
  });

  final FlightOrder order;
  final List<FlightOrderItem> items;
  final bool canCreate;
  final bool canReview;
  final void Function(String itemId, String newStatus) onStateChanged;
  final VoidCallback onOrderChanged;

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
    'cancelled': Icons.cancel,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDraft = order.status == 'draft';

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${order.orderNumber ?? '--'} — ${order.unitName ?? '--'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    StatusChip.fromStatus(order.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(order.operationDate),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                OrderStepper.flightOrder(currentStatus: order.status),
                const SizedBox(height: 16),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isDraft && canCreate) ...[
                    OutlinedButton.icon(
                      onPressed: () =>
                          _openAddItemDialog(context, ref, l10n),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.t('flightOrders.addItem')),
                    ),
                    const SizedBox(height: 12),
                    _ProfilesSection(
                      flightOrderId: order.id,
                      onChanged: onOrderChanged,
                    ),
                    const Divider(height: 24),
                  ],
                  if (items.isEmpty)
                    _EmptyFlightsPrompt(
                        canAdd: isDraft && canCreate,
                        onAdd: () =>
                            _openAddItemDialog(context, ref, l10n),
                        l10n: l10n)
                  else ...[
                    ...items.map((item) =>
                        _FlightItemCard(key: ValueKey(item.id), item: item, l10n: l10n)),
                    _buildOrderActions(context, ref, l10n),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderActions(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final actions = <Widget>[];

    if (order.status == 'draft' && canCreate) {
      actions.add(
        _orderActionButton(
          Icons.send_outlined,
          l10n.t('flightOrders.submit'),
          () => _confirmOrderAction(context, ref, 'submit', l10n),
        ),
      );
    }

    if ((order.status == 'submitted' || order.status == 'observed') &&
        canReview) {
      actions.add(
        _orderActionButton(
          Icons.check_circle_outline,
          l10n.t('flightOrders.approve'),
          () => _confirmOrderAction(context, ref, 'approve', l10n),
        ),
      );
      actions.add(
        _orderActionButton(
          Icons.visibility_outlined,
          l10n.t('flightOrders.observe'),
          () => _confirmOrderAction(context, ref, 'observe', l10n),
        ),
      );
    }

    if (order.status == 'approved' && canReview) {
      actions.add(
        _orderActionButton(
          Icons.lock_outlined,
          l10n.t('flightOrders.close'),
          () => _confirmOrderAction(context, ref, 'close', l10n),
        ),
      );
    }

    if (order.status == 'closed' && canReview) {
      actions.add(
        _orderActionButton(
          Icons.lock_open_outlined,
          l10n.t('flightOrders.reopen'),
          () => _confirmOrderAction(context, ref, 'reopen', l10n),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          for (int i = 0; i < actions.length; i++) ...[
            actions[i],
            if (i < actions.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _orderActionButton(
      IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Future<void> _confirmOrderAction(BuildContext context, WidgetRef ref,
      String action, AppLocalizations l10n) async {
    final confirmKey = 'flightOrders.${action}Confirm';
    final message = l10n.t(confirmKey);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('flightOrders.$action')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.t('flightOrders.$action')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final result = await ref
          .read(flightOrdersRepositoryProvider)
          .manageFlightOrder(flightOrderId: order.id, action: action);

      if (!context.mounted) return;

      switch (result) {
        case AppSuccess<FlightOrder>():
          onOrderChanged();
        case AppFailure<FlightOrder>(error: final error):
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _openAddItemDialog(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => FlightItemFormDialog(
        flightOrderId: order.id,
        unitId: order.unitId,
        operationDate: order.operationDate,
      ),
    );
    if (result == true && context.mounted) {
      onOrderChanged();
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _EmptyFlightsPrompt extends StatelessWidget {
  const _EmptyFlightsPrompt(
      {required this.canAdd, required this.onAdd, required this.l10n});

  final bool canAdd;
  final VoidCallback onAdd;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight_outlined,
                size: 36,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(l10n.t('flightOrders.noFlights'),
                style: Theme.of(context).textTheme.bodyMedium),
            if (canAdd) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.t('flightOrders.addItem')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlightItemCard extends StatefulWidget {
  const _FlightItemCard({super.key, required this.item, required this.l10n});

  final FlightOrderItem item;
  final AppLocalizations l10n;

  @override
  State<_FlightItemCard> createState() => _FlightItemCardState();
}

class _FlightItemCardState extends State<_FlightItemCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final l10n = widget.l10n;
    final isCancelled = item.cancelled;
    final isDelayed = item.isDelayed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isCancelled
              ? Colors.red.shade200
              : isDelayed
                  ? Colors.amber.shade300
                  : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isCancelled
            ? Colors.red.shade50
            : isDelayed
                ? Colors.amber.shade50
                : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Zone 1: Aircraft + Status + Mission
                  Row(
                    children: [
                      Icon(Icons.flight,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.aircraftRegistration ??
                              l10n.t('flightOrders.aircraft'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      StatusChip.fromStatus(
                          isCancelled ? 'cancelled' : item.status),
                      const SizedBox(width: 4),
                      Icon(Icons.expand_more,
                          size: 18,
                          color: _expanded
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Zone 2: Key info
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      if (item.mission != null && item.mission!.isNotEmpty)
                        _infoChip(Icons.bookmark_outline,
                            '${l10n.t("flightOrders.mission")}: ${item.mission}'),
                      if (item.eteMinutes != null)
                        _infoChip(Icons.timer_outlined,
                            '${l10n.t("flightOrders.ete")}: ${item.eteMinutes} min'),
                      if (item.flightLevelMin != null)
                        _infoChip(Icons.height,
                            item.flightLevelDisplay),
                      if (item.fuelAmount != null)
                        _infoChip(Icons.local_gas_station_outlined,
                            '${item.fuelAmount} lbs${item.fuelType != null ? " (${item.fuelType})" : ""}'),
                    ],
                  ),

                  // Crew
                  if (item.crew.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: item.crew
                          .map((c) => Text(
                                '${c.roleCode}: ${c.crewMemberName ?? "--"}${c.functionCode != null ? " [${c.functionCode}]" : ""}',
                                style: const TextStyle(fontSize: 11),
                              ))
                          .toList(),
                    ),
                  ],

                  // Zone 3: Mini flight state stepper
                  const SizedBox(height: 8),
                  _MiniFlightStepper(
                    currentStatus: isCancelled ? 'cancelled' : item.status,
                    isCancelled: isCancelled,
                    stateEvents: item.stateEvents,
                  ),

                  // Action buttons
                  if (!isCancelled) ...[
                    const SizedBox(height: 10),
                    _buildItemActions(context),
                  ],
                ],
              ),
            ),
          ),

          // Expanded detail
          if (_expanded) _buildExpandedDetail(context),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildItemActions(BuildContext context) {
    final item = widget.item;
    final l10n = widget.l10n;

    return Consumer(builder: (context, ref, _) {
      final canReview =
          ref.watch(sessionControllerProvider).can(AppPermission.flightOrdersClose) ||
          ref.watch(sessionControllerProvider).user?.role?.isGlobal == true;

      final nextState = FlightOrderDetailPanel._nextState[item.status];

      return Row(
        children: [
          if (nextState != null)
            FilledButton.icon(
              onPressed: () => _advanceState(context, ref, item.id, nextState),
              icon: Icon(
                  FlightOrderDetailPanel._stateIcons[nextState] ??
                      Icons.arrow_forward,
                  size: 16),
              label: Text(_stateLabel(nextState),
                  style: const TextStyle(fontSize: 12)),
            ),
          if (canReview && item.status != 'engine_off') ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _confirmCancel(context, ref, item),
              icon: const Icon(Icons.cancel, size: 16, color: Colors.red),
              label: Text(l10n.t('flightOrders.cancelFlight'),
                  style: const TextStyle(fontSize: 12, color: Colors.red)),
            ),
          ],
        ],
      );
    });
  }

  String _stateLabel(String state) {
    return switch (state) {
      'taxi' => widget.l10n.t('flightOrders.taxi'),
      'takeoff' => widget.l10n.t('flightOrders.takeoff'),
      'landing' => widget.l10n.t('flightOrders.landing'),
      'engine_off' => widget.l10n.t('flightOrders.engineOff'),
      _ => state,
    };
  }

  Widget _buildExpandedDetail(BuildContext context) {
    final item = widget.item;
    final l10n = widget.l10n;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Routes detail
          if (item.routes.isNotEmpty) ...[
            Text(l10n.t('flightOrders.routes'),
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
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
            const SizedBox(height: 8),
          ],

          // Profiles
          if (item.profiles.isNotEmpty) ...[
            Text(l10n.t('flightOrders.profiles'),
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: item.profiles
                  .map((p) => StatusChip(
                        label: 'Perfil ${p.profileNumber}: ${p.description}',
                        color: Colors.teal,
                        size: StatusChipSize.small,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],

          // State events timeline
          if (item.stateEvents.isNotEmpty) ...[
            Text(l10n.t('flightOrders.stateEvents'),
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            _StateTimeline(events: item.stateEvents),
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

          // Departure time
          if (item.scheduledDeparture != null) ...[
            const SizedBox(height: 6),
            Text(
              '${l10n.t("flightOrders.departure")}: ${_formatTime(item.scheduledDeparture!)}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ],
      ),
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
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
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

  DateTime? _eventTime(List<FlightOrderStateEvent> events, String status) {
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

  Future<void> _advanceState(
      BuildContext context, WidgetRef ref, String itemId, String nextStatus) {
    final completer = Completer<void>();
    final parent = context
        .findAncestorWidgetOfExactType<FlightOrderDetailPanel>();
    if (parent == null) return completer.future;

    final panel = parent;
    ref
        .read(flightOrdersRepositoryProvider)
        .advanceItemState(itemId, nextStatus)
        .then((result) {
      if (!context.mounted) return;
      switch (result) {
        case AppSuccess<void>():
          panel.onStateChanged(itemId, nextStatus);
        case AppFailure<void>(error: final error):
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    });

    return completer.future;
  }

  Future<void> _confirmCancel(
      BuildContext context, WidgetRef ref, FlightOrderItem item) async {
    final l10n = widget.l10n;
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
              (v == null || v.trim().isEmpty) ? l10n.t('validation.required') : null,
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

    if (confirmed == true && context.mounted) {
      final result = await ref
          .read(flightOrdersRepositoryProvider)
          .cancelItem(itemId: item.id, reason: reasonCtrl.text.trim());

      if (!context.mounted) return;

      final parent = context
          .findAncestorWidgetOfExactType<FlightOrderDetailPanel>();
      if (parent == null) return;

      switch (result) {
        case AppSuccess<void>():
          parent.onStateChanged(item.id, 'cancelled');
          parent.onOrderChanged();
        case AppFailure<void>(error: final error):
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _MiniFlightStepper extends StatelessWidget {
  const _MiniFlightStepper({
    required this.currentStatus,
    required this.isCancelled,
    required this.stateEvents,
  });

  final String currentStatus;
  final bool isCancelled;
  final List<FlightOrderStateEvent> stateEvents;

  static const _states = ['waiting', 'taxi', 'takeoff', 'landing', 'engine_off'];

  @override
  Widget build(BuildContext context) {
    final currentIdx = _states.indexOf(currentStatus);

    return Row(
      children: [
        for (int i = 0; i < _states.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= currentIdx && !isCancelled
                    ? _colorForStatus(_states[i])
                    : Colors.grey.shade200,
              ),
            ),
          _miniDot(
            _states[i],
            i < currentIdx,
            i == currentIdx,
            context,
          ),
        ],
      ],
    );
  }

  Color _colorForStatus(String status) {
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
      String status, bool completed, bool active, BuildContext context) {
    final color = isCancelled ? Colors.red : _colorForStatus(status);
    final hasEvent = stateEvents.any((e) => e.status == status);

    return Tooltip(
      message: _labelFor(status),
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

  String _labelFor(String status) {
    return switch (status) {
      'waiting' => 'Espera',
      'taxi' => 'Taxeo',
      'takeoff' => 'Despegue',
      'landing' => 'Aterrizaje',
      'engine_off' => 'Motor Apagado',
      _ => status,
    };
  }
}

class _StateTimeline extends StatelessWidget {
  const _StateTimeline({required this.events});

  final List<FlightOrderStateEvent> events;

  @override
  Widget build(BuildContext context) {
    final sorted = [...events]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

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

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}';
  }
}

// Profiles section (unchanged from original, kept private)
class _ProfilesSection extends ConsumerStatefulWidget {
  const _ProfilesSection({required this.flightOrderId, required this.onChanged});

  final String flightOrderId;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ProfilesSection> createState() => _ProfilesSectionState();
}

class _ProfilesSectionState extends ConsumerState<_ProfilesSection> {
  final _descCtrl = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<List<FlightOrderProfile>> _loadProfiles() async {
    final result = await ref
        .read(flightOrdersRepositoryProvider)
        .listOrderProfiles(widget.flightOrderId);
    return switch (result) {
      AppSuccess(data: final v) => v,
      _ => [],
    };
  }

  Future<void> _addProfile() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) return;
    setState(() => _adding = true);
    final result = await ref
        .read(flightOrdersRepositoryProvider)
        .addOrderProfile(
            flightOrderId: widget.flightOrderId, description: desc);
    if (!mounted) return;
    setState(() {
      _adding = false;
      _descCtrl.clear();
    });
    switch (result) {
      case AppSuccess():
        widget.onChanged();
      case AppFailure(error: final e):
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _removeProfile(String profileId) async {
    final result = await ref
        .read(flightOrdersRepositoryProvider)
        .removeOrderProfile(profileId);
    if (!mounted) return;
    switch (result) {
      case AppSuccess():
        widget.onChanged();
      case AppFailure(error: final e):
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<List<FlightOrderProfile>>(
      future: _loadProfiles(),
      builder: (context, snapshot) {
        final profiles = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.t('flightOrders.profiles'),
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            if (profiles.isNotEmpty)
              ...profiles.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.list_alt, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Perfil ${p.profileNumber}: ${p.description}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _removeProfile(p.id),
                        ),
                      ],
                    ),
                  )),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _descCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.t('flightOrders.profileDescription'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _adding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: _adding ? null : _addProfile,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
