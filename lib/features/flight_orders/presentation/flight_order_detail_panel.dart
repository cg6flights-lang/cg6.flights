import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/app/theme/status_colors.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/features/flight_orders/presentation/flight_item_detail_dialog.dart';
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
    this.onExportPdf,
    this.onDeleteOrder,
    required this.onStateChanged,
    required this.onOrderChanged,
  });

  final FlightOrder order;
  final List<FlightOrderItem> items;
  final VoidCallback? onExportPdf;
  final VoidCallback? onDeleteOrder;
  final void Function(String itemId, String newStatus) onStateChanged;
  final void Function(FlightOrder updatedOrder) onOrderChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final canCreate = session.can(AppPermission.flightOrdersCreate);
    final canReview = session.can(AppPermission.flightOrdersReview);
    final canClose = session.can(AppPermission.flightOrdersClose);
    final canExport = session.can(AppPermission.reportsExport);
    final canDelete = canClose || session.user?.role?.isGlobal == true;
    final isDraft = order.status == 'draft';

    final hasOrderActions =
        canExport ||
        (order.status == 'draft' && (canCreate || canDelete)) ||
        ((order.status == 'submitted' || order.status == 'approved' ||
          order.status == 'closed' || order.status == 'reopened') && canReview);

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
                OrderStepper.flightOrder(
                  currentStatus: order.status,
                  hasObservations: order.hasObservations,
                ),
                if (hasOrderActions) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (canExport)
                        ActionChip(
                          avatar: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                          label: Text(l10n.t('flightOrders.exportPdf')),
                          onPressed: onExportPdf!,
                        ),
                      if (order.status == 'draft' && canCreate)
                        ActionChip(
                          avatar: const Icon(Icons.send_outlined, size: 16),
                          label: Text(l10n.t('flightOrders.submit')),
                          onPressed: () => _confirmOrderAction(context, ref, 'submit', l10n),
                        ),
                      if (canDelete)
                        ActionChip(
                          avatar: const Icon(Icons.delete_outline, size: 16),
                          label: Text(l10n.t('flightOrders.delete')),
                          onPressed: onDeleteOrder!,
                        ),
                      if ((order.status == 'submitted' || order.status == 'reopened') && canReview)
                        ActionChip(
                          avatar: const Icon(Icons.check_circle_outline, size: 16),
                          label: Text(l10n.t('flightOrders.approve')),
                          onPressed: () => _confirmOrderAction(context, ref, 'approve', l10n),
                        ),
                      if (order.status == 'submitted' && canReview)
                        ActionChip(
                          avatar: const Icon(Icons.visibility_outlined, size: 16),
                          label: Text(l10n.t('flightOrders.observe')),
                          onPressed: () => _confirmOrderAction(context, ref, 'observe', l10n),
                        ),
                      if ((order.status == 'approved' || order.status == 'reopened') && canReview)
                        ActionChip(
                          avatar: const Icon(Icons.lock_outlined, size: 16),
                          label: Text(l10n.t('flightOrders.close')),
                          onPressed: () => _confirmOrderAction(context, ref, 'close', l10n),
                        ),
                      if (order.status == 'closed' && canReview)
                        ActionChip(
                          avatar: const Icon(Icons.lock_open_outlined, size: 16),
                          label: Text(l10n.t('flightOrders.reopen')),
                          onPressed: () => _confirmOrderAction(context, ref, 'reopen', l10n),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable content
          Expanded(
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
                    const Divider(height: 24),
                  ],
                  if (items.isEmpty)
                    _EmptyFlightsPrompt(
                        canAdd: isDraft && canCreate,
                        onAdd: () =>
                            _openAddItemDialog(context, ref, l10n),
                        l10n: l10n)
                  else ...[
                    ...items.map((item) => _FlightItemCard(
                      key: ValueKey(item.id),
                      item: item,
                      l10n: l10n,
                      onTap: () => _openItemDetailDialog(context, ref, item, l10n),
                      isParentClosed: order.status == 'closed',
                    )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
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
        case AppSuccess<FlightOrder>(data: final updated):
          onOrderChanged(updated);
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
      onOrderChanged(order);
    }
  }

  Future<void> _openItemDetailDialog(
      BuildContext context, WidgetRef ref, FlightOrderItem item, AppLocalizations l10n) async {
    final session = ref.read(sessionControllerProvider);
    final canClose = session.can(AppPermission.flightOrdersClose);
    final canEdit = (order.effectiveStatus == 'draft' && session.can(AppPermission.flightOrdersCreate)) ||
        canClose ||
        session.user?.role?.isGlobal == true;

    await showDialog(
      context: context,
      builder: (_) => FlightItemDetailDialog(
        item: item,
        operationDate: order.operationDate,
        canEdit: canEdit,
        onEdit: () => _openEditItemDialog(context, ref, item, l10n),
        onChanged: () => onOrderChanged(order),
      ),
    );
  }

  Future<void> _openEditItemDialog(
      BuildContext context, WidgetRef ref, FlightOrderItem item, AppLocalizations l10n) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => FlightItemFormDialog(
        flightOrderId: order.id,
        unitId: order.unitId,
        operationDate: order.operationDate,
        existingItem: item,
        itemId: item.id,
      ),
    );
    if (result == true && context.mounted) {
      onOrderChanged(order);
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

class _FlightItemCard extends StatelessWidget {
  const _FlightItemCard({
    super.key,
    required this.item,
    required this.l10n,
    required this.onTap,
    required this.isParentClosed,
  });

  final FlightOrderItem item;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final bool isParentClosed;

  String get _aircraftLabel {
    final reg = item.aircraftRegistration ?? l10n.t('flightOrders.aircraft');
    final model = item.aircraftModel;
    return model != null && model.isNotEmpty ? '$reg — $model' : reg;
  }

  bool get _canCancelStatus =>
      item.status == 'waiting' || item.status == 'taxi';

  /// The semantic color for this item's current state.
  Color _statusColor() {
    if (item.cancelled) return StatusColors.flightItem['cancelled']!;
    return StatusColors.of(item.status);
  }

  /// The left-accent-bar color — amber overrides when delayed, otherwise
  /// the status color.
  Color _accentColor() {
    if (item.cancelled) return StatusColors.flightItem['cancelled']!;
    if (item.isDelayed) return StatusColors.delayed;
    return _statusColor();
  }

  @override
  Widget build(BuildContext context) {
    final isCancelled = item.cancelled;
    final isDelayed = item.isDelayed;
    final accent = _accentColor();
    final statusColor = _statusColor();
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: statusColor.withValues(alpha: 0.04),
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left accent bar ────────────────────────────────────
            Container(
              width: 4,
              color: accent.withValues(alpha: 0.85),
            ),

            // ── Card content ───────────────────────────────────────
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header row
                    Row(
                      children: [
                        Icon(Icons.flight, size: 18, color: statusColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _aircraftLabel,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (isDelayed && !isCancelled) ...[
                          Icon(Icons.schedule,
                              size: 14, color: StatusColors.delayed),
                          const SizedBox(width: 4),
                        ],
                        StatusChip.fromStatus(
                            isCancelled ? 'cancelled' : item.status),
                        const SizedBox(width: 4),
                        Icon(Icons.open_in_new,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5)),
                        if (!isCancelled &&
                            _canCancelStatus &&
                            !isParentClosed)
                          _buildCancelButton(context),
                      ],
                    ),

                    // Mission
                    if (item.mission != null &&
                        item.mission!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.mission!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],

                    // Info chips
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        if (item.eteMinutes != null)
                          _infoChip(context,
                              Icons.timer_outlined,
                              '${l10n.t("flightOrders.ete")}: ${item.eteMinutes} min'),
                        if (item.flightLevelMin != null)
                          _infoChip(context,
                              Icons.height, item.flightLevelDisplay),
                        if (item.fuelAmount != null)
                          _infoChip(context,
                              Icons.local_gas_station_outlined,
                              '${item.fuelAmount} lbs${item.fuelType != null ? " (${item.fuelType})" : ""}'),
                      ],
                    ),

                    // Routes
                    if (item.routes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.alt_route,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.routes
                                  .map((r) => r.displayLabel)
                                  .join('  |  '),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Crew
                    if (item.crew.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...item.crew.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '${c.roleCode}: ${c.crewMemberName ?? "--"}${c.functionCode != null ? " [${c.functionCode}]" : ""}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _infoChip(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      final canReview =
          ref.watch(sessionControllerProvider).can(AppPermission.flightOrdersClose) ||
          ref.watch(sessionControllerProvider).user?.role?.isGlobal == true;

      if (!canReview) return const SizedBox.shrink();

      return IconButton(
        icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
        tooltip: l10n.t('flightOrders.cancelFlight'),
        visualDensity: VisualDensity.compact,
        onPressed: () => _confirmCancel(context, ref, item),
      );
    });
  }

  Future<void> _confirmCancel(
      BuildContext context, WidgetRef ref, FlightOrderItem item) async {
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
          parent.onOrderChanged(parent.order);
        case AppFailure<void>(error: final error):
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

