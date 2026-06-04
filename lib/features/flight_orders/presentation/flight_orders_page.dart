import 'package:cg6_flights/app/i18n/app_localizations.dart';
import 'package:cg6_flights/core/results/app_result.dart';
import 'package:cg6_flights/core/security/app_permission.dart';
import 'package:cg6_flights/core/state/timezone_provider.dart';
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
    final tz = ref.read(timezoneProvider);
    final now = toLocalTime(DateTime.now(), tz);
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
                                height: MediaQuery.of(context).size.height - 280,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Card(
                                        elevation: 1,
                                        margin: EdgeInsets.zero,
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.all(12),
                                          child: _buildTable(context, filtered, l10n),
                                        ),
                                      ),
                                    ),
                                    if (_selectedOrder != null) ...[
                                      const SizedBox(height: 8),
                                      _ProfilesCard(
                                        orderId: _selectedOrder!.id,
                                        onChanged: () => _selectOrder(_selectedOrder!),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const VerticalDivider(width: 32, thickness: 1),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: MediaQuery.of(context).size.height - 280,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeIn,
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                  child: _isLoadingItems
                                      ? const _LoadingDotsOverlay(
                                          key: ValueKey('loading'),
                                        )
                                      : _selectedOrder != null
                                      ? FlightOrderDetailPanel(
                                          key: ValueKey(_selectedOrder!.id),
                                          order: _selectedOrder!,
                                          items: _items,
                                          onExportPdf: () =>
                                              _exportPdf(_selectedOrder!, l10n),
                                          onDeleteOrder: () =>
                                              _confirmDeleteOrder(
                                                _selectedOrder!,
                                                l10n,
                                              ),
                                          onStateChanged: _onItemStateChanged,
                                          onOrderChanged: (updatedOrder) {
                                            setState(
                                              () =>
                                                  _selectedOrder = updatedOrder,
                                            );
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
                              child: _buildTable(context, filtered, l10n),
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
                                    FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                child: _isLoadingItems
                                    ? const _LoadingDotsOverlay(
                                        key: ValueKey('loading'),
                                      )
                                    : FlightOrderDetailPanel(
                                        key: ValueKey(_selectedOrder!.id),
                                        order: _selectedOrder!,
                                        items: _items,
                                        onExportPdf: () =>
                                            _exportPdf(_selectedOrder!, l10n),
                                        onDeleteOrder: () =>
                                            _confirmDeleteOrder(
                                              _selectedOrder!,
                                              l10n,
                                            ),
                                        onStateChanged: _onItemStateChanged,
                                        onOrderChanged: (updatedOrder) {
                                          setState(
                                            () => _selectedOrder = updatedOrder,
                                          );
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
    'draft',
    'submitted',
    'observed',
    'approved',
    'closed',
    'reopened',
  ];

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                value: _selectedUnitId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.t('flightOrders.unit'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Todas', style: TextStyle(fontSize: 13))),
                  for (final u in _units.where((e) => e.active))
                    DropdownMenuItem<String>(
                      value: u.id,
                      child: Text(u.name.isNotEmpty ? u.name : u.code, style: const TextStyle(fontSize: 13)),
                    ),
                ],
                onChanged: (v) => setState(() => _selectedUnitId = v),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                value: _dateFilter,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.t('flightOrders.date'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  for (final (value, label) in _dateOptions)
                    DropdownMenuItem<String>(value: value, child: Text(label, style: const TextStyle(fontSize: 13))),
                ],
                onChanged: (v) => setState(() => _dateFilter = v ?? 'all'),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                value: _statusFilters.isNotEmpty ? _statusFilters.first : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.t('flightOrders.status'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Todos', style: TextStyle(fontSize: 13))),
                  for (final s in _allStatuses)
                    DropdownMenuItem<String>(value: s, child: Text(s, style: const TextStyle(fontSize: 13))),
                ],
                onChanged: (v) => setState(() {
                  _statusFilters.clear();
                  if (v != null) _statusFilters.add(v);
                }),
              ),
            ),
            if (_hasActiveFilters)
              IconButton(
                icon: const Icon(Icons.clear_all, size: 18),
                tooltip: 'Limpiar filtros',
                visualDensity: VisualDensity.compact,
                onPressed: _clearAllFilters,
              ),
          ],
        ),
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
            Icon(
              Icons.filter_list_off,
              size: 36,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.t('flightOrders.filterEmpty'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
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
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08),
                      )
                    : null,
                onSelectChanged: (_) => _selectOrder(o),
                cells: [
                  DataCell(
                    Text(
                      o.orderNumber ?? '--',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  DataCell(
                    Text(
                      o.unitName ?? '--',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  DataCell(
                    Text(
                      _formatDate(o.operationDate),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
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
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _confirmDeleteOrder(
    FlightOrder order,
    AppLocalizations l10n,
  ) async {
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
      SnackBar(content: Text(l10n.t('flightOrders.exportingPdf'))),
    );

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
            SnackBar(content: Text(l10n.t('flightOrders.pdfExported'))),
          );
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
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: alpha.value),
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
            Icon(
              Icons.assignment_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.t('flightOrders.empty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
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

class _ProfilesCard extends ConsumerStatefulWidget {
  const _ProfilesCard({required this.orderId, required this.onChanged});
  final String orderId;
  final VoidCallback onChanged;
  @override
  ConsumerState<_ProfilesCard> createState() => _ProfilesCardState();
}

class _ProfilesCardState extends ConsumerState<_ProfilesCard> {
  final _descCtrl = TextEditingController();
  bool _adding = false;
  List<FlightOrderProfile> _profiles = [];
  bool _loaded = false;

  @override
  void dispose() { _descCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final result = await ref.read(flightOrdersRepositoryProvider).listOrderProfiles(widget.orderId);
    if (!mounted) return;
    if (result case AppSuccess(data: final list)) {
      setState(() { _profiles = list; _loaded = true; });
    } else {
      setState(() => _loaded = true);
    }
  }

  Future<void> _add() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) return;
    setState(() => _adding = true);
    await ref.read(flightOrdersRepositoryProvider).addOrderProfile(flightOrderId: widget.orderId, description: desc);
    _descCtrl.clear();
    setState(() => _adding = false);
    widget.onChanged();
    await _load();
  }

  Future<void> _remove(String id) async {
    await ref.read(flightOrdersRepositoryProvider).removeOrderProfile(id);
    widget.onChanged();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(elevation: 1, margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(12), child: FutureBuilder(
      future: _loaded ? Future.value() : _load(),
      builder: (context, _) {
        if (!_loaded) return const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Perfiles', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          if (_profiles.isNotEmpty) ...[
            ..._profiles.map((p) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
              Text('[${p.profileLabel}] ', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
              Expanded(child: Text(p.description, style: theme.textTheme.bodySmall)),
              InkWell(onTap: () => _remove(p.id), borderRadius: BorderRadius.circular(4), child: Padding(padding: const EdgeInsets.all(2), child: Icon(Icons.close, size: 14, color: theme.colorScheme.onSurfaceVariant))),
            ]))),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Expanded(child: TextFormField(controller: _descCtrl, decoration: const InputDecoration(hintText: 'Descripción del perfil', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)), style: theme.textTheme.bodySmall)),
            const SizedBox(width: 8),
            IconButton(onPressed: _adding ? null : _add, icon: _adding ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add, size: 18)),
          ]),
        ]);
      },
    )));
  }
}
