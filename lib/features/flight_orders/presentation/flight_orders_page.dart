import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/features/auth/application/session_controller.dart';
import 'package:cg6_flights/features/flight_orders/application/flight_order_pdf_downloader.dart';
import 'package:cg6_flights/features/flight_orders/application/flight_order_pdf_service.dart';
import 'package:cg6_flights/features/flight_orders/data/flight_orders_repository.dart';
import 'package:cg6_flights/features/flight_orders/domain/flight_order.dart';
import 'package:cg6_flights/features/flight_orders/presentation/flight_order_detail_panel.dart';
import 'package:cg6_flights/features/flight_orders/presentation/flight_order_form_dialog.dart';
import 'package:cg6_flights/features/units/data/units_repository.dart';
import 'package:cg6_flights/features/units/domain/unit_option.dart';
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:cg6_flights/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _ordersListProvider = FutureProvider<AppResult<List<FlightOrder>>>((ref) {
  final repo = ref.read(flightOrdersRepositoryProvider);
  return repo.listFlightOrders();
});

class FlightOrdersPage extends ConsumerStatefulWidget {
  const FlightOrdersPage({super.key});

  @override
  ConsumerState<FlightOrdersPage> createState() => _FlightOrdersPageState();
}

class _FlightOrdersPageState extends ConsumerState<FlightOrdersPage> {
  FlightOrder? _selectedOrder;
  List<FlightOrderItem> _items = [];
  bool _isLoadingItems = false;
  String? _selectedUnitId; // null = Todas
  String _dateFilter = 'today'; // 'all' | 'today' | 'yesterday' | 'week'
  final _statusFilters = <String>{};
  bool _initialSelectDone = false;
  List<UnitOption> _units = [];

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final result = await ref.read(unitsRepositoryProvider).listUnits();
    if (!mounted) return;
    switch (result) {
      case AppSuccess<List<UnitOption>>(data: final units):
        setState(() => _units = units);
      case AppFailure<List<UnitOption>>():
        setState(() => _units = []);
    }
  }

  List<FlightOrder> _applyFilters(List<FlightOrder> orders) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return orders.where((o) {
      if (_selectedUnitId != null && o.unitId != _selectedUnitId) {
        return false;
      }
      if (_dateFilter == 'today') {
        final od = o.operationDate;
        final orderDate = DateTime(od.year, od.month, od.day);
        if (orderDate != today) return false;
      } else if (_dateFilter == 'yesterday') {
        final od = o.operationDate;
        final orderDate = DateTime(od.year, od.month, od.day);
        if (orderDate != today.subtract(const Duration(days: 1))) return false;
      } else if (_dateFilter == 'week') {
        final od = o.operationDate;
        final orderDate = DateTime(od.year, od.month, od.day);
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        if (orderDate.isBefore(weekStart) || orderDate.isAfter(weekEnd)) {
          return false;
        }
      }
      if (_statusFilters.isNotEmpty && !_statusFilters.contains(o.status)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _selectOrder(FlightOrder order) {
    if (_selectedOrder?.id == order.id) return;
    setState(() {
      _selectedOrder = order;
      _items = [];
      _isLoadingItems = true;
    });
    _loadItems(order.id);
  }

  Future<void> _loadItems(String orderId) async {
    // Elegant 3-second loading transition
    final futures = await Future.wait([
      ref.read(flightOrdersRepositoryProvider).listItems(orderId),
      Future<void>.delayed(const Duration(seconds: 3)),
    ]);
    final result = futures[0] as AppResult<List<FlightOrderItem>>;
    if (!mounted) return;
    if (_selectedOrder?.id != orderId) return;
    switch (result) {
      case AppSuccess<List<FlightOrderItem>>(data: final items):
        setState(() {
          _items = items;
          _isLoadingItems = false;
        });
      case AppFailure<List<FlightOrderItem>>(error: final error):
        setState(() {
          _items = [];
          _isLoadingItems = false;
        });
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _onItemStateChanged(String itemId, String newStatus) {
    setState(() {
      _items = _items
          .map((i) => i.id == itemId ? i.copyWith(status: newStatus) : i)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionControllerProvider);
    final ordersAsync = ref.watch(_ordersListProvider);
    final canCreate = session.can(AppPermission.flightOrdersCreate);

    return ordersAsync.when(
      loading: () =>
          const DataStateView(kind: DataStateKind.loading, title: ''),
      error: (_, _) => DataStateView(
        kind: DataStateKind.systemError,
        title: l10n.t('flightOrders.loadFailed'),
        message: l10n.t('common.retry'),
        onRetry: () => ref.invalidate(_ordersListProvider),
      ),
      data: (result) {
        final allOrders = switch (result) {
          AppSuccess<List<FlightOrder>>(data: final list) => list,
          AppFailure<List<FlightOrder>>() => null,
        };

        if (allOrders == null) {
          final error = (result as AppFailure<List<FlightOrder>>).error;
          return DataStateView(
            kind: DataStateKind.systemError,
            title: l10n.t('flightOrders.loadFailed'),
            message: error.message,
            onRetry: () => ref.invalidate(_ordersListProvider),
          );
        }

        final filtered = _applyFilters(allOrders);

        if (!_initialSelectDone && filtered.isNotEmpty) {
          _initialSelectDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _selectOrder(filtered.first);
          });
        }

        if (allOrders.isEmpty) {
          return _EmptyState(canCreate: canCreate, onAdd: () => _openForm());
        }

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.t('nav.flightOrders'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (canCreate)
                  FilledButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(l10n.t('flightOrders.add')),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildFilterBar(l10n),
            const SizedBox(height: 12),
            filtered.isEmpty
                ? _buildEmptyFiltered(l10n)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 1100) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 550,
                                child: Card(
                                  elevation: 1,
                                  margin: EdgeInsets.zero,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(12),
                                    child: _buildTable(
                                      context,
                                      filtered,
                                      l10n,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const VerticalDivider(width: 32, thickness: 1),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 550,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(opacity: animation, child: child),
                                  child: _isLoadingItems
                                      ? const _LoadingDotsOverlay(key: ValueKey('loading'))
                                      : _selectedOrder != null
                                          ? FlightOrderDetailPanel(
                                              key: ValueKey(_selectedOrder!.id),
                                              order: _selectedOrder!,
                                              items: _items,
                                              onExportPdf: () => _exportPdf(_selectedOrder!, l10n),
                                              onDeleteOrder: () => _confirmDeleteOrder(_selectedOrder!, l10n),
                                              onStateChanged: _onItemStateChanged,
                                              onOrderChanged: (updatedOrder) {
                                                setState(() => _selectedOrder = updatedOrder);
                                                ref.invalidate(_ordersListProvider);
                                                setState(() {
                                                  _items = [];
                                                  _isLoadingItems = true;
                                                });
                                                _loadItems(updatedOrder.id);
                                              },
                                            )
                                          : _buildEmptyDetail(l10n),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          SizedBox(
                            height: 300,
                            child: SingleChildScrollView(
                              child: _buildTable(
                                context,
                                filtered,
                                l10n,
                              ),
                            ),
                          ),
                          if (_selectedOrder != null) ...[
                            const Divider(height: 32, thickness: 1),
                            SizedBox(
                              height: 400,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 350),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(opacity: animation, child: child),
                                child: _isLoadingItems
                                    ? const _LoadingDotsOverlay(key: ValueKey('loading'))
                                    : FlightOrderDetailPanel(
                                        key: ValueKey(_selectedOrder!.id),
                                        order: _selectedOrder!,
                                        items: _items,
                                        onExportPdf: () => _exportPdf(_selectedOrder!, l10n),
                                        onDeleteOrder: () => _confirmDeleteOrder(_selectedOrder!, l10n),
                                        onStateChanged: _onItemStateChanged,
                                        onOrderChanged: (updatedOrder) {
                                          setState(() => _selectedOrder = updatedOrder);
                                          ref.invalidate(_ordersListProvider);
                                          setState(() {
                                            _items = [];
                                            _isLoadingItems = true;
                                          });
                                          _loadItems(updatedOrder.id);
                                        },
                                      ),
                              ),
                              ),
                          ],
                        ],
                      );
                    },
                  ),
          ],
        );
      },
    );
  }

  // ── Filter bar ───────────────────────────────────────────────────

  static const _dateOptions = [
    ('all', 'Todo'),
    ('today', 'Hoy'),
    ('yesterday', 'Ayer'),
    ('week', 'Esta semana'),
  ];
  static const _allStatuses = [
    'draft', 'submitted', 'observed', 'approved', 'closed', 'reopened',
  ];

  String get _unitLabel {
    if (_selectedUnitId == null) return 'Todas';
    final u = _units.where((e) => e.id == _selectedUnitId).firstOrNull;
    return u?.name ?? u?.code ?? '--';
  }

  String get _dateLabel {
    return switch (_dateFilter) {
      'today' => 'Hoy',
      'yesterday' => 'Ayer',
      'week' => 'Esta semana',
      _ => 'Todo',
    };
  }

  String get _statusLabel {
    if (_statusFilters.isEmpty) return 'Todos';
    return _statusFilters.join(', ');
  }

  bool get _hasActiveFilters =>
      _selectedUnitId != null ||
      _dateFilter != 'all' ||
      _statusFilters.isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _selectedUnitId = null;
      _dateFilter = 'all';
      _statusFilters.clear();
    });
  }

  Widget _buildFilterBar(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final outlineColor = theme.colorScheme.outline.withValues(alpha: 0.3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Dropdown row ──────────────────────────────────────────
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterDropdown(
              label: l10n.t('flightOrders.unit'),
              icon: Icons.business_outlined,
              selectedLabel: _unitLabel,
              outlineColor: outlineColor,
              menuChildren: [
                _unitMenuItem(null, 'Todas'),
                for (final u in _units.where((e) => e.active))
                  _unitMenuItem(u.id, u.name.isNotEmpty ? u.name : u.code),
              ],
            ),
            _FilterDropdown(
              label: l10n.t('flightOrders.date'),
              icon: Icons.calendar_month_outlined,
              selectedLabel: _dateLabel,
              outlineColor: outlineColor,
              menuChildren: [
                for (final (value, label) in _dateOptions)
                  _dateMenuItem(value, label),
              ],
            ),
            _FilterDropdown(
              label: l10n.t('flightOrders.status'),
              icon: Icons.label_outlined,
              selectedLabel: _statusLabel,
              outlineColor: outlineColor,
              menuChildren: [
                for (final s in _allStatuses) _statusMenuItem(s),
              ],
            ),
            if (_hasActiveFilters)
              IconButton(
                icon: const Icon(Icons.clear_all, size: 18),
                tooltip: l10n.t('flightOrders.clearFilters'),
                visualDensity: VisualDensity.compact,
                onPressed: _clearAllFilters,
              ),
          ],
        ),

        // ── Active filter chips ───────────────────────────────────
        if (_hasActiveFilters) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (_selectedUnitId != null)
                _activeChip(
                  '${l10n.t("flightOrders.unit")}: $_unitLabel',
                  () => setState(() => _selectedUnitId = null),
                ),
              if (_dateFilter != 'all')
                _activeChip(
                  _dateLabel,
                  () => setState(() => _dateFilter = 'all'),
                ),
              for (final s in _statusFilters)
                _activeChip(
                  s,
                  () => setState(() => _statusFilters.remove(s)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _activeChip(String label, VoidCallback onDeleted) {
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 14),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  // ── PopupMenu items ──────────────────────────────────────────────

  PopupMenuItem<void> _unitMenuItem(String? unitId, String label) {
    return PopupMenuItem<void>(
      onTap: () => setState(() => _selectedUnitId = unitId),
      child: _popupRadio(label, _selectedUnitId == unitId),
    );
  }

  PopupMenuItem<void> _dateMenuItem(String value, String label) {
    return PopupMenuItem<void>(
      onTap: () => setState(() => _dateFilter = value),
      child: _popupRadio(label, _dateFilter == value),
    );
  }

  PopupMenuItem<void> _statusMenuItem(String status) {
    final checked = _statusFilters.contains(status);
    return PopupMenuItem<void>(
      onTap: () {
        setState(() {
          if (checked) {
            _statusFilters.remove(status);
          } else {
            _statusFilters.add(status);
          }
        });
      },
      child: _popupCheck(status, checked),
    );
  }

  Widget _popupRadio(String label, bool selected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          size: 18,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _popupCheck(String label, bool selected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: Checkbox(
            value: selected,
            onChanged: (_) {},
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildEmptyFiltered(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_off,
                size: 36,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(l10n.t('flightOrders.filterEmpty'),
                style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDetail(AppLocalizations l10n) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.t('flightOrders.empty'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    List<FlightOrder> orders,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 420),
        child: DataTable(
          showCheckboxColumn: false,
          headingTextStyle: Theme.of(context).textTheme.titleSmall,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          columns: [
            DataColumn(label: Text(l10n.t('flightOrders.orderNumber'))),
            DataColumn(label: Text(l10n.t('flightOrders.unit'))),
            DataColumn(label: Text(l10n.t('flightOrders.operationDate'))),
            DataColumn(label: Text(l10n.t('flightOrders.status'))),
            DataColumn(label: Text(l10n.t('flightOrders.items'))),
          ],
          rows: [
            for (final o in orders)
              DataRow(
                color: _selectedOrder?.id == o.id
                    ? WidgetStateProperty.all(
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.08))
                    : null,
                onSelectChanged: (_) => _selectOrder(o),
                cells: [
                  DataCell(Text(o.orderNumber ?? '--',
                      style: const TextStyle(fontSize: 13))),
                  DataCell(Text(o.unitName ?? '--',
                      style: const TextStyle(fontSize: 13))),
                  DataCell(Text(_formatDate(o.operationDate),
                      style: const TextStyle(fontSize: 13))),
                  DataCell(StatusChip.fromStatus(o.status)),
                  DataCell(_itemCountBadge(o)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _itemCountBadge(FlightOrder order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${order.itemsCount ?? 0}',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }


  String _formatDate(DateTime date) {
    final months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _confirmStatusChange(
      FlightOrder order, String action, AppLocalizations l10n) async {
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

    if (confirmed == true && mounted) {
      await _changeStatus(order.id, action);
    }
  }

  Future<void> _changeStatus(String orderId, String action) async {
    final result = await ref
        .read(flightOrdersRepositoryProvider)
        .manageFlightOrder(flightOrderId: orderId, action: action);

    if (!mounted) return;

    switch (result) {
      case AppSuccess<FlightOrder>(data: final updated):
        ref.invalidate(_ordersListProvider);
        if (_selectedOrder?.id == updated.id) {
          setState(() => _selectedOrder = updated);
        }
      case AppFailure<FlightOrder>(error: final error):
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _confirmDeleteOrder(
      FlightOrder order, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('flightOrders.deleteTitle')),
        content: Text(l10n.t('flightOrders.deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.t('flightOrders.delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final result = await ref
          .read(flightOrdersRepositoryProvider)
          .deleteFlightOrder(order.id);

      if (!mounted) return;

      switch (result) {
        case AppSuccess<void>():
          ref.invalidate(_ordersListProvider);
          if (_selectedOrder?.id == order.id) {
            setState(() {
              _selectedOrder = null;
              _items = [];
            });
          }
        case AppFailure<void>(error: final error):
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _exportPdf(FlightOrder order, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
        SnackBar(content: Text(l10n.t('flightOrders.exportingPdf'))));

    final repo = ref.read(flightOrdersRepositoryProvider);
    final itemsResult = await repo.listItems(order.id);
    final profilesResult = await repo.listOrderProfiles(order.id);

    if (!mounted) return;

    final List<FlightOrderItem> items;
    switch (itemsResult) {
      case AppSuccess<List<FlightOrderItem>>(data: final value):
        items = value;
      case AppFailure<List<FlightOrderItem>>(error: final error):
        messenger
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(error.message)));
        return;
    }

    final profiles = switch (profilesResult) {
      AppSuccess<List<FlightOrderProfile>>(data: final value) => value,
      AppFailure<List<FlightOrderProfile>>() => <FlightOrderProfile>[],
    };

    final pdfService = ref.read(flightOrderPdfServiceProvider);
    final pdfResult = await pdfService.buildFlightOrderPdf(
      order: order,
      items: items,
      orderProfiles: profiles,
    );

    if (!mounted) return;

    switch (pdfResult) {
      case AppSuccess(data: final bytes):
        savePdfFile(bytes, pdfService.fileNameFor(order));
        messenger
          ..clearSnackBars()
          ..showSnackBar(
              SnackBar(content: Text(l10n.t('flightOrders.pdfExported'))));
      case AppFailure(error: final error):
        messenger
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openForm() async {
    final result = await showDialog<FlightOrder>(
      context: context,
      builder: (_) => const FlightOrderFormDialog(),
    );
    if (result != null && mounted) {
      ref.invalidate(_ordersListProvider);
    }
  }
}

// ── Filter dropdown widget ─────────────────────────────────────────

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.icon,
    required this.selectedLabel,
    required this.outlineColor,
    required this.menuChildren,
  });

  final String label;
  final IconData icon;
  final String selectedLabel;
  final Color outlineColor;
  final List<Widget> menuChildren;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      offset: const Offset(0, 4),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (_) => menuChildren.cast<PopupMenuEntry<void>>(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: outlineColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  selectedLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading dots overlay ───────────────────────────────────────────

class _LoadingDotsOverlay extends StatefulWidget {
  const _LoadingDotsOverlay({super.key});

  @override
  State<_LoadingDotsOverlay> createState() => _LoadingDotsOverlayState();
}

class _LoadingDotsOverlayState extends State<_LoadingDotsOverlay>
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 3; i++)
                  _Dot(controller: _controller, index: i),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Cargando vuelos...',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.controller, required this.index});
  final AnimationController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    const size = 10.0;
    final delay = index * 0.25;
    final alpha = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, delay + 0.4, curve: Curves.easeInOut),
      ),
    );
    final scale = Tween<double>(begin: 0.7, end: 1.1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, delay + 0.4, curve: Curves.easeInOut),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => Transform.scale(
          scale: scale.value,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: alpha.value),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.canCreate, required this.onAdd});

  final bool canCreate;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(l10n.t('flightOrders.empty'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            if (canCreate) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(l10n.t('flightOrders.add')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
