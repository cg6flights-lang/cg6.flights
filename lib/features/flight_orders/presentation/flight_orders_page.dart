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
import 'package:cg6_flights/shared/widgets/data_state_view.dart';
import 'package:cg6_flights/shared/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _ordersListProvider = FutureProvider<AppResult<List<FlightOrder>>>((ref) {
  final repo = ref.read(flightOrdersRepositoryProvider);
  return repo.listFlightOrders();
});

enum _DateFilter { all, today, yesterday, thisWeek }

class FlightOrdersPage extends ConsumerStatefulWidget {
  const FlightOrdersPage({super.key});

  @override
  ConsumerState<FlightOrdersPage> createState() => _FlightOrdersPageState();
}

class _FlightOrdersPageState extends ConsumerState<FlightOrdersPage> {
  FlightOrder? _selectedOrder;
  List<FlightOrderItem> _items = [];
  _DateFilter _dateFilter = _DateFilter.all;
  final _statusFilters = <String>{};
  bool _initialSelectDone = false;

  List<FlightOrder> _applyFilters(List<FlightOrder> orders) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return orders.where((o) {
      if (_dateFilter == _DateFilter.today) {
        final od = o.operationDate;
        final orderDate = DateTime(od.year, od.month, od.day);
        if (orderDate != today) return false;
      } else if (_dateFilter == _DateFilter.yesterday) {
        final od = o.operationDate;
        final orderDate = DateTime(od.year, od.month, od.day);
        if (orderDate != today.subtract(const Duration(days: 1))) return false;
      } else if (_dateFilter == _DateFilter.thisWeek) {
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
    });
    _loadItems(order.id);
  }

  Future<void> _loadItems(String orderId) async {
    final result = await ref
        .read(flightOrdersRepositoryProvider)
        .listItems(orderId);
    if (!mounted) return;
    if (_selectedOrder?.id != orderId) return;
    switch (result) {
      case AppSuccess<List<FlightOrderItem>>(data: final items):
        setState(() => _items = items);
      case AppFailure<List<FlightOrderItem>>(error: final error):
        setState(() => _items = []);
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
                                child: _selectedOrder != null
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
                                          setState(() => _items = []);
                                          _loadItems(updatedOrder.id);
                                        },
                                      )
                                    : _buildEmptyDetail(l10n),
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
                              child: FlightOrderDetailPanel(
                                key: ValueKey(_selectedOrder!.id),
                                order: _selectedOrder!,
                                items: _items,
                                onExportPdf: () => _exportPdf(_selectedOrder!, l10n),
                                onDeleteOrder: () => _confirmDeleteOrder(_selectedOrder!, l10n),
                                onStateChanged: _onItemStateChanged,
                                onOrderChanged: (updatedOrder) {
                                  setState(() => _selectedOrder = updatedOrder);
                                  ref.invalidate(_ordersListProvider);
                                  setState(() => _items = []);
                                  _loadItems(updatedOrder.id);
                                },
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

  Widget _buildFilterBar(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(
            l10n.t('flightOrders.filterAll'),
            _dateFilter == _DateFilter.all,
            () => setState(() => _dateFilter = _DateFilter.all),
          ),
          const SizedBox(width: 8),
          _filterChip(
            l10n.t('flightOrders.filterToday'),
            _dateFilter == _DateFilter.today,
            () => setState(() => _dateFilter = _DateFilter.today),
          ),
          const SizedBox(width: 8),
          _filterChip(
            l10n.t('flightOrders.filterYesterday'),
            _dateFilter == _DateFilter.yesterday,
            () => setState(() => _dateFilter = _DateFilter.yesterday),
          ),
          const SizedBox(width: 8),
          _filterChip(
            l10n.t('flightOrders.filterThisWeek'),
            _dateFilter == _DateFilter.thisWeek,
            () => setState(() => _dateFilter = _DateFilter.thisWeek),
          ),
          const SizedBox(width: 16),
          _statusFilterChip(
            'draft',
            _statusFilters.contains('draft'),
            Colors.grey,
            () => _toggleStatusFilter('draft'),
          ),
          const SizedBox(width: 6),
          _statusFilterChip(
            'submitted',
            _statusFilters.contains('submitted'),
            Colors.blue,
            () => _toggleStatusFilter('submitted'),
          ),
          const SizedBox(width: 6),
          _statusFilterChip(
            'approved',
            _statusFilters.contains('approved'),
            Colors.green,
            () => _toggleStatusFilter('approved'),
          ),
          const SizedBox(width: 6),
          _statusFilterChip(
            'closed',
            _statusFilters.contains('closed'),
            Colors.red,
            () => _toggleStatusFilter('closed'),
          ),
        ],
      ),
    );
  }

  void _toggleStatusFilter(String status) {
    setState(() {
      if (_statusFilters.contains(status)) {
        _statusFilters.remove(status);
      } else {
        _statusFilters.add(status);
      }
    });
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _statusFilterChip(
      String status, bool selected, Color color, VoidCallback onTap) {
    return FilterChip(
      label: Text(status, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      selectedColor: color.withValues(alpha: 0.18),
      checkmarkColor: color,
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
